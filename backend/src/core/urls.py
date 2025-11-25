"""
Root URL configuration for the project.
Routes the API under /api/ and prepares for future apps.
"""
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    # Admin kept for development convenience; can be disabled in prod settings
    path("admin/", admin.site.urls),

    # API routes - organized by app
    path("api/auth/", include("users.urls")),           # /api/auth/login/, /api/auth/register/
    path("api/bookings/", include("bookings.urls")),    # /api/bookings/
    path("api/teams/", include("teams.urls")),          # /api/teams/
    path("api/notifications/", include("notifications.urls")),  # /api/notifications/
    path("api/", include("profile_app.urls")),          # /api/profile/, /api/profile/achievements/

]
