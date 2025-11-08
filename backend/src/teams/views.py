from django.conf import settings
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from teams.models import Team, Invitation, TeamMember, TeamAchievement
from backend.core_app.models import User, Sport
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
                "captain_name": team.captain.name,
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
        teams = Team.objects.all()
        data = [
            {
                "team_id": t.team_id,
                "team_name": t.team_name,
                "captain_name": t.captain.name,
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