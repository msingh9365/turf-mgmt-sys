# FILE: I:\PGSL Project\turf-mgmt-sys\backend\src\turfify\urls.py

from django.urls import path
from .views import DeviceTokenView

urlpatterns = [
    # API endpoint for POSTing the device token
    path('devices/token/', DeviceTokenView.as_view(), name='device-token-register'),
]