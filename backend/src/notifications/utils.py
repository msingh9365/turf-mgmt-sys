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
        Uses batch sending for better performance when multiple devices exist.
        Returns list of responses.
        """
        devices = UserDevice.objects.filter(user=user, is_active=True)
        
        if not devices.exists():
            logger.warning(f"No active devices found for user {user.id}")
            return []
        
        device_tokens = [device.device_token for device in devices]
        
        # Use batch sending if multiple devices (more efficient than loops)
        if len(device_tokens) > 1:
            results = self._send_batch(device_tokens, title, body, data)
            success = any(results)
        else:
            # Single device - use direct send
            resp = self.send_to_device(device_tokens[0], title, body, data)
            results = [resp]
            success = resp is not None
        
        # Create notification record only if at least one send was successful
        if success:
            Notification.objects.create(user=user, title=title, body=body, data=data or {})
            logger.info(f"Notification record created for user {user.id}")
        
        return results
    
    def _send_batch(self, device_tokens, title, body, data=None):
        """
        Send notification to multiple devices using FCM batch API.
        More efficient than individual sends for >1 device.
        Returns list of boolean success indicators.
        """
        if data:
            data = {k: str(v) for k, v in data.items()}
        
        messages = [
            messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                token=token,
                data=data or {},
            )
            for token in device_tokens
        ]
        
        try:
            # send_each() is the current recommended API (send_all is deprecated)
            response = messaging.send_each(messages)
            logger.info(f"Batch sent: {response.success_count}/{len(device_tokens)} successful")
            
            # Mark failed tokens as inactive
            for idx, send_response in enumerate(response.responses):
                if not send_response.success and isinstance(send_response.exception, messaging.UnregisteredError):
                    try:
                        UserDevice.objects.filter(
                            device_token=device_tokens[idx], 
                            is_active=True
                        ).update(is_active=False)
                        logger.warning(f"Deactivated invalid token: {device_tokens[idx]}")
                    except Exception as e:
                        logger.error(f"Failed to deactivate token: {e}")
            
            return [resp.success for resp in response.responses]
        except Exception as e:
            logger.error(f"Batch send error: {e}")
            return [False] * len(device_tokens)

    def broadcast(self, title, body, data=None, exclude_user=None):
        """
        Broadcast notification to all active devices using batch API.
        Creates individual Notification records for each user.
        Optimized with FCM multicast for better performance.
        
        Args:
            title: Notification title
            body: Notification body
            data: Optional data payload
            exclude_user: User object to exclude from broadcast (e.g., the sender)
        
        Returns:
            List of (token, success) tuples.
        """
        devices = UserDevice.objects.filter(is_active=True).select_related('user')
        
        # Exclude devices belonging to the specified user
        if exclude_user:
            devices = devices.exclude(user=exclude_user)
        
        if not devices.exists():
            logger.warning("No active devices found for broadcast")
            return []
        
        # Build token->user mapping for notification record creation
        device_list = list(devices)
        device_tokens = [d.device_token for d in device_list]
        token_to_user = {d.device_token: d.user for d in device_list}
        
        # Use batch sending for efficiency
        success_list = self._send_batch(device_tokens, title, body, data)
        
        # Create notification records for successfully notified users
        notified_users = set()
        notifications_to_create = []
        
        for token, success in zip(device_tokens, success_list):
            if success:
                user = token_to_user[token]
                if user.id not in notified_users:
                    notifications_to_create.append(
                        Notification(user=user, title=title, body=body, data=data or {})
                    )
                    notified_users.add(user.id)
        
        # Bulk create notification records (single DB query instead of N)
        if notifications_to_create:
            Notification.objects.bulk_create(notifications_to_create)

        results = list(zip(device_tokens, success_list))
        logger.info(f"Broadcast sent to {len(notified_users)} users, {sum(success_list)} devices (excluded: {exclude_user.id if exclude_user else 'none'})")
        return results
