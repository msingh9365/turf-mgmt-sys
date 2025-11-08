from django.contrib import admin
from .models import UserDevice, Notification

@admin.register(UserDevice)
class UserDeviceAdmin(admin.ModelAdmin):
    list_display = ('user', 'device_token', 'device_type', 'last_active', 'is_active', 'created_at')
    search_fields = ('user__email', 'device_token')
    list_filter = ('device_type', 'is_active')

@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ('user', 'title', 'body', 'is_read', 'created_at')
    search_fields = ('user__email', 'title', 'body')
    list_filter = ('is_read',)
