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
        slot_id = request.data.get('slot_id')
        
        # Validate required fields
        if not all([sport_id, date, slot_id]):
            return Response(
                {'detail': 'sport_id, date, and slot_id are required.'},
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
        
        # Validate slot exists
        try:
            slot = Slot.objects.get(slot_id=slot_id)
        except Slot.DoesNotExist:
            return Response(
                {'detail': 'Slot not found.'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        # Get user details
        user = request.user
        user_email = user.email
        user_name = user.name if hasattr(user, 'name') and user.name else user.email.split('@')[0]
        
        # Format slot time (assuming slot_id maps to time)
        slot_time = self._format_slot_time(slot_id)
        
        # Construct notification message
        title = f"Players Needed for {sport.sport_name}!"
        body = f"{user_name} ({user_email}) is looking for players for {sport.sport_name} on {date} at {slot_time}. Interested? Contact them!"
        
        # Data payload for app deep-linking
        data = {
            'type': 'looking_for_players',
            'sport_id': str(sport_id),
            'sport_name': sport.sport_name,
            'date': date,
            'slot_id': str(slot_id),
            'slot_time': slot_time,
            'user_name': user_name,
            'user_email': user_email,
        }
        
        # Send broadcast notification
        sender = FCMNotificationSender()
        results = sender.broadcast(title, body, data)
        
        logger.info(f"Broadcast sent by user {user.id} for {sport.sport_name} on {date} at slot {slot_id}")
        
        return Response(
            {
                'detail': 'Broadcast notification sent successfully.',
                'recipients': len(results),
                'sport': sport.sport_name,
                'date': date,
                'slot_time': slot_time,
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
