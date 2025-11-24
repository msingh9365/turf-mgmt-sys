from django.urls import path
from .views import (
    RegisterDeviceView, 
    SendNotificationView, 
    NotificationHistoryView,
    BroadcastLookingForPlayersView,
    MarkNotificationAsReadView,
    MarkAllNotificationsReadView,
    UnreadNotificationCountView,
)

urlpatterns = [
    path('register/', RegisterDeviceView.as_view(), name='register-device'),
    path('send/', SendNotificationView.as_view(), name='send-notification'),
    path('broadcast/looking-for-players/', BroadcastLookingForPlayersView.as_view(), name='broadcast-looking-for-players'),
    path('unread-count/', UnreadNotificationCountView.as_view(), name='unread-notification-count'),
    path('mark-all-read/', MarkAllNotificationsReadView.as_view(), name='mark-all-notifications-read'),
    path('<int:notification_id>/mark-read/', MarkNotificationAsReadView.as_view(), name='mark-notification-read'),
    path('', NotificationHistoryView.as_view(), name='notification-history'),
]
