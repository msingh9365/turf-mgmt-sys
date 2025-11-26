from django.contrib import admin
from django.utils.html import format_html
from django.utils import timezone
from .models import Event


@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = (
        "title", "sport_id", "starts_at", "ends_at", 
        "status_badge", "organizer_name", "created_by", "is_completed_display"
    )
    list_filter = ("status", "sport_id", "starts_at", "ends_at")
    search_fields = (
        "title", "location_text", 
        "organizer_name", "organizer_contact", "description"
    )
    readonly_fields = ("created_at", "updated_at", "is_completed_display", "days_until_display")
    
    fieldsets = (
        ("Event Information", {
            "fields": ("title", "description", "status")
        }),
        ("Sport Details", {
            "fields": ("sport_id", "poster_id")
        }),
        ("Date & Time", {
            "fields": ("starts_at", "ends_at", "is_completed_display", "days_until_display")
        }),
        ("Location", {
            "fields": ("location_text",)
        }),
        ("Organizer Information", {
            "fields": ("organizer_name", "organizer_contact")
        }),
        ("Metadata", {
            "fields": ("created_by", "created_at", "updated_at"),
            "classes": ("collapse",)
        }),
    )
    
    def status_badge(self, obj):
        """Display status with color badge"""
        colors = {
            Event.PUBLISHED: "green",
            Event.COMPLETED: "orange",
            Event.CANCELLED: "red",
        }
        color = colors.get(obj.status, "gray")
        return format_html(
            '<span style="background-color: {}; color: white; padding: 3px 10px; border-radius: 3px;">{}</span>',
            color, obj.get_status_display()
        )
    status_badge.short_description = "Status"
    
    def is_completed_display(self, obj):
        """Display whether event is completed"""
        is_completed = obj.is_completed()
        color = "red" if is_completed else "green"
        text = "Yes" if is_completed else "No"
        return format_html(
            '<span style="color: {}; font-weight: bold;">{}</span>',
            color, text
        )
    is_completed_display.short_description = "Completed?"
    
    def days_until_display(self, obj):
        """Display days until event starts"""
        days = obj.days_until_start()
        if days < 0:
            return format_html('<span style="color: orange;">Started {} days ago</span>', abs(days))
        elif days == 0:
            return format_html('<span style="color: green; font-weight: bold;">Today!</span>')
        else:
            return format_html('<span style="color: blue;">In {} days</span>', days)
    days_until_display.short_description = "Days Until Start"
    
    actions = ["mark_as_completed", "mark_as_cancelled"]
    
    def mark_as_completed(self, request, queryset):
        """Mark selected events as completed"""
        updated = queryset.update(status=Event.COMPLETED)
        self.message_user(request, f"{updated} event(s) marked as completed.")
    mark_as_completed.short_description = "Mark as completed"
    
    def mark_as_cancelled(self, request, queryset):
        """Mark selected events as cancelled"""
        updated = queryset.update(status=Event.CANCELLED)
        self.message_user(request, f"{updated} event(s) marked as cancelled.")
    mark_as_cancelled.short_description = "Mark as cancelled"
