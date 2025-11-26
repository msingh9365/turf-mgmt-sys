from __future__ import annotations

from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import ProfileView, AchievementViewSet

# Create router for achievements
router = DefaultRouter()
router.register(r"achievements", AchievementViewSet, basename="achievement")

urlpatterns = [
    # Profile endpoints
    path("profile/", ProfileView.as_view(), name="user-profile"),
    
    # Achievement endpoints (nested under profile)
    path("profile/", include(router.urls)),
]
