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
            action = 'created' if created else 'updated'
            logger.info(f"Device {action}: {device_token[:20]}... for user {user.id} ({user.email})")
            return Response({'detail': 'Device registered.'}, status=status.HTTP_201_CREATED)
        logger.error(f"Device registration failed: {serializer.errors}")
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class SendNotificationView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        from .tasks import send_notification_async, broadcast_notification_async
        
        title = request.data.get('title')
        body = request.data.get('body')
        data = request.data.get('data', {})
        user_id = request.data.get('user_id')
        
        if user_id:
            User = get_user_model()
            try:
                user = User.objects.get(id=user_id)
            except User.DoesNotExist:
                return Response({'detail': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)
            # Send async to specific user
            send_notification_async(user.id, title, body, data)
        else:
            # Broadcast async to all users
            broadcast_notification_async(title, body, data)
        
        logger.info(f"Notification queued: {title}")
        return Response({'detail': 'Notification queued for delivery.'}, status=status.HTTP_202_ACCEPTED)

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
            # Handle slot_id being a list or single value
            if isinstance(slot_id, (list, tuple)):
                normalized_slot_ids.extend(slot_id)
            else:
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

        # Send broadcast notification asynchronously (exclude the sender)
        from .tasks import broadcast_notification_async
        broadcast_notification_async(title, body, data, exclude_user_id=user.id)

        logger.info(
            "Broadcast queued by user %s for %s on %s at slots %s",
            user.id,
            sport.sport_name,
            date,
            slot_ids_sorted,
        )

        return Response(
            {
                'detail': 'Broadcast notification queued successfully.',
                'sport': sport.sport_name,
                'date': date,
                'slot_time': slot_time_text,
                'slot_times': slot_times,
            },
            status=status.HTTP_202_ACCEPTED
        )
    
    def _format_slot_time(self, slot_id):
        """
        Convert slot_id to readable time range.
        Slot 1 = 8:00 AM - 8:30 AM, ... Slot 28 = 9:30 PM - 10:00 PM.
        """
        slot_map = {
            1: "8:00 AM - 8:30 AM",
            2: "8:30 AM - 9:00 AM",
            3: "9:00 AM - 9:30 AM",
            4: "9:30 AM - 10:00 AM",
            5: "10:00 AM - 10:30 AM",
            6: "10:30 AM - 11:00 AM",
            7: "11:00 AM - 11:30 AM",
            8: "11:30 AM - 12:00 PM",
            9: "12:00 PM - 12:30 PM",
            10: "12:30 PM - 1:00 PM",
            11: "1:00 PM - 1:30 PM",
            12: "1:30 PM - 2:00 PM",
            13: "2:00 PM - 2:30 PM",
            14: "2:30 PM - 3:00 PM",
            15: "3:00 PM - 3:30 PM",
            16: "3:30 PM - 4:00 PM",
            17: "4:00 PM - 4:30 PM",
            18: "4:30 PM - 5:00 PM",
            19: "5:00 PM - 5:30 PM",
            20: "5:30 PM - 6:00 PM",
            21: "6:00 PM - 6:30 PM",
            22: "6:30 PM - 7:00 PM",
            23: "7:00 PM - 7:30 PM",
            24: "7:30 PM - 8:00 PM",
            25: "8:00 PM - 8:30 PM",
            26: "8:30 PM - 9:00 PM",
            27: "9:00 PM - 9:30 PM",
            28: "9:30 PM - 10:00 PM",
        }
        try:
            slot_num = int(slot_id)
            return slot_map.get(slot_num, f"Slot {slot_id}")
        except (ValueError, TypeError):
            return f"Slot {slot_id}"

    def _format_slot_end_time(self, slot_id):
        """
        Extract end time from slot mapping.
        """
        time_range = self._format_slot_time(slot_id)
        if " - " in time_range:
            return time_range.split(" - ")[1]
        return time_range

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


class MarkNotificationAsReadView(APIView):
    """
    Mark a single notification as read.
    PATCH /api/notifications/<id>/mark-read/
    """
    permission_classes = [permissions.IsAuthenticated]

    def patch(self, request, notification_id):
        try:
            notification = Notification.objects.get(id=notification_id, user=request.user)
        except Notification.DoesNotExist:
            return Response(
                {'detail': 'Notification not found or you do not have permission to access it.'},
                status=status.HTTP_404_NOT_FOUND
            )
        
        notification.is_read = True
        notification.save(update_fields=['is_read'])
        
        serializer = NotificationSerializer(notification)
        logger.info(f"Notification {notification_id} marked as read by user {request.user.id}")
        return Response(serializer.data, status=status.HTTP_200_OK)


class MarkAllNotificationsReadView(APIView):
    """
    Mark all notifications for the authenticated user as read.
    POST /api/notifications/mark-all-read/
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        updated_count = Notification.objects.filter(
            user=request.user,
            is_read=False
        ).update(is_read=True)
        
        logger.info(f"User {request.user.id} marked {updated_count} notifications as read")
        return Response(
            {
                'detail': f'{updated_count} notification(s) marked as read.',
                'count': updated_count
            },
            status=status.HTTP_200_OK
        )


class UnreadNotificationCountView(APIView):
    """
    Get the count of unread notifications for the authenticated user.
    GET /api/notifications/unread-count/
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        unread_count = Notification.objects.filter(
            user=request.user,
            is_read=False
        ).count()
        
        return Response(
            {'unread_count': unread_count},
            status=status.HTTP_200_OK
        )
