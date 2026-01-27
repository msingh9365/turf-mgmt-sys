from rest_framework import serializers
from .models import UserDevice, Notification

class UserDeviceSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserDevice
        fields = ['id', 'user', 'device_token', 'device_type', 'last_active', 'is_active', 'created_at']
        read_only_fields = ['id', 'user', 'last_active', 'created_at']
        extra_kwargs = {
            'device_token': {
                'validators': []  # Remove unique validator - update_or_create handles duplicates
            }
        }

class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ['id', 'user', 'title', 'body', 'data', 'is_read', 'created_at']
        read_only_fields = ['id', 'user', 'title', 'body', 'data', 'created_at']
