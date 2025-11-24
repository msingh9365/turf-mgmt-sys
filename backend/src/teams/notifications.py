"""
Notification utilities for Teams module.

Integrates with the notifications.utils module to send team-related notifications
to all team members via FCM (Firebase Cloud Messaging).
"""
import logging
from django.db import transaction
from threading import Thread
from typing import List, Optional

logger = logging.getLogger(__name__)


def send_team_notification(team, notification_type, message, exclude_user_ids=None):
    """
    Send notification to all members of a team asynchronously.
    
    Queues notifications after transaction commit to avoid sending notifications
    for operations that fail/rollback. Uses the notifications.tasks module for async sending.
    
    Args:
        team: Team instance to notify
        notification_type: String identifier for notification type
            Examples: 'MEMBER_ADDED', 'MEMBER_REMOVED', 'CAPTAIN_CHANGED', 'MEMBER_LEFT'
        message: Human-readable message to send
        exclude_user_ids: Optional list of user IDs to exclude from notification
            (e.g., exclude the user who triggered the action)
    
    Returns:
        None (sends async, doesn't wait for completion)
        
    Example:
        send_team_notification(
            team=team,
            notification_type='MEMBER_ADDED',
            message="John Doe was added to the team",
            exclude_user_ids=[request.user.id]
        )
    """
    if exclude_user_ids is None:
        exclude_user_ids = []
    
    def send_after_commit():
        """Lightweight callback that spawns async thread immediately (zero latency)"""
        _send_team_notification_async(
            team_id=team.team_id,
            team_name=team.team_name,
            notification_type=notification_type,
            message=message,
            exclude_user_ids=exclude_user_ids
        )
        logger.info(f"Team notification thread spawned: {notification_type} for team {team.team_id}")
    
    # Defer until transaction commits - prevents notifications on rollback
    # Callback spawns thread immediately, so adds minimal latency
    transaction.on_commit(send_after_commit)


def _send_team_notification_async(team_id, team_name, notification_type, message, exclude_user_ids):
    """
    Internal function to send team notifications asynchronously using threading.
    This runs in a background thread to avoid blocking the API response.
    """
    def _send():
        try:
            from notifications.tasks import send_notification_async
            from teams.models import Team
            
            # Re-fetch team in background thread to avoid DB transaction issues
            team = Team.objects.prefetch_related('members__user').get(team_id=team_id)
            
            # Prepare notification data
            title = f"Team Update: {team_name}"
            data = {
                'team_id': str(team_id),
                'team_name': team_name,
                'notification_type': notification_type,
            }
            
            # Send to each member (except excluded users)
            members = team.members.select_related('user').all()
            for member in members:
                if member.user and member.user.id not in exclude_user_ids:
                    try:
                        # Use the notification async system
                        send_notification_async(
                            user_id=member.user.id,
                            title=title,
                            body=message,
                            data=data
                        )
                        logger.info(f"Queued notification for user {member.user.id} about {notification_type} in team {team_id}")
                    except Exception as e:
                        logger.error(f"Failed to queue notification for user {member.user.id}: {e}")
            
            logger.info(f"Team notifications dispatched: {notification_type} for team {team_id}")
        except Exception as e:
            logger.error(f"Failed to send team notifications for team {team_id}: {e}")
    
    thread = Thread(target=_send, daemon=True)
    thread.start()
