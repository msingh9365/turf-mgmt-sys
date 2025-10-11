"""
Celery tasks for background processing
"""
from celery import shared_task
from django.contrib.auth import get_user_model
from fcm_django.models import FCMDevice
from .models import Notification

User = get_user_model()


@shared_task
def send_notification(user_id, notification_type, title, message, data=None):
    """
    Send push notification to user
    """
    try:
        user = User.objects.get(id=user_id)
        
        # Create notification record
        notification = Notification.objects.create(
            user=user,
            notification_type=notification_type,
            title=title,
            message=message,
            data=data or {}
        )
        
        # Send FCM notification if user has FCM token
        if user.fcm_token:
            try:
                devices = FCMDevice.objects.filter(user=user, active=True)
                devices.send_message(
                    title=title,
                    body=message,
                    data=data or {}
                )
            except Exception as e:
                print(f"Error sending FCM notification: {e}")
        
        return f"Notification sent to {user.username}"
    except User.DoesNotExist:
        return f"User {user_id} not found"
    except Exception as e:
        return f"Error: {str(e)}"


@shared_task
def send_booking_reminder():
    """
    Send reminder notifications for upcoming bookings
    """
    from django.utils import timezone
    from datetime import timedelta
    from .models import Booking
    
    tomorrow = timezone.now().date() + timedelta(days=1)
    
    # Get bookings for tomorrow
    upcoming_bookings = Booking.objects.filter(
        booking_date=tomorrow,
        status='confirmed'
    )
    
    for booking in upcoming_bookings:
        send_notification.delay(
            booking.user.id,
            'reminder',
            'Booking Reminder',
            f'You have a booking for {booking.ground.name} tomorrow at {booking.time_slot.start_time}'
        )
    
    return f"Sent {upcoming_bookings.count()} reminders"


@shared_task
def cleanup_old_notifications():
    """
    Clean up old read notifications (older than 30 days)
    """
    from django.utils import timezone
    from datetime import timedelta
    
    cutoff_date = timezone.now() - timedelta(days=30)
    deleted_count = Notification.objects.filter(
        is_read=True,
        sent_at__lt=cutoff_date
    ).delete()[0]
    
    return f"Deleted {deleted_count} old notifications"
