# Register your models here.
from django.contrib import admin
from .models import Profile, Achievement

@admin.register(Profile)
class ProfileAdmin(admin.ModelAdmin):
    list_display = ("id", "user", "avatar_id", "sports_count")
    list_filter = ("interested_sports",)
    search_fields = ("user__name", "user__email", "avatar_id")
    filter_horizontal = ("interested_sports",)
    
    fieldsets = (
        ("User Information", {
            "fields": ("user",)
        }),
        ("Profile Details", {
            "fields": ("avatar_id", "interested_sports")
        }),
    )
    
    def sports_count(self, obj):
        """Display count of interested sports"""
        try:
            return obj.interested_sports.count()
        except:
            return 0
    sports_count.short_description = "Sports Count"

@admin.register(Achievement)
class AchievementAdmin(admin.ModelAdmin):
    list_display = ("id", "profile", "sport", "title", "year", "achievement")
    list_filter = ("sport", "year")
    search_fields = ("title", "achievement", "profile__user__email", "profile__user__name")
