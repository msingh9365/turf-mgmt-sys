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
        
        # No slot validation: slots are only created when booked
        # We broadcast notifications regardless of slot existence in DB
        
        # Get user details
        user = request.user
        user_email = user.email
        user_name = getattr(user, 'name', None) or user.email.split('@')[0]

        # Format slot time(s) from slot ids
        # Display merged continuous ranges (e.g., "04:30 - 06:00") instead of discrete times
        slot_ids_sorted = sorted(set(coerced_slot_ids))
        slot_times = [self._format_slot_time(sid) for sid in slot_ids_sorted]
        slot_time_text = self._format_slot_range_text(slot_ids_sorted)

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
        success_count = sum(1 for _, r in results if r)
        failed_tokens = [t for t, r in results if not r]

        logger.info(
            "Broadcast sent by user %s for %s on %s at slots %s",
            user.id,
            sport.sport_name,
            date,
            slot_ids_sorted,
        )

        return Response(
            {
                'detail': 'Broadcast notification sent successfully.',
                'recipients': success_count,
                'failed_tokens': failed_tokens,
                'sport': sport.sport_name,
                'date': date,
                'slot_time': slot_time_text,
                'slot_times': slot_times,
            },
            status=status.HTTP_200_OK
        )
    
    def _format_slot_time(self, slot_id):
        """
        Convert slot_id to readable 12-hour start time.
        Slots start at 8:00 AM. Slot 1 = 8:00 AM - 8:30 AM, ... Slot 28 = 9:30 PM - 10:00 PM.
        """
        try:
            slot_num = int(slot_id)
            if slot_num < 1 or slot_num > 28:
                return f"Slot {slot_id}"
            total_minutes = 8 * 60 + (slot_num - 1) * 30
            return self._format_minutes_12h(total_minutes)
        except (ValueError, TypeError):
            return f"Slot {slot_id}"

    def _format_slot_end_time(self, slot_id):
        """
        End time is 30 minutes after slot start. Slot 28 ends at 10:00 PM.
        """
        try:
            slot_num = int(slot_id)
            if slot_num < 1 or slot_num > 28:
                return f"Slot {slot_id}"
            total_minutes = 8 * 60 + slot_num * 30  # end boundary
            return self._format_minutes_12h(total_minutes)
        except (ValueError, TypeError):
            return f"Slot {slot_id}"

    def _format_slot_range_text(self, slot_ids):
        """
        Given a sorted list of slot_ids, merge continuous sequences into time ranges.
        Example: [9,10,11] -> "04:00 - 05:30". Multiple ranges will be comma-separated.
        """
        if not slot_ids:
            return ""

        ranges = []
        start = prev = slot_ids[0]
        for sid in slot_ids[1:]:
            if sid == prev + 1:
                prev = sid
                continue
            # close current range
            ranges.append((start, prev))
            start = prev = sid
        ranges.append((start, prev))

        parts = []
        for s, e in ranges:
            start_text = self._format_slot_time(s)
            end_text = self._format_slot_end_time(e)
            parts.append(f"{start_text} - {end_text}")
        return ", ".join(parts)

    def _format_minutes_12h(self, total_minutes: int) -> str:
        """Format minutes since 00:00 to 12-hour clock like '8:00 AM'."""
        hours24 = (total_minutes // 60) % 24
        minutes = total_minutes % 60
        suffix = "AM" if hours24 < 12 else "PM"
        hours12 = hours24 % 12
        if hours12 == 0:
            hours12 = 12
        return f"{hours12}:{minutes:02d} {suffix}"
