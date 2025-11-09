from django.contrib import admin
from .models import Event

@admin.register(Event)
class EventAdmin(admin.ModelAdmin):
    list_display = ("title", "sport_id", "starts_at", "created_by", "created_at", "status")
    list_filter = ("status",)
    search_fields = ("title", "location_text", "organizer_contact", "description")
    readonly_fields = ("created_at", "updated_at")
