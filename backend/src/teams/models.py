from django.db import models
from django.utils import timezone
from django.conf import settings
from bookings.models import Sport, Ground

class Team(models.Model):
    team_id = models.AutoField(primary_key=True)
    team_name = models.CharField(max_length=100)
    captain = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='captained_teams'
    )
    member_count = models.IntegerField(default=0)
    sport = models.ForeignKey(Sport, on_delete=models.PROTECT)
    created_at = models.DateTimeField(default=timezone.now)
    achievements = models.JSONField(
        default=list, 
        blank=True,
        help_text="Team achievements (max 2). Each achievement should have: title, description, date"
    )

    class Meta:
        db_table = 'teams'
        constraints = [
            models.UniqueConstraint(fields=['team_name'], name='unique_team_name')
        ]

    def __str__(self):
        return f"{self.team_name} ({self.sport.sport_name})"


class TeamMember(models.Model):
    team = models.ForeignKey(Team, on_delete=models.CASCADE, related_name='members')
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='team_memberships',
        null=True,
        blank=True,
    )
    member_name = models.CharField(max_length=100)
    email_id = models.EmailField(max_length=100)
    sort_key = models.CharField(max_length=20, db_index=True, default='', help_text="First 7 chars of email for optimized lookup")
    role = models.CharField(max_length=20, default='player')  # 'captain' or 'player'
    date_joined = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = 'team_members'
        constraints = [
            # Ensure the same user cannot be added to a team multiple times
            models.UniqueConstraint(fields=['team', 'user'], name='unique_team_member')
        ]

    def __str__(self):
        return f"{self.member_name} ({self.role}) - {self.team.team_name}"


class Invitation(models.Model):
    INVITATION_TYPES = [
        ('PLAYER_INVITE', 'Player Invite'),
        ('MATCH_INVITE', 'Match Invite'),
        ('TEAM_INVITE', 'Team Invite'),
        ('TEAM_REQUEST', 'Team Request'),
    ]
    STATUS_CHOICES = [
        ('SENT', 'Sent'),
        ('ACCEPTED', 'Accepted'),
        ('DECLINED', 'Declined'),
        ('EXPIRED', 'Expired'),
    ]

    invitation_id = models.AutoField(primary_key=True)
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sent_invitations',
        null=True,
        blank=True,
    )
    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='received_invitations'
    )
    type = models.CharField(max_length=20, choices=INVITATION_TYPES)
    related_team = models.ForeignKey(Team, on_delete=models.CASCADE, null=True, blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='SENT')
    expiry_time = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    match_details = models.JSONField(
        null=True, 
        blank=True,
        help_text="For MATCH_INVITE type: stores sender_team_id, sender_captain_email, message, preferred_date, ground_id"
    )

    def __str__(self):
        return f"Invitation ({self.get_type_display()}) to {getattr(self.recipient, 'name', str(self.recipient))}"

    class Meta:
        db_table = 'invitations'

    class Meta:
        db_table = 'team_achievements'
