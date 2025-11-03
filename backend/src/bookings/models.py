"""
Booking model for turf management system.
Stores booking information in Supabase PostgreSQL.
"""
from __future__ import annotations

import uuid
from django.db import models
from django.conf import settings
from django.utils import timezone


class Booking(models.Model):
    """
    Booking model representing a ground slot reservation.
    
    Schema matches the specified Supabase table:
    - Unique_ID: Primary key (VARCHAR 50)
    - Booking_ID: Auto-increment serial
    - User_ID: Foreign key to User
    - Ground_ID: Foreign key to Ground (stored as INT)
    - Slot_ID: Foreign key to Slot (stored as INT)
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
    
    # Auto-increment primary key
    id = models.BigAutoField(
        primary_key=True,
        db_column="id",
    )
    
    # Booking ID - shared across multiple slots in same booking
    booking_id = models.CharField(
        max_length=50,
        editable=False,
        db_index=True,
        db_column="Booking_ID",
    )
    
    # Foreign key to User
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.RESTRICT,  # Prevent deletion of users with bookings
        db_column="User_ID",
        related_name="bookings",
    )
    
    # Ground ID (references Ground table - not creating FK to avoid dependency)
    ground_id = models.IntegerField(
        db_column="Ground_ID",
    )
    
    # Slot ID (references Slot table - not creating FK to avoid dependency)
    slot_id = models.IntegerField(
        db_column="Slot_ID",
    )
    
    # Booking date
    date = models.DateField(
        db_column="Date",
    )
    
    # Metadata stored as JSON
    metadata = models.JSONField(
        default=dict,
        blank=True,
        db_column="Metadata",
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
            models.Index(fields=["ground_id", "date", "slot_id"]),
            models.Index(fields=["status"]),
        ]
        
        # Ensure unique booking per slot per date
        constraints = [
            models.UniqueConstraint(
                fields=["ground_id", "slot_id", "date"],
                condition=models.Q(status="Done"),
                name="unique_active_booking_per_slot",
            )
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
        return f"Booking {self.booking_id} - {self.user.email} - Ground {self.ground_id}, Slot {self.slot_id}, Date {self.date}"
    
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
        
        # Check if current time is before the booking date
        # In production, you'd check against slot start time
        now = timezone.now().date()
        return self.date > now
