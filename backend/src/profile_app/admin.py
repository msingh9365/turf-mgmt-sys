# Register your models here.
from django.contrib import admin
from .models import Profile, Achievement

@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    list_display = ("id", "user")

@admin.register(Achievement)
class AchievementAdmin(admin.ModelAdmin):
    list_display = ("id", "profile", "sport", "title", "year", "achievement")
    list_filter = ("sport", "year")
    search_fields = ("title", "achievement", "profile__user__email", "profile__user__name")
