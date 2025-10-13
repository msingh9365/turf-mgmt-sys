from django.db import models

class User(models.Model):
    # Based on your 'users' table fields
    user_id = models.AutoField(primary_key=True)
    name = models.CharField(max_length=100)
    email_id = models.EmailField(max_length=100, unique=True)
    password_hash = models.CharField(max_length=255) # For stored HASHED password
    entry_no = models.CharField(max_length=20, unique=True)
    sort_key = models.CharField(max_length=20, blank=True) # Used for token/auth management
    is_admin = models.BooleanField(default=False)
    phone = models.CharField(max_length=15)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'users'

class Ground(models.Model):
    # Based on your 'ground' table fields
    ground_id = models.AutoField(primary_key=True)
    ground_name = models.CharField(max_length=100)
    sport_id = models.IntegerField() # Foreign key to the 'sport' table
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'grounds'
        
class Slot(models.Model):
    # Based on your 'slot' table fields
    slot_id = models.AutoField(primary_key=True)
    ground = models.ForeignKey(Ground, on_delete=models.CASCADE) 
    date = models.DateField()
    is_booked = models.BooleanField(default=False)
    unique_id = models.CharField(max_length=50, unique=True) # For tracking specific slot instances
    
    class Meta:
        db_table = 'slots'