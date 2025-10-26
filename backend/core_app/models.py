from django.db import models

class User(models.Model):
    user_id = models.AutoField(primary_key=True)
    name = models.CharField(max_length=100)
    email_id = models.EmailField(max_length=100, unique=True)
    password_hash = models.CharField(max_length=255) 
    entry_no = models.CharField(max_length=20, unique=True)
    sort_key = models.CharField(max_length=20, blank=True, null=True)
    is_admin = models.BooleanField(default=False)
    phone = models.CharField(max_length=15)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'users'

class Ground(models.Model):
    # Based on your 'ground' table fields
    ground_id = models.AutoField(primary_key=True)
    ground_name = models.CharField(max_length=100)
    sport_id = models.IntegerField() 
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'grounds'

class Booking(models.Model):
    # Based on your ER Diagram
    booking_id = models.AutoField(primary_key=True)
    user = models.ForeignKey(User, on_delete=models.CASCADE) # The user who made the booking
    created_at = models.DateTimeField(auto_now_add=True)
    # Status and Metadata will be added later for enforcement

    class Meta:
        db_table = 'bookings'

class Slot(models.Model):
    # Based on your 'slot' table fields
    slot_id = models.AutoField(primary_key=True)
    ground = models.ForeignKey(Ground, on_delete=models.CASCADE) 
    date = models.DateField()
    is_booked = models.BooleanField(default=False)
    unique_id = models.CharField(max_length=50, unique=True, null=True)
    
    # NEW FIELD: Link the slot to the actual booking record
    booked_by = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True)
    
    class Meta:
        db_table = 'slots'