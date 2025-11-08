from django.conf import settings
import django.db.models.deletion
import django.utils.timezone
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('bookings', '0005_remove_booking_metadata'),
    ]

    operations = [
        migrations.CreateModel(
            name='Team',
            fields=[
                ('team_id', models.AutoField(primary_key=True, serialize=False)),
                ('team_name', models.CharField(max_length=100)),
                ('member_count', models.IntegerField(default=0)),
                ('created_at', models.DateTimeField(default=django.utils.timezone.now)),
                ('captain', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='captained_teams', to=settings.AUTH_USER_MODEL)),
                ('sport', models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, to='bookings.sport')),
            ],
            options={
                'db_table': 'teams',
            },
        ),
        migrations.CreateModel(
            name='Invitation',
            fields=[
                ('invitation_id', models.AutoField(primary_key=True, serialize=False)),
                ('type', models.CharField(choices=[('PLAYER_INVITE', 'Player Invite'), ('MATCH_INVITE', 'Match Invite'), ('TEAM_INVITE', 'Team Invite'), ('TEAM_REQUEST', 'Team Request')], max_length=20)),
                ('status', models.CharField(choices=[('SENT', 'Sent'), ('ACCEPTED', 'Accepted'), ('DECLINED', 'Declined'), ('EXPIRED', 'Expired')], default='SENT', max_length=10)),
                ('expiry_time', models.DateTimeField(blank=True, null=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('recipient', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='received_invitations', to=settings.AUTH_USER_MODEL)),
                ('sender', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='sent_invitations', to=settings.AUTH_USER_MODEL)),
                ('related_team', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, to='teams.team')),
            ],
            options={
                'db_table': 'invitations',
            },
        ),
        migrations.CreateModel(
            name='TeamAchievement',
            fields=[
                ('achievement_id', models.AutoField(primary_key=True, serialize=False)),
                ('title', models.CharField(max_length=255)),
                ('description', models.TextField(blank=True, null=True)),
                ('date_achieved', models.DateField(auto_now_add=True)),
                ('players', models.ManyToManyField(blank=True, related_name='player_achievements', to=settings.AUTH_USER_MODEL)),
                ('team', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='achievements', to='teams.team')),
            ],
            options={
                'db_table': 'team_achievements',
            },
        ),
        migrations.CreateModel(
            name='TeamMember',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('member_name', models.CharField(max_length=100)),
                ('email_id', models.EmailField(max_length=100)),
                ('role', models.CharField(default='player', max_length=20)),
                ('date_joined', models.DateTimeField(default=django.utils.timezone.now)),
                ('team', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='members', to='teams.team')),
                ('user', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.CASCADE, related_name='team_memberships', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'db_table': 'team_members',
            },
        ),
    ]
