"""
Django signals for the bookings app.
Handles automatic notifications and other post-save actions.
"""
from django.db import transaction
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Booking
import logging

logger = logging.getLogger(__name__)


@receiver(post_save, sender=Booking)
def send_booking_notification(sender, instance, created, **kwargs):
    """
    Send a push notification to the user when a new booking is created.
    Only sends for newly created bookings with 'Done' status.
    Uses transaction.on_commit() with lambda to ensure zero-latency async execution.
    """
    # Only send notification for new bookings with Done status
    if created and instance.status == Booking.STATUS_DONE:
        # Capture data now (inside transaction) to avoid re-querying later
        booking_id = instance.booking_id
        user_id = instance.user.id
        date = instance.date
        status = instance.status
        
        # Get booking details for notification (before commit callback)
        detail = instance.booked_details.first()
        ground_name = detail.ground.ground_name if detail and detail.ground else "your chosen ground"
        
        def send_notification_callback():
            """Lightweight callback that immediately spawns async thread"""
            try:
                from notifications.tasks import send_notification_async
                
                # Spawn async immediately - doesn't block commit
                send_notification_async(
                    user_id=user_id,
                    title="Booking Confirmed!",
                    body=f"Your booking {booking_id} for {ground_name} on {date} is confirmed.",
                    data={
                        "booking_id": booking_id,
                        "date": str(date),
                        "status": status,
                        "type": "booking_confirmation"
                    }
                )
                logger.info(f"Async notification thread spawned for booking {booking_id}")
            except Exception as e:
                logger.error(f"Failed to spawn notification thread for booking {booking_id}: {str(e)}")
        
        # Register callback - executes during commit but spawns thread immediately
        transaction.on_commit(send_notification_callback)
