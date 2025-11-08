import os
import json
import logging
import firebase_admin
from firebase_admin import credentials, messaging
from django.conf import settings
from .models import Notification, UserDevice

logger = logging.getLogger(__name__)

# Initialize Firebase app once
if not firebase_admin._apps:
    # Try to load from environment variable first (for production/Render)
    firebase_json = os.environ.get('FIREBASE_SERVICE_ACCOUNT_JSON')
    
    if firebase_json:
        # Production: Load from environment variable
        service_account_info = json.loads(firebase_json)
        cred = credentials.Certificate(service_account_info)
        logger.info("Firebase initialized from environment variable")
    else:
        # Local development: Load from file
        SERVICE_ACCOUNT_PATH = os.path.join(
            os.path.dirname(__file__), 
            'campus-court-firebase-adminsdk-fbsvc-5a6d8c607a.json'
        )
        cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
        logger.info("Firebase initialized from local file")
    
    firebase_admin.initialize_app(cred)

class FCMNotificationSender:
    """
    Uses firebase-admin and service account for secure FCM notification sending.
    """
    def send_to_device(self, device_token, title, body, data=None):
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=device_token,
            data=data or {},
        )
        try:
            response = messaging.send(message)
            logger.info(f"FCM sent to {device_token}: {response}")
            return response
        except Exception as e:
            logger.error(f"FCM send error to {device_token}: {e}")
            return None

    def send_to_user(self, user, title, body, data=None):
        devices = UserDevice.objects.filter(user=user, is_active=True)
        results = []
        for device in devices:
            resp = self.send_to_device(device.device_token, title, body, data)
            results.append(resp)
            if resp:
                Notification.objects.create(user=user, title=title, body=body, data=data or {})
            else:
                logger.error(f"Failed to send notification to {device.device_token}")
        return results

    def broadcast(self, title, body, data=None):
        devices = UserDevice.objects.filter(is_active=True)
        results = []
        for device in devices:
            resp = self.send_to_device(device.device_token, title, body, data)
            results.append(resp)
            if resp:
                Notification.objects.create(user=device.user, title=title, body=body, data=data or {})
            else:
                logger.error(f"Failed to send notification to {device.device_token}")
        return results
