"""
Notification utilities for Teams module.

Integrates with the notifications.utils module to send team-related notifications
to all team members via FCM (Firebase Cloud Messaging).
"""
import logging
from notifications.utils import FCMNotificationSender

logger = logging.getLogger(__name__)


def send_team_notification(team, notification_type, message, exclude_user_ids=None):
    """
    Send notification to all members of a team.
    
    Uses the existing FCMNotificationSender to send push notifications to all
    active devices registered by team members. Optionally excludes specific users.
    
    Args:
        team: Team instance to notify
        notification_type: String identifier for notification type
            Examples: 'MEMBER_ADDED', 'MEMBER_REMOVED', 'CAPTAIN_CHANGED', 'MEMBER_LEFT'
        message: Human-readable message to send
        exclude_user_ids: Optional list of user IDs to exclude from notification
            (e.g., exclude the user who triggered the action)
    
    Returns:
        int: Number of users successfully notified
        
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
    
    # Get all team members
    members = team.members.select_related('user').all()
    
    # Initialize FCM sender
    fcm_sender = FCMNotificationSender()
    
    # Prepare notification data
    title = f"Team Update: {team.team_name}"
    data = {
        'team_id': str(team.team_id),
        'team_name': team.team_name,
        'notification_type': notification_type,
    }
    
    # Send to each member (except excluded users)
    notified_count = 0
    for member in members:
        if member.user and member.user.id not in exclude_user_ids:
            try:
                results = fcm_sender.send_to_user(
                    user=member.user,
                    title=title,
                    body=message,
                    data=data
                )
                # Count as notified if at least one device received the message
                if any(results):
                    notified_count += 1
                    logger.info(f"Notified user {member.user.id} about {notification_type} in team {team.team_id}")
            except Exception as e:
                logger.error(f"Failed to notify user {member.user.id}: {e}")
                # Continue sending to other members even if one fails
    
    logger.info(f"Team notification sent: {notification_type} for team {team.team_id} - {notified_count} users notified")
    return notified_count
