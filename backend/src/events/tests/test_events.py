"""
Comprehensive tests for event creation restricted to team captains.
Tests cover:
- Captain-only event creation
- Creator and admin permissions for update/delete
- Ownership persistence after captaincy transfer
- Unauthenticated read access
"""
import pytest
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import timedelta
from rest_framework.test import APIClient
from rest_framework import status

from events.models import Event
from teams.models import Team, TeamMember
from bookings.models import Sport

User = get_user_model()


@pytest.fixture
def api_client():
    """Provide API client for tests."""
    return APIClient()


@pytest.fixture
def sport(db):
    """Create a test sport."""
    return Sport.objects.create(
        sport_name="Football",
        min_player=5
    )


@pytest.fixture
def captain_user(db):
    """Create a captain user."""
    return User.objects.create_user(
        email="captain@example.com",
        name="Captain User",
        password="testpass123",
        sort_key="captain"
    )


@pytest.fixture
def non_captain_user(db):
    """Create a non-captain user."""
    return User.objects.create_user(
        email="noncaptain@example.com",
        name="Non Captain User",
        password="testpass123",
        sort_key="noncapt"
    )


@pytest.fixture
def another_captain_user(db):
    """Create another captain user."""
    return User.objects.create_user(
        email="captain2@example.com",
        name="Captain Two",
        password="testpass123",
        sort_key="captai2"
    )


@pytest.fixture
def admin_user(db):
    """Create an admin user."""
    return User.objects.create_user(
        email="admin@example.com",
        name="Admin User",
        password="testpass123",
        sort_key="admin",
        is_admin=True
    )


@pytest.fixture
def team(db, captain_user, sport):
    """Create a team with captain_user as captain."""
    team = Team.objects.create(
        team_name="Test Team",
        captain=captain_user,
        sport=sport,
        member_count=1
    )
    # Add captain as member
    TeamMember.objects.create(
        team=team,
        user=captain_user,
        member_name=captain_user.name,
        email_id=captain_user.email,
        sort_key=captain_user.sort_key,
        role="captain"
    )
    return team


@pytest.fixture
def sample_event_data():
    """Provide sample event data for creation."""
    tomorrow = timezone.now() + timedelta(days=1)
    day_after = timezone.now() + timedelta(days=2)
    return {
        "sport_id": 101,
        "poster_id": "poster_1.jpg",
        "title": "Test Tournament",
        "description": "A test tournament",
        "location_text": "Main Ground",
        "starts_at": tomorrow.isoformat(),
        "ends_at": day_after.isoformat(),
        "organizer_name": "Test Organizer",
        "organizer_contact": "1234567890"
    }


@pytest.mark.django_db
class TestCaptainOnlyEventCreation:
    """Test that only team captains can create events."""

    def test_unauthenticated_user_can_list_events(self, api_client, captain_user, team, sample_event_data):
        """Test that unauthenticated users can list events (read access)."""
        # Create an event as captain
        api_client.force_authenticate(user=captain_user)
        api_client.post("/api/events/", sample_event_data, format="json")
        
        # Logout and try to list events
        api_client.force_authenticate(user=None)
        response = api_client.get("/api/events/")
        
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) > 0

    def test_unauthenticated_user_can_retrieve_event(self, api_client, captain_user, team, sample_event_data):
        """Test that unauthenticated users can retrieve event details."""
        # Create an event as captain
        api_client.force_authenticate(user=captain_user)
        create_response = api_client.post("/api/events/", sample_event_data, format="json")
        event_id = create_response.data["id"]
        
        # Logout and try to retrieve event
        api_client.force_authenticate(user=None)
        response = api_client.get(f"/api/events/{event_id}/")
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data["title"] == "Test Tournament"

    def test_unauthenticated_user_cannot_create_event(self, api_client, sample_event_data):
        """Test that unauthenticated users cannot create events."""
        api_client.force_authenticate(user=None)
        response = api_client.post("/api/events/", sample_event_data, format="json")
        
        # Unauthenticated users get 401 Unauthorized, not 403 Forbidden
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_non_captain_cannot_create_event(self, api_client, non_captain_user, sample_event_data):
        """Test that non-captain authenticated users cannot create events."""
        api_client.force_authenticate(user=non_captain_user)
        response = api_client.post("/api/events/", sample_event_data, format="json")
        
        assert response.status_code == status.HTTP_403_FORBIDDEN
        assert "team captain" in str(response.data).lower()

    def test_captain_can_create_event(self, api_client, captain_user, team, sample_event_data):
        """Test that a team captain can successfully create an event."""
        api_client.force_authenticate(user=captain_user)
        response = api_client.post("/api/events/", sample_event_data, format="json")
        
        assert response.status_code == status.HTTP_201_CREATED
        assert response.data["title"] == "Test Tournament"
        
        # Verify event was created with correct created_by
        event = Event.objects.get(id=response.data["id"])
        assert event.created_by == captain_user

    def test_creator_can_update_own_event(self, api_client, captain_user, team, sample_event_data):
        """Test that event creator can update their own event."""
        api_client.force_authenticate(user=captain_user)
        
        # Create event
        create_response = api_client.post("/api/events/", sample_event_data, format="json")
        event_id = create_response.data["id"]
        
        # Update event
        update_data = sample_event_data.copy()
        update_data["title"] = "Updated Tournament"
        response = api_client.put(f"/api/events/{event_id}/", update_data, format="json")
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data["title"] == "Updated Tournament"

    def test_creator_can_delete_own_event(self, api_client, captain_user, team, sample_event_data):
        """Test that event creator can delete their own event."""
        api_client.force_authenticate(user=captain_user)
        
        # Create event
        create_response = api_client.post("/api/events/", sample_event_data, format="json")
        event_id = create_response.data["id"]
        
        # Delete event
        response = api_client.delete(f"/api/events/{event_id}/")
        
        assert response.status_code == status.HTTP_204_NO_CONTENT
        assert not Event.objects.filter(id=event_id).exists()

    def test_former_captain_can_update_event_after_transfer(
        self, api_client, captain_user, another_captain_user, team, sport, sample_event_data
    ):
        """Test that a former captain can still update their event after transferring captaincy."""
        api_client.force_authenticate(user=captain_user)
        
        # Create event as captain
        create_response = api_client.post("/api/events/", sample_event_data, format="json")
        event_id = create_response.data["id"]
        
        # Add another captain to team and transfer captaincy
        TeamMember.objects.create(
            team=team,
            user=another_captain_user,
            member_name=another_captain_user.name,
            email_id=another_captain_user.email,
            sort_key=another_captain_user.sort_key,
            role="player"
        )
        team.captain = another_captain_user
        team.save()
        
        # Former captain updates their existing TeamMember role to player
        former_captain_member = TeamMember.objects.get(team=team, user=captain_user)
        former_captain_member.role = "player"
        former_captain_member.save()
        
        # Former captain should still be able to update their event
        update_data = sample_event_data.copy()
        update_data["title"] = "Updated by Former Captain"
        response = api_client.put(f"/api/events/{event_id}/", update_data, format="json")
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data["title"] == "Updated by Former Captain"

    def test_former_captain_can_delete_event_after_transfer(
        self, api_client, captain_user, another_captain_user, team, sport, sample_event_data
    ):
        """Test that a former captain can still delete their event after transferring captaincy."""
        api_client.force_authenticate(user=captain_user)
        
        # Create event as captain
        create_response = api_client.post("/api/events/", sample_event_data, format="json")
        event_id = create_response.data["id"]
        
        # Transfer captaincy
        TeamMember.objects.create(
            team=team,
            user=another_captain_user,
            member_name=another_captain_user.name,
            email_id=another_captain_user.email,
            sort_key=another_captain_user.sort_key,
            role="player"
        )
        team.captain = another_captain_user
        team.save()
        
        former_captain_member = TeamMember.objects.get(team=team, user=captain_user)
        former_captain_member.role = "player"
        former_captain_member.save()
        
        # Former captain should still be able to delete their event
        response = api_client.delete(f"/api/events/{event_id}/")
        
        assert response.status_code == status.HTTP_204_NO_CONTENT
        assert not Event.objects.filter(id=event_id).exists()

    def test_former_captain_cannot_create_new_event(
        self, api_client, captain_user, another_captain_user, team, sport, sample_event_data
    ):
        """Test that a former captain cannot create new events after transferring captaincy."""
        # Transfer captaincy first
        TeamMember.objects.create(
            team=team,
            user=another_captain_user,
            member_name=another_captain_user.name,
            email_id=another_captain_user.email,
            sort_key=another_captain_user.sort_key,
            role="player"
        )
        team.captain = another_captain_user
        team.save()
        
        former_captain_member = TeamMember.objects.get(team=team, user=captain_user)
        former_captain_member.role = "player"
        former_captain_member.save()
        
        # Former captain tries to create a new event
        api_client.force_authenticate(user=captain_user)
        response = api_client.post("/api/events/", sample_event_data, format="json")
        
        assert response.status_code == status.HTTP_403_FORBIDDEN
        assert "team captain" in str(response.data).lower()

    def test_admin_can_update_any_event(
        self, api_client, captain_user, admin_user, team, sample_event_data
    ):
        """Test that admin users can update any event."""
        # Create event as captain
        api_client.force_authenticate(user=captain_user)
        create_response = api_client.post("/api/events/", sample_event_data, format="json")
        event_id = create_response.data["id"]
        
        # Admin updates the event
        api_client.force_authenticate(user=admin_user)
        update_data = sample_event_data.copy()
        update_data["title"] = "Updated by Admin"
        response = api_client.put(f"/api/events/{event_id}/", update_data, format="json")
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data["title"] == "Updated by Admin"

    def test_admin_can_delete_any_event(
        self, api_client, captain_user, admin_user, team, sample_event_data
    ):
        """Test that admin users can delete any event."""
        # Create event as captain
        api_client.force_authenticate(user=captain_user)
        create_response = api_client.post("/api/events/", sample_event_data, format="json")
        event_id = create_response.data["id"]
        
        # Admin deletes the event
        api_client.force_authenticate(user=admin_user)
        response = api_client.delete(f"/api/events/{event_id}/")
        
        assert response.status_code == status.HTTP_204_NO_CONTENT
        assert not Event.objects.filter(id=event_id).exists()

    def test_non_creator_cannot_update_event(
        self, api_client, captain_user, another_captain_user, team, sport, sample_event_data
    ):
        """Test that a different captain cannot update another captain's event."""
        # Create second team with another_captain_user
        team2 = Team.objects.create(
            team_name="Another Team",
            captain=another_captain_user,
            sport=sport,
            member_count=1
        )
        TeamMember.objects.create(
            team=team2,
            user=another_captain_user,
            member_name=another_captain_user.name,
            email_id=another_captain_user.email,
            sort_key=another_captain_user.sort_key,
            role="captain"
        )
        
        # Create event as first captain
        api_client.force_authenticate(user=captain_user)
        create_response = api_client.post("/api/events/", sample_event_data, format="json")
        event_id = create_response.data["id"]
        
        # Second captain tries to update
        api_client.force_authenticate(user=another_captain_user)
        update_data = sample_event_data.copy()
        update_data["title"] = "Unauthorized Update"
        response = api_client.put(f"/api/events/{event_id}/", update_data, format="json")
        
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_non_creator_cannot_delete_event(
        self, api_client, captain_user, another_captain_user, team, sport, sample_event_data
    ):
        """Test that a different captain cannot delete another captain's event."""
        # Create second team with another_captain_user
        team2 = Team.objects.create(
            team_name="Another Team",
            captain=another_captain_user,
            sport=sport,
            member_count=1
        )
        TeamMember.objects.create(
            team=team2,
            user=another_captain_user,
            member_name=another_captain_user.name,
            email_id=another_captain_user.email,
            sort_key=another_captain_user.sort_key,
            role="captain"
        )
        
        # Create event as first captain
        api_client.force_authenticate(user=captain_user)
        create_response = api_client.post("/api/events/", sample_event_data, format="json")
        event_id = create_response.data["id"]
        
        # Second captain tries to delete
        api_client.force_authenticate(user=another_captain_user)
        response = api_client.delete(f"/api/events/{event_id}/")
        
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_my_events_endpoint_returns_creator_events(
        self, api_client, captain_user, team, sample_event_data
    ):
        """Test that my_events endpoint returns only events created by the authenticated user."""
        api_client.force_authenticate(user=captain_user)
        
        # Create two events
        api_client.post("/api/events/", sample_event_data, format="json")
        
        sample_event_data["title"] = "Second Event"
        api_client.post("/api/events/", sample_event_data, format="json")
        
        # Get my events
        response = api_client.get("/api/events/mine/")
        
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 2
        assert all(event["title"] in ["Test Tournament", "Second Event"] for event in response.data)

    def test_featured_events_accessible_without_auth(self, api_client, captain_user, team, sample_event_data):
        """Test that featured events endpoint is accessible without authentication."""
        # Create event as captain
        api_client.force_authenticate(user=captain_user)
        api_client.post("/api/events/", sample_event_data, format="json")
        
        # Access featured events without authentication
        api_client.force_authenticate(user=None)
        response = api_client.get("/api/events/featured/")
        
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) > 0
