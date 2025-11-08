from rest_framework import serializers
from teams.models import Team, TeamMember, Invitation, TeamAchievement

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
            "members",
        ]
        read_only_fields = ["team_id", "member_count", "created_at"]

    def get_captain_name(self, obj):
        return getattr(obj.captain, 'name', getattr(obj.captain, 'email', ''))

class TeamCreateSerializer(serializers.ModelSerializer):
    member_emails = serializers.ListField(child=serializers.EmailField(), write_only=True, required=False)

    class Meta:
        model = Team
        fields = ["team_name", "sport_id", "member_emails"]

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
