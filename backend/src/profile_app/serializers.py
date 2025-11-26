from __future__ import annotations
from rest_framework import serializers
from users.models import User
from .models import Profile, Achievement
from teams.models import Team
from bookings.models import Sport


class SportSerializer(serializers.ModelSerializer):
    """Serializer for the Sport model."""
    class Meta:
        model = Sport
        fields = ["sport_id", "sport_name"]


class TeamBriefSerializer(serializers.ModelSerializer):
    """Lightweight serializer for team details on the profile page."""

    team_id = serializers.IntegerField(source="team_id", read_only=True)
    team_name = serializers.CharField(read_only=True)
    sport_name = serializers.SerializerMethodField()
    captain_name = serializers.SerializerMethodField()
    is_captain = serializers.SerializerMethodField()
    created_on = serializers.DateTimeField(source="created_at", read_only=True)

    class Meta:
        model = Team
        fields = ["team_id", "team_name", "sport_name", "captain_name", "is_captain", "created_on"]

    def get_sport_name(self, obj: Team) -> str:
        """Get sport name from the Sport model"""
        try:
            return obj.sport.sport_name
        except Exception:
            return str(obj.sport)
    
    def get_is_captain(self, obj: Team) -> int:
        """
        Return 1 if current user is captain, 0 if just a member.
        Gets current user from context.
        """
        request = self.context.get('request')
        if request and hasattr(request, 'user'):
            current_user = request.user
            return 1 if obj.captain_id == current_user.id else 0
        return 0

    def get_captain_name(self, obj: Team) -> str:
        """
        Return captain's name.
        If current user is captain, returns 'You', otherwise captain's name.
        """
        try:
            request = self.context.get('request')
            if request and hasattr(request, 'user'):
                current_user = request.user
                if obj.captain_id == current_user.id:
                    return "You"
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
    achievements = AchievementSerializer(source="achievements.all", many=True, read_only=True)
    interested_sports = SportSerializer(source="interested_sports.all", many=True, read_only=True)
    
    avatar_id = serializers.CharField(read_only=True)

    def to_representation(self, instance: Profile):
        # The 'teams' field needs context from the view, so we handle it here.
        data = super().to_representation(instance)
        teams_queryset = self.context.get("teams_queryset", [])
        # Pass request context to TeamBriefSerializer for is_captain check
        request = self.context.get("request")
        data["teams"] = TeamBriefSerializer(
            teams_queryset, 
            many=True, 
            context={"request": request}
        ).data
        return data


class ProfileEditSerializer(serializers.Serializer):
    """Optimized serializer for edit mode - returns sport IDs for easier frontend handling."""
    
    name = serializers.CharField(source="user.name", read_only=True)
    email = serializers.EmailField(source="user.email", read_only=True)
    phone = serializers.CharField(source="user.phone", read_only=True)
    interested_sports = serializers.ListField(child=serializers.IntegerField(), read_only=True)
    avatar_id = serializers.CharField(read_only=True)
    teams = TeamBriefSerializer(many=True, read_only=True)
    achievements = AchievementSerializer(many=True, read_only=True)

    def to_representation(self, instance: Profile):
        data = super().to_representation(instance)
        teams = self.context.get("teams_queryset", [])
        # Pass request context to TeamBriefSerializer for is_captain check
        request = self.context.get("request")
        data["teams"] = TeamBriefSerializer(
            teams, 
            many=True, 
            context={"request": request}
        ).data
        data["achievements"] = AchievementSerializer(
            instance.achievements.all(), many=True
        ).data
        # Return sport IDs only for edit mode (easier for frontend to handle)
        sport_ids = []
        try:
            sport_ids = list(instance.interested_sports.values_list('pk', flat=True))
        except Exception:
            sport_ids = []
        data["interested_sports"] = sport_ids
        data["avatar_id"] = instance.avatar_id
        return data


class CombinedProfileUpdateSerializer(serializers.Serializer):
    """Combined serializer for updating profile and achievements together in ONE API call."""
    
    # Profile fields
    name = serializers.CharField(required=True, allow_blank=False, help_text="Name is required")
    phone = serializers.CharField(required=True, allow_blank=False, help_text="Phone is required")
    interested_sports = serializers.ListField(
        child=serializers.IntegerField(), required=True, allow_empty=False,
        help_text="List of Sport IDs - at least one sport is required"
    )
    avatar_id = serializers.CharField(required=True, allow_blank=False, help_text="Avatar selection is required")
    
    # Achievements field (list of achievement objects)
    achievements = serializers.ListField(
        child=serializers.DictField(), 
        required=False, 
        allow_empty=True,
        help_text="List of achievements - each achievement should have sport, title, year, achievement, experience"
    )
    
    def validate_interested_sports(self, value):
        """Ensure at least one sport is selected"""
        if not value or len(value) == 0:
            raise serializers.ValidationError("At least one interested sport is required.")
        return value

    def validate_phone(self, value: str) -> str:
        return value.strip()
    
    def validate_achievements(self, value):
        """Validate each achievement in the list."""
        validated_achievements = []
        for achievement_data in value:
            # Remove 'id' if present (we'll replace all achievements)
            achievement_data.pop('id', None)
            # Use AchievementSerializer to validate each achievement
            serializer = AchievementSerializer(data=achievement_data)
            serializer.is_valid(raise_exception=True)
            validated_achievements.append(serializer.validated_data)
        return validated_achievements

    def update(self, instance: Profile, validated_data):
        user: User = instance.user
        update_fields = []

        # Update user fields
        if "name" in validated_data:
            user.name = validated_data["name"].strip()
            update_fields.append("name")

        if "phone" in validated_data:
            user.phone = validated_data["phone"].strip()
            update_fields.append("phone")

        if update_fields:
            user.save(update_fields=update_fields)

        # Update profile fields
        profile_updated = False
        if "interested_sports" in validated_data:
            sport_ids = validated_data.get("interested_sports") or []
            try:
                qs = Sport.objects.filter(pk__in=sport_ids)
                instance.interested_sports.set(qs)
                profile_updated = True
            except Exception:
                pass

        if "avatar_id" in validated_data:
            instance.avatar_id = validated_data.get("avatar_id")
            profile_updated = True

        if profile_updated:
            instance.save()

        # Handle achievements - replace all existing ones
        if "achievements" in validated_data:
            # Delete existing achievements
            instance.achievements.all().delete()
            
            # Create new achievements
            achievements_data = validated_data.get("achievements", [])
            for achievement_data in achievements_data:
                Achievement.objects.create(profile=instance, **achievement_data)

        return instance

    def create(self, validated_data):
        raise NotImplementedError("Use update() on an existing profile.")


class ProfileUpdateSerializer(serializers.Serializer):
    """Allows updating user fields (name, phone, interested_sports, avatar_id) from the profile page."""

    name = serializers.CharField(required=True, allow_blank=False, help_text="Name is required")
    phone = serializers.CharField(required=True, allow_blank=False, help_text="Phone is required")
    interested_sports = serializers.ListField(
        child=serializers.IntegerField(), required=True, allow_empty=False,
        help_text="List of Sport IDs - at least one sport is required"
    )
    avatar_id = serializers.CharField(required=True, allow_blank=False, help_text="Avatar selection is required")
    
    def validate_interested_sports(self, value):
        """Ensure at least one sport is selected"""
        if not value or len(value) == 0:
            raise serializers.ValidationError("At least one interested sport is required.")
        return value

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

        # Update profile-specific fields
        profile_updated = False
        if "interested_sports" in validated_data:
            sport_ids = validated_data.get("interested_sports") or []
            # Use Sport PK (sport_id) to set M2M
            try:
                qs = Sport.objects.filter(pk__in=sport_ids)
                instance.interested_sports.set(qs)
                profile_updated = True
            except Exception:
                # ignore invalid sport ids
                pass

        if "avatar_id" in validated_data:
            instance.avatar_id = validated_data.get("avatar_id")
            profile_updated = True

        if profile_updated:
            instance.save()

        return instance

    def create(self, validated_data):
        raise NotImplementedError("Use update() on an existing profile.")
