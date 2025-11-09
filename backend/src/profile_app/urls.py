from __future__ import annotations

from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import ProfileView, AchievementViewSet

router = DefaultRouter()
router.register(r"achievements", AchievementViewSet, basename="achievement")

urlpatterns = [
    path("profile/", ProfileView.as_view(), name="profile"),
    path("", include(router.urls)),
]
