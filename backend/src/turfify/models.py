# FILE: I:\PGSL Project\turf-mgmt-sys\backend\src\turfify\models.py

from django.db import models
from django.conf import settings 
# Assuming Django's settings are available to access AUTH_USER_MODEL

# Get the User model dynamically
User = settings.AUTH_USER_MODEL 

class DeviceToken(models.Model):
    """
    Stores the FCM Registration Token for a user's device.
    One user can have many tokens (devices).
    """
    
    # 1. Link to the User
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='device_tokens')
    
    # 2. The token itself. Must be unique.
    token = models.CharField(max_length=255, unique=True, verbose_name="FCM Registration Token")
    
    # 3. Status flag (useful for marking tokens as expired/inactive if FCM reports errors)
    is_active = models.BooleanField(default=True) 
    
    # 4. Timestamps for tracking
    updated_at = models.DateTimeField(auto_now=True)
    
    class Meta:
        verbose_name = "Device Token"
        verbose_name_plural = "Device Tokens"

    def __str__(self):
        return f"Token for {self.user.username} (Active: {self.is_active})"