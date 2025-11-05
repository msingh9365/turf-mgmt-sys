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
        metadata = data.get("metadata", {})
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
        
        user_candidates = User.objects.filter(sort_key__in=player_sort_keys).values_list("sort_key", "email")
        users_by_sort: dict[str, set[str]] = {}
        for sort_key, email in user_candidates:
            users_by_sort.setdefault(sort_key.upper(), set()).add(email.lower())
        
        for payload, email, sort_key in zip(players_payload, player_emails, player_sort_keys):
            name = payload["name"].strip()
            candidate_emails = users_by_sort.get(sort_key.upper(), set())
            is_registered = email in candidate_emails
            normalized_players.append(
                {
                    "name": name,
                    "email": email,
                    "sort_key": sort_key,
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
        
        metadata = {**metadata}
        metadata.setdefault("ground_id", ground.ground_id)
        metadata.setdefault("ground_name", ground.ground_name)
        # Ensure players in metadata reflect normalized players (including creator)
        metadata["players"] = normalized_players
        metadata.setdefault("slots", slot_ids)
        
        # Generate a single Booking_ID that will be shared by all slots
        booking_id = Booking.generate_booking_id()
        
        user = request.user
        
        # Track locks acquired and slots to create
        acquired_locks = []
        slots_to_book = []
        
        try:
            # Phase 1: Acquire locks and validate all slots
            for slot_id in slot_ids:
                # Try to acquire Redis lock for this slot
                lock_acquired = RedisClient.acquire_slot_lock(
                    ground_id=ground_id,
                    date=str(booking_date),
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
                    date=str(booking_date),
                    slot_id=slot_id,
                )
                
                if slot_status == "booked":
                    logger.info(
                        f"Slot {slot_id} on {booking_date} already marked as booked in Redis"
                    )
                    raise SlotAlreadyBookedError(slot_id)

                slot_conflict = Slot.objects.filter(
                    ground=ground,
                    date=booking_date,
                    slot_id=slot_id,
                    booked=True,
                ).exists()

                if slot_conflict:
                    logger.warning(
                        f"Slot {slot_id} on {booking_date} already marked as booked in DB"
                    )
                    RedisClient.mark_slot_booked(ground_id, str(booking_date), slot_id)
                    raise SlotAlreadyBookedError(slot_id)
                
                slots_to_book.append(slot_id)
            
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
                    metadata=metadata,
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

                for slot_obj in locked_slots:
                    slot_obj.booked = True
                    slot_obj.save(update_fields=["booked"])

                logger.info(
                    f"Booking created: {booking_id} for user {user.id} "
                    f"with {len(slots_to_book)} slots: {slots_to_book}"
                )

            # Phase 3: Mark all slots as booked in Redis
            for slot_id in slots_to_book:
                RedisClient.mark_slot_booked(
                    ground_id=ground_id,
                    date=str(booking_date),
                    slot_id=slot_id,
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
                    date=str(booking_date),
                    slot_id=slot_id,
                )
    
    @action(detail=False, methods=["get"], url_path="my")
    def my_bookings(self, request):
        """
        Get all bookings for the authenticated user.
        
        Returns:
            List of bookings with details
        """
        queryset = self.get_queryset().order_by("-created_at")
        serializer = BookingSerializer(queryset, many=True)
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
                        slot_obj.save(update_fields=["booked"])
                
                logger.info(
                    f"Booking cancelled via cancel endpoint: {booking_id} by user {request.user.id} "
                    f"({len(slots_cancelled)} slots: {sorted(slots_cancelled)})"
                )
            
            # Mark all slots as available in Redis
            for detail in details:
                RedisClient.mark_slot_available(
                    ground_id=detail.ground.ground_id,
                    date=str(detail.date),
                    slot_id=detail.slot_id,
                )
            
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
                        slot_obj.save(update_fields=["booked"])
                
                logger.info(
                    f"Booking cancelled: {booking_id} by user {request.user.id} "
                    f"({len(slots_cancelled)} slots: {sorted(slots_cancelled)})"
                )
            
            # Mark all slots as available in Redis
            for detail in details:
                RedisClient.mark_slot_available(
                    ground_id=detail.ground.ground_id,
                    date=str(detail.date),
                    slot_id=detail.slot_id,
                )
            
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
