"""
Google OAuth2 authentication for Android app.
Verifies Google ID tokens and returns JWT tokens.
"""
from __future__ import annotations

from django.conf import settings
from django.utils import timezone
from google.auth.transport import requests
from google.oauth2 import id_token
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken

from users.models import User


@api_view(["POST"])
@permission_classes([AllowAny])
def google_sign_in_android(request):
    """
    Android Google Sign-In endpoint.
    
    Accepts an ID token from Google Sign-In on Android,
    verifies it, and returns JWT tokens.
    
    Request body:
    {
        "id_token": "eyJhbGciOiJSUzI1NiIsImtpZCI6IjU5M..."
    }
    
    Response (Success):
    {
        "access": "jwt_access_token",
        "refresh": "jwt_refresh_token",
        "user": {
            "id": 123,
            "email": "user@iitrpr.ac.in",
            "name": "John Doe",
            "sort_key": "entry_number"
        },
        "created": false
    }
    """
    token = request.data.get("id_token")

    if not token:
        return Response(
            {"error": "id_token is required"},
            status=status.HTTP_400_BAD_REQUEST
        )

    # Ensure the token looks like a JWT before contacting Google
    if token.count(".") != 2:
        return Response(
            {
                "error": "Invalid token format",
                "detail": "Expected a JWT with three segments. Copy the full id_token returned by Google."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    android_client_id = getattr(settings, "GOOGLE_CLIENT_ID_ANDROID", "").strip()
    if not android_client_id or android_client_id == "stub_android_id":
        return Response(
            {
                "error": "Server configuration error",
                "detail": "Set GOOGLE_CLIENT_ID_ANDROID in the environment before using Google Sign-In."
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

    allowed_audiences = {android_client_id}

    web_client_id = getattr(settings, "GOOGLE_CLIENT_ID_WEB", "").strip()
    if web_client_id and web_client_id != "stub_web_id":
        allowed_audiences.add(web_client_id)
    
    try:
        # Verify the ID token with Google (signature, issuer, expiry)
        idinfo = id_token.verify_oauth2_token(
            token,
            requests.Request(),
            audience=None
        )

        token_audience = idinfo.get('aud')
        if token_audience not in allowed_audiences:
            return Response(
                {
                    "error": "Invalid audience",
                    "detail": "Token was not issued for a configured client ID."
                },
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Get user info from token
        email = idinfo.get('email')
        name = (
            idinfo.get('name')
            or idinfo.get('given_name')
            or idinfo.get('family_name')
            or ""
        )
        google_id = idinfo.get('sub')
        email_verified = idinfo.get('email_verified', False)

        if not name and email:
            name = email.split('@')[0]
        
        if not email:
            return Response(
                {"error": "Email not provided by Google"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        if not email_verified:
            return Response(
                {"error": "Email not verified by Google"},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check email domain
        if not email.endswith(settings.ALLOWED_EMAIL_DOMAIN):
            return Response(
                {"error": f"Only {settings.ALLOWED_EMAIL_DOMAIN} emails are allowed"},
                status=status.HTTP_403_FORBIDDEN
            )
        
        default_sort_key = email[:7]
        # Get or create user
        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                'name': name,
                'sort_key': default_sort_key,  # Use email prefix as default sort_key
            }
        )
        
        # Update mutable fields when needed
        now = timezone.now()
        fields_to_update: list[str] = []

        if name and user.name != name:
            user.name = name
            fields_to_update.append('name')

        if not user.sort_key:
            user.sort_key = default_sort_key
            fields_to_update.append('sort_key')

        user.last_login = now
        fields_to_update.append('last_login')

        if fields_to_update:
            user.save(update_fields=fields_to_update)
        
        # Generate JWT tokens
        refresh = RefreshToken.for_user(user)
        
        return Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "user": {
                    "id": user.id,
                    "email": user.email,
                    "name": user.name,
                    "sort_key": user.sort_key,
                },
                "created": created,
            },
            status=status.HTTP_200_OK
        )
        
    except ValueError as e:
        # Invalid token
        return Response(
            {"error": f"Invalid token: {str(e)}"},
            status=status.HTTP_401_UNAUTHORIZED
        )
    except Exception as e:
        return Response(
            {"error": f"Authentication failed: {str(e)}"},
            status=status.HTTP_400_BAD_REQUEST
        )