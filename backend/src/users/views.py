"""
Views for user registration, login (JWT), profile, and Google Sign-In stub.
"""
from __future__ import annotations

from django.conf import settings
from rest_framework import permissions, status, generics
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenRefreshView

from .models import User
from .serializers import (
    LoginSerializer,
    RegisterSerializer,
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
        tokens = TokenPairSerializer.for_user(user)
        return Response(tokens, status=status.HTTP_200_OK)


class MeView(generics.RetrieveAPIView):
    """Returns the current authenticated user's profile."""

    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user


@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def google_sign_in(request):
    """
    Google Sign-In stub endpoint.

    Expects JSON body with a `token` (ID token) field. For now returns 501.
    When implementing, verify the token against Google's OAuth2 tokeninfo endpoint
    or using google-auth library and the configured client IDs:
    - settings.GOOGLE_CLIENT_ID_ANDROID
    - settings.GOOGLE_CLIENT_ID_WEB
    """
    token = request.data.get("token")
    if not token:
        return Response({"detail": "'token' is required"}, status=status.HTTP_400_BAD_REQUEST)

    return Response(
        {"detail": "Google sign-in not yet implemented"},
        status=status.HTTP_501_NOT_IMPLEMENTED,
    )
