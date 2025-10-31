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
    lookup_field = "unique_id"
    
    def get_queryset(self):
        """Filter queryset based on the user."""
        if self.action == "my_bookings":
            return Booking.objects.filter(user=self.request.user)
        return Booking.objects.filter(user=self.request.user)
    
    def create(self, request, *args, **kwargs):
        """
        Create a new booking with distributed Redis locking.
        
        Flow:
        1. Validate input data
        2. Acquire Redis lock for the slot
        3. Check if slot is already booked (Redis + DB)
        4. Create booking in database (atomic transaction)
        5. Mark slot as booked in Redis
        6. Release lock
        """
        # Validate input
        serializer = BookingCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        ground_id = serializer.validated_data["ground_id"]
        slot_id = serializer.validated_data["slot_id"]
        booking_date = serializer.validated_data["date"]
        metadata = serializer.validated_data.get("metadata", {})
        
        user = request.user
        
        # Try to acquire Redis lock
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
                {"error": "Slot is being booked by another user. Please try again."},
                status=status.HTTP_409_CONFLICT,
            )
        
        try:
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
                    {"error": "Slot already booked"},
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
                    {"error": "Slot already booked"},
                    status=status.HTTP_409_CONFLICT,
                )
            
            # Create booking in atomic transaction
            with transaction.atomic():
                booking = Booking.objects.create(
                    user=user,
                    ground_id=ground_id,
                    slot_id=slot_id,
                    date=booking_date,
                    metadata=metadata,
                    status=Booking.STATUS_DONE,
                )
                
                logger.info(
                    f"Booking created: {booking.unique_id} for user {user.id}"
                )
            
            # Mark slot as booked in Redis
            RedisClient.mark_slot_booked(
                ground_id=ground_id,
                date=str(booking_date),
                slot_id=slot_id,
            )
            
            # Return success response
            return Response(
                {
                    "booking_id": booking.unique_id,
                    "status": booking.status,
                    "message": "Booking confirmed successfully",
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
            # Always release the lock
            RedisClient.release_slot_lock(
                ground_id=ground_id,
                date=str(booking_date),
                slot_id=slot_id,
            )
            logger.debug(f"Lock released for slot {slot_id} on {booking_date}")
    
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
        
        Validations:
        1. Booking must belong to the authenticated user
        2. Booking must be in 'Done' status
        3. Booking date must be in the future
        
        Updates:
        - Database: Status = 'Rejected'
        - Redis: Slot marked as 'available'
        """
        try:
            # Get booking by unique_id
            booking = self.get_object()
            
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
            
            # Check if booking date is in the future
            if not booking.can_be_cancelled:
                return Response(
                    {"error": "Cannot cancel past bookings or bookings that have started"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            
            # Update booking status to Rejected
            with transaction.atomic():
                booking.status = Booking.STATUS_REJECTED
                booking.save(update_fields=["status"])
                
                logger.info(
                    f"Booking cancelled: {booking.unique_id} by user {request.user.id}"
                )
            
            # Mark slot as available in Redis
            RedisClient.mark_slot_available(
                ground_id=booking.ground_id,
                date=str(booking.date),
                slot_id=booking.slot_id,
            )
            
            return Response(
                {
                    "message": "Booking cancelled successfully",
                    "booking_id": booking.unique_id,
                },
                status=status.HTTP_200_OK,
            )
        
        except Booking.DoesNotExist:
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
