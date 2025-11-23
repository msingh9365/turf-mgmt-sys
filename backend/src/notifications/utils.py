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
        """
        Send notification to a single device.
        Returns message_id on success, None on failure.
        """
        # Ensure data values are strings (FCM requirement)
        if data:
            data = {k: str(v) for k, v in data.items()}
        
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
        except messaging.UnregisteredError as e:
            logger.warning(f"Deactivating invalid FCM token {device_token}: {e}")
            try:
                UserDevice.objects.filter(device_token=device_token, is_active=True).update(is_active=False)
            except Exception as db_e:
                logger.error(f"Failed to deactivate device token {device_token}: {db_e}")
            return None
        except firebase_admin.exceptions.FirebaseError as e:
            logger.error(f"FCM send error to {device_token}: {e}")
            return None

    def send_to_user(self, user, title, body, data=None):
        """
        Send notification to all active devices of a user.
        Creates a Notification record only once per user (not per device).
        Returns list of responses.
        """
        devices = UserDevice.objects.filter(user=user, is_active=True)
        
        if not devices.exists():
            logger.warning(f"No active devices found for user {user.id}")
            return []
        
        results = []
        success = False
        
        for device in devices:
            resp = self.send_to_device(device.device_token, title, body, data)
            results.append(resp)
            if resp:
                success = True
        
        # Create notification record only if at least one send was successful
        if success:
            Notification.objects.create(user=user, title=title, body=body, data=data or {})
            logger.info(f"Notification record created for user {user.id}")
        
        return results

    def broadcast(self, title, body, data=None, exclude_user=None):
        """
        Broadcast notification to all active devices.
        Creates individual Notification records for each user.
        
        Args:
            title: Notification title
            body: Notification body
            data: Optional data payload
            exclude_user: User object to exclude from broadcast (e.g., the sender)
        
        Returns:
            List of responses.
        """
        devices = UserDevice.objects.filter(is_active=True)
        
        # Exclude devices belonging to the specified user
        if exclude_user:
            devices = devices.exclude(user=exclude_user)
        
        if not devices.exists():
            logger.warning("No active devices found for broadcast")
            return []
        
        results = []
        notified_users = set()

        for device in devices:
            resp = self.send_to_device(device.device_token, title, body, data)
            results.append((device.device_token, resp))

            if resp and device.user.id not in notified_users:
                Notification.objects.create(user=device.user, title=title, body=body, data=data or {})
                notified_users.add(device.user.id)

        logger.info(f"Broadcast successful for {len(notified_users)} users (excluded: {exclude_user.id if exclude_user else 'none'})")
        return results
