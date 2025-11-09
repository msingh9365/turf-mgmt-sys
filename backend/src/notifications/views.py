from rest_framework import status, permissions, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import UserDevice, Notification
from .serializers import UserDeviceSerializer, NotificationSerializer
from .utils import FCMNotificationSender
from django.contrib.auth import get_user_model
from bookings.models import Sport, Slot
import logging

logger = logging.getLogger(__name__)

class RegisterDeviceView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = UserDeviceSerializer(data=request.data)
        if serializer.is_valid():
            device_token = serializer.validated_data['device_token']
            device_type = serializer.validated_data['device_type']
            user = request.user
            device, created = UserDevice.objects.update_or_create(
                device_token=device_token,
                defaults={
                    'user': user,
                    'device_type': device_type,
                    'is_active': True,
                }
            )
            logger.info(f"Device registered: {device_token} for user {user.id}")
            return Response({'detail': 'Device registered.'}, status=status.HTTP_201_CREATED)
        logger.error(f"Device registration failed: {serializer.errors}")
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class SendNotificationView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        title = request.data.get('title')
        body = request.data.get('body')
        data = request.data.get('data', {})
        user_id = request.data.get('user_id')
        sender = FCMNotificationSender()
        if user_id:
            User = get_user_model()
            try:
                user = User.objects.get(id=user_id)
            except User.DoesNotExist:
                return Response({'detail': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)
            sender.send_to_user(user, title, body, data)
        else:
            sender.broadcast(title, body, data)
        logger.info(f"Notification sent: {title}")
        return Response({'detail': 'Notification sent.'}, status=status.HTTP_200_OK)

class NotificationHistoryView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = NotificationSerializer

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user).order_by('-created_at')


class BroadcastLookingForPlayersView(APIView):
    """
    Broadcast a notification to all users that the authenticated user is looking for players.
    Requires: sport_id, date, slot_id
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        sport_id = request.data.get('sport_id')
        date = request.data.get('date')
        # Support both single and multiple slots: slot_id or slot_ids
        slot_id = request.data.get('slot_id')
        slot_ids = request.data.get('slot_ids')

        # Normalize slot_ids
        normalized_slot_ids = []
        if slot_ids is not None:
            # Could be a list or a comma-separated string
            if isinstance(slot_ids, str):
                parts = [p.strip() for p in slot_ids.split(',') if p.strip()]
                normalized_slot_ids = parts
            elif isinstance(slot_ids, (list, tuple)):
                normalized_slot_ids = list(slot_ids)
            else:
                return Response(
                    {'detail': 'slot_ids must be a list or comma-separated string.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        if slot_id is not None:
            normalized_slot_ids.append(slot_id)

        # Coerce to strings then ints where possible to be tolerant of input types
        coerced_slot_ids = []
        for sid in normalized_slot_ids:
            try:
                coerced_slot_ids.append(int(str(sid)))
            except (TypeError, ValueError):
                return Response(
                    {'detail': f'Invalid slot id: {sid}'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        # Validate required fields
        if not sport_id or not date or not coerced_slot_ids:
            return Response(
                {'detail': 'sport_id, date, and at least one slot_id/slot_ids are required.'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Validate sport exists
        try:
            sport = Sport.objects.get(sport_id=sport_id)
        except Sport.DoesNotExist:
            return Response(
                {'detail': 'Sport not found.'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Validate slots exist for the given sport and date
        # Note: slot_id is not globally unique; uniqueness is (ground, date, slot_id).
        # We check presence of each requested slot_id across any ground for the sport.
        existing = set(
            Slot.objects.filter(
                slot_id__in=coerced_slot_ids,
                date=date,
                ground__sport_id=sport_id,
            ).values_list('slot_id', flat=True).distinct()
        )
        missing = [sid for sid in sorted(set(coerced_slot_ids)) if sid not in existing]
        if missing:
            return Response(
                {'detail': f'Slot(s) not found for given sport/date: {missing}'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Get user details
        user = request.user
        user_email = user.email
        user_name = getattr(user, 'name', None) or user.email.split('@')[0]

        # Format slot time(s) from slot ids
        slot_times = [self._format_slot_time(sid) for sid in coerced_slot_ids]
        slot_time_text = ", ".join(slot_times)

        # Construct notification message
        title = f"Players Needed for {sport.sport_name}!"
        body = (
            f"{user_name} ({user_email}) is looking for players for {sport.sport_name} "
            f"on {date} at {slot_time_text}. Interested? Contact them!"
        )

        # Data payload for app deep-linking
        data = {
            'type': 'looking_for_players',
            'sport_id': str(sport_id),
            'sport_name': sport.sport_name,
            'date': date,
            # Only include human-readable times; do not include slot ids
            'slot_time': slot_time_text,
            'slot_times': slot_times,
            'user_name': user_name,
            'user_email': user_email,
        }

        # Send broadcast notification (exclude the sender)
        sender = FCMNotificationSender()
        results = sender.broadcast(title, body, data, exclude_user=user)

        logger.info(
            "Broadcast sent by user %s for %s on %s at slot %s",
            user.id,
            sport.sport_name,
            date,
            coerced_slot_ids,
        )

        return Response(
            {
                'detail': 'Broadcast notification sent successfully.',
                'recipients': len(results),
                'sport': sport.sport_name,
                'date': date,
                'slot_time': slot_time_text,
                'slot_times': slot_times,
            },
            status=status.HTTP_200_OK
        )
    
    def _format_slot_time(self, slot_id):
        """
        Convert slot_id to readable time format.
        Assuming slots are 30-minute intervals starting from 00:00 (1-48).
        """
        try:
            slot_num = int(slot_id)
            hours = (slot_num - 1) // 2
            minutes = ((slot_num - 1) % 2) * 30
            return f"{hours:02d}:{minutes:02d}"
        except (ValueError, TypeError):
            return f"Slot {slot_id}"
