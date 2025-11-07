"""
Booking model for turf management system.
Stores booking information in Supabase PostgreSQL.
"""
from __future__ import annotations

import uuid
from django.db import models
from django.conf import settings
from django.utils import timezone


class Sport(models.Model):
    """
    Sport model defining different sports.
    """
    sport_id = models.AutoField(
        primary_key=True,
        db_column="Sport_ID",
    )
    
    sport_name = models.CharField(
        max_length=100,
        db_column="Sport_Name",
    )
    
    min_player = models.IntegerField(
        db_column="Min_Player",
    )
    
    class Meta:
        db_table = "Sport"
        verbose_name = "Sport"
        verbose_name_plural = "Sports"
    
    def __str__(self):
        return self.sport_name


class Ground(models.Model):
    """
    Ground model representing a turf ground.
    """
    ground_id = models.AutoField(
        primary_key=True,
        db_column="Ground_ID",
    )
    
    ground_name = models.CharField(
        max_length=100,
        db_column="Ground_Name",
    )
    
    sport = models.ForeignKey(
        Sport,
        on_delete=models.RESTRICT,
        db_column="Sport_ID",
        related_name="grounds",
    )
    
    class Meta:
        db_table = "Ground"
        verbose_name = "Ground"
        verbose_name_plural = "Grounds"
    
    def __str__(self):
        return f"{self.ground_name} ({self.sport.sport_name})"


class Slot(models.Model):
    """
    Slot model representing time slots for grounds.
    Slots are numbered based on 30-minute divisions of 24 hours (1-48).
    """
    slot_id = models.IntegerField(
        db_column="Slot_ID",
    )
    
    ground = models.ForeignKey(
        Ground,
        on_delete=models.CASCADE,
        db_column="Ground_ID",
        related_name="slots",
    )
    
    date = models.DateField(
        db_column="Date",
    )
    
    booked = models.BooleanField(
        default=False,
        db_column="Booked",
    )
    
    class Meta:
        db_table = "Slot"
        verbose_name = "Slot"
        verbose_name_plural = "Slots"
        
        # Unique constraint for slot per ground per date
        unique_together = ("ground", "date", "slot_id")
    
    def __str__(self):
        return f"Slot {self.slot_id} - Ground {self.ground.ground_id} - {self.date}"


class Booked_Details(models.Model):
    """
    Booked_Details model for storing detailed booking information.
    """
    player_name = models.CharField(
        max_length=100,
        db_column="player_name",
    )
    booking = models.ForeignKey(
        'Booking',
        on_delete=models.CASCADE,
        db_column="Booking_ID",
        to_field="booking_id",
        related_name="booked_details",
    )
    
    player_email = models.CharField(
        max_length=100,
        db_column="player_email",
    )
    
    sort_key = models.CharField(
        max_length=20,
        db_column="Sort_Key",
    )
    
    ground = models.ForeignKey(
        Ground,
        on_delete=models.CASCADE,
        db_column="Ground_ID",
        related_name="booked_details",
    )
    
    is_user = models.BooleanField(
        default=False,
        db_column="IsUser",
    )
    
    date = models.DateField(
        db_column="Date",
    )
    
    slot_id = models.IntegerField(
        db_column="Slot_ID",
    )
    
    class Meta:
        db_table = "Booked_Details"
        verbose_name = "Booked Detail"
        verbose_name_plural = "Booked Details"
        
        # Composite indexes for efficient queries
        indexes = [
            # Index for member lock system: check if registered user has booking on ground/date
            models.Index(fields=["ground", "date", "is_user"], name="idx_member_lock"),
            # Index for player email lookups
            models.Index(fields=["player_email", "is_user"], name="idx_player_lookup"),
        ]
    
    def __str__(self):
        return f"Booked Detail - {self.booking.booking_id} - {self.player_email}"


class Booking(models.Model):
    """
    Booking model representing a ground reservation request.

    Schema matches the specified Supabase table:
    - Booking_ID: Primary key (VARCHAR 50)
    - User_ID: Foreign key to User
    - Ground_ID: Foreign key to Ground (stored as INT)
    - Date: Booking date
    - Metadata: JSONB field for additional data
    - Status: Booking status (Done, Rejected, Waitlist Processing)
    - Created_At: Timestamp of creation
    """
    
    # Status choices
    STATUS_DONE = "Done"
    STATUS_REJECTED = "Rejected"
    STATUS_WAITLIST = "Waitlist Processing"
    
    STATUS_CHOICES = [
        (STATUS_DONE, "Done"),
        (STATUS_REJECTED, "Rejected"),
        (STATUS_WAITLIST, "Waitlist Processing"),
    ]
    
    # Booking ID - shared across multiple slots in same booking
    booking_id = models.CharField(
        max_length=50,
        primary_key=True,
        editable=False,
        db_index=True,
        default='',
        db_column="Booking_ID",
    )
    
    # Foreign key to User
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.RESTRICT,  # Prevent deletion of users with bookings
        db_column="User_ID",
        related_name="bookings",
    )

    # Booking date
    date = models.DateField(
        db_column="Date",
    )
    
    
    # Booking status
    status = models.CharField(
        max_length=30,
        choices=STATUS_CHOICES,
        default=STATUS_WAITLIST,
        db_column="Status",
    )
    
    # Creation timestamp
    created_at = models.DateTimeField(
        default=timezone.now,
        db_column="Created_At",
    )
    
    class Meta:
        db_table = "Booking"  # Match the exact table name in Supabase
        ordering = ["-created_at"]
        verbose_name = "Booking"
        verbose_name_plural = "Bookings"
        
        # Composite index for efficient queries
        indexes = [
            models.Index(fields=["user", "date"]),
            models.Index(fields=["status"]),
        ]
    
    def save(self, *args, **kwargs):
        """Override save to generate booking_id if not set."""
        if not self.booking_id:
            self.booking_id = self.generate_booking_id()
        super().save(*args, **kwargs)
    
    @staticmethod
    def generate_booking_id():
        """
        Generate a unique booking ID in format: BK{YYYYMMDD}{6-char-hex}
        Example: BK202501156A3F2E
        """
        from datetime import datetime
        import secrets
        
        date_str = datetime.now().strftime("%Y%m%d")
        random_hex = secrets.token_hex(3)  # 3 bytes = 6 hex chars
        return f"BK{date_str}{random_hex.upper()}"
    
    def __str__(self):
        # Derive ground name from first booked detail if available (metadata column removed)
        detail = self.booked_details.first()
        ground_display = (
            f"{detail.ground.ground_name}" if detail and detail.ground else "Unknown ground"
        )
        return f"Booking {self.booking_id} - {self.user.email} - {ground_display} - Date {self.date}"
    
    @property
    def is_active(self) -> bool:
        """Check if booking is active (Done status)."""
        return self.status == self.STATUS_DONE
    
    @property
    def can_be_cancelled(self) -> bool:
        """Check if booking can be cancelled (before slot time)."""
        from datetime import datetime, timedelta
        
        # Only Done bookings can be cancelled
        if self.status != self.STATUS_DONE:
            return False
        
        # Check if booking date is today or in the future
        # Note: This allows same-day cancellations (date-based only, not slot-time-aware)
        now = timezone.now().date()
        return self.date >= now
