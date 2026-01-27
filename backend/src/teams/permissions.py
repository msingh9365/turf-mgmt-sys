"""
Permission helper functions for Teams module.

These functions provide reusable authorization checks for team operations.
Used across views to enforce business logic and security rules.
"""
from django.contrib.auth import get_user_model

User = get_user_model()


def is_team_captain(user, team):
    """
    Check if user is the captain of the team.
    
    Args:
        user: User instance (request.user)
        team: Team instance
        
    Returns:
        bool: True if user is the team captain, False otherwise
        
    Example:
        if is_team_captain(request.user, team):
            # Allow captain-only operation
    """
    return team.captain_id == user.id


def is_admin_user(user):
    """
    Check if user has admin privileges.
    
    Admin users can perform operations on any team regardless of membership.
    Uses the is_admin flag from the User model.
    
    Args:
        user: User instance (request.user)
        
    Returns:
        bool: True if user has is_admin=True, False otherwise
        
    Example:
        if is_admin_user(request.user):
            # Allow admin override
    """
    return getattr(user, 'is_admin', False)


def is_team_member(user, team):
    """
    Check if user is a member of the team.
    
    This includes both captain and regular members.
    Uses optimized two-step lookup: sort_key filter followed by user_id check.
    
    Args:
        user: User instance (request.user)
        team: Team instance
        
    Returns:
        bool: True if user is a member of the team, False otherwise
        
    Example:
        if is_team_member(request.user, team):
            # Allow member operation
    """
    # Optimized lookup using indexed sort_key field
    user_email = getattr(user, 'email', '')
    if not user_email:
        return False
    
    sort_key = user_email[:7].lower() if len(user_email) >= 7 else user_email.lower()
    return team.members.filter(sort_key__iexact=sort_key, user_id=user.id).exists()


def can_modify_team(user, team):
    """
    Check if user can modify team settings (captain or admin).
    
    Convenience function that combines captain and admin checks.
    
    Args:
        user: User instance (request.user)
        team: Team instance
        
    Returns:
        bool: True if user is captain or admin, False otherwise
        
    Example:
        if not can_modify_team(request.user, team):
            return Response({"message": "Permission denied"}, status=403)
    """
    return is_team_captain(user, team) or is_admin_user(user)
