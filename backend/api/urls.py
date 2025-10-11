"""
URL configuration for API
"""
from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import (
    UserViewSet, SportsTypeViewSet, GroundViewSet, BookingViewSet,
    TeamViewSet, TeamRequestViewSet, NotificationViewSet, BookingQueueViewSet
)

router = DefaultRouter()
router.register(r'users', UserViewSet, basename='user')
router.register(r'sports-types', SportsTypeViewSet, basename='sports-type')
router.register(r'grounds', GroundViewSet, basename='ground')
router.register(r'bookings', BookingViewSet, basename='booking')
router.register(r'teams', TeamViewSet, basename='team')
router.register(r'team-requests', TeamRequestViewSet, basename='team-request')
router.register(r'notifications', NotificationViewSet, basename='notification')
router.register(r'booking-queue', BookingQueueViewSet, basename='booking-queue')

urlpatterns = [
    path('', include(router.urls)),
]
