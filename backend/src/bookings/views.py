"""
Views for booking management.
Implements distributed locking with Redis for concurrency control.
"""
import logging
from rest_framework import viewsets, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from django.db import transaction
from django.utils import timezone
from django.http import Http404

from .models import Booking
from .serializers import (
    BookingSerializer,
    BookingCreateSerializer,
    BookingCancelSerializer,
    BookingResponseSerializer,
)
from core.redis_client import RedisClient

logger = logging.getLogger(__name__)


class BookingViewSet(viewsets.ModelViewSet):
    """
    ViewSet for booking management.
    
    Endpoints:
    - POST /api/bookings/ - Create a new booking (with Redis lock)
    - GET /api/bookings/my/ - Get all bookings for authenticated user
    - DELETE /api/bookings/{id}/ - Cancel a booking
    """
    
    queryset = Booking.objects.all()
    serializer_class = BookingSerializer
    permission_classes = [IsAuthenticated]
    lookup_field = "booking_id"  # Using booking_id to cancel all slots in a booking
    
    def get_queryset(self):
        """Filter queryset based on the user and action."""
        if self.action == "my_bookings":
            return Booking.objects.filter(user=self.request.user)
        elif self.action == "destroy":
            # For delete, we need to check all bookings to give proper 403 vs 404
            return Booking.objects.all()
        return Booking.objects.filter(user=self.request.user)
    
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
                    return Response(
                        {"error": f"Slot {slot_id} is already booked"},
                        status=status.HTTP_409_CONFLICT,
                    )
                
                # Double-check database for existing active booking
                existing_booking = Booking.objects.filter(
                    ground_id=ground_id,
                    slot_id=slot_id,
                    date=booking_date,
                    status=Booking.STATUS_DONE,
                ).first()
                
                if existing_booking:
                    logger.warning(
                        f"Slot {slot_id} on {booking_date} already booked in database"
                    )
                    # Update Redis cache
                    RedisClient.mark_slot_booked(ground_id, str(booking_date), slot_id)
                    return Response(
                        {"error": f"Slot {slot_id} is already booked"},
                        status=status.HTTP_409_CONFLICT,
                    )
                
                slots_to_book.append(slot_id)
            
            # Phase 2: Create booking records - one row per slot, same booking_id
            with transaction.atomic():
                created_bookings = []
                for slot_id in slots_to_book:
                    booking = Booking.objects.create(
                        booking_id=booking_id,  # Same Booking_ID for all slots
                        user=user,
                        ground_id=ground_id,
                        slot_id=slot_id,
                        date=booking_date,
                        metadata=metadata,
                        status=Booking.STATUS_DONE,
                    )
                    created_bookings.append(booking)
                
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
            
            # Return success response
            return Response(
                {
                    "booking_id": booking_id,
                    "status": Booking.STATUS_DONE,
                    "slots_booked": slots_to_book,
                    "message": f"Successfully booked {len(slots_to_book)} slot(s)",
                },
                status=status.HTTP_200_OK,
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
            
            # Get all bookings with this booking_id
            bookings = Booking.objects.filter(booking_id=booking_id)
            
            if not bookings.exists():
                return Response(
                    {"error": "Booking not found"},
                    status=status.HTTP_404_NOT_FOUND,
                )
            
            # Verify ownership (check first booking, all should have same user)
            first_booking = bookings.first()
            if first_booking.user != request.user:
                return Response(
                    {"error": "You can only cancel your own bookings"},
                    status=status.HTTP_403_FORBIDDEN,
                )
            
            # Check if all bookings can be cancelled
            for booking in bookings:
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
            
            # Update all bookings status to Rejected
            with transaction.atomic():
                slots_cancelled = []
                for booking in bookings:
                    booking.status = Booking.STATUS_REJECTED
                    booking.save(update_fields=["status"])
                    slots_cancelled.append(booking.slot_id)
                
                logger.info(
                    f"Booking cancelled: {booking_id} by user {request.user.id} "
                    f"({len(slots_cancelled)} slots: {slots_cancelled})"
                )
            
            # Mark all slots as available in Redis
            for booking in bookings:
                RedisClient.mark_slot_available(
                    ground_id=booking.ground_id,
                    date=str(booking.date),
                    slot_id=booking.slot_id,
                )
            
            return Response(
                {
                    "message": f"Booking cancelled successfully ({len(slots_cancelled)} slot(s))",
                    "booking_id": booking_id,
                    "slots_cancelled": slots_cancelled,
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
