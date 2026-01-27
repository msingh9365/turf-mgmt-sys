"""
Custom user model for the playground backend.
Implements fields per the provided schema and uses email as username.
"""
from __future__ import annotations

from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.core.validators import RegexValidator
from django.db import models
from django.utils import timezone


class UserManager(BaseUserManager):
    """Manager for the custom User model using email as username."""

    def create_user(self, email: str, password: str | None = None, **extra_fields):
        if not email:
            raise ValueError("Users must have an email address")
        email = self.normalize_email(email).lower()  # Ensure email is lowercase
        user = self.model(email=email, **extra_fields)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, email: str, password: str, **extra_fields):
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("is_admin", True)
        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")
        return self.create_user(email.lower(), password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):
    """
    Custom user model.

    Fields map to the provided schema with Django conventions:
    - id: Primary key (auto-increment), corresponds to User_ID
    - name: varchar(100), corresponds to Name
    - email: varchar(100), unique, corresponds to Email_ID
    - password: hashed password via AbstractBaseUser
    - sort_key: varchar(20), unique, corresponds to Sort_Key
    - is_admin: boolean, default False, corresponds to Is_Admin
    - phone: varchar(15), optional, corresponds to Phone
    - created_at: timestamp, default now, corresponds to Created_At

    Additional fields for Django admin compatibility:
    - is_active, is_staff are standard flags
    """

    name = models.CharField(max_length=100)
    email = models.EmailField(max_length=50, unique=True)
    sort_key = models.CharField(max_length=20, db_index=True, null=False)

    is_admin = models.BooleanField(default=False)
    is_staff = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    phone = models.CharField(
        max_length=15,
        blank=True,
        validators=[RegexValidator(r"^[0-9+\-() ]*$", "Enter a valid phone number")],
    )

    created_at = models.DateTimeField(default=timezone.now, db_index=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS: list[str] = ["name", "sort_key"]

    class Meta:
        db_table = "users"
        verbose_name = "User"
        verbose_name_plural = "Users"
        constraints = [
            models.UniqueConstraint(fields=["email"], name="unique_user_email"),
        ]

    def save(self, *args, **kwargs):
        """Ensure email and sort_key are stored in lowercase."""
        if self.email:
            self.email = self.email.lower()
        if self.sort_key:
            self.sort_key = self.sort_key.lower()
        super().save(*args, **kwargs)

    def __str__(self) -> str:  # pragma: no cover - trivial
        return f"{self.email} ({self.name})"
