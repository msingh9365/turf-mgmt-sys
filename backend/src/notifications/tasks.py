"""
Async notification tasks.
Provides both threading-based (immediate) and Celery-ready task implementations.
"""
import logging
from threading import Thread
from typing import Optional, Dict, Any, List
from django.contrib.auth import get_user_model
from django.db import close_old_connections

logger = logging.getLogger(__name__)

User = get_user_model()


def send_notification_async(user_id: int, title: str, body: str, data: Optional[Dict[str, Any]] = None, sync_for_tests: bool = False):
    """
    Send notification to a user asynchronously using threading.
    This is a quick fix that doesn't block the HTTP response.
    
    Args:
        user_id: ID of the user to notify
        title: Notification title
        body: Notification body
        data: Optional data payload
        sync_for_tests: If True, runs synchronously (for testing)
    """
    def _send():
        try:
            # Close old connections to ensure fresh database state
            close_old_connections()
            
            from .utils import FCMNotificationSender
            
            user = User.objects.get(id=user_id)
            sender = FCMNotificationSender()
            sender.send_to_user(user, title, body, data)
            logger.info(f"Async notification sent to user {user_id}")
        except User.DoesNotExist:
            logger.error(f"User {user_id} not found for notification")
        except Exception as e:
            logger.error(f"Failed to send async notification to user {user_id}: {e}")
        finally:
            # Close connections after thread completes
            close_old_connections()
    
    if sync_for_tests:
        # Run synchronously for tests to avoid transaction isolation issues
        _send()
    else:
        thread = Thread(target=_send, daemon=True)
        thread.start()


def broadcast_notification_async(title: str, body: str, data: Optional[Dict[str, Any]] = None, exclude_user_id: Optional[int] = None):
    """
    Broadcast notification to all users asynchronously using threading.
    
    Args:
        title: Notification title
        body: Notification body
        data: Optional data payload
        exclude_user_id: Optional user ID to exclude from broadcast
    """
    def _broadcast():
        try:
            # Close old connections to ensure fresh database state
            close_old_connections()
            
            from .utils import FCMNotificationSender
            
            sender = FCMNotificationSender()
            exclude_user = None
            if exclude_user_id:
                try:
                    exclude_user = User.objects.get(id=exclude_user_id)
                except User.DoesNotExist:
                    logger.warning(f"Exclude user {exclude_user_id} not found")
            
            # Extract sport_id from data payload for sport-based filtering
            sport_filter = None
            if data and 'sport_id' in data:
                try:
                    sport_filter = int(data['sport_id'])
                except (ValueError, TypeError):
                    logger.warning(f"Invalid sport_id in data: {data.get('sport_id')}, falling back to no filter")
            
            sender.broadcast(title, body, data, exclude_user=exclude_user, sport_filter=sport_filter)
            logger.info(f"Async broadcast notification sent (excluded: {exclude_user_id}, sport_filter: {sport_filter})")
        except Exception as e:
            logger.error(f"Failed to broadcast async notification: {e}")
        finally:
            # Close connections after thread completes
            close_old_connections()
    
    thread = Thread(target=_broadcast, daemon=True)
    thread.start()


# ============================================================================
# Celery-ready task definitions (commented out until Celery is configured)
# ============================================================================
# 
# To enable Celery:
# 1. Add celery to requirements.txt
# 2. Create core/celery.py with Celery app configuration
# 3. Configure CELERY_BROKER_URL in settings (e.g., Redis)
# 4. Uncomment the code below
# 5. Replace threading calls with .delay() calls in signals/views
#
# from celery import shared_task
#
# @shared_task(bind=True, max_retries=3)
# def send_notification_task(self, user_id: int, title: str, body: str, data: Optional[Dict[str, Any]] = None):
#     """
#     Celery task to send notification to a user.
#     Retries on failure with exponential backoff.
#     """
#     try:
#         from .utils import FCMNotificationSender
#         
#         user = User.objects.get(id=user_id)
#         sender = FCMNotificationSender()
#         sender.send_to_user(user, title, body, data)
#         logger.info(f"Celery notification sent to user {user_id}")
#     except User.DoesNotExist:
#         logger.error(f"User {user_id} not found for notification")
#         raise
#     except Exception as e:
#         logger.error(f"Failed to send notification to user {user_id}: {e}")
#         raise self.retry(exc=e, countdown=2 ** self.request.retries)
#
#
# @shared_task(bind=True, max_retries=3)
# def broadcast_notification_task(self, title: str, body: str, data: Optional[Dict[str, Any]] = None, exclude_user_id: Optional[int] = None):
#     """
#     Celery task to broadcast notification to all users.
#     """
#     try:
#         from .utils import FCMNotificationSender
#         
#         sender = FCMNotificationSender()
#         exclude_user = None
#         if exclude_user_id:
#             try:
#                 exclude_user = User.objects.get(id=exclude_user_id)
#             except User.DoesNotExist:
#                 logger.warning(f"Exclude user {exclude_user_id} not found")
#         
#         sender.broadcast(title, body, data, exclude_user=exclude_user)
#         logger.info(f"Celery broadcast notification sent (excluded: {exclude_user_id})")
#     except Exception as e:
#         logger.error(f"Failed to broadcast notification: {e}")
#         raise self.retry(exc=e, countdown=2 ** self.request.retries)
