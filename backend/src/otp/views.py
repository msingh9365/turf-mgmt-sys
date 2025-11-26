from django.shortcuts import render

# Create your views here.
import random
from django.utils import timezone
from rest_framework.response import Response
from rest_framework import status, generics
from rest_framework.permissions import AllowAny
from .models import EmailOTP
from django.conf import settings
from .serializers import SendOTPSerializer, VerifyOTPSerializer
import sib_api_v3_sdk
from sib_api_v3_sdk.rest import ApiException


class SendOTPView(generics.GenericAPIView):

    # Ignore any Authorization header for this public endpoint
    authentication_classes = []
    permission_classes = [AllowAny]


    serializer_class = SendOTPSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"].lower()

        # Follow signup flow: allow OTP for any (college-domain) email.
        # The frontend will create the user after OTP verification.
        # Rate-limit: if a non-expired OTP exists for this email, deny a new one
        last = EmailOTP.objects.filter(email__iexact=email).order_by("-created_at").first()
        if last and not last.is_expired():
            return Response({"error": "An active OTP was already sent. Please wait until it expires."}, status=status.HTTP_429_TOO_MANY_REQUESTS)

        # Generate OTP
        otp = f"{random.randint(0, 999999):06d}"

        # Save OTP
        EmailOTP.objects.create(email=email, otp=otp, expires_at=EmailOTP.expiry_time(5))

        # Send Email using Brevo API
        try:
            configuration = sib_api_v3_sdk.Configuration()
            configuration.api_key['api-key'] = settings.BREVO_API_KEY
            
            api_instance = sib_api_v3_sdk.TransactionalEmailsApi(sib_api_v3_sdk.ApiClient(configuration))
            
            send_smtp_email = sib_api_v3_sdk.SendSmtpEmail(
                to=[{"email": email}],
                sender={"email": settings.DEFAULT_FROM_EMAIL, "name": "IIT Ropar Sports"},
                subject="Your OTP Code",
                text_content=(
                    f"Dear User,\n\n"
                    f"Your One-Time Password (OTP) for accessing the IIT Ropar Sports Booking System "
                    f"is: {otp}\n\n"
                    f"This OTP is valid for the next 5 minutes and is required to verify your identity "
                    f"before you can continue with secure login and booking operations.\n\n"
                    f"Thank you for using the Proximity-Based Sports Networking & Turf Management System.\n"
                    f"Team EndGame"
                )
            )
            
            api_instance.send_transac_email(send_smtp_email)
            
        except ApiException as e:
            return Response(
                {"error": f"Failed to send email: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        except Exception as e:
            return Response(
                {"error": f"Failed to send email: {str(e)}"},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        return Response(
            {
             "message": "OTP has been sent to your IITRPR email. Please enter it within 5 minutes to continue.",
             "status": "success"
            },
            status=status.HTTP_200_OK
            )


class VerifyOTPView(generics.GenericAPIView):
    
    # Ignore any Authorization header for this public endpoint
    authentication_classes = []
    permission_classes = [AllowAny]

    serializer_class = VerifyOTPSerializer

    def post(self, request):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        email = serializer.validated_data["email"].lower()
        otp = serializer.validated_data["otp"]

        try:
            entry = EmailOTP.objects.filter(email__iexact=email).order_by("-created_at").first()
        except EmailOTP.DoesNotExist:
            entry = None

        if not entry:
            return Response(
                {
                    "error": "No OTP request was found for this email. Please request a new OTP to continue."
                }, status=status.HTTP_400_BAD_REQUEST)

        if entry.is_expired():
            return Response(
                {
                    "error": "Your OTP has expired. Please request a new one to complete your verification."
                }, status=status.HTTP_400_BAD_REQUEST)

        if entry.otp != otp:
            return Response(
                {
                    "error": "The OTP you entered is incorrect. Please try again with the correct code."
                }, status=status.HTTP_400_BAD_REQUEST)


        # Delete or mark OTP as used. delete to avoid reuse.
        entry.delete()

        return Response(
            {
                "message": "OTP verified successfully"
            }, status=status.HTTP_200_OK)
