"""
Django admin configuration for bookings.
"""
from django.contrib import admin
from .models import Booking


@admin.register(Booking)
class BookingAdmin(admin.ModelAdmin):
    """Admin interface for Booking model."""
    
    list_display = ("unique_id", "user", "ground_id", "slot_id", "date", "status", "created_at")
    list_filter = ("status", "date", "created_at")
    search_fields = ("unique_id", "user__email", "user__name")
    readonly_fields = ("unique_id", "created_at")
    ordering = ("-created_at",)
    
    fieldsets = (
        ("Booking Information", {
            "fields": ("unique_id", "user", "ground_id", "slot_id", "date")
        }),
        ("Status & Metadata", {
            "fields": ("status", "metadata")
        }),
        ("Timestamps", {
            "fields": ("created_at",)
        }),
    )
