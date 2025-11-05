"""
Django admin configuration for bookings.
"""
from django.contrib import admin
from .models import Booking


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    """Admin interface for Booking model."""
    
    list_display = ("booking_id", "user", "date", "status", "created_at")
    list_filter = ("status", "date", "created_at")
    search_fields = ("booking_id", "user__email", "user__name")
    readonly_fields = ("booking_id", "created_at")
    ordering = ("-created_at",)
    
    fieldsets = (
        ("Booking Information", {
            "fields": ("booking_id", "user", "date")
        }),
        ("Status & Metadata", {
            "fields": ("status", "metadata")
        }),
        ("Timestamps", {
            "fields": ("created_at",)
        }),
    )
