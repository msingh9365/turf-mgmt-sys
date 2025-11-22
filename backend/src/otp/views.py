from django.shortcuts import render

# Create your views here.
import random
from django.utils import timezone
from rest_framework.response import Response
from rest_framework import status, generics
from .models import EmailOTP
from django.core.mail import send_mail
from django.conf import settings
from .serializers import SendOTPSerializer, VerifyOTPSerializer


class SendOTPView(generics.GenericAPIView):
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

        # Send Email
        send_mail(
            subject="Your OTP Code",
            message=f"Your OTP is {otp}. It will expire in 5 minutes.",
            from_email=getattr(settings, "DEFAULT_FROM_EMAIL", None),
            recipient_list=[email],
            fail_silently=False,
        )

        return Response({"message": "OTP sent successfully"}, status=status.HTTP_200_OK)


class VerifyOTPView(generics.GenericAPIView):
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
            return Response({"error": "OTP not found"}, status=status.HTTP_400_BAD_REQUEST)

        if entry.is_expired():
            return Response({"error": "OTP expired"}, status=status.HTTP_400_BAD_REQUEST)

        if entry.otp != otp:
            return Response({"error": "Invalid OTP"}, status=status.HTTP_400_BAD_REQUEST)

        # Optionally: delete or mark OTP as used. We'll delete to avoid reuse.
        entry.delete()

        return Response({"message": "OTP verified successfully"}, status=status.HTTP_200_OK)
