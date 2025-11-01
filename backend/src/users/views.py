"""
Views for user registration, login (JWT), profile, and Google Sign-In stub.
"""
from __future__ import annotations

from django.conf import settings
from rest_framework import permissions, status, generics
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework_simplejwt.views import TokenRefreshView
from .models import OTP, User #CustomUser # Assuming CustomUser is your main user model
from .utils import generate_otp, send_verification_email

from rest_framework import viewsets # For BookingViewSet
from rest_framework.decorators import action # For /bookings/{id}/members/
from rest_framework.views import APIView # For DeviceTokenView
from rest_framework.exceptions import ValidationError
from django.db import transaction
from django_redis import get_redis_connection # For Redis lock
import uuid
# Import your models from the same app (since you're keeping them here)
from .models import Booking, Sport, Ground, Slot, BookedDetails
from turfify.models import DeviceToken

from .models import User

from .serializers import (
    LoginSerializer,
    RegisterSerializer,
    TokenPairSerializer,
    UserSerializer,
)

class RegisterView(generics.CreateAPIView):
    """Registers a new user after validating college email domain."""

    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]


class LoginView(generics.GenericAPIView):
    """Authenticates user by email/password and returns a JWT token pair."""

    serializer_class = LoginSerializer
    permission_classes = [permissions.AllowAny]

    def post(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data, context={"request": request})
        serializer.is_valid(raise_exception=True)
        user: User = serializer.validated_data["user"]
        tokens = TokenPairSerializer.for_user(user)
        return Response(tokens, status=status.HTTP_200_OK)


class MeView(generics.RetrieveAPIView):
    """Returns the current authenticated user's profile."""

    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        return self.request.user


class DeviceTokenView(APIView):
    """API endpoint to register and update a user's FCM device token."""
    permission_classes = [permissions.IsAuthenticated] 

    def post(self, request, *args, **kwargs):
        token = request.data.get('fcm_token')
        
        if not token:
            return Response({"detail": "fcm_token field is required."},
                            status=status.HTTP_400_BAD_REQUEST)

        # Use update_or_create to handle both new tokens and token updates
        device, created = DeviceToken.objects.update_or_create(
            token=token,
            defaults={
                'user': request.user,
                'is_active': True,
            }
        )
        
        message = "FCM token registered successfully." if created else "FCM token updated successfully."
        return Response({"detail": message}, status=status.HTTP_200_OK)


class BookingViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    # --- Week 2: Booking Creation Logic ---
    def create(self, request):
        # NOTE: This logic assumes you are handling Ground/Date/Time validation here
        # and depends on the Redis connection and Celery task imports being available.
        
        # Placeholder for Week 2 creation logic (requires Redis lock, transaction, and Celery imports)
        # You will need to bring in the Redis, Celery, and DB logic here
        
        # Example of minimum logic needed:
        # lock_key = f"booking:{ground_id}:{date_str}:{time_str}"
        # redis_conn = get_redis_connection("locks")
        # lock = redis_conn.lock(lock_key, timeout=5)
        # if not lock.acquire(blocking=False): return 409
        # try: with transaction.atomic(): Booking.objects.create(...)
        # finally: lock.release()
        
        return Response({"detail": "Booking Creation API not fully implemented (Week 2 logic needed)."}, status=status.HTTP_501_NOT_IMPLEMENTED)


    # --- Week 3: Member Lock System & Minimum Player Enforcement ---
    @action(detail=True, methods=['post'], url_path='members')
    def members(self, request, pk=None):
        """
        Implements Minimum Player Enforcement and the Member Lock System.
        POST /bookings/{id}/members/
        """
        member_ids_list = request.data.get('member_user_ids', [])
        
        if not isinstance(member_ids_list, list):
            raise ValidationError({'member_user_ids': 'Must be a list of User IDs.'})

        booking_creator_id = request.user.id
        all_participant_ids = set(member_ids_list)
        all_participant_ids.add(booking_creator_id)

        # 1. Retrieve Booking and related Sport data
        try:
            # NOTE: Adjust select_related paths if Sport/Ground/Slot models are defined elsewhere
            booking = Booking.objects.select_related('slot__ground__sport').get(
                pk=pk, user=request.user, status='Waitlist Processing'
            )
            sport_min_players = booking.slot.ground.sport.min_player 
            
        except Booking.DoesNotExist:
            return Response({"detail": "Booking not found or already finalized."}, status=status.HTTP_404_NOT_FOUND)
        except Exception as e:
            # Catch errors if the related models (Slot, Ground, Sport) are not linked correctly
            return Response({"detail": "Error accessing required ground/sport data."}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        # 2. Minimum Player Enforcement
        if len(all_participant_ids) < sport_min_players:
            raise ValidationError({'detail': f'Minimum player requirement not met. Required: {sport_min_players} players.'})

        # 3. Finalize Transaction (Member Lock System & DB Integrity)
        with transaction.atomic():
            
            # Verify all participants are valid registered Users
            valid_users = User.objects.filter(id__in=all_participant_ids).values('id', 'name', 'email', 'sort_key')
            if len(valid_users) != len(all_participant_ids):
                raise ValidationError({'detail': 'One or more submitted User IDs are invalid or non-existent.'})

            # Delete any previous attempts at booking details for this slot
            BookedDetails.objects.filter(slot_id=booking.slot_id).delete()

            # Create BookedDetails records (Member Lock System)
            booked_details_objects = []
            for user_data in valid_users:
                obj = BookedDetails(
                    ground_id=booking.slot.ground_id,
                    slot_id=booking.slot_id,
                    date=booking.slot.date,
                    name=user_data['name'],
                    r_mail=user_data['email'],
                    sort_key=user_data['sort_key'],
                    user_or_not=True,
                    user_id=user_data['id']
                )
                booked_details_objects.append(obj)
            
            BookedDetails.objects.bulk_create(booked_details_objects)
            
            # Finalize Booking Status
            booking.status = 'Done'
            booking.save()
            
            # (Optional: Dispatch success notification task here)

        return Response({"detail": "Booking confirmed, member list locked, and transaction complete."}, status=status.HTTP_200_OK)
    

@api_view(["POST"])
@permission_classes([permissions.AllowAny])
def google_sign_in(request):
    """
    Google Sign-In stub endpoint.

    Expects JSON body with a `token` (ID token) field. For now returns 501.
    When implementing, verify the token against Google's OAuth2 tokeninfo endpoint
    or using google-auth library and the configured client IDs:
    - settings.GOOGLE_CLIENT_ID_ANDROID
    - settings.GOOGLE_CLIENT_ID_WEB
    """
    token = request.data.get("token")
    if not token:
        return Response({"detail": "'token' is required"}, status=status.HTTP_400_BAD_REQUEST)

    return Response(
        {"detail": "Google sign-in not yet implemented"},
        status=status.HTTP_501_NOT_IMPLEMENTED,
    )

@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def send_otp(request):
    email = request.data.get('email')
    
    try:
        user = User.objects.get(email=email)
    except User.DoesNotExist:
        return Response({'detail': 'User not found.'}, status=404)
        
    if user.is_email_verified:
        return Response({'detail': 'Email already verified.'}, status=400)
        
    # 1. Clear old unverified OTPs
    OTP.objects.filter(user=user, is_verified=False).delete()
    
    # 2. Generate and save new OTP
    otp_code = generate_otp()
    OTP.objects.create(user=user, code=otp_code)
    
    # 3. Send email
    send_verification_email(user.email, otp_code)
    
    return Response({'detail': 'OTP sent to email.'}, status=200)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def verify_otp(request):
    email = request.data.get('email')
    otp_entered = request.data.get('otp')
    
    if not email or not otp_entered:
        return Response({'detail': 'Email and OTP are required.'}, status=400)
    
    try:
        user = User.objects.get(email=email)
        otp_instance = OTP.objects.filter(user=user, code=otp_entered, is_verified=False).latest('created_at')
    except (User.DoesNotExist, OTP.DoesNotExist):
        return Response({'detail': 'Invalid OTP or email.'}, status=400)

    if otp_instance.is_valid():
        with transaction.atomic():
            otp_instance.is_verified = True
            otp_instance.save()

            user.is_email_verified = True 
            user.save()
        
        return Response({'detail': 'Verification successful.'}, status=200)
    else:
        return Response({'detail': 'OTP is invalid or expired.'}, status=400)

