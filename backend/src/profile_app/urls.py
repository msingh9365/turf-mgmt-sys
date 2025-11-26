from __future__ import annotations

from django.urls import path
from .views import ProfileView

urlpatterns = [
    # Combined Profile + Achievements endpoint
    path("me/", ProfileView.as_view(), name="profile-me"),
]
