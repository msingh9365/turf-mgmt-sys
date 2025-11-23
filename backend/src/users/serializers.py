"""
Serializers for user registration, login, and profile.
"""
from __future__ import annotations

from django.conf import settings
from django.contrib.auth import authenticate
from django.core.exceptions import ValidationError
from rest_framework import serializers
from rest_framework_simplejwt.tokens import RefreshToken

from .models import User


def validate_college_email(email: str) -> None:
    domain = getattr(settings, "ALLOWED_EMAIL_DOMAIN", "@iitrpr.ac.in")
    if not email.lower().endswith(domain.lower()):
        raise ValidationError(f"Email must end with {domain}")


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ("name", "email", "password", "sort_key", "phone")

    def validate_email(self, value: str) -> str:  # type: ignore[override]
        validate_college_email(value)
        # Normalize email to lowercase
        return value.lower()

    def validate_sort_key(self, value: str) -> str:  # type: ignore[override]
        # Normalize sort_key to lowercase
        if value:
            return value.lower()
        return value

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = User.objects.create_user(**validated_data)
        user.set_password(password)
        user.save()
        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True)

    def validate(self, attrs):  # type: ignore[override]
        email = attrs.get("email")
        password = attrs.get("password")
        validate_college_email(email)
        user = authenticate(request=self.context.get("request"), email=email, password=password)
        if not user:
            raise serializers.ValidationError("Invalid credentials")
        if not user.is_active:
            raise serializers.ValidationError("User account is disabled")
        attrs["user"] = user
        return attrs


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("id", "name", "email", "sort_key", "phone", "is_admin", "created_at")
        read_only_fields = ("id", "email", "is_admin", "created_at")


class TokenPairSerializer(serializers.Serializer):
    access = serializers.CharField()
    refresh = serializers.CharField()

    @staticmethod
    def for_user(user: User) -> dict[str, str]:
        refresh = RefreshToken.for_user(user)
        return {"access": str(refresh.access_token), "refresh": str(refresh)}
