# FILE: I:\PGSL Project\turf-mgmt-sys\backend\src\turfify\utils.py

from firebase_admin import messaging
from firebase_admin import exceptions as firebase_exceptions
from django.contrib.auth import get_user_model

from celery import shared_task # <-- NEW IMPORT
from .models import DeviceToken

# Assuming DeviceToken is in turfify/models.py
from .models import DeviceToken 

User = get_user_model() # Get your custom User model

def send_fcm_notification(user_id: int, title: str, body: str, data: dict = None):
    """
    Sends an FCM notification to all active devices of a given user.
    Also handles errors to deactivate stale tokens.
    """
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        print(f"ERROR: User with ID {user_id} not found.")
        return False
    
    # 1. Get all active tokens for the user
    tokens = DeviceToken.objects.filter(user=user, is_active=True).values_list('token', flat=True)
    
    if not tokens:
        print(f"INFO: User {user.username} has no active FCM tokens.")
        return False
        
    # 2. Build the FCM message payload
    message = messaging.MulticastMessage(
        tokens=list(tokens), 
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        # Ensure all data values are strings for Firebase
        data={str(k): str(v) for k, v in (data or {}).items()}, 
    )
    
    # 3. Send the message and handle errors
    try:
        response = messaging.send_multicast(message)
        
        # 4. Process the response to find and deactivate bad tokens
        if response.failure_count > 0:
            bad_tokens = []
            for idx, resp in enumerate(response.responses):
                if not resp.success:
                    # Tokens that are NOT_FOUND or INVALID are permanently unusable
                    if resp.exception and resp.exception.code in ('UNREGISTERED', 'INVALID_ARGUMENT'):
                        bad_tokens.append(tokens[idx])
            
            # Deactivate the invalid tokens
            if bad_tokens:
                DeviceToken.objects.filter(token__in=bad_tokens).update(is_active=False)
                print(f"INFO: Deactivated {len(bad_tokens)} stale FCM tokens for user {user.username}.")
                
        print(f"✅ INFO: FCM: Sent {response.success_count}, Failed {response.failure_count}")
        return True
        
    except firebase_exceptions.FirebaseError as e:
        print(f"❌ ERROR: Firebase Admin SDK error during send: {e}")
        return False
    

# Convert the utility function into a Celery task using the decorator
@shared_task(bind=True, max_retries=3) # Add bind=True and max_retries for failure handling
def send_fcm_notification_task(self, user_id: int, title: str, body: str, data: dict = None):
    """
    Celery task to send an FCM notification to a user's active devices.
    Runs asynchronously and handles token cleanup.
    """
    User = get_user_model()
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        print(f"ERROR: User with ID {user_id} not found.")
        return False
    
    # ... (Rest of the logic from before, unchanged) ...
    tokens = DeviceToken.objects.filter(user=user, is_active=True).values_list('token', flat=True)
    
    if not tokens:
        print(f"INFO: User {user.username} has no active FCM tokens.")
        return False
        
    message = messaging.MulticastMessage(
        tokens=list(tokens), 
        notification=messaging.Notification(title=title, body=body),
        data={str(k): str(v) for k, v in (data or {}).items()}, 
    )
    
    try:
        response = messaging.send_multicast(message)
        # ... (Token cleanup logic remains here) ...
        print(f"✅ INFO: FCM: Sent {response.success_count}, Failed {response.failure_count}")
        return True
        
    except firebase_exceptions.FirebaseError as exc:
        # If Firebase fails, Celery retries the task after a delay
        raise self.retry(exc=exc, countdown=2 ** self.request.retries) 
    except Exception as e:
        print(f"CRITICAL ERROR: Unexpected error during FCM send: {e}")
        return False