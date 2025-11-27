"""
Views for user registration, login (JWT), and profile.
"""
from __future__ import annotations

from django.conf import settings
from django.utils import timezone
from rest_framework import permissions, status, generics
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenRefreshView
import sib_api_v3_sdk
from sib_api_v3_sdk.rest import ApiException

from .models import User
from .serializers import (
    LoginSerializer,
    RegisterSerializer,
    ResetPasswordSerializer,
    TokenPairSerializer,
    UserSerializer,
)


class RegisterView(generics.CreateAPIView):
    """Registers a new user after validating college email domain."""

    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]


class LoginView(generics.GenericAPIView):
    """Authenticates user by email/password and returns a JWT token pair."""

    serializer_class = LoginSerializer
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        user: User = serializer.validated_data["user"]
        # Use Django's localtime() which converts aware UTC now to the
        # timezone specified in settings.TIME_ZONE (now set to 'Asia/Kolkata').
        now = timezone.localtime()
        user.last_login = now
        user.save(update_fields=["last_login"])
        tokens = TokenPairSerializer.for_user(user)
        return Response(tokens, status=status.HTTP_200_OK)


class MeView(generics.RetrieveAPIView):
    """Returns the current authenticated user's profile."""

    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user


class ResetPasswordView(generics.GenericAPIView):
    """Resets user password after OTP verification (handled by frontend)."""

    authentication_classes = []
    permission_classes = [permissions.AllowAny]
    serializer_class = ResetPasswordSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        
        email = serializer.validated_data["email"]
        new_password = serializer.validated_data["new_password"]

        # Check if user exists
        try:
            user = User.objects.get(email__iexact=email)
        except User.DoesNotExist:
            return Response(
                {"error": "User with this email does not exist."},
                status=status.HTTP_404_NOT_FOUND
            )

        # Update password and invalidate all existing sessions
        user.set_password(new_password)
        user.last_login = None  # Invalidate all JWT tokens by clearing last_login
        user.save(update_fields=["password", "last_login"])

        # Send confirmation email via Brevo
        try:
            configuration = sib_api_v3_sdk.Configuration()
            configuration.api_key["api-key"] = settings.BREVO_API_KEY
            
            api_instance = sib_api_v3_sdk.TransactionalEmailsApi(
                sib_api_v3_sdk.ApiClient(configuration)
            )
            
            send_smtp_email = sib_api_v3_sdk.SendSmtpEmail(
                to=[{"email": email}],
                sender={"email": settings.DEFAULT_FROM_EMAIL, "name": "IIT Ropar Sports"},
                subject="Password Reset Confirmation",
                text_content=(
                    f"Dear {user.name},\n\n"
                    f"Your password has been successfully reset for the IIT Ropar Sports Booking System.\n\n"
                    f"All devices have been logged out for security. Please log in again with your new password.\n\n"
                    f"If you did not request this password reset, please contact support immediately.\n\n"
                    f"Thank you for using the Proximity-Based Sports Networking & Turf Management System.\n"
                    f"Team EndGame"
                )
            )
            
            api_instance.send_transac_email(send_smtp_email)
            
        except ApiException as e:
            # Log error but don't fail the request since password was already reset
            print(f"Failed to send confirmation email: {str(e)}")
        except Exception as e:
            print(f"Failed to send confirmation email: {str(e)}")

        return Response(
            {
                "message": "Password has been reset successfully. All devices have been logged out. Please log in with your new password.",
                "status": "success"
            },
            status=status.HTTP_200_OK
        )
