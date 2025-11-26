# Create your views here.
from __future__ import annotations

from django.shortcuts import render

from django.db.models import QuerySet
from rest_framework import permissions, status, viewsets
from rest_framework.response import Response
from rest_framework.views import APIView

from users.models import User
from teams.models import Team, TeamMember
from .models import Profile, Achievement
from .serializers import (
    ProfileSerializer,
    ProfileEditSerializer,
    ProfileUpdateSerializer,
    CombinedProfileUpdateSerializer,
    AchievementSerializer,
)

def get_user_teams(user: User) -> QuerySet[Team]:
    """
    Return teams the user belongs to (member or captain), robust across schemas.

    - If a TeamMember model exists with FK to User and Team, we use it.
    - Otherwise, we return teams where the user is captain.
    """
    # Try TeamMember path
    try:
        from teams.models import TeamMember  # type: ignore
        member_team_ids = TeamMember.objects.filter(user=user).values_list("team_id", flat=True)
        return Team.objects.filter(pk__in=member_team_ids).union(Team.objects.filter(captain=user))
    except Exception:
        # Fallback: only captaincy
        return Team.objects.filter(captain=user)


class ProfileView(APIView):
    """
    GET  -> Fetch the logged-in user's full profile (user info, teams, achievements)
    PUT  -> Update profile details AND achievements in ONE request
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        # Check if this is edit mode (for optimized response)
        edit_mode = request.query_params.get('edit', 'false').lower() == 'true'
        
        # Ensure a profile exists for this user
        profile, _ = Profile.objects.get_or_create(user=request.user)

        # Fetch all teams user belongs to (as member or captain)
        teams_qs = get_user_teams(request.user).order_by("-created_at")

        # Use appropriate serializer based on mode
        if edit_mode:
            serializer = ProfileEditSerializer(
                profile, 
                context={
                    "teams_queryset": teams_qs,
                    "request": request
                }
            )
            message = "Profile fetched for editing."
        else:
            serializer = ProfileSerializer(
                profile, 
                context={
                    "teams_queryset": teams_qs,
                    "request": request
                }
            )
            message = "Profile fetched successfully."
            
        return Response(
            {
                "message": message,
                "profile": serializer.data,
            },
            status=status.HTTP_200_OK,
        )

    def put(self, request):
        # Ensure a profile exists
        profile, _ = Profile.objects.get_or_create(user=request.user)

        # Validate and update profile + achievements together
        serializer = CombinedProfileUpdateSerializer(
            instance=profile, data=request.data
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()

        # Return updated profile view (with achievements included)
        teams_qs = get_user_teams(request.user).order_by("-created_at")
        read = ProfileSerializer(
            profile, 
            context={
                "teams_queryset": teams_qs,
                "request": request
            }
        )

        return Response(
            {
                "message": "Profile and achievements updated successfully.",
                "profile": read.data,
            },
            status=status.HTTP_200_OK,
        )


class AchievementViewSet(viewsets.ModelViewSet):
    """
    CRUD for the logged-in user's achievements.
    """
    serializer_class = AchievementSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        profile, _ = Profile.objects.get_or_create(user=self.request.user)
        return Achievement.objects.filter(profile=profile).order_by("-year", "sport", "title")

    def perform_create(self, serializer):
        profile, _ = Profile.objects.get_or_create(user=self.request.user)
        serializer.save(profile=profile)
