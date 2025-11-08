from django.db import models
from django.utils import timezone

class User(models.Model):
    user_id = models.AutoField(primary_key=True)
    name = models.CharField(max_length=100)
    email_id = models.EmailField(max_length=100, unique=True)
    password_hash = models.CharField(max_length=255) 
    # entry_no = models.CharField(max_length=20, unique=True)
    sort_key = models.CharField(max_length=20, blank=True, null=True)
    is_admin = models.BooleanField(default=False)
    phone = models.CharField(max_length=15)
    fcm_token = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    sports_interest = models.CharField(max_length=255, blank=True, null=True)

    def __str__(self):
        return self.name

    class Meta:
        db_table = 'users'

class Sport(models.Model):
    sport_id = models.AutoField(primary_key=True)
    sport_name = models.CharField(max_length=100, unique=True)
    min_player = models.IntegerField(default=1)

    def __str__(self):
        return self.sport_name

    class Meta:
        db_table = 'sport'
