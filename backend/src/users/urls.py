"""URL routes for the users app."""
from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import LoginView, MeView, RegisterView
from .views_google import GoogleConnectView, GoogleLoginView

urlpatterns = [
    # Auth
    path("auth/register/", RegisterView.as_view(), name="auth-register"),
    path("auth/login/", LoginView.as_view(), name="auth-login"),
    path("auth/google/connect/", GoogleConnectView.as_view(), name="auth-google-connect"),
    path("auth/google/login/", GoogleLoginView.as_view(), name="auth-google-login"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),

    # Profile
    path("user/me/", MeView.as_view(), name="user-me"),
]
