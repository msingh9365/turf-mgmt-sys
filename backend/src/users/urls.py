"""URL routes for the users app."""
from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import LoginView, MeView, RegisterView, google_sign_in
from . import views

urlpatterns = [
    # Auth
    path("auth/register/", RegisterView.as_view(), name="auth-register"),
    path("auth/login/", LoginView.as_view(), name="auth-login"),
    path("auth/google/", google_sign_in, name="auth-google"),
    path("auth/token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),

    # Profile
    path("user/me/", MeView.as_view(), name="user-me"),
    path('send-otp/', views.send_otp, name='send_otp'),
    path('verify-otp/', views.verify_otp, name='verify_otp'),
]

# # FILE: I:\PGSL Project\turf-mgmt-sys\backend\src\users\urls.py (MODIFIED)

# from django.urls import path, include # <-- Need to include the 'include' function here
# from rest_framework_simplejwt.views import TokenRefreshView

# from .views import LoginView, MeView, RegisterView, google_sign_in
# from . import views

# # Define all authentication routes in a sub-list
# auth_urlpatterns = [
#     path("register/", RegisterView.as_view(), name="auth-register"),
#     path("login/", LoginView.as_view(), name="auth-login"),
#     path("google/", google_sign_in, name="auth-google"),
#     path("token/refresh/", TokenRefreshView.as_view(), name="token-refresh"),
# ]

# urlpatterns = [
#     # 1. AUTH ROUTES: Now accessible via /api/v1/auth/register/
#     path("auth/", include(auth_urlpatterns)), 

#     # 2. PROFILE: Accessible via /api/v1/user/me/
#     path("user/me/", MeView.as_view(), name="user-me"),

#     # 3. OTP Verification: Accessible directly via /api/v1/send-otp/
#     path('send-otp/', views.send_otp, name='send_otp'),
#     path('verify-otp/', views.verify_otp, name='verify_otp'),
# ]