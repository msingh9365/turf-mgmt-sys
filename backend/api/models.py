"""
Database models for turf management system
"""
from django.db import models
from django.contrib.auth.models import AbstractUser
from django.utils import timezone
from datetime import timedelta


class User(AbstractUser):
    """Custom User model for students and faculty"""
    USER_TYPE_CHOICES = [
        ('student', 'Student'),
        ('faculty', 'Faculty'),
        ('admin', 'Admin'),
    ]
    
    user_type = models.CharField(max_length=10, choices=USER_TYPE_CHOICES, default='student')
    phone_number = models.CharField(max_length=15, blank=True)
    roll_number = models.CharField(max_length=20, blank=True, null=True)
    department = models.CharField(max_length=100, blank=True)
    fcm_token = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'users'

    def __str__(self):
        return f"{self.username} ({self.user_type})"


class SportsType(models.Model):
    """Sports types available in the campus"""
    name = models.CharField(max_length=50, unique=True)
    description = models.TextField(blank=True)
    icon = models.ImageField(upload_to='sports_icons/', blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'sports_types'
        verbose_name_plural = 'Sports Types'

    def __str__(self):
        return self.name


class Ground(models.Model):
    """Sports grounds available in campus"""
    name = models.CharField(max_length=100)
    location = models.CharField(max_length=200)
    sports_type = models.ForeignKey(SportsType, on_delete=models.CASCADE, related_name='grounds')
    capacity = models.IntegerField(default=20)
    description = models.TextField(blank=True)
    image = models.ImageField(upload_to='grounds/', blank=True, null=True)
    is_available = models.BooleanField(default=True)
    amenities = models.TextField(blank=True, help_text="Comma-separated amenities")
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'grounds'

    def __str__(self):
        return f"{self.name} - {self.sports_type.name}"


class TimeSlot(models.Model):
    """Available time slots for bookings"""
    ground = models.ForeignKey(Ground, on_delete=models.CASCADE, related_name='time_slots')
    start_time = models.TimeField()
    end_time = models.TimeField()
    is_available = models.BooleanField(default=True)
    
    class Meta:
        db_table = 'time_slots'
        unique_together = ['ground', 'start_time', 'end_time']
        ordering = ['start_time']

    def __str__(self):
        return f"{self.ground.name}: {self.start_time} - {self.end_time}"


class Booking(models.Model):
    """Ground booking records"""
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('cancelled', 'Cancelled'),
        ('completed', 'Completed'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='bookings')
    ground = models.ForeignKey(Ground, on_delete=models.CASCADE, related_name='bookings')
    time_slot = models.ForeignKey(TimeSlot, on_delete=models.CASCADE, related_name='bookings')
    booking_date = models.DateField()
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    purpose = models.TextField(blank=True)
    number_of_players = models.IntegerField(default=1)
    queue_position = models.IntegerField(default=0)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'bookings'
        unique_together = ['ground', 'time_slot', 'booking_date']
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} - {self.ground.name} on {self.booking_date}"


class Team(models.Model):
    """Teams for collaborative sports"""
    name = models.CharField(max_length=100)
    sports_type = models.ForeignKey(SportsType, on_delete=models.CASCADE, related_name='teams')
    captain = models.ForeignKey(User, on_delete=models.CASCADE, related_name='captained_teams')
    members = models.ManyToManyField(User, related_name='teams', blank=True)
    max_members = models.IntegerField(default=11)
    description = models.TextField(blank=True)
    logo = models.ImageField(upload_to='team_logos/', blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'teams'

    def __str__(self):
        return f"{self.name} ({self.sports_type.name})"


class TeamRequest(models.Model):
    """Team join requests"""
    STATUS_CHOICES = [
        ('pending', 'Pending'),
        ('accepted', 'Accepted'),
        ('rejected', 'Rejected'),
    ]

    team = models.ForeignKey(Team, on_delete=models.CASCADE, related_name='join_requests')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='team_requests')
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    message = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'team_requests'
        unique_together = ['team', 'user']
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.user.username} -> {self.team.name} ({self.status})"


class Notification(models.Model):
    """Push notifications for users"""
    NOTIFICATION_TYPE_CHOICES = [
        ('booking_confirmed', 'Booking Confirmed'),
        ('booking_cancelled', 'Booking Cancelled'),
        ('queue_update', 'Queue Update'),
        ('team_invite', 'Team Invite'),
        ('team_request', 'Team Request'),
        ('reminder', 'Reminder'),
        ('general', 'General'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='notifications')
    notification_type = models.CharField(max_length=30, choices=NOTIFICATION_TYPE_CHOICES)
    title = models.CharField(max_length=200)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    data = models.JSONField(blank=True, null=True)
    sent_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'notifications'
        ordering = ['-sent_at']

    def __str__(self):
        return f"{self.title} -> {self.user.username}"


class BookingQueue(models.Model):
    """Queue management for bookings"""
    booking = models.OneToOneField(Booking, on_delete=models.CASCADE, related_name='queue_entry')
    position = models.IntegerField()
    estimated_wait_time = models.IntegerField(help_text="Estimated wait time in minutes")
    notified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'booking_queues'
        ordering = ['position']

    def __str__(self):
        return f"Queue #{self.position} - {self.booking}"
