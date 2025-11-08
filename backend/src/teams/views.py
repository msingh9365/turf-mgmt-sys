from django.conf import settings
from django.contrib.auth import get_user_model
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status, permissions
from teams.models import Team, Invitation, TeamMember, TeamAchievement
from bookings.models import Sport

User = get_user_model()


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
            # TODO: Replace fallback with request.user once auth is wired for this endpoint
            captain = request.user if request.user and request.user.is_authenticated else User.objects.first()
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
                member_name=getattr(captain, 'name', captain.email),
                email_id=getattr(captain, 'email', ''),
                role="captain"
            )


            # ✅ Add other members
            for email in member_emails:
                try:
                    member = User.objects.get(email=email)
                    TeamMember.objects.create(
                        team=team,
                        user=member,
                        member_name=getattr(member, 'name', member.email),
                        email_id=getattr(member, 'email', ''),
                        role="player"
                    )
                except User.DoesNotExist:
                    print(f"⚠️ User with email {email} not found — skipped.")

            team_data = {
                "team_id": team.team_id,
                "team_name": team.team_name,
                "captain_name": getattr(team.captain, 'name', team.captain.email),
                "sport_name": team.sport.sport_name,
                "sport_id": team.sport.sport_id,
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
                "role": membership.role,
            })

        team_data = {
            "team_id": team.team_id,
            "team_name": team.team_name,
            "captain": {"user_id": getattr(team.captain, 'id', None), "name": getattr(team.captain, 'name', team.captain.email)},
            "sport": {"sport_id": team.sport.sport_id, "sport_name": team.sport.sport_name},
            # Use len of in-memory list to avoid extra COUNT query
            "member_count": len(members_data),
            "members": members_data,
            "achievements": [] # Placeholder for achievements
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
def leave_team(request, id):
    return Response({"detail": "Leave team not implemented yet."}, status=status.HTTP_501_NOT_IMPLEMENTED)


@api_view(["POST"])
@permission_classes([permissions.IsAuthenticated])
def invite_team_for_match(request):
    return Response({"detail": "Invite team for match not implemented yet."}, status=status.HTTP_501_NOT_IMPLEMENTED)


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