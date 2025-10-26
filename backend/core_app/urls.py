from django.urls import path
from . import views

urlpatterns = [
    # Maps the local path 'login' to your view function
    path('login', views.login_view, name='auth-login'), 
    path('test-notify', views.test_notification_view, name='test-notify'), 
]