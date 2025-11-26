from __future__ import annotations

from django.conf import settings
from django.core.exceptions import ValidationError
from rest_framework import serializers


class SendOTPSerializer(serializers.Serializer):
    email = serializers.EmailField()

    def validate_email(self, value: str) -> str:  # type: ignore[override]
        domain = getattr(settings, "ALLOWED_EMAIL_DOMAIN", "@iitrpr.ac.in")
        if not value.lower().endswith(domain.lower()):
            raise ValidationError(f"Email must end with {domain}")
        return value


class VerifyOTPSerializer(serializers.Serializer):
    email = serializers.EmailField()
    otp = serializers.CharField(max_length=6)

    def validate_otp(self, value: str) -> str:  # type: ignore[override]
        if not value.isdigit() or len(value) != 6:
            raise ValidationError("OTP must be a 6-digit numeric string")
        return value
