"""
Authentication backends and helpers.
We provide an email-based authentication backend so `authenticate(email=..., password=...)` works.
"""
from __future__ import annotations

from typing import Optional

from django.contrib.auth.backends import ModelBackend
from django.contrib.auth import get_user_model


class EmailBackend(ModelBackend):
    """Authenticate using email and password for the custom user model."""

    def authenticate(self, request, username: Optional[str] = None, password: Optional[str] = None, **kwargs):
        email = kwargs.get("email") or username
        if email is None or password is None:
            return None
        try:
            user = get_user_model().objects.get(email__iexact=email)
        except get_user_model().DoesNotExist:  # type: ignore[attr-defined]
            return None
        if user.check_password(password) and self.user_can_authenticate(user):
            return user
        return None
