"""
URL configuration for bookings API.
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import BookingViewSet

# Create router and register viewsets
router = DefaultRouter()
router.register(r"bookings", BookingViewSet, basename="booking")

urlpatterns = [
    path("", include(router.urls)),
]
