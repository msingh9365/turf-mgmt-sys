from django.urls import path
from .views import (
    RegisterDeviceView, 
    SendNotificationView, 
    NotificationHistoryView,
    BroadcastLookingForPlayersView
)

urlpatterns = [
    path('register/', RegisterDeviceView.as_view(), name='register-device'),
    path('send/', SendNotificationView.as_view(), name='send-notification'),
    path('broadcast/looking-for-players/', BroadcastLookingForPlayersView.as_view(), name='broadcast-looking-for-players'),
    path('', NotificationHistoryView.as_view(), name='notification-history'),
]
