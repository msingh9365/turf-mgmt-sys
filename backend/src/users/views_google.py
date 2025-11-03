"""
Google OAuth2 authentication views for the playground backend.
Integrates django-allauth with JWT token generation.
"""
from __future__ import annotations

from allauth.socialaccount.helpers import complete_social_login
from allauth.socialaccount.models import SocialAccount
from allauth.socialaccount.providers.google.views import GoogleOAuth2Adapter
from allauth.socialaccount.providers.oauth2.client import OAuth2Client
from django.contrib.auth import login
from django.conf import settings
from django.http import HttpRequest
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from users.models import User


class GoogleLoginView(APIView):
    """
    Google OAuth2 login view that returns JWT tokens.

    This view handles the OAuth2 callback from Google and returns
    access and refresh tokens for authenticated users.
    """

    permission_classes = [AllowAny]
    adapter_class = GoogleOAuth2Adapter
    client_class = OAuth2Client
    callback_url = settings.GOOGLE_CALLBACK_URL

    def get(self, request):
        """Handle the OAuth2 callback from Google."""
        # Get the authorization code from query parameters
        code = request.GET.get('code')
        if not code:
            return Response(
                {"error": "Authorization code not provided"},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            # Create adapter instance
            adapter = self.adapter_class(request)
            provider = adapter.get_provider()
            client = self.client_class(
                request,
                provider.app.client_id,
                provider.app.secret,
                access_token_method=provider.get_access_token_method(),
                access_token_url=provider.get_access_token_url(),
                callback_url=self.callback_url,
            )

            # Exchange code for access token
            token = client.get_access_token(code)

            # Get user info from Google
            login_url = provider.get_login_url(request, **{'process': 'login'})
            social_login = provider.sociallogin_from_response(request, token.__dict__)

            # Complete the social login
            complete_social_login(request, social_login)

            # Get the authenticated user
            user = social_login.user

            # Generate JWT tokens
            refresh = RefreshToken.for_user(user)
            access_token = str(refresh.access_token)
            refresh_token = str(refresh)

            # Return custom response with tokens
            return Response(
                {
                    "user": {
                        "id": user.id,
                        "email": user.email,
                        "name": user.name,
                        "sort_key": user.sort_key,
                    },
                    "tokens": {
                        "access": access_token,
                        "refresh": refresh_token,
                    },
                    "message": "Successfully authenticated with Google",
                },
                status=status.HTTP_200_OK,
            )

        except Exception as e:
            return Response(
                {"error": f"Authentication failed: {str(e)}"},
                status=status.HTTP_400_BAD_REQUEST
            )


class GoogleConnectView(APIView):
    """
    View to initiate Google OAuth2 login flow.

    This returns the Google OAuth2 authorization URL that the frontend
    should redirect the user to.
    """

    permission_classes = [AllowAny]

    def get(self, request):
        """Return Google OAuth2 authorization URL."""
        # This is a simplified implementation
        # In production, you'd want to generate the proper OAuth URL
        # For now, we'll let the frontend handle the redirect to allauth URLs

        return Response(
            {
                "auth_url": "/accounts/google/login/",
                "message": "Redirect to this URL to start Google authentication",
            },
            status=status.HTTP_200_OK,
        )