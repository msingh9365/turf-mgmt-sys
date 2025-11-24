from rest_framework import serializers
from teams.models import Team, TeamMember, Invitation

class TeamMemberSerializer(serializers.ModelSerializer):
    user_id = serializers.IntegerField(source='user.id', read_only=True)
    name = serializers.CharField(source='member_name')

    class Meta:
        model = TeamMember
        fields = ["user_id", "name", "role", "email_id", "date_joined"]
        read_only_fields = ["user_id", "date_joined"]

class TeamSerializer(serializers.ModelSerializer):
    captain_name = serializers.SerializerMethodField()
    sport_name = serializers.CharField(source='sport.sport_name', read_only=True)
    members = TeamMemberSerializer(source='members', many=True, read_only=True)

    class Meta:
        model = Team
        fields = [
            "team_id",
            "team_name",
            "captain_name",
            "sport_name",
            "sport_id",
            "member_count",
            "created_at",
            "achievements",
            "members",
        ]
        read_only_fields = ["team_id", "member_count", "created_at"]

    def get_captain_name(self, obj):
        return getattr(obj.captain, 'name', getattr(obj.captain, 'email', ''))

class TeamCreateSerializer(serializers.ModelSerializer):
    member_emails = serializers.ListField(child=serializers.EmailField(), write_only=True, required=False)

    achievements = serializers.JSONField(required=False, default=list)

    class Meta:
        model = Team
        fields = ["team_name", "sport_id", "member_emails", "achievements"]

    def validate_achievements(self, value):
        """Validate achievements field - max 2 achievements allowed"""
        if not isinstance(value, list):
            raise serializers.ValidationError("Achievements must be a list")
        if len(value) > 10:
            raise serializers.ValidationError("Maximum 10 achievements allowed")
        # Validate each achievement has required fields
        for achievement in value:
            if not isinstance(achievement, dict):
                raise serializers.ValidationError("Each achievement must be an object")
            if 'title' not in achievement:
                raise serializers.ValidationError("Each achievement must have a 'title' field")
        return value

    def validate(self, attrs):
        sport_id = attrs.get('sport_id')
        from bookings.models import Sport
        try:
            sport = Sport.objects.get(sport_id=sport_id)
        except Sport.DoesNotExist:
            raise serializers.ValidationError({"sport_id": "Invalid sport_id"})
        member_emails = attrs.get('member_emails', [])
        if len(member_emails) + 1 < sport.min_player:
            raise serializers.ValidationError({"member_emails": f"Minimum {sport.min_player} players required for {sport.sport_name}."})
        return attrs


class BulkUpdateMembersSerializer(serializers.Serializer):
    """Serializer for bulk updating team members."""
    member_emails = serializers.ListField(
        child=serializers.EmailField(),
        required=True,
        allow_empty=False,
        help_text="List of member email addresses to replace existing members (except captain)"
    )

    def validate_member_emails(self, value):
        """Validate member emails list."""
        if not value:
            raise serializers.ValidationError("At least one member email is required")
        
        # Deduplicate (case-insensitive)
        unique_emails = list(set(email.strip().lower() for email in value if email and email.strip()))
        
        if not unique_emails:
            raise serializers.ValidationError("No valid email addresses provided")
        
        return unique_emails


class TransferCaptainSerializer(serializers.Serializer):
    """Serializer for transferring team captaincy."""
    new_captain_user_id = serializers.IntegerField(
        required=True,
        help_text="User ID of the new captain (must be an existing team member)"
    )

    def validate_new_captain_user_id(self, value):
        """Validate new captain user ID."""
        if value <= 0:
            raise serializers.ValidationError("Invalid user ID")
        return value
