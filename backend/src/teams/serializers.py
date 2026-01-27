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


class BulkUpdateTeamSerializer(serializers.Serializer):
    """Serializer for bulk updating team members and achievements."""
    member_emails = serializers.ListField(
        child=serializers.EmailField(),
        required=True,
        allow_empty=False,
        help_text="List of member email addresses to replace existing members (except captain)"
    )
    achievements = serializers.JSONField(
        required=True,
        help_text="Team achievements (max 10). Each achievement should have: title, description, date"
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
    
    def validate_achievements(self, value):
        """Validate achievements field - max 10 achievements allowed"""
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


class MatchInviteSerializer(serializers.Serializer):
    """Serializer for creating match invitations."""
    sender_team_id = serializers.IntegerField(
        required=True,
        help_text="ID of your team sending the invitation (you must be captain)"
    )
    target_team_id = serializers.IntegerField(
        required=True,
        help_text="ID of the team to invite"
    )
    message = serializers.CharField(
        required=False,
        allow_blank=True,
        max_length=500,
        help_text="Optional message to include with the invitation"
    )
    preferred_date = serializers.DateField(
        required=False,
        allow_null=True,
        help_text="Optional preferred match date (YYYY-MM-DD format)"
    )
    ground_id = serializers.IntegerField(
        required=False,
        allow_null=True,
        help_text="Optional preferred ground/venue ID"
    )

    def validate_sender_team_id(self, value):
        """Validate sender team exists."""
        if value <= 0:
            raise serializers.ValidationError("Invalid sender team ID")
        try:
            Team.objects.get(team_id=value)
        except Team.DoesNotExist:
            raise serializers.ValidationError("Sender team does not exist")
        return value

    def validate_target_team_id(self, value):
        """Validate target team exists."""
        if value <= 0:
            raise serializers.ValidationError("Invalid team ID")
        try:
            Team.objects.get(team_id=value)
        except Team.DoesNotExist:
            raise serializers.ValidationError("Target team does not exist")
        return value

    def validate_ground_id(self, value):
        """Validate ground exists if provided."""
        if value is not None and value > 0:
            from bookings.models import Ground
            try:
                Ground.objects.get(ground_id=value)
            except Ground.DoesNotExist:
                raise serializers.ValidationError("Ground does not exist")
        return value

    def validate(self, attrs):
        """Cross-field validation."""
        sender_team_id = attrs.get('sender_team_id')
        target_team_id = attrs.get('target_team_id')
        
        # Prevent self-invitation
        if sender_team_id == target_team_id:
            raise serializers.ValidationError({
                "target_team_id": "Cannot invite your own team"
            })
        
        # Additional validation will be done in the view for:
        # - sender is captain of sender_team
        # - same sport check
        return attrs


class InvitationDetailSerializer(serializers.ModelSerializer):
    """Serializer for displaying invitation details."""
    sender_name = serializers.CharField(source='sender.name', read_only=True)
    sender_email = serializers.CharField(source='sender.email', read_only=True)
    recipient_name = serializers.CharField(source='recipient.name', read_only=True)
    recipient_email = serializers.CharField(source='recipient.email', read_only=True)
    team_name = serializers.CharField(source='related_team.team_name', read_only=True)
    sport_name = serializers.CharField(source='related_team.sport.sport_name', read_only=True)
    type_display = serializers.CharField(source='get_type_display', read_only=True)
    status_display = serializers.CharField(source='get_status_display', read_only=True)

    class Meta:
        model = Invitation
        fields = [
            'invitation_id',
            'sender_name',
            'sender_email',
            'recipient_name',
            'recipient_email',
            'type',
            'type_display',
            'team_name',
            'sport_name',
            'status',
            'status_display',
            'match_details',
            'created_at',
            'expiry_time',
        ]
        read_only_fields = fields
