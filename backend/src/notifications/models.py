from django.db import models
from django.conf import settings

class UserDevice(models.Model):
    """
    Stores device tokens for push notifications via FCM.
    Linked to User, supports multiple devices per user.
    """
    DEVICE_TYPE_CHOICES = (
        ('android', 'Android'),
        ('ios', 'iOS'),
    )
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='devices')
    device_token = models.CharField(max_length=255, unique=True)
    device_type = models.CharField(max_length=10, choices=DEVICE_TYPE_CHOICES)
    last_active = models.DateTimeField(auto_now=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            # Optimize: filter(user=X, is_active=True) - used when sending notifications
            models.Index(fields=['user', 'is_active'], name='userdevice_user_active_idx'),
            # Optimize: filter(is_active=True) - used for broadcasts
            models.Index(fields=['is_active'], name='userdevice_active_idx'),
        ]

    def __str__(self):
        return f"{self.user.email} - {self.device_type}"

    # Inline comment: device_token is validated in API before saving

class Notification(models.Model):
    """
    Stores notification history for users.
    Created when a notification is sent successfully via FCM.
    """
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='notifications')
    title = models.CharField(max_length=255)
    body = models.TextField()
    data = models.JSONField(blank=True, null=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        indexes = [
            # Optimize: filter(user=X).order_by('-created_at') - notification history
            models.Index(fields=['user', '-created_at'], name='notif_user_created_idx'),
            # Optimize: filter(user=X, is_read=False) - unread count and mark all as read
            models.Index(fields=['user', 'is_read'], name='notif_user_read_idx'),
            # Optimize: filter(user=X, is_read=False).order_by('-created_at') - unread notifications
            models.Index(fields=['user', 'is_read', '-created_at'], name='notif_user_read_created_idx'),
        ]

    def __str__(self):
        return f"{self.title} to {self.user.email}"