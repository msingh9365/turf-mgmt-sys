from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from django.contrib.auth import get_user_model
from django.conf import settings
from django.utils import timezone
from datetime import timedelta
import logging
import sib_api_v3_sdk
from sib_api_v3_sdk.rest import ApiException

from otp.models import EmailOTP
from .serializers import (
    RequestOTPSerializer, 
    VerifyOTPSerializer, 
    ResetPasswordSerializer
)

User = get_user_model()
logger = logging.getLogger(__name__)


@api_view(['POST'])
@permission_classes([AllowAny])
def request_otp(request):
    """
    Request an OTP for password reset.
    
    Expected payload:
    {
        "email": "user@example.com"
    }
    """
    serializer = RequestOTPSerializer(data=request.data)
    
    if not serializer.is_valid():
        return Response(
            {
                "success": False,
                "message": "Invalid input",
                "errors": serializer.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )
    
    email = serializer.validated_data['email']
    
    try:
        # Rate limiting: Check if user has requested OTP in the last minute
        recent_request = EmailOTP.objects.filter(
            email=email,
            created_at__gte=timezone.now() - timedelta(minutes=1)
        ).first()
        
        if recent_request:
            return Response(
                {
                    "success": False,
                    "message": "Please wait a minute before requesting another OTP"
                },
                status=status.HTTP_429_TOO_MANY_REQUESTS
            )
        
        # Create new password reset request
        import secrets
        otp_code = f"{secrets.randbelow(1000000):06d}"
        reset_request = EmailOTP.objects.create(email=email, otp=otp_code)
        
        # Send OTP via email
        subject = "Password Reset OTP"
        message = f"""
        Hello,
        
        You have requested to reset your password. Please use the following OTP to verify your request:
        
        OTP: {reset_request.otp}
        
        This OTP will expire in 5 minutes.
        
        If you did not request this, please ignore this email.
        
        Best regards,
        Turf Management System Team
        """
        
        try:
            # Send Email using Brevo API (same as your existing OTP implementation)
            configuration = sib_api_v3_sdk.Configuration()
            configuration.api_key['api-key'] = settings.BREVO_API_KEY
            
            api_instance = sib_api_v3_sdk.TransactionalEmailsApi(sib_api_v3_sdk.ApiClient(configuration))
            
            send_smtp_email = sib_api_v3_sdk.SendSmtpEmail(
                to=[{"email": email}],
                sender={"email": settings.DEFAULT_FROM_EMAIL, "name": "IIT Ropar Sports"},
                subject="Password Reset OTP",
                text_content=(
                    f"Dear User,\n\n"
                    f"You have requested to reset your password for the IIT Ropar Sports Booking System.\n\n"
                    f"Your One-Time Password (OTP) is: {reset_request.otp}\n\n"
                    f"This OTP is valid for the next 5 minutes. Please use it to verify your identity "
                    f"and complete the password reset process.\n\n"
                    f"If you did not request this password reset, please ignore this email.\n\n"
                    f"Thank you for using the Proximity-Based Sports Networking & Turf Management System.\n"
                    f"Team EndGame"
                )
            )
            
            api_instance.send_transac_email(send_smtp_email)
            
            logger.info(f"Password reset OTP sent to {email}")
            
            return Response(
                {
                    "success": True,
                    "message": "OTP sent successfully to your email address"
                },
                status=status.HTTP_200_OK
            )
            
        except ApiException as e:
            logger.error(f"Brevo API error for {email}: {str(e)}")
            # Delete the request if email sending failed
            reset_request.delete()
            return Response(
                {
                    "success": False,
                    "message": "Failed to send OTP. Please try again later.",
                    "error": f"Email service error: {str(e)}" if settings.DEBUG else None
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        except Exception as e:
            logger.error(f"Failed to send password reset OTP to {email}: {str(e)}")
            # Delete the request if email sending failed
            reset_request.delete()
            
            return Response(
                {
                    "success": False,
                    "message": "Failed to send OTP. Please try again later.",
                    "error": str(e) if settings.DEBUG else None
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
    
    except Exception as e:
        logger.error(f"Error in request_otp for {email}: {str(e)}")
        return Response(
            {
                "success": False,
                "message": "An error occurred. Please try again later."
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([AllowAny])
def verify_otp(request):
    """
    Verify the OTP sent to user's email.
    
    Expected payload:
    {
        "email": "user@example.com",
        "otp": "123456"
    }
    """
    serializer = VerifyOTPSerializer(data=request.data)
    
    if not serializer.is_valid():
        return Response(
            {
                "success": False,
                "message": "Invalid input",
                "errors": serializer.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )
    
    try:
        # Get the validated reset request from serializer
        reset_request = serializer.validated_data['reset_request']
        
        # OTP is valid, no need to mark as verified since EmailOTP doesn't have that field
        logger.info(f"OTP verified for {reset_request.email}")
        
        return Response(
            {
                "success": True,
                "message": "OTP verified successfully. You can now reset your password."
            },
            status=status.HTTP_200_OK
        )
    
    except Exception as e:
        logger.error(f"Error in verify_otp: {str(e)}")
        return Response(
            {
                "success": False,
                "message": "An error occurred during verification. Please try again."
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(['POST'])
@permission_classes([AllowAny])
def reset_password(request):
    """
    Reset user's password after OTP verification.
    
    Expected payload:
    {
        "email": "user@example.com",
        "new_password": "newpassword123",
        "confirm_password": "newpassword123"
    }
    """
    serializer = ResetPasswordSerializer(data=request.data)
    
    if not serializer.is_valid():
        return Response(
            {
                "success": False,
                "message": "Invalid input",
                "errors": serializer.errors
            },
            status=status.HTTP_400_BAD_REQUEST
        )
    
    email = serializer.validated_data['email']
    new_password = serializer.validated_data['new_password']
    
    try:
        # Get the user
        user = User.objects.get(email=email)
        
        # Update the user's password
        user.set_password(new_password)
        user.save()
        
        # Get the reset request to mark it as used
        reset_request = serializer.validated_data['reset_request']
        
        # Optional: Delete the reset request or mark it as used
        # For security, we'll delete all password reset requests for this email
        EmailOTP.objects.filter(email=email).delete()
        
        logger.info(f"Password reset successful for {email}")
        
        return Response(
            {
                "success": True,
                "message": "Password reset successful. You can now login with your new password."
            },
            status=status.HTTP_200_OK
        )
    
    except User.DoesNotExist:
        return Response(
            {
                "success": False,
                "message": "User not found."
            },
            status=status.HTTP_404_NOT_FOUND
        )
    
    except Exception as e:
        logger.error(f"Error in reset_password for {email}: {str(e)}")
        return Response(
            {
                "success": False,
                "message": "An error occurred during password reset. Please try again."
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )
