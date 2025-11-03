"""
Root URL configuration for the project.
Routes the API under /api/ and prepares for future apps.
"""
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    # Admin kept for development convenience; can be disabled in prod settings
    path("admin/", admin.site.urls),

    # Allauth URLs for social authentication
    path("accounts/", include("allauth.urls")),

    # API routes
    path("api/", include("users.urls")),
]
