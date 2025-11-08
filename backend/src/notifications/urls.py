from django.urls import path
from .views import RegisterDeviceView, SendNotificationView, NotificationHistoryView

urlpatterns = [
    path('register/', RegisterDeviceView.as_view(), name='register-device'),
    path('send/', SendNotificationView.as_view(), name='send-notification'),
    path('', NotificationHistoryView.as_view(), name='notification-history'),
]
