"""
Custom user model for the playground backend.
Implements fields per the provided schema and uses email as username.
"""
from __future__ import annotations

from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.core.validators import RegexValidator
from django.db import models
from django.utils import timezone
from django.conf import settings
from datetime import datetime, timedelta

class UserManager(BaseUserManager):
    """Manager for the custom User model using email as username."""

    def create_user(self, email: str, password: str | None = None, **extra_fields):
        if not email:
            raise ValueError("Users must have an email address")
        email = self.normalize_email(email)
        user = self.model(email=email, **extra_fields)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, email: str, password: str, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_admin", True)
        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")
        return self.create_user(email, password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    """
    Custom user model.

    Fields map to the provided schema with Django conventions:
    - id: Primary key (auto-increment), corresponds to User_ID
    - name: varchar(100), corresponds to Name
    - email: varchar(100), unique, corresponds to Email_ID
    - password: hashed password via AbstractBaseUser
    - sort_key: varchar(20), unique, corresponds to Sort_Key
    - is_admin: boolean, default False, corresponds to Is_Admin
    - phone: varchar(15), optional, corresponds to Phone
    - created_at: timestamp, default now, corresponds to Created_At

    Additional fields for Django admin compatibility:
    - is_active, is_staff are standard flags
    """

    name = models.CharField(max_length=100)
    email = models.EmailField(max_length=100, unique=True, db_index=True)
    sort_key = models.CharField(max_length=20, unique=True)

    is_admin = models.BooleanField(default=False)
    is_staff = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    phone = models.CharField(
        max_length=15,
        blank=True,
        validators=[RegexValidator(r"^[0-9+\-() ]*$", "Enter a valid phone number")],
    )

    created_at = models.DateTimeField(default=timezone.now, db_index=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = ["name", "sort_key"]

    class Meta:
        db_table = "users"
        verbose_name = "User"
        verbose_name_plural = "Users"
        constraints = [
            models.UniqueConstraint(fields=["email"], name="unique_user_email"),
            models.UniqueConstraint(fields=["sort_key"], name="unique_user_sort_key"),
        ]

    def __str__(self) -> str:  # pragma: no cover - trivial
        return f"{self.email} ({self.name})"
    

# ---------------------- 1. Sport Table (2) ----------------------
class Sport(models.Model):
    """Maps to Sport_ID, Sport_Name, Min_Player."""
    # Sport_ID is the auto-generated primary key
    sport_name = models.CharField(max_length=100, unique=True)
    min_player = models.IntegerField()
    
    class Meta:
        db_table = "sport"
    
    def __str__(self):
        return self.sport_name

# ---------------------- 2. Ground Table (3) ----------------------
class Ground(models.Model):
    """Maps to Ground_ID, Ground_Name, Sport_ID."""
    # Ground_ID is the auto-generated primary key
    ground_name = models.CharField(max_length=100)
    
    # One Ground belongs to one Sport (per your schema)
    sport = models.ForeignKey(Sport, on_delete=models.RESTRICT, db_column='Sport_ID', related_name='grounds')
    
    class Meta:
        db_table = "ground"
    
    def __str__(self):
        return f"{self.ground_name} ({self.sport.sport_name})"

# ---------------------- 3. Slot Table (4) ----------------------
class Slot(models.Model):
    """Maps to Slot_ID, Ground_ID, Date, Booked, Unique_ID."""
    # Slot_ID is the auto-generated primary key
    ground = models.ForeignKey(Ground, on_delete=models.RESTRICT, db_column='Ground_ID', related_name='slots')
    date = models.DateField()
    booked = models.BooleanField(default=False)
    
    # Unique_ID for linking to Booking and Waitlist. We use CharField for UUIDs.
    unique_id = models.CharField(max_length=50, unique=True, blank=True, null=True) 
    
    class Meta:
        db_table = "slot"
        # Unique constraint from schema: UNIQUE KEY (Ground_ID, Date, Slot_ID)
        # We rely on PK for Slot_ID uniqueness, and ground+date to ensure uniqueness for slot data.
        # Note: If Ground_ID and Date alone are unique identifiers for this table, 
        # the UNIQUE KEY in the schema is redundant. We will ensure Ground+Date 
        # is unique to ensure a ground on a date is represented by one Slot row.
        # Given your Time_Table structure, we'll keep it simple for now and rely on PK.
    
    def __str__(self):
        return f"{self.ground.ground_name} | {self.date}"

# ---------------------- 4. Time_Table (5) ----------------------
class TimeSlot(models.Model): 
    """Maps to Slot_ID (FK), Time (the actual bookable time)."""
    # Note: Renamed to TimeSlot to avoid Python keyword conflict with datetime.time
    
    # The Slot row this time belongs to (ON DELETE CASCADE)
    slot = models.ForeignKey(Slot, on_delete=models.CASCADE, db_column='Slot_ID', related_name='times')
    
    # The actual TIME field
    time = models.TimeField()
    
    class Meta:
        db_table = "time_table"
        # Primary key constraint (Slot_ID, Time)
        unique_together = ('slot', 'time')
        
    def __str__(self):
        return f"{self.slot.ground.ground_name} - {self.slot.date} @ {self.time}"

# ---------------------- 5. Notification Table (8) ----------------------
class SportNotification(models.Model):
    """Maps to User_ID and Sports_ID (User subscriptions)."""
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, db_column='User_ID')
    sport = models.ForeignKey(Sport, on_delete=models.CASCADE, db_column='Sports_ID')
    
    class Meta:
        db_table = "notification"
        # Primary key constraint (User_ID, Sports_ID)
        unique_together = ('user', 'sport')

    def __str__(self):
        return f"{self.user.email} subscribes to {self.sport.sport_name}"

# ---------------------- Booking ----------------------
import uuid

# Define the status choices based on your schema's ENUM
BOOKING_STATUS_CHOICES = [
    ('Done', 'Done'),
    ('Rejected', 'Rejected'),
    ('Waitlist Processing', 'Waitlist Processing'),
]

class Booking(models.Model):
    """
    Corresponds to Schema Table 6: Stores the primary reservation transaction record.
    Note: Unique_ID is the PK in the schema, but we will use Django's 'id' as 
    PK and enforce unique constraint on Unique_ID for simplicity.
    """
    
    # Schema PK: VARCHAR(50) PRIMARY KEY (Using CharField with unique=True)
    unique_id = models.CharField(
        max_length=50, 
        unique=True, 
        default=uuid.uuid4, # Auto-generate the ID
        verbose_name="Unique Booking ID"
    )
    # Schema Booking_ID: INT AUTO_INCREMENT UNIQUE (Using Django's default 'id' PK)
    
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.RESTRICT, db_column='User_ID', related_name='bookings')
    metadata = models.JSONField(null=True, blank=True)
    status = models.CharField(max_length=50, choices=BOOKING_STATUS_CHOICES, default='Waitlist Processing')

    class Meta:
        db_table = "booking"
        verbose_name = "Booking"
        verbose_name_plural = "Bookings"
    
    def __str__(self):
        return f"Booking {self.unique_id} by {self.user.email}"

# ---------------------- BookingDetails ----------------------

class BookedDetails(models.Model):
    """
    Corresponds to Schema Table 10: Stores participant details and reservation metadata.
    This serves as the 'Member Lock System' record.
    """
    # NOTE: Since Name, R_Mail, and Sort_Key are available from the linked User, 
    # we link to the user and avoid data duplication for users who are registered.

    # Primary Link: The Ground and Slot reserved
    ground = models.ForeignKey('Ground', on_delete=models.RESTRICT, db_column='Ground_ID')
    slot = models.ForeignKey('Slot', on_delete=models.RESTRICT, db_column='Slot_ID')
    date = models.DateField()

    # Participant Details (Required by your schema, even if redundant for registered users)
    name = models.CharField(max_length=100)
    r_mail = models.CharField(max_length=100)
    sort_key = models.CharField(max_length=20)
    
    # If the participant is a registered User (best practice for Member Lock System)
    user_or_not = models.BooleanField(default=False, verbose_name="Is Registered User")
    
    # Optional Link to the User (If user_or_not is True)
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True)

    class Meta:
        db_table = "booked_details"
        verbose_name = "Booked Detail"
        verbose_name_plural = "Booked Details"
        # We will need to enforce uniqueness in a complex way at the API level
        # to ensure the same user isn't booked in the same slot twice.

    def __str__(self):
        return f"Booking Detail for {self.r_mail} on {self.date}"

# ---------------------- OTP Model ----------------------
class OTP(models.Model):
    email = models.EmailField()
    code = models.CharField(max_length=6)
    created_at = models.DateTimeField(auto_now_add=True)
    is_verified = models.BooleanField(default=False)  # Add this field


    class Meta:
        db_table = "otp"  # 👈 this forces the table name

    def is_valid(self):
        from django.utils import timezone
        from datetime import timedelta
        return timezone.now() <= self.created_at + timedelta(minutes=5)

