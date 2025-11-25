from __future__ import annotations
from django.db import models
from django.db.models.signals import post_save
from django.dispatch import receiver

# Your custom User model lives in users.models (as you shared)
from users.models import User
from bookings.models import Sport


class Profile(models.Model):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name="profile")
    # User's interested sports (many-to-many to central Sport model)
    interested_sports = models.ManyToManyField(
        Sport,
        related_name="interested_profiles",
        blank=True,
        help_text="Sports user is interested in (frontend will store IDs)"
    )

    # Avatar selected by the user (frontend provides an `avatar_id` or filename)
    avatar_id = models.CharField(max_length=200, blank=True, null=True, help_text="Avatar identifier selected by user")

    class Meta:
        db_table = "user_profile"  # ✅ Clean custom table name
        verbose_name_plural = "User Profiles"

    def __str__(self) -> str:
        return self.user.name or self.user.email
    


class Achievement(models.Model):
    profile = models.ForeignKey(
        Profile, 
        on_delete=models.CASCADE, 
        related_name="achievements"
    )
    sport = models.CharField(max_length=50)
    title = models.CharField(max_length=100)
    year = models.IntegerField()
    achievement = models.CharField(max_length=100)
    experience = models.TextField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "user_achievements"  # ✅ Clean custom table name
        ordering = ["-year", "sport", "title"]
        verbose_name_plural = "User Achievements"

    def __str__(self) -> str:
        return f"{self.title} • {self.year}"


# Auto-create a Profile for every User (and keep it if user is created via admin/registration)
@receiver(post_save, sender=User)
def create_or_update_user_profile(sender, instance: User, created: bool, **kwargs):
    if created:
        Profile.objects.create(user=instance)
    else:
        # ensure profile exists even if created before signal was added
        Profile.objects.get_or_create(user=instance)
