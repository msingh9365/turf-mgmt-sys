from django.db import models
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import timedelta

User = get_user_model()

class Event(models.Model):
    PUBLISHED = "published"
    CANCELLED = "cancelled"
    COMPLETED = "completed"
    STATUS_CHOICES = [
        (PUBLISHED, "Published"), 
        (CANCELLED, "Cancelled"),
        (COMPLETED, "Completed")
    ]

    # Sport ID (frontend maps to sport name: 101=Football, 102=Cricket, etc.)
    sport_id = models.IntegerField(help_text="Sport ID reference")

    # Event details
    poster_id = models.CharField(max_length=200, help_text="Poster filename or URL selected by user")
    title = models.CharField(max_length=120, help_text="Tournament/Event title")
    description = models.TextField(blank=True, help_text="Tournament description")
    location_text = models.CharField(max_length=200, help_text="Venue location")
    
    # Date & Time
    starts_at = models.DateTimeField(help_text="Event start date and time")
    ends_at = models.DateTimeField(help_text="Event end date and time")
    
    # Organizer information
    organizer_name = models.CharField(max_length=100, help_text="Name of the organizer")
    organizer_contact = models.CharField(max_length=30, help_text="Contact number of organizer")
    
    # Status and metadata
    status = models.CharField(max_length=12, choices=STATUS_CHOICES, default=PUBLISHED)
    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="events_created")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["starts_at"]
        indexes = [
            models.Index(fields=['starts_at', 'status']),
            models.Index(fields=['ends_at']),
        ]

    def __str__(self):
        return f"{self.title} (Sport ID: {self.sport_id})"
    
    def is_completed(self):
        """Check if event has passed (ends_at is in the past)"""
        return timezone.now() > self.ends_at
    
    def should_auto_delete(self):
        """Check if event should be auto-deleted (3 days after completion)"""
        if not self.is_completed():
            return False
        delete_threshold = self.ends_at + timedelta(days=3)
        return timezone.now() > delete_threshold
    
    def days_until_start(self):
        """Return days until event starts (negative if already started)"""
        delta = self.starts_at - timezone.now()
        return delta.days
    
    def save(self, *args, **kwargs):
        """Auto-update status to COMPLETED if event has ended"""
        if self.is_completed() and self.status == self.PUBLISHED:
            self.status = self.COMPLETED
        super().save(*args, **kwargs)
