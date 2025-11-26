"""
Root URL configuration for the project.
Routes the API under /api/ and prepares for future apps.
"""
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    # Admin kept for development convenience; can be disabled in prod settings
    path("admin/", admin.site.urls),

    # API routes
    path("api/", include("users.urls")),
    path("api/", include("bookings.urls")),
    path("api/", include("teams.urls")),
    path("api/notifications/", include("notifications.urls")),
    path("api/", include("events.urls")),
    # OTP endpoints (available under /api/otp/...)
    path("api/otp/", include("otp.urls")),
    path("api/", include("profile_app.urls")),
]
