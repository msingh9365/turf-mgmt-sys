"""
Django signals for the bookings app.
Handles automatic notifications and other post-save actions.
"""
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
    """
    # Only send notification for new bookings with Done status
    if created and instance.status == Booking.STATUS_DONE:
        try:
            # Import here to avoid circular imports
            from notifications.utils import FCMNotificationSender
            
            # Get booking details for notification
            detail = instance.booked_details.first()
            ground_name = detail.ground.ground_name if detail and detail.ground else "your chosen ground"
            
            # Send notification
            sender_obj = FCMNotificationSender()
            sender_obj.send_to_user(
                user=instance.user,
                title="Booking Confirmed!",
                body=f"Your booking {instance.booking_id} for {ground_name} on {instance.date} is confirmed.",
                data={
                    "booking_id": instance.booking_id,
                    "date": str(instance.date),
                    "status": instance.status,
                    "type": "booking_confirmation"
                }
            )
            logger.info(f"Notification sent for booking {instance.booking_id} to user {instance.user.id}")
        except Exception as e:
            # Log error but don't fail the booking creation
            logger.error(f"Failed to send notification for booking {instance.booking_id}: {str(e)}")
