from django.conf import settings
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import User, Team, Invitation, Sport, TeamMember, TeamAchievement
from .notification_utils import (
    send_team_invite_notification,
    send_join_request_notification,
    send_match_invite_notification,
    send_invitation_response_notification,
    send_join_request_response_notification,
    send_match_invitation_response_notification,
)
import datetime


@api_view(["GET", "POST"])
def list_or_create_team(request):
    """
    Handles GET and POST requests for /api/teams/
    GET: Lists all teams.
    POST: Creates a new team (only if member count >= sport.min_player)
    """
    if request.method == "POST":
        try:
            team_name = request.data["team_name"]
            sport_id = request.data["sport_id"]
            member_emails = request.data.get("member_emails", [])
            # captain = request.user

            # ✅ Temporary captain for testing
            captain = User.objects.first()
            if not captain:
                return Response({"message": "No users found. Please add users first."}, status=status.HTTP_400_BAD_REQUEST)

            sport = Sport.objects.get(sport_id=sport_id)

            # ✅ Minimum player validation
            if len(member_emails) + 1 < sport.min_player:  # +1 for captain
                return Response(
                    {"message": f"Minimum {sport.min_player} players required for {sport.sport_name}."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            # ✅ Create team
            team = Team.objects.create(
                team_name=team_name,
                captain=captain,
                sport=sport,
                member_count=len(member_emails) + 1
            )

            # ✅ Add captain as team member
            TeamMember.objects.create(
                team=team,
                user=captain,
                member_name=captain.name,
                email_id=captain.email_id,
                role="player"
)


            # ✅ Add other members
            for email in member_emails:
                try:
                    member = User.objects.get(email_id=email)
                    TeamMember.objects.create(
                        team=team,
                        user=member,
                        member_name=member.name,
                        email_id=member.email_id,
                        role="player"
                    )
                except User.DoesNotExist:
                    print(f"⚠️ User with email {email} not found — skipped.")

            team_data = {
                "team_id": team.team_id,
                "team_name": team.team_name,
                "captain_name": team.captain_name,
                "sport_name": team.sport_name,
                "sport_id": team.sport_id,
                "member_count": team.member_count,
                "created_at": team.created_at,
            }

            return Response(team_data, status=status.HTTP_201_CREATED)

        except (KeyError, Sport.DoesNotExist) as e:
            return Response(
                {"message": f"Invalid request: {e}. team_name and sport_id are required."},
                status=status.HTTP_400_BAD_REQUEST
            )

    # ✅ GET: List all teams
    if request.method == "GET":
        teams = Team.objects.all()
        data = [
            {
                "team_id": t.team_id,
                "team_name": t.team_name,
                "captain_name": t.captain_name,
                "sport_name": t.sport_name,
                "sport_id": t.sport_id,
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
        team = Team.objects.get(team_id=id)
        members_data = [{
            "user_id": member.user_id,
            "name": member.name,
            "role": TeamMember.objects.get(team=team, user=member).role
        } for member in team.members.all()]

        team_data = {
            "team_id": team.team_id,
            "team_name": team.team_name,
            "captain": {"user_id": team.captain.user_id, "name": team.captain.name},
            "sport": {"sport_id": team.sport.sport_id, "sport_name": team.sport.sport_name},
            "member_count": team.members.count(),
            "members": members_data,
            "achievements": [] # Placeholder for achievements
        }
        return Response(team_data, status=status.HTTP_200_OK)
    except Team.DoesNotExist:
        return Response({"message": "Team not found."}, status=status.HTTP_404_NOT_FOUND)


# This view is for the captain to invite a player to their team.
@api_view(["POST"])
def invite_player_to_team(request, id):
    """
    Handles POST request for /api/teams/{id}/invite-member/
    Captain invites a player to the team.
    Expects: {"recipient_id": <user_id>} in request body.
    """
    team_id = id
    try:
        recipient_id = request.data["recipient_id"]
        sender = request.user # Assuming authentication is in place
        
        team = Team.objects.get(team_id=team_id)
        
        if team.captain != sender:
            return Response({"message": "Only the team captain can invite members."}, status=status.HTTP_403_FORBIDDEN)

        recipient = User.objects.get(user_id=recipient_id)

        # Check if user is already a member
        if TeamMember.objects.filter(team=team, user=recipient).exists():
            return Response({"message": "User is already in the team."}, status=status.HTTP_400_BAD_REQUEST)

    except (KeyError, Team.DoesNotExist, User.DoesNotExist):
        return Response({"message": "Invalid request, team not found, or user not found."}, status=status.HTTP_404_NOT_FOUND)

    expiry_time = datetime.datetime.utcnow() + datetime.timedelta(days=1)
    invitation = Invitation.objects.create(
        sender=sender,
        recipient=recipient,
        type="TEAM_INVITE", # This is a captain inviting a player
        related_team=team,
        expiry_time=expiry_time
    )

    send_team_invite_notification(recipient, sender, team, invitation)

    return Response({"message": "Invitation sent successfully."}, status=status.HTTP_200_OK)


# This view is for a player to request to join a team.
@api_view(["POST"])
def request_to_join_team(request, id):
    """
    Handles POST request for /api/teams/{id}/request-to-join/
    Player requests to join a team.
    """
    team_id = id
    sender = request.user

    try:
        team = Team.objects.get(team_id=team_id)
    except Team.DoesNotExist:
        return Response({"message": "Team not found."}, status=status.HTTP_404_NOT_FOUND)

    # Check if user is already a member
    if TeamMember.objects.filter(team=team, user=sender).exists():
        return Response({"message": "You are already in this team."}, status=status.HTTP_400_BAD_REQUEST)

    recipient = team.captain # Notification goes to the captain
    expiry_time = datetime.datetime.utcnow() + datetime.timedelta(days=1)
    invitation = Invitation.objects.create(
        sender=sender,
        recipient=recipient,
        type="TEAM_REQUEST",
        related_team=team,
        expiry_time=expiry_time
    )

    send_join_request_notification(recipient, sender, team, invitation)

    return Response({"message": "Request to join sent successfully."}, status=status.HTTP_200_OK)


# This view is for a captain to invite another team to a match.
@api_view(["POST"])
def invite_team_for_match(request):
    """
    Handles POST request for /api/invitations/match-invite/
    A team captain invites another team for a match.
    Expects: {"sender_team_id": <team_id>, "recipient_captain_id": <user_id>}
    """
    sender = request.user
    try:
        sender_team_id = request.data["sender_team_id"]
        recipient_captain_id = request.data["recipient_captain_id"]

        sender_team = Team.objects.get(team_id=sender_team_id)
        recipient_captain = User.objects.get(user_id=recipient_captain_id)
        # Assuming the recipient captain has only one team for simplicity
        recipient_team = Team.objects.filter(captain=recipient_captain).first()
    except (KeyError, Team.DoesNotExist, User.DoesNotExist):
        return Response({"message": "Invalid request, team or user not found."}, status=status.HTTP_404_NOT_FOUND)

    if sender_team.captain != sender:
        return Response({"message": "Only the team captain can send a match invite."}, status=status.HTTP_403_FORBIDDEN)

    if not recipient_team:
        return Response({"message": "Recipient is not a captain of any team."}, status=status.HTTP_400_BAD_REQUEST)

    if sender_team.sport != recipient_team.sport:
        return Response({"message": "Both teams must play the same sport."}, status=status.HTTP_400_BAD_REQUEST)

    expiry_time = datetime.datetime.utcnow() + datetime.timedelta(days=1)
    invitation = Invitation.objects.create(
        sender=sender,
        recipient=recipient_captain,
        type="MATCH_INVITE",
        related_team=sender_team, # The invitation is related to the sender\"s team
        expiry_time=expiry_time
    )

    send_match_invite_notification(recipient_captain, sender_team, invitation)

    return Response({"message": "Match invitation sent successfully."}, status=status.HTTP_200_OK)


@api_view(["POST"])
def respond_to_team_invitation(request, id):
    """
    Handles a player\"s response to a TEAM_INVITE.
    URL: /api/invitations/team-invite/<id>/respond/
    """
    try:
        response = request.data["response"].upper()
        user = request.user # This is the player responding

        invitation = Invitation.objects.get(
            invitation_id=id, 
            recipient=user, 
            type="TEAM_INVITE"
        )
    except (KeyError, Invitation.DoesNotExist):
        return Response({"message": "Invalid request or invitation not found."}, status=status.HTTP_404_NOT_FOUND)

    if invitation.status != "SENT":
        return Response({"message": "This invitation has already been responded to."}, status=status.HTTP_400_BAD_REQUEST)

    if response not in ["ACCEPTED", "DECLINED"]:
        return Response({"message": "Invalid response. Must be ACCEPTED or DECLINED."}, status=status.HTTP_400_BAD_REQUEST)

    invitation.status = response
    invitation.save()

    team = invitation.related_team
    captain = invitation.sender # The captain who sent the invite

    if response == "ACCEPTED":
        TeamMember.objects.create(user=user, team=team, role="player")
        notification_body = f"{user.name} has accepted your invitation to join {team.team_name}."
    else: # Declined
        notification_body = f"{user.name} has declined your invitation to join {team.team_name}."

    send_invitation_response_notification(captain, team.team_name, response, invitation)

    return Response({"message": f"Invitation {response.lower()}."}, status=status.HTTP_200_OK)


@api_view(["POST"])
def respond_to_join_request(request, id):
    """
    Handles a captain\"s response to a TEAM_REQUEST.
    URL: /api/invitations/team-request/<id>/respond/
    """
    try:
        response = request.data["response"].upper()
        captain = request.user # This is the captain responding

        invitation = Invitation.objects.get(
            invitation_id=id, 
            recipient=captain, 
            type="TEAM_REQUEST"
        )
    except (KeyError, Invitation.DoesNotExist):
        return Response({"message": "Invalid request or invitation not found."}, status=status.HTTP_404_NOT_FOUND)

    if invitation.status != "SENT":
        return Response({"message": "This invitation has already been responded to."}, status=status.HTTP_400_BAD_REQUEST)

    if response not in ["ACCEPTED", "DECLINED"]:
        return Response({"message": "Invalid response. Must be ACCEPTED or DECLINED."}, status=status.HTTP_400_BAD_REQUEST)

    invitation.status = response
    invitation.save()

    team = invitation.related_team
    player = invitation.sender # The player who sent the request

    if response == "ACCEPTED":
        TeamMember.objects.create(user=player, team=team, role="player")
        notification_body = f"Your request to join {team.team_name} has been accepted."
    else: # Declined
        notification_body = f"Your request to join {team.team_name} has been declined."

    send_join_request_response_notification(player, team.team_name, response, invitation)

    return Response({"message": f"Invitation {response.lower()}."}, status=status.HTTP_200_OK)


@api_view(["POST"])
def respond_to_match_invitation(request, id):
    """
    Handles a captain\"s response to a MATCH_INVITE.
    URL: /api/invitations/match-invite/<id>/respond/
    """
    try:
        response = request.data["response"].upper()
        captain = request.user # This is the captain responding

        invitation = Invitation.objects.get(
            invitation_id=id, 
            recipient=captain, 
            type="MATCH_INVITE"
        )
    except (KeyError, Invitation.DoesNotExist):
        return Response({"message": "Invalid request or invitation not found."}, status=status.HTTP_404_NOT_FOUND)

    if invitation.status != "SENT":
        return Response({"message": "This invitation has already been responded to."}, status=status.HTTP_400_BAD_REQUEST)

    if response not in ["ACCEPTED", "DECLINED"]:
        return Response({"message": "Invalid response. Must be ACCEPTED or DECLINED."}, status=status.HTTP_400_BAD_REQUEST)

    invitation.status = response
    invitation.save()

    # TODO: What happens when a match invite is accepted?
    # This would likely involve creating a booking or a match record,
    # which is currently out of scope for the notification branch.
    # For now, we just update the status and notify the other captain.

    other_captain = invitation.sender
    sender_team = invitation.related_team

    send_match_invitation_response_notification(other_captain, sender_team, response, invitation)

    return Response({"message": f"Match invitation {response.lower()}."}, status=status.HTTP_200_OK)

@api_view(["POST"])
def remove_member(request, id):
    """
    Handles POST request for /api/teams/{id}/remove-member/
    Captain removes a player from the team.
    Expects: {"user_id": <user_id>} in request body.
    """
    team_id = id
    try:
        user_id_to_remove = request.data["user_id"]
        captain = request.user

        team = Team.objects.get(team_id=team_id)

        if team.captain != captain:
            return Response({"message": "Only the team captain can remove members."}, status=status.HTTP_403_FORBIDDEN)

        user_to_remove = User.objects.get(user_id=user_id_to_remove)

        # Check if the user to remove is actually a member of the team
        team_member_to_remove = TeamMember.objects.get(team=team, user=user_to_remove)

        if team_member_to_remove.role == "captain":
            return Response({"message": "The captain cannot be removed directly. Transfer captaincy first."}, status=status.HTTP_400_BAD_REQUEST)

        team_member_to_remove.delete()
        # Optionally, send a notification to the removed user
        return Response({"message": "Member removed successfully."}, status=status.HTTP_200_OK)

    except (KeyError, Team.DoesNotExist, User.DoesNotExist, TeamMember.DoesNotExist):
        return Response({"message": "Invalid request, team not found, user not found, or user is not a member of this team."}, status=status.HTTP_404_NOT_FOUND)

@api_view(["POST"])
def leave_team(request, id):
    """
    Handles POST request for /api/teams/{id}/leave/
    A member leaves the team.
    """
    team_id = id
    user = request.user

    try:
        team = Team.objects.get(team_id=team_id)

        team_member = TeamMember.objects.get(team=team, user=user)

        if team_member.role == "captain":
            return Response({"message": "The captain cannot leave the team directly. Transfer captaincy first."}, status=status.HTTP_400_BAD_REQUEST)

        team_member.delete()
        # Optionally, send a notification to the captain
        return Response({"message": "You have left the team."}, status=status.HTTP_200_OK)

    except (Team.DoesNotExist, TeamMember.DoesNotExist):
        return Response({"message": "Team not found or you are not a member of this team."}, status=status.HTTP_404_NOT_FOUND)
