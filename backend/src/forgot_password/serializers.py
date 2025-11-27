from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from otp.models import EmailOTP

User = get_user_model()


class RequestOTPSerializer(serializers.Serializer):
    """
    Serializer for requesting an OTP for password reset.
    Validates that the email exists in the system.
    """
    email = serializers.EmailField(
        help_text="Email address of the user requesting password reset"
    )

    def validate_email(self, value):
        """Validate that the email exists in the system."""
        try:
            user = User.objects.get(email=value)
        except User.DoesNotExist:
            raise serializers.ValidationError(
                "No account found with this email address."
            )
        return value


class VerifyOTPSerializer(serializers.Serializer):
    """
    Serializer for verifying the OTP sent to user's email.
    """
    email = serializers.EmailField(
        help_text="Email address of the user"
    )
    otp = serializers.CharField(
        max_length=6,
        min_length=6,
        help_text="6-digit OTP code received in email"
    )

    def validate(self, data):
        """Validate the OTP for the given email."""
        email = data.get('email')
        otp = data.get('otp')

        # Find the most recent OTP request for this email
        try:
            reset_request = EmailOTP.objects.filter(
                email=email
            ).order_by('-created_at').first()

            if not reset_request:
                raise serializers.ValidationError(
                    "No password reset request found for this email."
                )

            if reset_request.otp != otp:
                raise serializers.ValidationError(
                    "Invalid OTP code."
                )

            if reset_request.is_expired():
                raise serializers.ValidationError(
                    "OTP has expired. Please request a new one."
                )

            # Store the validated reset request for use in the view
            data['reset_request'] = reset_request

        except EmailOTP.DoesNotExist:
            raise serializers.ValidationError(
                "No password reset request found for this email."
            )

        return data


class ResetPasswordSerializer(serializers.Serializer):
    """
    Serializer for resetting the password after OTP verification.
    Validates password strength and confirmation.
    """
    email = serializers.EmailField(
        help_text="Email address of the user"
    )
    new_password = serializers.CharField(
        write_only=True,
        style={'input_type': 'password'},
        help_text="New password for the account"
    )
    confirm_password = serializers.CharField(
        write_only=True,
        style={'input_type': 'password'},
        help_text="Confirm the new password"
    )

    def validate_new_password(self, value):
        """Validate password strength using Django's validators."""
        try:
            validate_password(value)
        except DjangoValidationError as e:
            raise serializers.ValidationError(e.messages)
        return value

    def validate(self, data):
        """Validate that passwords match and OTP is verified."""
        email = data.get('email')
        new_password = data.get('new_password')
        confirm_password = data.get('confirm_password')

        # Check if passwords match
        if new_password != confirm_password:
            raise serializers.ValidationError(
                "The two password fields didn't match."
            )

        # Check if there's a recent valid OTP for this email
        try:
            reset_request = EmailOTP.objects.filter(
                email=email
            ).order_by('-created_at').first()

            if not reset_request:
                raise serializers.ValidationError(
                    "No password reset request found. Please request an OTP first."
                )

            if reset_request.is_expired():
                raise serializers.ValidationError(
                    "OTP has expired. Please request a new one."
                )

            # Store the validated reset request for use in the view
            data['reset_request'] = reset_request

        except Exception as e:
            raise serializers.ValidationError(
                "Unable to process password reset. Please try again."
            )

        return data


