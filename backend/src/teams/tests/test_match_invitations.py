"""
Tests for team match invitation feature.
"""
import pytest
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status
from teams.models import Team, Invitation
from bookings.models import Sport, Ground

User = get_user_model()


@pytest.fixture
def api_client():
    return APIClient()


@pytest.fixture
def sport(db):
    """Create a test sport."""
    return Sport.objects.create(
        sport_name="Tennis",
        min_player=2
    )


@pytest.fixture
def ground(db, sport):
    """Create a test ground."""
    return Ground.objects.create(
        ground_name="Court 1",
        sport=sport
    )


@pytest.fixture
def captain1(db):
    """Create first captain user."""
    return User.objects.create_user(
        email="captain1@example.com",
        name="Captain One",
        password="testpass123"
    )


@pytest.fixture
def captain2(db):
    """Create second captain user."""
    return User.objects.create_user(
        email="captain2@example.com",
        name="Captain Two",
        password="testpass123"
    )


@pytest.fixture
def member1(db):
    """Create a regular team member."""
    return User.objects.create_user(
        email="member1@example.com",
        name="Member One",
        password="testpass123"
    )


@pytest.fixture
def member2(db):
    """Create another regular team member."""
    return User.objects.create_user(
        email="member2@example.com",
        name="Member Two",
        password="testpass123"
    )


@pytest.fixture
def team1(db, captain1, sport, member1):
    """Create first test team with captain1."""
    team = Team.objects.create(
        team_name="Thunder Strikers",
        captain=captain1,
        sport=sport,
        member_count=2
    )
    # Add captain and member
    team.members.create(
        user=captain1,
        member_name=captain1.name,
        email_id=captain1.email,
        role='captain',
        sort_key=captain1.email[:7].lower()
    )
    team.members.create(
        user=member1,
        member_name=member1.name,
        email_id=member1.email,
        role='player',
        sort_key=member1.email[:7].lower()
    )
    return team


@pytest.fixture
def team2(db, captain2, sport, member2):
    """Create second test team with captain2."""
    team = Team.objects.create(
        team_name="Lightning Bolts",
        captain=captain2,
        sport=sport,
        member_count=2
    )
    # Add captain and member
    team.members.create(
        user=captain2,
        member_name=captain2.name,
        email_id=captain2.email,
        role='captain',
        sort_key=captain2.email[:7].lower()
    )
    team.members.create(
        user=member2,
        member_name=member2.name,
        email_id=member2.email,
        role='player',
        sort_key=member2.email[:7].lower()
    )
    return team


@pytest.mark.django_db
class TestMatchInvitation:
    """Test match invitation creation and listing."""
    
    def test_invite_team_for_match_success(self, api_client, captain1, team1, team2):
        """Test successful match invitation creation."""
        api_client.force_authenticate(user=captain1)
        
        data = {
            "sender_team_id": team1.team_id,
            "target_team_id": team2.team_id,
            "message": "Let's play a friendly match this Saturday!",
            "preferred_date": "2025-12-01",
        }
        
        response = api_client.post("/api/teams/invitations/match-invite/", data, format='json')
        
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data['message'] == "Match invitation sent successfully."
        assert 'invitation_id' in response.data
        assert response.data['sender_team_id'] == team1.team_id
        assert response.data['target_team_id'] == team2.team_id
        assert response.data['target_team_name'] == team2.team_name
        
        # Verify invitation was created in database
        invitation = Invitation.objects.get(invitation_id=response.data['invitation_id'])
        assert invitation.type == 'MATCH_INVITE'
        assert invitation.sender == captain1
        assert invitation.recipient == team2.captain
        assert invitation.status == 'SENT'
        assert invitation.match_details['sender_captain_email'] == captain1.email
        assert invitation.match_details['message'] == data['message']
    
    def test_invite_team_non_captain_fails(self, api_client, member1, team1, team2):
        """Test that non-captains cannot send match invitations."""
        api_client.force_authenticate(user=member1)
        
        data = {
            "sender_team_id": team1.team_id,
            "target_team_id": team2.team_id,
        }
        
        response = api_client.post("/api/teams/invitations/match-invite/", data, format='json')
        
        assert response.status_code == status.HTTP_403_FORBIDDEN
        assert "captain" in response.data['message'].lower()
    
    def test_invite_own_team_fails(self, api_client, captain1, team1):
        """Test that captains cannot invite their own team."""
        api_client.force_authenticate(user=captain1)
        
        data = {
            "sender_team_id": team1.team_id,
            "target_team_id": team1.team_id,
        }
        
        response = api_client.post("/api/teams/invitations/match-invite/", data, format='json')
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        # Error now comes from serializer validation
        assert "own team" in str(response.data).lower() or "own team" in response.data.get('errors', {}).get('target_team_id', [''])[0].lower()
    
    def test_invite_different_sport_fails(self, api_client, captain1, team1, captain2):
        """Test that invitations fail when teams play different sports."""
        # Create a different sport team
        basketball = Sport.objects.create(sport_name="Basketball", min_player=5)
        basketball_team = Team.objects.create(
            team_name="Hoops Masters",
            captain=captain2,
            sport=basketball,
            member_count=5
        )
        
        api_client.force_authenticate(user=captain1)
        
        data = {
            "sender_team_id": team1.team_id,
            "target_team_id": basketball_team.team_id,
        }
        
        response = api_client.post("/api/teams/invitations/match-invite/", data, format='json')
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "same sport" in response.data['message'].lower()
    
    def test_invite_with_ground_preference(self, api_client, captain1, team1, team2, ground):
        """Test match invitation with ground preference."""
        api_client.force_authenticate(user=captain1)
        
        data = {
            "sender_team_id": team1.team_id,
            "target_team_id": team2.team_id,
            "ground_id": ground.ground_id,
            "preferred_date": "2025-12-15",
        }
        
        response = api_client.post("/api/teams/invitations/match-invite/", data, format='json')
        
        assert response.status_code == status.HTTP_201_CREATED
        
        # Verify ground details in match_details
        invitation = Invitation.objects.get(invitation_id=response.data['invitation_id'])
        assert invitation.match_details['ground_id'] == ground.ground_id
        assert invitation.match_details['ground_name'] == ground.ground_name
    
    def test_list_sent_invitations(self, api_client, captain1, team1, team2):
        """Test listing sent invitations."""
        api_client.force_authenticate(user=captain1)
        
        # Create an invitation
        Invitation.objects.create(
            sender=captain1,
            recipient=team2.captain,
            type='MATCH_INVITE',
            related_team=team2,
            status='SENT',
            match_details={
                'sender_team_id': team1.team_id,
                'sender_team_name': team1.team_name,
                'sender_captain_email': captain1.email,
                'target_team_id': team2.team_id,
                'target_team_name': team2.team_name,
            }
        )
        
        response = api_client.get("/api/teams/invitations/sent/")
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data['count'] == 1
        assert len(response.data['invitations']) == 1
        assert response.data['invitations'][0]['type'] == 'MATCH_INVITE'
    
    def test_list_received_invitations(self, api_client, captain2, team1, team2):
        """Test listing received invitations."""
        api_client.force_authenticate(user=captain2)
        
        # Create an invitation to team2
        Invitation.objects.create(
            sender=team1.captain,
            recipient=captain2,
            type='MATCH_INVITE',
            related_team=team2,
            status='SENT',
            match_details={
                'sender_team_id': team1.team_id,
                'sender_team_name': team1.team_name,
                'sender_captain_email': team1.captain.email,
            }
        )
        
        response = api_client.get("/api/teams/invitations/received/")
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data['count'] == 1
        assert len(response.data['invitations']) == 1
        assert response.data['invitations'][0]['type'] == 'MATCH_INVITE'
        assert response.data['invitations'][0]['status'] == 'SENT'
    
    def test_list_invitations_non_captain(self, api_client, member1):
        """Test that non-captains get empty list for sent invitations."""
        api_client.force_authenticate(user=member1)
        
        response = api_client.get("/api/teams/invitations/sent/")
        
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data['invitations']) == 0
        assert "not a captain" in response.data['message'].lower()
    
    def test_invite_nonexistent_team_fails(self, api_client, captain1):
        """Test that inviting non-existent team fails."""
        api_client.force_authenticate(user=captain1)
        
        data = {
            "target_team_id": 99999,  # Non-existent team
        }
        
        response = api_client.post("/api/teams/invitations/match-invite/", data, format='json')
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
    
    def test_invite_requires_authentication(self, api_client, team2):
        """Test that authentication is required to send invitations."""
        data = {
            "target_team_id": team2.team_id,
        }
        
        response = api_client.post("/api/teams/invitations/match-invite/", data, format='json')
        
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
