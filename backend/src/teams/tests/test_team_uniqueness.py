import pytest
from rest_framework.test import APIClient
from users.models import User
from bookings.models import Sport
from teams.models import Team, TeamMember


@pytest.mark.django_db
class TestTeamUniqueness:
    """Tests for team name uniqueness and duplicate member prevention."""

    def setup_method(self):
        self.client = APIClient()
        self.sport = Sport.objects.create(sport_name="Soccer", min_player=1)
        self.captain = User.objects.create_user(
            email="captain@example.com", password="pass", name="Captain", sort_key="CAP001"
        )
        self.member1 = User.objects.create_user(
            email="member1@example.com", password="pass", name="Member1", sort_key="MEM001"
        )
        self.member2 = User.objects.create_user(
            email="member2@example.com", password="pass", name="Member2", sort_key="MEM002"
        )

    def test_duplicate_team_name_rejected(self):
        """Creating a team with an existing name should fail with 400."""
        payload = {
            "team_name": "Rockets",
            "sport_id": self.sport.sport_id,
            "member_emails": [],
        }
        
        # First creation succeeds
        resp1 = self.client.post('/api/teams/', payload, format='json')
        assert resp1.status_code == 201
        assert resp1.json()["team_name"] == "Rockets"
        
        # Second with same name fails
        resp2 = self.client.post('/api/teams/', payload, format='json')
        assert resp2.status_code == 400
        assert "already exists" in resp2.json()["message"].lower()
        assert "Rockets" in resp2.json()["message"]

    def test_duplicate_member_emails_deduplicated(self):
        """Duplicate emails in member_emails should be deduplicated."""
        payload = {
            "team_name": "DupeTest",
            "sport_id": self.sport.sport_id,
            "member_emails": [
                "member1@example.com",
                "member1@example.com",  # duplicate
                "Member1@Example.com",  # case variant
                "member2@example.com",
            ],
        }
        
        resp = self.client.post('/api/teams/', payload, format='json')
        assert resp.status_code == 201
        
        team_id = resp.json()["team_id"]
        team = Team.objects.get(team_id=team_id)
        
        # Should have captain + 2 unique members (not 4)
        assert team.member_count == 3
        
        # Verify only 3 TeamMember records exist
        members = TeamMember.objects.filter(team=team)
        assert members.count() == 3
        
        # Verify member1 appears only once
        member1_count = members.filter(user=self.member1).count()
        assert member1_count == 1

    def test_captain_in_member_emails_ignored(self):
        """If captain's email is in member_emails, it should not create duplicate."""
        payload = {
            "team_name": "CaptainDupe",
            "sport_id": self.sport.sport_id,
            "member_emails": [
                "captain@example.com",  # Captain's own email
                "member1@example.com",
            ],
        }
        
        resp = self.client.post('/api/teams/', payload, format='json')
        assert resp.status_code == 201
        
        team_id = resp.json()["team_id"]
        team = Team.objects.get(team_id=team_id)
        
        # Should have captain + 1 member (not 2)
        assert team.member_count == 2
        
        # Captain should appear only once
        captain_memberships = TeamMember.objects.filter(team=team, user=self.captain)
        assert captain_memberships.count() == 1
        assert captain_memberships.first().role == "captain"

    def test_empty_and_whitespace_emails_filtered(self):
        """Empty strings and whitespace-only emails should be filtered."""
        payload = {
            "team_name": "WhitespaceTest",
            "sport_id": self.sport.sport_id,
            "member_emails": [
                "",
                "  ",
                "member1@example.com",
                "   ",
                "member2@example.com",
            ],
        }
        
        resp = self.client.post('/api/teams/', payload, format='json')
        assert resp.status_code == 201
        
        team_id = resp.json()["team_id"]
        team = Team.objects.get(team_id=team_id)
        
        # Should have captain + 2 valid members
        assert team.member_count == 3

    def test_nonexistent_users_skipped(self):
        """Non-existent user emails should be silently skipped."""
        payload = {
            "team_name": "PartialMembers",
            "sport_id": self.sport.sport_id,
            "member_emails": [
                "member1@example.com",  # exists
                "ghost@example.com",    # does not exist
                "phantom@example.com",  # does not exist
                "member2@example.com",  # exists
            ],
        }
        
        resp = self.client.post('/api/teams/', payload, format='json')
        assert resp.status_code == 201
        
        team_id = resp.json()["team_id"]
        team = Team.objects.get(team_id=team_id)
        
        # Should have captain + 2 existing members (ghosts skipped)
        assert team.member_count == 3
        
        members = TeamMember.objects.filter(team=team).exclude(role="captain")
        assert members.count() == 2

    def test_case_insensitive_email_dedup(self):
        """Email deduplication should be case-insensitive."""
        payload = {
            "team_name": "CaseTest",
            "sport_id": self.sport.sport_id,
            "member_emails": [
                "Member1@Example.com",
                "MEMBER1@EXAMPLE.COM",
                "member1@example.com",
            ],
        }
        
        resp = self.client.post('/api/teams/', payload, format='json')
        assert resp.status_code == 201
        
        team_id = resp.json()["team_id"]
        # Should only add member1 once + captain
        assert Team.objects.get(team_id=team_id).member_count == 2

    def test_database_constraint_prevents_duplicate_member(self):
        """Database constraint should prevent adding the same user twice (direct ORM test)."""
        team = Team.objects.create(
            team_name="DirectTest",
            captain=self.captain,
            sport=self.sport,
            member_count=1
        )
        
        TeamMember.objects.create(
            team=team,
            user=self.member1,
            member_name="First",
            email_id=self.member1.email,
            role="player"
        )
        
        # Attempting to add same user again should raise IntegrityError
        from django.db import IntegrityError
        with pytest.raises(IntegrityError):
            TeamMember.objects.create(
                team=team,
                user=self.member1,
                member_name="Duplicate",
                email_id=self.member1.email,
                role="player"
            )
