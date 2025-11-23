from django.conf import settings
from django.contrib.auth import get_user_model
from django.db import IntegrityError, transaction
from django.db.models import Q
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response
from rest_framework import status, permissions
from teams.models import Team, Invitation, TeamMember
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
            
            # Deduplicate member emails (case-insensitive) and filter empty strings
            member_emails = list(set(email.strip().lower() for email in member_emails if email and email.strip()))
            
            # captain = request.user

            # ✅ Temporary captain for testing
            # TODO: Replace fallback with request.user once auth is wired for this endpoint
            captain = request.user if request.user and request.user.is_authenticated else User.objects.first()
            if not captain:
                return Response({"message": "No users found. Please add users first."}, status=status.HTTP_400_BAD_REQUEST)

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
            
            # Add warning if some members weren't added
            if failed_emails:
                team_data["warning"] = f"Team created but {len(failed_emails)} member(s) not found: {', '.join(failed_emails)}"

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