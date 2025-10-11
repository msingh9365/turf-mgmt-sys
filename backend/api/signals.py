"""
Signal handlers for model events
"""
from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import Booking, TeamRequest


@receiver(post_save, sender=Booking)
def booking_status_changed(sender, instance, created, **kwargs):
    """
    Handle booking status changes
    """
    if not created and instance.status == 'confirmed':
        # Booking was confirmed
        from .tasks import send_notification
        send_notification.delay(
            instance.user.id,
            'booking_confirmed',
            'Booking Confirmed',
            f'Your booking for {instance.ground.name} on {instance.booking_date} has been confirmed.'
        )


@receiver(post_save, sender=TeamRequest)
def team_request_created(sender, instance, created, **kwargs):
    """
    Notify team captain when a new join request is created
    """
    if created:
        from .tasks import send_notification
        send_notification.delay(
            instance.team.captain.id,
            'team_request',
            'New Team Request',
            f'{instance.user.username} wants to join your team {instance.team.name}'
        )
