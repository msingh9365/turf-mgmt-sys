from django.urls import path
from . import views

app_name = 'forgot_password'

urlpatterns = [
    path('request-otp/', views.request_otp, name='request_otp'),
    path('verify-otp/', views.verify_otp, name='verify_otp'),
    path('reset-password/', views.reset_password, name='reset_password'),
]