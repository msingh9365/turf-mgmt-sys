from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.db.models import Q
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status, permissions
from teams.models import Team, Invitation, TeamMember
from bookings.models import Sport
from teams.permissions import is_team_captain, is_admin_user, is_team_member, can_modify_team
from teams.notifications import send_team_notification
from teams.serializers import (
    BulkUpdateTeamSerializer, 
    TransferCaptainSerializer,
    MatchInviteSerializer,
    InvitationDetailSerializer
)
import logging

User = get_user_model()
logger = logging.getLogger(__name__)


@api_view(["GET", "POST"])
def list_or_create_team(request):
    """
    Handles GET and POST requests for /api/teams/
    GET: Lists all teams (no authentication required).
    POST: Creates a new team (authentication required, member count >= sport.min_player)
    """
    if request.method == "POST":
        # Enforce authentication for POST requests
        if not request.user or not request.user.is_authenticated:
            return Response(
                {"message": "Authentication required to create a team."},
                status=status.HTTP_401_UNAUTHORIZED
            )
        try:
            team_name = request.data["team_name"]
            sport_id = request.data["sport_id"]
            member_emails = request.data.get("member_emails", [])
            
            # Deduplicate member emails (case-insensitive) and filter empty strings
            member_emails = list(set(email.strip().lower() for email in member_emails if email and email.strip()))
            
            # Use authenticated user as captain (authentication enforced by decorator)
            captain = request.user

            sport = Sport.objects.get(sport_id=sport_id)
            
            # Remove captain's email from member list if accidentally included
            captain_email = getattr(captain, 'email', '').lower()
            if captain_email in member_emails:
                member_emails.remove(captain_email)

            # ✅ Minimum player validation
            if len(member_emails) + 1 < sport.min_player:  # +1 for captain
                return Response(
                    {"message": f"Minimum {sport.min_player} players required for {sport.sport_name}."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # Use atomic transaction to ensure all-or-nothing team creation
            with transaction.atomic():
                # ✅ Create team (will raise IntegrityError if duplicate name)
                team = Team.objects.create(
                    team_name=team_name,
                    captain=captain,
                    sport=sport,
                    member_count=len(member_emails) + 1,
                    achievements=request.data.get("achievements", "")
                )

                # ✅ Add captain as team member
                captain_email = getattr(captain, 'email', '')
                TeamMember.objects.create(
                    team=team,
                    user=captain,
                    member_name=getattr(captain, 'name', captain.email),
                    email_id=captain_email,
                    sort_key=(captain_email[:7].lower() if len(captain_email) >= 7 else captain_email.lower()),
                    role="captain"
                )

                # ✅ Add other members (only valid users)
                added_members = 0
                failed_emails = []
                for email in member_emails:
                    try:
                        # Case-insensitive two-step lookup:
                        # 1. Narrow by sort_key (first 7 chars of email) using indexed field
                        # 2. Exact (case-insensitive) match on email within that subset
                        email_l = (email or "").strip().lower()
                        prefix = email_l[:7] if len(email_l) >= 7 else email_l
                        try:
                            member = User.objects.filter(sort_key__iexact=prefix).get(email__iexact=email_l)
                        except User.DoesNotExist:
                            # Fallback: direct email lookup (handles legacy or missing sort_key consistency)
                            member = User.objects.get(email__iexact=email_l)

                        # Create membership; dedup on DB-level unique constraint (team, user)
                        member_email = getattr(member, 'email', '')
                        TeamMember.objects.create(
                            team=team,
                            user=member,
                            member_name=getattr(member, 'name', member.email),
                            email_id=member_email,
                            sort_key=(member_email[:7].lower() if len(member_email) >= 7 else member_email.lower()),
                            role="player"
                        )
                        added_members += 1
                    except User.DoesNotExist:
                        # Track emails that don't correspond to registered users
                        failed_emails.append(email)

                # Update actual member count based on what was added
                team.member_count = added_members + 1  # +1 for captain
                team.save(update_fields=['member_count'])

            team_data = {
                "team_id": team.team_id,
                "team_name": team.team_name,
                "captain_name": getattr(team.captain, 'name', team.captain.email),
                "sport_name": team.sport.sport_name,
                "sport_id": team.sport.sport_id,
                "member_count": team.member_count,
                "created_at": team.created_at,
                "achievements": team.achievements,
            }
            
            # Add warning if some members weren't added with email details
            if failed_emails:
                team_data["warning"] = f"Team created but {len(failed_emails)} member(s) not found and were not added."
                team_data["rejected_members"] = failed_emails

            return Response(team_data, status=status.HTTP_201_CREATED)

        except IntegrityError as e:
            # Handle unique constraint violations
            if 'unique_team_name' in str(e).lower() or 'team_name' in str(e).lower():
                return Response(
                    {"message": f"Team name '{team_name}' already exists. Please choose a different name."},
                    status=status.HTTP_400_BAD_REQUEST
                )
            else:
                return Response(
                    {"message": "Database integrity error. Please check your data."},
                    status=status.HTTP_400_BAD_REQUEST
                )
        except (KeyError, Sport.DoesNotExist) as e:
            return Response(
                {"message": f"Invalid request: {e}. team_name and sport_id are required."},
                status=status.HTTP_400_BAD_REQUEST
            )

    # ✅ GET: List all teams
    if request.method == "GET":
        # Optimize query pattern: select related captain and sport to prevent N+1
        teams = Team.objects.select_related("captain", "sport").all()
        data = [
            {
                "team_id": t.team_id,
                "team_name": t.team_name,
                "captain_name": getattr(t.captain, 'name', t.captain.email),
                "sport_name": t.sport.sport_name,
                "sport_id": t.sport.sport_id,
                "member_count": t.member_count,
                "created_at": t.created_at,
            }
            for t in teams
        ]
        return Response(data, status=status.HTTP_200_OK)


@api_view(["GET"])
def retrieve_team_details(request, id):
    """
    Handles GET request for /api/teams/{id}/
    Retrieves details for a specific team.
    """
    try:
        # select_related to reduce FK lookups
        team = Team.objects.select_related('captain', 'sport').get(team_id=id)
        members_data = []
        for membership in team.members.select_related('user').all():
            u = membership.user
            members_data.append({
                "user_id": getattr(u, 'id', None),
                "name": getattr(u, 'name', getattr(u, 'email', '')),
                "email": getattr(u, 'email', ''),
                "role": membership.role,
            })

        team_data = {
            "team_id": team.team_id,
            "team_name": team.team_name,
            "captain": {
                "user_id": getattr(team.captain, 'id', None),
                "name": getattr(team.captain, 'name', team.captain.email),
                "email": getattr(team.captain, 'email', '')
            },
            "sport": {"sport_id": team.sport.sport_id, "sport_name": team.sport.sport_name},
            # Use len of in-memory list to avoid extra COUNT query
            "member_count": len(members_data),
            "members": members_data,
            "created_at": team.created_at,
            "achievements": team.achievements,
        }
        return Response(team_data, status=status.HTTP_200_OK)
    except Team.DoesNotExist:
        return Response({"message": "Team not found."}, status=status.HTTP_404_NOT_FOUND)


# Placeholder endpoints to satisfy URL wiring; implement business logic later
@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def invite_player_to_team(request, id):
    return Response({"detail": "Invite player to team not implemented yet."}, status=status.HTTP_501_NOT_IMPLEMENTED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def request_to_join_team(request, id):
    return Response({"detail": "Request to join team not implemented yet."}, status=status.HTTP_501_NOT_IMPLEMENTED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def remove_member(request, id):
    return Response({"detail": "Remove member not implemented yet."}, status=status.HTTP_501_NOT_IMPLEMENTED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def bulk_update_team(request, team_id):
    """
    Replace all team members (except captain) with a new list and update achievements.
    
    Requires captain or admin authorization. Validates minimum player
    count before performing any deletions. Operation is atomic.
    
    Args:
        request: DRF request with authenticated user
        team_id: Integer ID of the team
        
    Request Body:
        member_emails: List of email addresses
        achievements: List of achievement objects (max 10)
        
    Returns:
        200: Success with updated team details
        400: Validation error (min players, invalid data)
        403: Unauthorized
        404: Team not found or some users not found
        
    Raises:
        IntegrityError: If database constraints violated (should not happen)
    """
    # Validate request data
    serializer = BulkUpdateTeamSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(
            {"message": f"Invalid request data: {serializer.errors}"},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    member_emails = serializer.validated_data['member_emails']
    achievements = serializer.validated_data['achievements']
    
    try:
        # Fetch team with related data
        team = Team.objects.select_related('captain', 'sport').get(team_id=team_id)
    except Team.DoesNotExist:
        return Response(
            {"message": "Team not found."},
            status=status.HTTP_404_NOT_FOUND
        )
    
    # Authorization check: must be captain or admin
    if not can_modify_team(request.user, team):
        return Response(
            {"message": "You do not have permission to perform this action. Only team captain or admin can update members."},
            status=status.HTTP_403_FORBIDDEN
        )
    
    # Remove captain's email from member list if present
    captain_email = team.captain.email.lower()
    member_emails = [email for email in member_emails if email != captain_email]
    
    # Pre-validation: Check if minimum player count will be met
    # Total members = 1 (captain) + new members
    total_members = 1 + len(member_emails)
    if total_members < team.sport.min_player:
        return Response(
            {"message": f"Cannot update members. Minimum {team.sport.min_player} players required for {team.sport.sport_name}. You provided {total_members} total members."},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Lookup users by email
    found_users = []
    failed_emails = []
    
    for email in member_emails:
        try:
            # Use optimized two-step lookup
            email_l = email.strip().lower()
            prefix = email_l[:7] if len(email_l) >= 7 else email_l
            try:
                member = User.objects.filter(sort_key__iexact=prefix).get(email__iexact=email_l)
            except User.DoesNotExist:
                member = User.objects.get(email__iexact=email_l)
            
            # Don't add captain as a regular member
            if member.id != team.captain_id:
                found_users.append(member)
        except User.DoesNotExist:
            failed_emails.append(email)
    
    # Atomic transaction: delete old members and add new ones
    with transaction.atomic():
        # Get existing members before deletion (for notification)
        existing_member_ids = set(
            team.members.exclude(user_id=team.captain_id).values_list('user_id', flat=True)
        )
        
        # Delete all members except captain
        members_removed = team.members.exclude(user_id=team.captain_id).delete()[0]
        
        # Add new members
        new_members = []
        for user in found_users:
            member_email = user.email
            new_members.append(TeamMember(
                team=team,
                user=user,
                member_name=user.name,
                email_id=member_email,
                sort_key=member_email[:7].lower() if len(member_email) >= 7 else member_email.lower(),
                role='player'
            ))
        
        # Bulk create new members
        TeamMember.objects.bulk_create(new_members, ignore_conflicts=True)
        
        # Update member count and achievements
        team.member_count = 1 + len(new_members)  # 1 for captain + new members
        team.achievements = achievements
        team.save(update_fields=['member_count', 'achievements'])
        
        members_added = len(new_members)
    
    # Send notification to all team members about roster changes
    try:
        new_member_ids = set(user.id for user in found_users)
        all_affected_ids = existing_member_ids.union(new_member_ids)
        
        # Create detailed message
        message = f"Team roster and achievements updated: {members_added} member(s) added, {members_removed} member(s) removed"
        send_team_notification(
            team=team,
            notification_type='ROSTER_UPDATED',
            message=message,
            exclude_user_ids=[]  # Notify all members including those who left
        )
    except Exception as e:
        logger.error(f"Failed to send notification for team {team_id}: {e}")
        # Don't fail the request if notification fails
    
    # Prepare response
    response_data = {
        "team_id": team.team_id,
        "team_name": team.team_name,
        "member_count": team.member_count,
        "members_added": members_added,
        "members_removed": members_removed,
        "achievements_updated": True,
        "message": "Team roster and achievements updated successfully"
    }
    
    if failed_emails:
        response_data["failed_emails"] = failed_emails
        response_data["warning"] = f"{len(failed_emails)} email(s) not found: {', '.join(failed_emails)}"
    
    return Response(response_data, status=status.HTTP_200_OK)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def leave_team(request, id):
    """
    Allow a member to leave the team.
    
    Members (but not captain) can leave the team if doing so doesn't violate
    the minimum player requirement for the sport.
    
    Args:
        request: DRF request with authenticated user
        id: Integer ID of the team
        
    Returns:
        200: Success message
        400: Validation error (would violate min players)
        403: Unauthorized (captain cannot leave, or user not a member)
        404: Team not found
    """
    user = request.user
    
    try:
        # Fetch team with related data
        team = Team.objects.select_related('captain', 'sport').get(team_id=id)
    except Team.DoesNotExist:
        return Response(
            {"message": "Team not found."},
            status=status.HTTP_404_NOT_FOUND
        )
    
    # Check if user is the captain
    if is_team_captain(user, team):
        return Response(
            {"message": "Captain cannot leave the team. Transfer captaincy first."},
            status=status.HTTP_403_FORBIDDEN
        )
    
    # Check if user is a member
    if not is_team_member(user, team):
        return Response(
            {"message": "You are not a member of this team."},
            status=status.HTTP_403_FORBIDDEN
        )
    
    # Validate minimum player count
    remaining_members = team.member_count - 1
    if remaining_members < team.sport.min_player:
        return Response(
            {"message": f"Cannot leave - team would fall below minimum player requirement of {team.sport.min_player} for {team.sport.sport_name}."},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Atomic delete and update
    with transaction.atomic():
        # Delete member record
        deleted_count = team.members.filter(user_id=user.id).delete()[0]
        
        if deleted_count == 0:
            # Should not happen due to earlier check, but be defensive
            return Response(
                {"message": "You are not a member of this team."},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Update member count
        team.member_count = remaining_members
        team.save(update_fields=['member_count'])
    
    # Send notification to remaining team members
    try:
        message = f"{user.name} has left the team"
        send_team_notification(
            team=team,
            notification_type='MEMBER_LEFT',
            message=message,
            exclude_user_ids=[user.id]  # Don't notify the user who left
        )
    except Exception as e:
        logger.error(f"Failed to send notification for team {id}: {e}")
    
    return Response(
        {
            "message": f"You have successfully left {team.team_name}",
            "team_name": team.team_name
        },
        status=status.HTTP_200_OK
    )


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def transfer_captain(request, team_id):
    """
    Transfer team captaincy to another member.
    
    Only current captain or admin can transfer captaincy. The new captain must
    be an existing member of the team. The old captain remains as a regular member.
    
    Args:
        request: DRF request with authenticated user
        team_id: Integer ID of the team
        
    Request Body:
        new_captain_user_id: User ID of the new captain
        
    Returns:
        200: Success with old and new captain details
        400: Validation error (invalid user_id, new captain not a member)
        403: Unauthorized (not captain or admin)
        404: Team or new captain not found
    """
    # Validate request data
    serializer = TransferCaptainSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(
            {"message": f"Invalid request data: {serializer.errors}"},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    new_captain_user_id = serializer.validated_data['new_captain_user_id']
    
    try:
        # Fetch team with related data
        team = Team.objects.select_related('captain', 'sport').get(team_id=team_id)
    except Team.DoesNotExist:
        return Response(
            {"message": "Team not found."},
            status=status.HTTP_404_NOT_FOUND
        )
    
    # Authorization check: must be captain or admin
    if not can_modify_team(request.user, team):
        return Response(
            {"message": "You do not have permission to perform this action. Only team captain or admin can transfer captaincy."},
            status=status.HTTP_403_FORBIDDEN
        )
    
    # Check if new captain is the same as current captain
    if new_captain_user_id == team.captain_id:
        return Response(
            {"message": "The specified user is already the captain of this team."},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Verify new captain exists
    try:
        new_captain = User.objects.get(id=new_captain_user_id)
    except User.DoesNotExist:
        return Response(
            {"message": "New captain user does not exist."},
            status=status.HTTP_404_NOT_FOUND
        )
    
    # Verify new captain is a member of the team
    try:
        new_captain_membership = team.members.select_related('user').get(user_id=new_captain_user_id)
    except TeamMember.DoesNotExist:
        return Response(
            {"message": "New captain is not a member of this team."},
            status=status.HTTP_404_NOT_FOUND
        )
    
    # Store old captain info for response
    old_captain = team.captain
    old_captain_id = old_captain.id
    old_captain_name = old_captain.name
    
    # Atomic transaction: update captain in Team and update roles in TeamMember
    with transaction.atomic():
        # Update old captain's role to player
        team.members.filter(user_id=old_captain_id).update(role='player')
        
        # Update new captain's role to captain
        new_captain_membership.role = 'captain'
        new_captain_membership.save(update_fields=['role'])
        
        # Update team's captain foreign key
        team.captain = new_captain
        team.save(update_fields=['captain'])
    
    # Send notification to all team members
    try:
        message = f"Team captaincy transferred from {old_captain_name} to {new_captain.name}"
        send_team_notification(
            team=team,
            notification_type='CAPTAIN_CHANGED',
            message=message,
            exclude_user_ids=[]  # Notify all members
        )
    except Exception as e:
        logger.error(f"Failed to send notification for team {team_id}: {e}")
    
    return Response(
        {
            "message": "Team captaincy transferred successfully",
            "team_id": team.team_id,
            "team_name": team.team_name,
            "old_captain": {
                "user_id": old_captain_id,
                "name": old_captain_name
            },
            "new_captain": {
                "user_id": new_captain.id,
                "name": new_captain.name
            }
        },
        status=status.HTTP_200_OK
    )


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def invite_team_for_match(request):
    """
    Send a match invitation from one team to another.
    
    POST /api/teams/invitations/match-invite/
    Body: {
        "sender_team_id": 1,                     // required
        "target_team_id": 2,                     // required
        "message": "Let's play this Saturday!",  // optional
        "preferred_date": "2025-12-01",          // optional (YYYY-MM-DD)
        "ground_id": 1                           // optional
    }
    
    Rules:
    - Only team captains can send match invitations
    - Must be captain of the sender_team
    - Cannot invite own team
    - Teams must play the same sport
    - All members of target team receive notification
    """
    # Validate request data
    serializer = MatchInviteSerializer(data=request.data)
    if not serializer.is_valid():
        return Response(
            {"message": "Invalid request data", "errors": serializer.errors},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    sender_team_id = serializer.validated_data['sender_team_id']
    target_team_id = serializer.validated_data['target_team_id']
    message = serializer.validated_data.get('message', '')
    preferred_date = serializer.validated_data.get('preferred_date')
    ground_id = serializer.validated_data.get('ground_id')
    
    # Get sender's team and verify they are captain
    try:
        sender_team = Team.objects.select_related('captain', 'sport').get(
            team_id=sender_team_id,
            captain=request.user
        )
    except Team.DoesNotExist:
        return Response(
            {"message": "You must be the captain of the sender team to send match invitations."},
            status=status.HTTP_403_FORBIDDEN
        )
    
    # Get target team
    try:
        target_team = Team.objects.select_related('captain', 'sport').prefetch_related('members__user').get(team_id=target_team_id)
    except Team.DoesNotExist:
        return Response(
            {"message": "Target team not found."},
            status=status.HTTP_404_NOT_FOUND
        )
    
    # Check same sport
    if sender_team.sport_id != target_team.sport_id:
        return Response(
            {"message": f"Teams must play the same sport. Your team plays {sender_team.sport.sport_name}, target team plays {target_team.sport.sport_name}."},
            status=status.HTTP_400_BAD_REQUEST
        )
    
    # Prepare match details
    match_details = {
        'sender_team_id': sender_team.team_id,
        'sender_team_name': sender_team.team_name,
        'sender_captain_email': request.user.email,
        'sender_captain_name': getattr(request.user, 'name', request.user.email),
        'target_team_id': target_team.team_id,
        'target_team_name': target_team.team_name,
    }
    
    if message:
        match_details['message'] = message
    if preferred_date:
        match_details['preferred_date'] = str(preferred_date)
    if ground_id:
        from bookings.models import Ground
        try:
            ground = Ground.objects.get(ground_id=ground_id)
            match_details['ground_id'] = ground_id
            match_details['ground_name'] = ground.ground_name
        except Ground.DoesNotExist:
            pass  # Already validated in serializer
    
    try:
        with transaction.atomic():
            # Create invitation record
            invitation = Invitation.objects.create(
                sender=request.user,
                recipient=target_team.captain,
                type='MATCH_INVITE',
                related_team=target_team,
                status='SENT',
                match_details=match_details
            )
            
            # Build notification message
            notification_title = f"Match Invitation from {sender_team.team_name}"
            notification_body = f"{sender_team.team_name} wants to play a match with your team ({target_team.team_name})."
            
            if message:
                notification_body += f"\n\nMessage: {message}"
            
            if preferred_date:
                notification_body += f"\n\nPreferred Date: {preferred_date}"
            
            if ground_id and 'ground_name' in match_details:
                notification_body += f"\nVenue: {match_details['ground_name']}"
            
            notification_body += f"\n\nContact {match_details['sender_captain_name']} at {request.user.email} to arrange the match."
            
            # Send notification to all target team members
            notification_data = {
                'type': 'MATCH_INVITE_RECEIVED',
                'invitation_id': str(invitation.invitation_id),
                'sender_team_id': str(sender_team.team_id),
                'sender_team_name': sender_team.team_name,
                'target_team_id': str(target_team.team_id),
                'target_team_name': target_team.team_name,
                'sender_captain_email': request.user.email,
                'sender_captain_name': match_details['sender_captain_name'],
            }
            
            if preferred_date:
                notification_data['preferred_date'] = str(preferred_date)
            if ground_id:
                notification_data['ground_id'] = str(ground_id)
                notification_data['ground_name'] = match_details.get('ground_name', '')
            
            # Use send_team_notification to notify all target team members
            notified_count = send_team_notification(
                team=target_team,
                notification_type='MATCH_INVITE_RECEIVED',
                message=notification_body,
                exclude_user_ids=[],
                title=notification_title,
                data=notification_data
            )
            
            logger.info(
                f"Match invitation created: {sender_team.team_name} (ID: {sender_team.team_id}) -> {target_team.team_name} (ID: {target_team.team_id}). "
                f"Notified {notified_count} members."
            )
            
            return Response(
                {
                    "message": "Match invitation sent successfully.",
                    "invitation_id": invitation.invitation_id,
                    "sender_team_id": sender_team.team_id,
                    "sender_team_name": sender_team.team_name,
                    "target_team_id": target_team.team_id,
                    "target_team_name": target_team.team_name,
                    "members_notified": notified_count
                },
                status=status.HTTP_201_CREATED
            )
    
    except Exception as e:
        logger.error(f"Error creating match invitation: {str(e)}")
        return Response(
            {"message": "Failed to send match invitation. Please try again."},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def respond_to_team_invitation(request, id):
    return Response({"detail": "Respond to team invitation not implemented yet."}, status=status.HTTP_501_NOT_IMPLEMENTED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def respond_to_join_request(request, id):
    return Response({"detail": "Respond to join request not implemented yet."}, status=status.HTTP_501_NOT_IMPLEMENTED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def respond_to_match_invitation(request, id):
    return Response({"detail": "Respond to match invitation not implemented yet."}, status=status.HTTP_501_NOT_IMPLEMENTED)


@api_view(["GET"]) 
@permission_classes([permissions.IsAuthenticated])
def list_captain_teams(request):
    """
    GET /api/teams/captain/?sport_id=<int>

    Returns a lean list of teams where the requesting user is the captain,
    filtered by sport_id.
    
    Query Parameters:
    - sport_id (required): Integer ID of the sport
    
    Response items include only:
    - team_id
    - team_name

    Returns empty array if no matching teams found.
    """
    sport_id = request.query_params.get("sport_id")
    if sport_id is None:
        return Response({"message": "sport_id is required as a query parameter"}, status=status.HTTP_400_BAD_REQUEST)
    
    try:
        sport_id_int = int(sport_id)
    except (TypeError, ValueError):
        return Response({"message": "sport_id must be an integer"}, status=status.HTTP_400_BAD_REQUEST)
    
    # Validate sport exists
    try:
        Sport.objects.get(sport_id=sport_id_int)
    except Sport.DoesNotExist:
        return Response({"message": "Invalid sport_id. Sport does not exist."}, status=status.HTTP_400_BAD_REQUEST)
    
    qs = (
        Team.objects
        .filter(captain=request.user, sport_id=sport_id_int)
        .only("team_id", "team_name")
        .order_by("team_name")
    )

    data = list(qs.values("team_id", "team_name"))
    return Response(data, status=status.HTTP_200_OK)


@api_view(["GET"]) 
def list_teams_by_sport(request):
    """
    GET /api/teams/by-sport/?sport_id=<int>

    Returns a lean list of teams for a given sport with only two fields per item:
    - team_id
    - team_name

    Performance considerations:
    - Filters by sport_id directly (uses FK index)
    - Fetches only required fields via values() to avoid model instantiation overhead
    - Orders by team_name for stable responses (optional but helpful for clients)
    """
    sport_id = request.query_params.get("sport_id")
    if sport_id is None:
        return Response({"message": "sport_id is required as a query parameter"}, status=status.HTTP_400_BAD_REQUEST)
    try:
        sport_id_int = int(sport_id)
    except (TypeError, ValueError):
        return Response({"message": "sport_id must be an integer"}, status=status.HTTP_400_BAD_REQUEST)

    # Filter by FK id; rely on queryset returning empty list if sport has no teams
    qs = (
        Team.objects
        .filter(sport_id=sport_id_int)
        .only("team_id", "team_name")
        .order_by("team_name")
    )

    # Use values to return lean dicts and avoid extra attribute access
    data = list(qs.values("team_id", "team_name"))
    return Response(data, status=status.HTTP_200_OK)


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def list_sent_invitations(request):
    """
    List all match invitations sent by the requesting user's captained teams.
    
    GET /api/teams/invitations/sent/
    
    Returns:
        List of invitations with full details including team names, recipient info,
        match details, and status
    """
    # Get teams where the requesting user is captain
    captained_teams = Team.objects.filter(captain=request.user)
    
    if not captained_teams.exists():
        return Response(
            {"message": "You are not a captain of any team.", "invitations": []},
            status=status.HTTP_200_OK
        )
    
    # Get all match invitations sent by the user
    invitations = (
        Invitation.objects
        .filter(
            sender=request.user,
            type='MATCH_INVITE'
        )
        .select_related('sender', 'recipient', 'related_team__sport')
        .order_by('-created_at')
    )
    
    serializer = InvitationDetailSerializer(invitations, many=True)
    
    return Response(
        {
            "message": "Sent invitations retrieved successfully.",
            "count": invitations.count(),
            "invitations": serializer.data
        },
        status=status.HTTP_200_OK
    )


@api_view(["GET"])
@permission_classes([permissions.IsAuthenticated])
def list_received_invitations(request):
    """
    List all pending match invitations received by teams where the requesting user is captain.
    
    GET /api/teams/invitations/received/
    
    Returns:
        List of pending invitations with full details including sender team info,
        match details, and captain contact information
    """
    # Get teams where the requesting user is captain
    captained_teams = Team.objects.filter(captain=request.user)
    
    if not captained_teams.exists():
        return Response(
            {"message": "You are not a captain of any team.", "invitations": []},
            status=status.HTTP_200_OK
        )
    
    # Get all match invitations received by the user (as team captain)
    invitations = (
        Invitation.objects
        .filter(
            recipient=request.user,
            type='MATCH_INVITE',
            status='SENT'  # Only show pending invitations
        )
        .select_related('sender', 'recipient', 'related_team__sport')
        .order_by('-created_at')
    )
    
    serializer = InvitationDetailSerializer(invitations, many=True)
    
    return Response(
        {
            "message": "Received invitations retrieved successfully.",
            "count": invitations.count(),
            "invitations": serializer.data
        },
        status=status.HTTP_200_OK
    )