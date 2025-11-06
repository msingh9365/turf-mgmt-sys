"""
Views for booking management.
Implements distributed locking with Redis for concurrency control.
"""
import logging
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from django.http import Http404

from .models import Booking, Booked_Details, Slot, Ground
from .serializers import (
    BookingSerializer,
    BookingSummarySerializer,
    BookingCreateSerializer,
    BookingCancelSerializer,
    BookingResponseSerializer,
)
from core.redis_client import RedisClient

logger = logging.getLogger(__name__)
User = get_user_model()


def _derive_sort_key(email: str) -> str:
    """Return the first seven characters of the email local part as sort key."""
    local_part = email.split("@")[0]
    return local_part[:7].upper()


class SlotAlreadyBookedError(Exception):
    """Raised when a requested slot is already booked."""

    def __init__(self, slot_id: int):
        super().__init__(f"Slot {slot_id} is already booked")
        self.slot_id = slot_id


class BookingViewSet(viewsets.ModelViewSet):
    """
    ViewSet for booking management.
    
    Endpoints:
    - POST /api/bookings/ - Create a new booking (with Redis lock)
    - GET /api/bookings/my/ - Get all bookings for authenticated user
    - DELETE /api/bookings/{id}/ - Cancel a booking
    """
    
    queryset = Booking.objects.select_related("user").prefetch_related("booked_details__ground")
    serializer_class = BookingSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = "booking_id"  # Using booking_id to cancel all slots in a booking
    
    def get_queryset(self):
        """Filter queryset based on the user and action."""
        base_qs = Booking.objects.select_related("user").prefetch_related("booked_details__ground")
        if self.action == "destroy":
            # For delete, we need to check all bookings to give proper 403 vs 404
            return base_qs
        return base_qs.filter(user=self.request.user)
    
    def create(self, request, *args, **kwargs):
        """
        Create a new booking for one or multiple slots.
        All slots will share the same Booking_ID.
        
        Flow:
        1. Validate input (date, slot_ids, ground_id)
        2. Acquire Redis locks for ALL slots (fail if any slot locked/booked)
        3. Create booking records with same Booking_ID (one row per slot)
        4. Mark all slots as booked in Redis
        5. Release all locks
        
        Returns:
            200: Booking created successfully with list of slots_booked
            400: Validation error (past date, slot already booked, etc.)
            409: Conflict (slot locked by another user)
            500: Server error (rollback if any step fails)
        """
        serializer = BookingCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        data = serializer.validated_data
        ground_id = data["ground_id"]
        slot_ids = data["slot_id"]  # This is a list now
        booking_date = data["date"]
    # metadata field removed from model; all derived info comes from related Booked_Details
        players_payload = data["players"]
        player_emails = [player["email"].lower() for player in players_payload]
        player_sort_keys = [_derive_sort_key(email) for email in player_emails]
        normalized_players = []
        try:
            ground = Ground.objects.get(ground_id=ground_id)
        except Ground.DoesNotExist:
            return Response(
                {"error": "Ground does not exist"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        # Use Q objects for case-insensitive OR lookup across multiple sort keys
        from django.db.models import Q
        q_objects = Q()
        for sk in player_sort_keys:
            q_objects |= Q(sort_key__iexact=sk)
        
        user_candidates = User.objects.filter(q_objects).values_list("sort_key", "email")
        users_by_sort: dict[str, set[str]] = {}
        for sort_key, email in user_candidates:
            users_by_sort.setdefault(sort_key.upper(), set()).add(email.lower())
        
        for payload, email, original_sort_key in zip(players_payload, player_emails, player_sort_keys):
            name = payload["name"].strip()
            # Use uppercase sort key for case-insensitive lookup
            sort_key_upper = original_sort_key.upper()
            candidate_emails = users_by_sort.get(sort_key_upper, set())
            is_registered = email in candidate_emails
            normalized_players.append(
                {
                    "name": name,
                    "email": email,
                    "sort_key": sort_key_upper,  # Store uppercase for consistency
                    "is_user": is_registered,
                }
            )

        # Ensure the booking creator is included in booked_details
        creator_email = request.user.email.lower()
        if creator_email and creator_email not in {p["email"] for p in normalized_players}:
            creator_name = getattr(request.user, "name", "").strip() or request.user.email
            creator_sort_key = _derive_sort_key(creator_email)
            normalized_players.append(
                {
                    "name": creator_name,
                    "email": creator_email,
                    "sort_key": creator_sort_key,
                    "is_user": True,
                }
            )
        
        # Member Lock System: Check if any registered user already has a booking on this ground/date
        registered_player_emails = [p["email"] for p in normalized_players if p["is_user"]]
        
        if registered_player_emails:
            # Check for existing active bookings for these members on the same ground and date
            # Optimized query: uses composite index (ground, date, is_user) and only fetches needed fields
            conflicting_booking = (
                Booked_Details.objects
                .filter(
                    ground=ground,
                    date=booking_date,
                    is_user=True,  # Filter early for index usage
                    player_email__in=registered_player_emails,
                )
                .filter(booking__status=Booking.STATUS_DONE)  # Separate filter for better query plan
                .values('player_email', 'player_name', 'booking_id')  # Only fetch needed fields
                .first()  # Stop at first conflict (more efficient than distinct())
            )
            
            if conflicting_booking:
                conflicting_player_email = conflicting_booking['player_email']
                conflicting_player_name = conflicting_booking['player_name']
                conflicting_booking_id = conflicting_booking['booking_id']
                
                logger.warning(
                    f"Member lock violation: {conflicting_player_email} already has booking "
                    f"{conflicting_booking_id} on {ground.ground_name} for {booking_date}"
                )
                return Response(
                    {
                        "error": "Member lock violation",
                        "message": f"Player '{conflicting_player_name}' ({conflicting_player_email}) "
                                   f"already has an active booking on this ground for {booking_date}. "
                                   f"Booking ID: {conflicting_booking_id}",
                        "conflicting_player": conflicting_player_email,
                        "existing_booking_id": conflicting_booking_id,
                    },
                    status=status.HTTP_409_CONFLICT,
                )
        
    # metadata removed: ground/players/slots information will be derived from Booked_Details
        
        # Generate a single Booking_ID that will be shared by all slots
        booking_id = Booking.generate_booking_id()
        
        user = request.user
        
        # Convert booking_date to string once (optimization: reuse throughout)
        booking_date_str = str(booking_date)
        
        # Track locks acquired and slots to create
        acquired_locks = []
        slots_to_book = []
        
        try:
            # Phase 1: Acquire locks and validate all slots
            for slot_id in slot_ids:
                # Try to acquire Redis lock for this slot
                lock_acquired = RedisClient.acquire_slot_lock(
                    ground_id=ground_id,
                    date=booking_date_str,
                    slot_id=slot_id,
                    user_id=user.id,
                    ttl=10,  # 10 seconds lock timeout
                )
                
                if not lock_acquired:
                    logger.warning(
                        f"Lock acquisition failed for slot {slot_id} on {booking_date} "
                        f"by user {user.id}"
                    )
                    return Response(
                        {"error": f"Slot {slot_id} is being booked by another user. Please try again."},
                        status=status.HTTP_409_CONFLICT,
                    )
                
                acquired_locks.append(slot_id)

                # Check Redis cache for slot status
                slot_status = RedisClient.get_slot_status(
                    ground_id=ground_id,
                    date=booking_date_str,
                    slot_id=slot_id,
                )
                
                if slot_status == "booked":
                    logger.info(
                        f"Slot {slot_id} on {booking_date} already marked as booked in Redis"
                    )
                    raise SlotAlreadyBookedError(slot_id)
            
            # Batch check: Query all slots at once for conflicts (optimization: 1 query instead of N)
            already_booked_slots = set(
                Slot.objects.filter(
                    ground=ground,
                    date=booking_date,
                    slot_id__in=slot_ids,
                    booked=True,
                ).values_list('slot_id', flat=True)
            )
            
            if already_booked_slots:
                conflicting_slot = list(already_booked_slots)[0]
                logger.warning(
                    f"Slot {conflicting_slot} on {booking_date} already marked as booked in DB"
                )
                # Sync Redis cache for the conflicting slot
                RedisClient.mark_slot_booked(ground_id, booking_date_str, conflicting_slot)
                raise SlotAlreadyBookedError(conflicting_slot)
            
            slots_to_book = slot_ids
            
            # Phase 2: Create booking records - one row per slot, same booking_id
            with transaction.atomic():
                locked_slots = []
                for slot_id in slots_to_book:
                    slot_obj, _ = Slot.objects.select_for_update().get_or_create(
                        ground=ground,
                        date=booking_date,
                        slot_id=slot_id,
                        defaults={"booked": False},
                    )
                    if slot_obj.booked:
                        logger.warning(
                            f"Slot {slot_id} on {booking_date} already booked during transaction"
                        )
                        raise SlotAlreadyBookedError(slot_id)
                    locked_slots.append(slot_obj)

                booking = Booking.objects.create(
                    booking_id=booking_id,
                    user=user,
                    date=booking_date,
                    status=Booking.STATUS_DONE,
                )

                details = [
                    Booked_Details(
                        booking=booking,
                        player_name=player_info["name"],
                        player_email=player_info["email"],
                        sort_key=player_info["sort_key"],
                        ground=ground,
                        is_user=player_info["is_user"],
                        date=booking_date,
                        slot_id=slot_id,
                    )
                    for slot_id in slots_to_book
                    for player_info in normalized_players
                ]
                if details:
                    Booked_Details.objects.bulk_create(details)

                # Bulk update: Mark all slots as booked (optimization: 1 query instead of N)
                for slot_obj in locked_slots:
                    slot_obj.booked = True
                Slot.objects.bulk_update(locked_slots, ['booked'])

                logger.info(
                    f"Booking created: {booking_id} for user {user.id} "
                    f"with {len(slots_to_book)} slots: {slots_to_book}"
                )

            # Phase 3: Mark all slots as booked in Redis (batch operation: 1 pipeline instead of N round trips)
            RedisClient.mark_slots_booked_batch(
                ground_id=ground_id,
                date=booking_date_str,
                slot_ids=slots_to_book,
            )

            response_payload = {
                "booking_id": booking_id,
                "status": Booking.STATUS_DONE,
                "slots_booked": slots_to_book,
                "players": normalized_players,
                "message": f"Successfully booked {len(slots_to_book)} slot(s)",
            }

            return Response(response_payload, status=status.HTTP_200_OK)

        except SlotAlreadyBookedError as conflict:
            logger.warning(
                f"Slot booking conflict for user {user.id}: booking_id={booking_id}, slot={conflict.slot_id}"
            )
            return Response(
                {"error": f"Slot {conflict.slot_id} is already booked"},
                status=status.HTTP_409_CONFLICT,
            )

        except Exception as e:
            logger.error(f"Error creating booking: {str(e)}", exc_info=True)
            return Response(
                {"error": "An error occurred while creating the booking"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        finally:
            # Always release all acquired locks
            for slot_id in acquired_locks:
                RedisClient.release_slot_lock(
                    ground_id=ground_id,
                    date=booking_date_str,
                    slot_id=slot_id,
                )
    
    @action(detail=False, methods=["get"], url_path="my")
    def my_bookings(self, request):
        """
        Get all bookings for the authenticated user.
        
        Returns:
            List of bookings in summary format required by client
        """
        queryset = self.get_queryset().order_by("-created_at")
        serializer = BookingSummarySerializer(queryset, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)
    
    @action(detail=True, methods=["post"], url_path="cancel")
    def cancel_booking(self, request, booking_id=None):
        """
        Cancel a booking by setting its status to 'Rejected'.
        Frees all associated slots.
        
        URL: POST /api/bookings/{booking_id}/cancel/
        
        Validations:
        1. Booking must belong to the authenticated user
        2. Booking must be in 'Done' status
        3. Booking date must be in the future
        
        Updates:
        - Database: Status = 'Rejected'
        - Slots: booked = False
        - Redis: All slots marked as 'available'
        """
        try:
            booking = (
                Booking.objects.select_related("user")
                .prefetch_related("booked_details__ground")
                .filter(booking_id=booking_id)
                .first()
            )
            
            if not booking:
                return Response(
                    {"error": "Booking not found"},
                    status=status.HTTP_404_NOT_FOUND,
                )
            
            # Verify ownership
            if booking.user != request.user:
                return Response(
                    {"error": "You can only cancel your own bookings"},
                    status=status.HTTP_403_FORBIDDEN,
                )
            
            # Check if booking can be cancelled
            if booking.status != Booking.STATUS_DONE:
                return Response(
                    {"error": f"Cannot cancel booking with status '{booking.status}'"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            
            if not booking.can_be_cancelled:
                return Response(
                    {"error": "Cannot cancel past bookings or bookings that have started"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            details = list(booking.booked_details.all())
            slots_cancelled = set()

            # Update booking status and slot availability
            with transaction.atomic():
                booking.status = Booking.STATUS_REJECTED
                booking.save(update_fields=["status"])

                # Collect slot objects and mark as available (batch optimization)
                slots_to_update = []
                redis_batch_data = []
                for detail in details:
                    slots_cancelled.add(detail.slot_id)
                    slot_obj = (
                        Slot.objects.select_for_update()
                        .filter(
                            ground=detail.ground,
                            date=detail.date,
                            slot_id=detail.slot_id,
                        )
                        .first()
                    )
                    if slot_obj:
                        slot_obj.booked = False
                        slots_to_update.append(slot_obj)
                    redis_batch_data.append((detail.ground.ground_id, str(detail.date), detail.slot_id))
                
                # Bulk update all slots in one query
                if slots_to_update:
                    Slot.objects.bulk_update(slots_to_update, ['booked'])
                
                logger.info(
                    f"Booking cancelled via cancel endpoint: {booking_id} by user {request.user.id} "
                    f"({len(slots_cancelled)} slots: {sorted(slots_cancelled)})"
                )
            
            # Mark all slots as available in Redis (batch operation)
            if details:
                # Group by ground and date for efficient batching
                first_detail = details[0]
                ground_id = first_detail.ground.ground_id
                date_str = str(first_detail.date)
                slot_ids = [detail.slot_id for detail in details]
                RedisClient.mark_slots_available_batch(ground_id, date_str, slot_ids)

            
            return Response(
                {
                    "message": f"Booking cancelled successfully ({len(slots_cancelled)} slot(s))",
                    "booking_id": booking_id,
                    "status": "Rejected",
                    "slots_cancelled": sorted(slots_cancelled),
                },
                status=status.HTTP_200_OK,
            )
        
        except Exception as e:
            logger.error(f"Error cancelling booking: {str(e)}", exc_info=True)
            return Response(
                {"error": "An error occurred while cancelling the booking"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
    
    def destroy(self, request, *args, **kwargs):
        """
        Cancel a booking (mark as Rejected).
        Cancels ALL slots associated with the same booking_id.
        
        Validations:
        1. Booking must belong to the authenticated user
        2. Booking must be in 'Done' status
        3. Booking date must be in the future
        
        Updates:
        - Database: Status = 'Rejected' for all slots with same booking_id
        - Redis: All slots marked as 'available'
        """
        try:
            # Get the booking_id from URL
            booking_id = self.kwargs.get('booking_id')
            
            booking = (
                Booking.objects.select_related("user")
                .prefetch_related("booked_details__ground")
                .filter(booking_id=booking_id)
                .first()
            )
            
            if not booking:
                return Response(
                    {"error": "Booking not found"},
                    status=status.HTTP_404_NOT_FOUND,
                )
            
            # Verify ownership (check first booking, all should have same user)
            if booking.user != request.user:
                return Response(
                    {"error": "You can only cancel your own bookings"},
                    status=status.HTTP_403_FORBIDDEN,
                )
            
            # Check if all bookings can be cancelled
            if booking.status != Booking.STATUS_DONE:
                return Response(
                    {"error": f"Cannot cancel booking with status '{booking.status}'"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            
            if not booking.can_be_cancelled:
                return Response(
                    {"error": "Cannot cancel past bookings or bookings that have started"},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            details = list(booking.booked_details.all())
            
            slots_cancelled = set()

            # Update booking status and slot availability
            with transaction.atomic():
                booking.status = Booking.STATUS_REJECTED
                booking.save(update_fields=["status"])

                # Collect slot objects and mark as available (batch optimization)
                slots_to_update = []
                for detail in details:
                    slots_cancelled.add(detail.slot_id)
                    slot_obj = (
                        Slot.objects.select_for_update()
                        .filter(
                            ground=detail.ground,
                            date=detail.date,
                            slot_id=detail.slot_id,
                        )
                        .first()
                    )
                    if slot_obj:
                        slot_obj.booked = False
                        slots_to_update.append(slot_obj)
                
                # Bulk update all slots in one query
                if slots_to_update:
                    Slot.objects.bulk_update(slots_to_update, ['booked'])
                
                logger.info(
                    f"Booking cancelled: {booking_id} by user {request.user.id} "
                    f"({len(slots_cancelled)} slots: {sorted(slots_cancelled)})"
                )
            
            # Mark all slots as available in Redis (batch operation)
            if details:
                # Group by ground and date for efficient batching
                first_detail = details[0]
                ground_id = first_detail.ground.ground_id
                date_str = str(first_detail.date)
                slot_ids = [detail.slot_id for detail in details]
                RedisClient.mark_slots_available_batch(ground_id, date_str, slot_ids)

            
            return Response(
                {
                    "message": f"Booking cancelled successfully ({len(slots_cancelled)} slot(s))",
                    "booking_id": booking_id,
                    "slots_cancelled": sorted(slots_cancelled),
                },
                status=status.HTTP_200_OK,
            )
        
        except Http404:
            return Response(
                {"error": "Booking not found"},
                status=status.HTTP_404_NOT_FOUND,
            )
        except Exception as e:
            logger.error(f"Error cancelling booking: {str(e)}", exc_info=True)
            return Response(
                {"error": "An error occurred while cancelling the booking"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )
    
    @action(detail=False, methods=["get"], url_path="booked-slots")
    def booked_slots(self, request):
        """
        Get list of booked slot IDs for a given date and ground.
        
        Query Parameters:
            - date (required): Date in YYYY-MM-DD format
            - ground_id (required): Ground ID
        
        Returns:
            200: {
                "ground_id": int,
                "date": str,
                "booked_slot_ids": [list of slot IDs]
            }
            400: Validation error (missing or invalid parameters)
        """
        # Get and validate query parameters
        date_str = request.query_params.get("date")
        ground_id_str = request.query_params.get("ground_id")
        
        if not date_str:
            return Response(
                {"error": "Missing required parameter: date"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        if not ground_id_str:
            return Response(
                {"error": "Missing required parameter: ground_id"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        # Validate ground_id
        try:
            ground_id = int(ground_id_str)
        except ValueError:
            return Response(
                {"error": "Invalid ground_id: must be an integer"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        # Validate date format
        try:
            from datetime import datetime
            booking_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            return Response(
                {"error": "Invalid date format. Use YYYY-MM-DD"},
                status=status.HTTP_400_BAD_REQUEST,
            )
        
        # Check if ground exists
        try:
            ground = Ground.objects.get(ground_id=ground_id)
        except Ground.DoesNotExist:
            return Response(
                {"error": f"Ground with ID {ground_id} does not exist"},
                status=status.HTTP_404_NOT_FOUND,
            )
        
        # Query booked slots from Slot table
        booked_slots = Slot.objects.filter(
            ground=ground,
            date=booking_date,
            booked=True
        ).values_list('slot_id', flat=True).order_by('slot_id')
        
        return Response(
            {
                "ground_id": ground_id,
                "ground_name": ground.ground_name,
                "date": date_str,
                "booked_slot_ids": list(booked_slots),
            },
            status=status.HTTP_200_OK,
        )
