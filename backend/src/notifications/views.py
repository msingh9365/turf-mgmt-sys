from rest_framework import status, permissions, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from .models import UserDevice, Notification
from .serializers import UserDeviceSerializer, NotificationSerializer
from .utils import FCMNotificationSender
from django.contrib.auth import get_user_model
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
