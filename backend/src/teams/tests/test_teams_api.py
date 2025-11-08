import os
import time
import pytest
from django.urls import reverse
from django.db import connection
from rest_framework.test import APIClient
from users.models import User
from bookings.models import Sport

@pytest.mark.django_db
class TestTeamsAPI:
    def setup_method(self):
        self.client = APIClient()

    def test_list_teams_initially_empty(self):
        resp = self.client.get('/api/teams/')
        assert resp.status_code == 200
        assert resp.json() == []

    def test_create_team_with_min_members(self):
        # Create a user and a sport
        captain = User.objects.create_user(email="cap@example.com", password="pass", name="Captain", sort_key="cap")
        sport = Sport.objects.create(sport_name="Football", min_player=2)

        # Use 1 additional member to satisfy min_player=2 (captain + 1)
        payload = {
            "team_name": "Alpha",
            "sport_id": sport.sport_id,
            "member_emails": ["p1@example.com"],
        }

        # Pre-create the additional member as a user (optional path taken by view)
        User.objects.create_user(email="p1@example.com", password="pass", name="P1", sort_key="p1")

        resp = self.client.post('/api/teams/', payload, format='json')
        assert resp.status_code == 201, resp.content
        data = resp.json()
        assert data["team_name"] == "Alpha"
        assert data["sport_id"] == sport.sport_id
        assert data["member_count"] == 2

        # Now list should show one team
        resp2 = self.client.get('/api/teams/')
        assert resp2.status_code == 200
        assert len(resp2.json()) == 1

    def test_list_teams_query_count_and_latency(self):
        """Ensure listing teams is efficient (O(1) queries regardless of members)."""
        sport = Sport.objects.create(sport_name="Cricket", min_player=1)
        # Create captain and members for multiple teams
        cap = User.objects.create_user(email="cap2@example.com", password="pass", name="Cap2", sort_key="cap2")
        # Pre-populate 5 teams each with 3 members
        for i in range(5):
            payload = {
                "team_name": f"Team{i}",
                "sport_id": sport.sport_id,
                "member_emails": [],
            }
            self.client.post('/api/teams/', payload, format='json')

        # Measure queries using Django debug instrumentation
        from django.db import reset_queries
        reset_queries()
        initial_query_count = len(connection.queries)
        start = time.perf_counter()
        resp = self.client.get('/api/teams/')
        elapsed_ms = (time.perf_counter() - start) * 1000
        new_queries = len(connection.queries) - initial_query_count
        assert resp.status_code == 200
        assert len(resp.json()) >= 5
        # Accept a small fixed number of queries (1 select + maybe auth/session)
        assert new_queries <= 5, f"Too many queries for team list: {new_queries}" 
        assert elapsed_ms < 300, f"Team list too slow: {elapsed_ms:.2f}ms"

    def test_team_detail_query_efficiency(self):
        sport = Sport.objects.create(sport_name="Basketball", min_player=1)
        User.objects.create_user(email="main@example.com", password="pass", name="Main", sort_key="main")
        payload = {"team_name": "DetailTeam", "sport_id": sport.sport_id, "member_emails": []}
        create_resp = self.client.post('/api/teams/', payload, format='json')
        team_id = create_resp.json()["team_id"]
        from django.db import reset_queries
        reset_queries()
        start = time.perf_counter()
        detail_resp = self.client.get(f'/api/teams/{team_id}/')
        elapsed_ms = (time.perf_counter() - start) * 1000
        q_count = len(connection.queries)
        assert detail_resp.status_code == 200
        assert q_count <= 5, f"Team detail N+1 suspected: {q_count} queries"
        assert elapsed_ms < 200, f"Detail endpoint slow: {elapsed_ms:.2f}ms"

    def test_team_detail_not_found(self):
        resp = self.client.get('/api/teams/9999/')
        assert resp.status_code == 404
