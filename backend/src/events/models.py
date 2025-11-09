from django.db import models
from django.contrib.auth import get_user_model

User = get_user_model()

class Event(models.Model):
    PUBLISHED = "published"
    CANCELLED = "cancelled"
    STATUS_CHOICES = [(PUBLISHED, "Published"), (CANCELLED, "Cancelled")]

    # ✅ Now it's a plain integer, not a ForeignKey
    sport_id = models.IntegerField()

    poster_id = models.CharField(max_length=200)
    title = models.CharField(max_length=120)
    description = models.TextField(blank=True)
    location_text = models.CharField(max_length=200)
    starts_at = models.DateTimeField()
    organizer_contact = models.CharField(max_length=30)
    status = models.CharField(max_length=12, choices=STATUS_CHOICES, default=PUBLISHED)

    created_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name="events_created")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["starts_at"]

    def __str__(self):
        return f"{self.title} (Sport ID: {self.sport_id})"
