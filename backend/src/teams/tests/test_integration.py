"""
End-to-end integration test demonstrating team creation workflow
with all validation and uniqueness features.
"""
import pytest
from rest_framework.test import APIClient
from users.models import User
from bookings.models import Sport
from teams.models import Team, TeamMember


@pytest.mark.django_db
class TestTeamCreationIntegration:
    """Complete integration test for team creation with realistic scenario."""

    def test_complete_team_creation_workflow(self):
        """Test the complete workflow of creating multiple teams with edge cases."""
        client = APIClient()
        
        # Setup: Create sport and users
        tennis = Sport.objects.create(sport_name="Tennis", min_player=2)
        soccer = Sport.objects.create(sport_name="Soccer", min_player=5)
        
        captain1 = User.objects.create_user(
            email="alice@example.com", password="pass", name="Alice", sort_key="A001"
        )
        captain2 = User.objects.create_user(
            email="bob@example.com", password="pass", name="Bob", sort_key="B001"
        )
        player1 = User.objects.create_user(
            email="charlie@example.com", password="pass", name="Charlie", sort_key="C001"
        )
        player2 = User.objects.create_user(
            email="diana@example.com", password="pass", name="Diana", sort_key="D001"
        )
        
        # ===== Scenario 1: Create valid tennis team =====
        tennis_payload = {
            "team_name": "Ace Smashers",
            "sport_id": tennis.sport_id,
            "member_emails": ["charlie@example.com"]  # captain + 1 = meets min 2
        }
        resp1 = client.post('/api/teams/', tennis_payload, format='json')
        assert resp1.status_code == 201
        assert resp1.json()["team_name"] == "Ace Smashers"
        assert resp1.json()["member_count"] == 2
        team1_id = resp1.json()["team_id"]
        
        # Verify team in database
        team1 = Team.objects.get(team_id=team1_id)
        assert team1.members.count() == 2
        assert team1.members.filter(role="captain", user=captain1).exists()
        assert team1.members.filter(role="player", user=player1).exists()
        
        # ===== Scenario 2: Try duplicate team name (should fail) =====
        duplicate_payload = {
            "team_name": "Ace Smashers",  # Same name!
            "sport_id": tennis.sport_id,  # Use tennis (min 2) not soccer
            "member_emails": ["diana@example.com"]  # Enough members
        }
        resp2 = client.post('/api/teams/', duplicate_payload, format='json')
        assert resp2.status_code == 400
        assert "already exists" in resp2.json()["message"].lower()
        
        # ===== Scenario 3: Create team with duplicate member emails =====
        # Create more users for soccer (needs 5 minimum)
        player3 = User.objects.create_user(
            email="eve@example.com", password="pass", name="Eve", sort_key="E001"
        )
        player4 = User.objects.create_user(
            email="frank@example.com", password="pass", name="Frank", sort_key="F001"
        )
        player5 = User.objects.create_user(
            email="grace@example.com", password="pass", name="Grace", sort_key="G001"
        )
        
        dedup_payload = {
            "team_name": "Goal Crushers",
            "sport_id": soccer.sport_id,
            "member_emails": [
                "charlie@example.com",
                "CHARLIE@EXAMPLE.COM",  # Case variant
                "diana@example.com",
                "charlie@example.com",  # Explicit duplicate
                "eve@example.com",
                "frank@example.com",
                "ghost@example.com",    # Non-existent
                "",                      # Empty
                "  ",                    # Whitespace
            ]
        }
        resp3 = client.post('/api/teams/', dedup_payload, format='json')
        assert resp3.status_code == 201
        team2_id = resp3.json()["team_id"]
        
        # Should have captain + 4 unique valid members (charlie, diana, eve, frank)
        team2 = Team.objects.get(team_id=team2_id)
        assert team2.member_count == 5
        assert team2.members.count() == 5
        assert team2.members.filter(user=player1).count() == 1  # Charlie added once
        assert team2.members.filter(user=player2).count() == 1  # Diana added once
        
        # ===== Scenario 4: List all teams =====
        list_resp = client.get('/api/teams/')
        assert list_resp.status_code == 200
        teams = list_resp.json()
        assert len(teams) == 2
        team_names = {t["team_name"] for t in teams}
        assert team_names == {"Ace Smashers", "Goal Crushers"}
        
        # ===== Scenario 5: Get team detail =====
        detail_resp = client.get(f'/api/teams/{team1_id}/')
        assert detail_resp.status_code == 200
        detail = detail_resp.json()
        assert detail["team_name"] == "Ace Smashers"
        assert detail["sport"]["sport_name"] == "Tennis"
        assert len(detail["members"]) == 2
        
        # Verify captain role
        captain_member = next(m for m in detail["members"] if m["role"] == "captain")
        assert captain_member["name"] == "Alice"
        
        # ===== Scenario 6: Captain accidentally in member list (auto-removed) =====
        # Note: The current captain will be the first user in DB (alice from earlier team)
        # So bob will just be a regular member here
        self_include_payload = {
            "team_name": "Self Include Test",
            "sport_id": tennis.sport_id,
            "member_emails": [
                "alice@example.com",    # Current captain's email (will be removed)
                "diana@example.com"
            ]
        }
        resp4 = client.post('/api/teams/', self_include_payload, format='json')
        assert resp4.status_code == 201
        team3 = Team.objects.get(team_id=resp4.json()["team_id"])
        
        # Should have captain (alice) + 1 (diana), not 2
        # Alice should appear only once as captain, not as a member too
        assert team3.member_count == 2
        assert team3.members.filter(user=captain1).count() == 1  # Alice appears once
        assert team3.members.filter(user=captain1, role="captain").exists()

    def test_performance_with_many_duplicates(self):
        """Ensure deduplication doesn't cause performance issues."""
        client = APIClient()
        sport = Sport.objects.create(sport_name="Basketball", min_player=1)
        
        # Create 10 users
        users = [
            User.objects.create_user(
                email=f"player{i}@example.com",
                password="pass",
                name=f"Player{i}",
                sort_key=f"P{i:03d}"
            )
            for i in range(10)
        ]
        
        # Create payload with many duplicates (100 emails -> 10 unique)
        # Note: don't include player0 since that will be the captain (auto-excluded)
        member_emails = []
        for user in users[1:]:  # Skip first user who will be captain
            # Add each email 10 times with different case variations
            for j in range(10):
                if j % 3 == 0:
                    member_emails.append(user.email.upper())
                elif j % 3 == 1:
                    member_emails.append(user.email.lower())
                else:
                    member_emails.append(user.email.title())
        
        import time
        start = time.perf_counter()
        
        payload = {
            "team_name": "Dedup Test",
            "sport_id": sport.sport_id,
            "member_emails": member_emails  # 100 emails
        }
        
        resp = client.post('/api/teams/', payload, format='json')
        elapsed_ms = (time.perf_counter() - start) * 1000
        
        assert resp.status_code == 201
        team = Team.objects.get(team_id=resp.json()["team_id"])
        
        # Should deduplicate to captain + 9 members (users[1:])
        assert team.member_count == 10
        assert team.members.count() == 10
        
        # Should complete in reasonable time despite 100 input emails
        assert elapsed_ms < 1000, f"Team creation too slow: {elapsed_ms:.2f}ms"
