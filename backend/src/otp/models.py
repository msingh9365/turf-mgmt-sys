from django.db import models
from django.utils import timezone
from django.core.validators import RegexValidator
from datetime import timedelta

class EmailOTP(models.Model):
    email = models.EmailField()
    otp = models.CharField(
        max_length=6,
        validators=[RegexValidator(r"^\d{6}$", "Enter a valid 6-digit OTP")],
    )
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()

    def is_expired(self):
        return timezone.now() > self.expires_at

    @staticmethod
    def expiry_time(minutes=5):
        return timezone.now() + timedelta(minutes=minutes)

    def save(self, *args, **kwargs):
        # Ensure expires_at is always set (helps avoid accidental nulls when
        # creating instances via code). Do not change DB field nullability here
        # to avoid extra migrations; just set a default before saving.
        if not self.expires_at:
            self.expires_at = self.expiry_time()
        super().save(*args, **kwargs)

    def __str__(self):
        # Avoid exposing full OTP in logs/representations. Show masked value.
        masked = f"****{self.otp[-2:]}" if self.otp and len(self.otp) >= 2 else "****"
        return f"{self.email} - {masked}"

    class Meta:
        indexes = [models.Index(fields=["email"]), models.Index(fields=["expires_at"]) ]
