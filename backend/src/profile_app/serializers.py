from __future__ import annotations
from rest_framework import serializers
from users.models import User
from .models import Profile, Achievement
from teams.models import Team


class TeamBriefSerializer(serializers.ModelSerializer):
    """Lightweight serializer for team details on the profile page."""

    sport = serializers.SerializerMethodField()
    captain_name = serializers.SerializerMethodField()
    created_on = serializers.DateTimeField(source="created_at", read_only=True)

    class Meta:
        model = Team
        fields = ["team_name", "sport", "captain_name", "created_on"]

    def get_sport(self, obj: Team) -> str:
        try:
            return obj.sport.sport_name
        except Exception:
            return str(obj.sport)

    def get_captain_name(self, obj: Team) -> str:
        try:
            return obj.captain.name or obj.captain.email
        except Exception:
            return ""


class AchievementSerializer(serializers.ModelSerializer):
    """Serializer for user achievements."""
    class Meta:
        model = Achievement
        fields = ["id", "sport", "title", "year", "achievement", "experience"]


class ProfileSerializer(serializers.Serializer):
    """
    Combines user info, teams, and achievements for profile view.
    """
    name = serializers.CharField(source="user.name", read_only=True)
    email = serializers.EmailField(source="user.email", read_only=True)
    phone = serializers.CharField(source="user.phone", read_only=True)
    teams = TeamBriefSerializer(many=True, read_only=True)
    achievements = AchievementSerializer(many=True, read_only=True)

    def to_representation(self, instance: Profile):
        data = super().to_representation(instance)
        teams = self.context.get("teams_queryset", [])
        data["teams"] = TeamBriefSerializer(teams, many=True).data
        data["achievements"] = AchievementSerializer(
            instance.achievements.all(), many=True
        ).data
        return data


class ProfileUpdateSerializer(serializers.Serializer):
    """Allows updating user fields (name, phone) from the profile page."""

    name = serializers.CharField(required=False, allow_blank=True)
    phone = serializers.CharField(required=False, allow_blank=True)

    def validate_phone(self, value: str) -> str:
        return value.strip()

    def update(self, instance: Profile, validated_data):
        user: User = instance.user
        update_fields = []

        if "name" in validated_data:
            user.name = validated_data["name"].strip()
            update_fields.append("name")

        if "phone" in validated_data:
            user.phone = validated_data["phone"].strip()
            update_fields.append("phone")

        if update_fields:
            user.save(update_fields=update_fields)

        return instance

    def create(self, validated_data):
        raise NotImplementedError("Use update() on an existing profile.")
