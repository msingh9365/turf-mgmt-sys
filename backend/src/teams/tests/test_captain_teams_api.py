import pytest
from django.db import connection
from rest_framework.test import APIClient
from users.models import User
from bookings.models import Sport
from teams.models import Team, TeamMember


@pytest.mark.django_db
class TestCaptainTeamsAPI:
    """Test suite for GET /api/teams/captain/ endpoint."""
    
    def setup_method(self):
        """Setup test client and common fixtures."""
        self.client = APIClient()
        
        # Create sports
        self.football = Sport.objects.create(sport_name="Football", min_player=2)
        self.basketball = Sport.objects.create(sport_name="Basketball", min_player=2)
        self.cricket = Sport.objects.create(sport_name="Cricket", min_player=2)
        
        # Create users
        self.captain1 = User.objects.create_user(
            email="captain1@example.com", 
            password="pass123", 
            name="Captain One",
            sort_key="captain"
        )
        self.captain2 = User.objects.create_user(
            email="captain2@example.com", 
            password="pass123", 
            name="Captain Two",
            sort_key="captain"
        )
        self.player = User.objects.create_user(
            email="player@example.com", 
            password="pass123", 
            name="Regular Player",
            sort_key="player"
        )
    
    def test_requires_authentication(self):
        """Endpoint should return 401 for unauthenticated requests."""
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.football.sport_id}')
        assert resp.status_code == 401
    
    def test_requires_sport_id_parameter(self):
        """Endpoint should return 400 if sport_id is missing."""
        self.client.force_authenticate(user=self.captain1)
        resp = self.client.get('/api/teams/captain/')
        assert resp.status_code == 400
        assert 'sport_id is required' in resp.json()['message']
    
    def test_sport_id_must_be_integer(self):
        """Endpoint should return 400 if sport_id is not a valid integer."""
        self.client.force_authenticate(user=self.captain1)
        
        # Test with non-numeric string
        resp = self.client.get('/api/teams/captain/?sport_id=abc')
        assert resp.status_code == 400
        assert 'must be an integer' in resp.json()['message']
        
        # Test with float
        resp = self.client.get('/api/teams/captain/?sport_id=1.5')
        assert resp.status_code == 400
    
    def test_sport_id_must_exist(self):
        """Endpoint should return 400 if sport_id doesn't exist in database."""
        self.client.force_authenticate(user=self.captain1)
        resp = self.client.get('/api/teams/captain/?sport_id=99999')
        assert resp.status_code == 400
        assert 'Sport does not exist' in resp.json()['message']
    
    def test_returns_empty_list_when_no_captain_teams(self):
        """Should return empty list if user is not captain of any team for the sport."""
        self.client.force_authenticate(user=self.player)
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.football.sport_id}')
        assert resp.status_code == 200
        assert resp.json() == []
    
    def test_returns_empty_list_when_captain_of_different_sport(self):
        """Should return empty list if user is captain but for a different sport."""
        # Create a football team with captain1
        team = Team.objects.create(
            team_name="Football Kings",
            captain=self.captain1,
            sport=self.football,
            member_count=1
        )
        TeamMember.objects.create(
            team=team,
            user=self.captain1,
            member_name=self.captain1.name,
            email_id=self.captain1.email,
            sort_key="captain",
            role="captain"
        )
        
        # Query for basketball teams
        self.client.force_authenticate(user=self.captain1)
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.basketball.sport_id}')
        assert resp.status_code == 200
        assert resp.json() == []
    
    def test_returns_single_captain_team(self):
        """Should return single team when user is captain of one team for the sport."""
        team = Team.objects.create(
            team_name="Eagles",
            captain=self.captain1,
            sport=self.football,
            member_count=1
        )
        TeamMember.objects.create(
            team=team,
            user=self.captain1,
            member_name=self.captain1.name,
            email_id=self.captain1.email,
            sort_key="captain",
            role="captain"
        )
        
        self.client.force_authenticate(user=self.captain1)
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.football.sport_id}')
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]['team_id'] == team.team_id
        assert data[0]['team_name'] == "Eagles"
        # Ensure only expected fields are returned
        assert set(data[0].keys()) == {"team_id", "team_name"}
    
    def test_returns_multiple_captain_teams_sorted(self):
        """Should return multiple teams sorted alphabetically by team_name."""
        # Create multiple teams with same captain and sport
        team_zebra = Team.objects.create(
            team_name="Zebras",
            captain=self.captain1,
            sport=self.football,
            member_count=1
        )
        team_alpha = Team.objects.create(
            team_name="Alpha Team",
            captain=self.captain1,
            sport=self.football,
            member_count=1
        )
        team_beta = Team.objects.create(
            team_name="Beta Squad",
            captain=self.captain1,
            sport=self.football,
            member_count=1
        )
        
        # Create memberships
        for team in [team_zebra, team_alpha, team_beta]:
            TeamMember.objects.create(
                team=team,
                user=self.captain1,
                member_name=self.captain1.name,
                email_id=self.captain1.email,
                sort_key="captain",
                role="captain"
            )
        
        self.client.force_authenticate(user=self.captain1)
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.football.sport_id}')
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 3
        
        # Verify alphabetical order
        team_names = [t['team_name'] for t in data]
        assert team_names == ["Alpha Team", "Beta Squad", "Zebras"]
    
    def test_filters_by_captain_correctly(self):
        """Should only return teams where the authenticated user is captain."""
        # Captain1 creates a team
        team1 = Team.objects.create(
            team_name="Team One",
            captain=self.captain1,
            sport=self.football,
            member_count=1
        )
        TeamMember.objects.create(
            team=team1,
            user=self.captain1,
            member_name=self.captain1.name,
            email_id=self.captain1.email,
            sort_key="captain",
            role="captain"
        )
        
        # Captain2 creates another team (same sport)
        team2 = Team.objects.create(
            team_name="Team Two",
            captain=self.captain2,
            sport=self.football,
            member_count=1
        )
        TeamMember.objects.create(
            team=team2,
            user=self.captain2,
            member_name=self.captain2.name,
            email_id=self.captain2.email,
            sort_key="captain",
            role="captain"
        )
        
        # Captain1 should only see their team
        self.client.force_authenticate(user=self.captain1)
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.football.sport_id}')
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]['team_name'] == "Team One"
        
        # Captain2 should only see their team
        self.client.force_authenticate(user=self.captain2)
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.football.sport_id}')
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]['team_name'] == "Team Two"
    
    def test_filters_by_sport_correctly(self):
        """Should return teams only for the specified sport."""
        # Create teams for different sports
        football_team = Team.objects.create(
            team_name="Football Team",
            captain=self.captain1,
            sport=self.football,
            member_count=1
        )
        basketball_team = Team.objects.create(
            team_name="Basketball Team",
            captain=self.captain1,
            sport=self.basketball,
            member_count=1
        )
        
        for team in [football_team, basketball_team]:
            TeamMember.objects.create(
                team=team,
                user=self.captain1,
                member_name=self.captain1.name,
                email_id=self.captain1.email,
                sort_key="captain",
                role="captain"
            )
        
        self.client.force_authenticate(user=self.captain1)
        
        # Query for football
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.football.sport_id}')
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]['team_name'] == "Football Team"
        
        # Query for basketball
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.basketball.sport_id}')
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]['team_name'] == "Basketball Team"
    
    def test_query_efficiency(self):
        """Endpoint should use minimal database queries."""
        # Create multiple teams
        for i in range(5):
            team = Team.objects.create(
                team_name=f"Team {i}",
                captain=self.captain1,
                sport=self.football,
                member_count=3
            )
            # Add captain membership
            TeamMember.objects.create(
                team=team,
                user=self.captain1,
                member_name=self.captain1.name,
                email_id=self.captain1.email,
                sort_key="captain",
                role="captain"
            )
            # Add some regular members
            for j in range(2):
                member = User.objects.create_user(
                    email=f"member{i}_{j}@example.com",
                    password="pass",
                    name=f"Member {i}_{j}",
                    sort_key=f"member{i}"
                )
                TeamMember.objects.create(
                    team=team,
                    user=member,
                    member_name=member.name,
                    email_id=member.email,
                    sort_key=f"member{i}",
                    role="player"
                )
        
        self.client.force_authenticate(user=self.captain1)
        
        # Measure query count
        from django.db import reset_queries
        reset_queries()
        
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.football.sport_id}')
        query_count = len(connection.queries)
        
        assert resp.status_code == 200
        assert len(resp.json()) == 5
        
        # Should use minimal queries (sport validation + team select + auth overhead)
        # Allow up to 5 queries for auth/session/sport check/team select
        assert query_count <= 5, f"Too many queries: {query_count}. Queries: {connection.queries}"
    
    def test_does_not_return_member_teams(self):
        """Should not return teams where user is only a member, not captain."""
        # Create a team with captain2
        team = Team.objects.create(
            team_name="Captain2 Team",
            captain=self.captain2,
            sport=self.football,
            member_count=2
        )
        TeamMember.objects.create(
            team=team,
            user=self.captain2,
            member_name=self.captain2.name,
            email_id=self.captain2.email,
            sort_key="captain",
            role="captain"
        )
        # Add captain1 as a regular member
        TeamMember.objects.create(
            team=team,
            user=self.captain1,
            member_name=self.captain1.name,
            email_id=self.captain1.email,
            sort_key="captain",
            role="player"
        )
        
        # Captain1 queries - should get empty list (they're only a member, not captain)
        self.client.force_authenticate(user=self.captain1)
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.football.sport_id}')
        assert resp.status_code == 200
        assert resp.json() == []
        
        # Captain2 queries - should see their team
        self.client.force_authenticate(user=self.captain2)
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.football.sport_id}')
        assert resp.status_code == 200
        data = resp.json()
        assert len(data) == 1
        assert data[0]['team_name'] == "Captain2 Team"
    
    def test_response_format_consistency(self):
        """Response should always be a list, never wrapped in an object."""
        self.client.force_authenticate(user=self.captain1)
        
        # Test empty response
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.football.sport_id}')
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)
        
        # Create a team and test non-empty response
        team = Team.objects.create(
            team_name="Test Team",
            captain=self.captain1,
            sport=self.football,
            member_count=1
        )
        TeamMember.objects.create(
            team=team,
            user=self.captain1,
            member_name=self.captain1.name,
            email_id=self.captain1.email,
            sort_key="captain",
            role="captain"
        )
        
        resp = self.client.get(f'/api/teams/captain/?sport_id={self.football.sport_id}')
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)
        assert len(resp.json()) == 1
