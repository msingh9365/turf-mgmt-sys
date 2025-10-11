"""
Admin configuration for models
"""
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from .models import (
    User, SportsType, Ground, TimeSlot, Booking,
    Team, TeamRequest, Notification, BookingQueue
)


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    list_display = ['username', 'email', 'user_type', 'department', 'is_staff']
    list_filter = ['user_type', 'is_staff', 'is_superuser', 'department']
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Additional Info', {
            'fields': ('user_type', 'phone_number', 'roll_number', 'department', 'fcm_token')
        }),
    )
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('Additional Info', {
            'fields': ('user_type', 'phone_number', 'roll_number', 'department')
        }),
    )


@admin.register(SportsType)
class SportsTypeAdmin(admin.ModelAdmin):
    list_display = ['name', 'is_active', 'created_at']
    list_filter = ['is_active']
    search_fields = ['name']


@admin.register(Ground)
class GroundAdmin(admin.ModelAdmin):
    list_display = ['name', 'sports_type', 'location', 'capacity', 'is_available']
    list_filter = ['sports_type', 'is_available']
    search_fields = ['name', 'location']


@admin.register(TimeSlot)
class TimeSlotAdmin(admin.ModelAdmin):
    list_display = ['ground', 'start_time', 'end_time', 'is_available']
    list_filter = ['ground', 'is_available']


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    list_display = ['user', 'ground', 'booking_date', 'status', 'queue_position', 'created_at']
    list_filter = ['status', 'booking_date', 'ground']
    search_fields = ['user__username', 'ground__name']
    date_hierarchy = 'booking_date'


@admin.register(Team)
class TeamAdmin(admin.ModelAdmin):
    list_display = ['name', 'sports_type', 'captain', 'is_active', 'created_at']
    list_filter = ['sports_type', 'is_active']
    search_fields = ['name', 'captain__username']
    filter_horizontal = ['members']


@admin.register(TeamRequest)
class TeamRequestAdmin(admin.ModelAdmin):
    list_display = ['user', 'team', 'status', 'created_at']
    list_filter = ['status', 'team']
    search_fields = ['user__username', 'team__name']


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ['user', 'notification_type', 'title', 'is_read', 'sent_at']
    list_filter = ['notification_type', 'is_read', 'sent_at']
    search_fields = ['user__username', 'title']


@admin.register(BookingQueue)
class BookingQueueAdmin(admin.ModelAdmin):
    list_display = ['booking', 'position', 'estimated_wait_time', 'notified', 'created_at']
    list_filter = ['notified']
    search_fields = ['booking__user__username']
