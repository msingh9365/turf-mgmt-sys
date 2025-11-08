from django.db import models
from django.utils import timezone

class User(models.Model):
    user_id = models.AutoField(primary_key=True)
    name = models.CharField(max_length=100)
    email_id = models.EmailField(max_length=100, unique=True)
    password_hash = models.CharField(max_length=255) 
    # entry_no = models.CharField(max_length=20, unique=True)
    sort_key = models.CharField(max_length=20, blank=True, null=True)
    is_admin = models.BooleanField(default=False)
    phone = models.CharField(max_length=15)
    fcm_token = models.CharField(max_length=255, blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)
    sports_interest = models.CharField(max_length=255, blank=True, null=True)

    def __str__(self):
        return self.name

    class Meta:
        db_table = 'users'

class Sport(models.Model):
    sport_id = models.AutoField(primary_key=True)
    sport_name = models.CharField(max_length=100, unique=True)
    min_player = models.IntegerField(default=1)

    def __str__(self):
        return self.sport_name

    class Meta:
        db_table = 'sport'

class Team(models.Model):
    team_id = models.AutoField(primary_key=True)
    team_name = models.CharField(max_length=100)
    captain = models.ForeignKey(User, on_delete=models.CASCADE, related_name='captained_teams')
    member_count = models.IntegerField(default=0)
    sport = models.ForeignKey(Sport, on_delete=models.PROTECT)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = 'teams'

    def __str__(self):
        return f"{self.team_name} ({self.sport.sport_name})"


class TeamMember(models.Model):
    team = models.ForeignKey(Team, on_delete=models.CASCADE, related_name='members')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='team_memberships', null=True, blank=True)
    member_name = models.CharField(max_length=100)
    email_id = models.EmailField(max_length=100)
    role = models.CharField(max_length=20, default='player')  # 'captain' or 'player'
    date_joined = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = 'team_members'

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
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='sent_invitations', null=True, blank=True)
    recipient = models.ForeignKey(User, on_delete=models.CASCADE, related_name='received_invitations')
    type = models.CharField(max_length=20, choices=INVITATION_TYPES)
    related_team = models.ForeignKey(Team, on_delete=models.CASCADE, null=True, blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='SENT')
    expiry_time = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Invitation ({self.get_type_display()}) to {self.recipient.name}"

    class Meta:
        db_table = 'invitations'

class TeamAchievement(models.Model):
    achievement_id = models.AutoField(primary_key=True)
    team = models.ForeignKey(Team, on_delete=models.CASCADE, related_name='achievements')
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True, null=True)
    date_achieved = models.DateField(auto_now_add=True)
    players = models.ManyToManyField(User, related_name='player_achievements', blank=True)

    def __str__(self):
        return f"{self.team.team_name} - {self.title}"

    class Meta:
        db_table = 'team_achievements'
