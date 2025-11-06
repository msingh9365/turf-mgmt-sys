"""
Comprehensive unit tests for bookings module.
Tests booking creation, locking, conflicts, and cancellation.
"""
import pytest
from datetime import datetime, timedelta
from django.utils import timezone
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
from rest_framework import status

from bookings.models import Booking, Booked_Details, Slot, Ground
from core.redis_client import RedisClient

User = get_user_model()


def _api_create_booking(client, ground, slot_ids, date, players, metadata=None):
    """Helper to create a booking via API and return response payload."""
    payload = {
        "ground_id": ground.ground_id,
        "slot_id": slot_ids,
        "date": str(date),
        "players": players,
    }
    if metadata is not None:
        payload["metadata"] = metadata

    response = client.post("/api/bookings/", payload, format="json")
    assert response.status_code == status.HTTP_200_OK
    return response.data


@pytest.fixture
def api_client():
    """Fixture to provide API client."""
    return APIClient()


@pytest.fixture
def test_user(db):
    """Fixture to create a test user."""
    user = User.objects.create_user(
        email="test@iitrpr.ac.in",
        name="Test User",
        sort_key="TEST",
        password="testpass123",
    )
    return user


@pytest.fixture
def another_user(db):
    """Fixture to create another test user."""
    user = User.objects.create_user(
        email="another@iitrpr.ac.in",
        name="Another User",
        sort_key="ANOTHER",
        password="testpass123",
    )
    return user


@pytest.fixture
def authenticated_client(api_client, test_user):
    """Fixture to provide authenticated API client."""
    api_client.force_authenticate(user=test_user)
    return api_client


@pytest.mark.django_db
class TestBookingCreation:
    """Tests for booking creation with Redis locking."""
    
    def test_creator_is_auto_included_when_missing(self, authenticated_client, test_user, fake_redis_client, ground):
        """If creator isn't in players payload, ensure they are auto-added to Booked_Details and response."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()

        # Do not include the creator in players list
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [5, 6],
            "date": str(tomorrow),
            "players": [
                {"name": "Guest One", "email": "guest1@example.com"},
                {"name": "Guest Two", "email": "guest2@example.com"},
            ],
            "metadata": {"note": "team booking"},
        }

        response = authenticated_client.post("/api/bookings/", data, format="json")

        assert response.status_code == status.HTTP_200_OK
        assert "players" in response.data

        # Creator should be present and marked is_user=True
        emails = {p["email"] for p in response.data["players"]}
        assert test_user.email.lower() in emails

        creator_entry = next(p for p in response.data["players"] if p["email"] == test_user.email.lower())
        assert creator_entry["is_user"] is True

        # Verify Booked_Details created for creator across all slots
        booking_id = response.data["booking_id"]
        details = Booked_Details.objects.filter(booking__booking_id=booking_id, player_email=test_user.email.lower())
        assert details.count() == 2
        assert set(details.values_list("slot_id", flat=True)) == {5, 6}
    
    def test_sort_key_case_insensitive_matching(self, authenticated_client, fake_redis_client, ground, db):
        """Test that sort key matching is case-insensitive."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Create a user with mixed-case email
        user_mixed_case = User.objects.create_user(
            email="MixedCase@iitrpr.ac.in",
            name="Mixed Case User",
            sort_key="MIXEDCA",  # This will be stored in uppercase
            password="testpass123",
        )
        
        # Authenticate as different user
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [7],
            "date": str(tomorrow),
            "players": [
                # Use lowercase email - should still match the user with uppercase sort_key
                {"name": "Mixed Case Player", "email": "mixedcase@iitrpr.ac.in"},
            ],
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_200_OK
        assert "players" in response.data
        
        # Should have 2 players: the one we specified + the authenticated creator
        assert len(response.data["players"]) == 2
        
        # Find the mixed case player in response
        mixed_player = next(
            (p for p in response.data["players"] if "mixedcase" in p["email"].lower()),
            None
        )
        assert mixed_player is not None
        # Should be recognized as registered user despite case difference
        assert mixed_player["is_user"] is True
        assert mixed_player["sort_key"] == "MIXEDCA"

    def test_successful_booking_creation(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test successful booking creation with valid data."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [5],  # Now expects a list
            "date": str(tomorrow),
            "players": [
                {"name": "Test User", "email": test_user.email},
                {"name": "Guest Player", "email": "guest1@example.com"},
            ],
            "metadata": {"team_name": "Test Team"},
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_200_OK
        assert "booking_id" in response.data
        assert response.data["status"] == "Done"
        assert "slots_booked" in response.data
        assert response.data["slots_booked"] == [5]
        assert len(response.data["players"]) == 2
        assert response.data["players"][0]["sort_key"] == "TEST"
        assert response.data["players"][0]["is_user"] is True
        assert response.data["players"][1]["is_user"] is False
        
        # Verify booking exists in database
        booking = Booking.objects.get(booking_id=response.data["booking_id"])
        assert booking.user == test_user
        assert booking.status == Booking.STATUS_DONE
        assert booking.metadata["team_name"] == "Test Team"
        assert booking.metadata["slots"] == [5]
        assert len(booking.metadata["players"]) == 2
        assert booking.metadata["ground_id"] == ground.ground_id
        assert booking.metadata["ground_name"] == ground.ground_name

        details = Booked_Details.objects.filter(booking=booking)
        assert details.count() == 2  # 2 players x 1 slot
        detail = details.first()
        assert detail.player_email in {test_user.email.lower(), "guest1@example.com"}
        assert detail.ground == ground
        assert detail.slot_id == 5
        assert detail.is_user in {True, False}

        slot = Slot.objects.get(ground=ground, date=tomorrow, slot_id=5)
        assert slot.booked is True
        
        # Verify Redis slot is marked as booked
        slot_key = f"slot:{ground.ground_id}:{tomorrow}:5"
        assert fake_redis_client.get(slot_key) == b"booked"
    
    def test_multi_slot_booking_creation(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test successful booking creation with multiple slots sharing same booking_id."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        secondary_ground = Ground.objects.create(ground_name="Practice Field", sport=ground.sport)
        
        data = {
            "ground_id": secondary_ground.ground_id,
            "slot_id": [3, 4, 5],  # Multiple slots
            "date": str(tomorrow),
            "players": [
                {"name": "Test User", "email": test_user.email},
                {"name": "Guest Player", "email": "guest2@example.com"},
                {"name": "Guest Player 2", "email": "guest3@example.com"},
            ],
            "metadata": {"team_name": "Hostel 5 FC", "notes": "Final match"},
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_200_OK
        assert "booking_id" in response.data
        assert response.data["status"] == "Done"
        assert "slots_booked" in response.data
        assert response.data["slots_booked"] == [3, 4, 5]
        assert "3 slot(s)" in response.data["message"]
        
        # Verify booking exists and details captured
        booking = Booking.objects.get(booking_id=response.data["booking_id"])
        assert booking.metadata["slots"] == [3, 4, 5]
        assert len(booking.metadata["players"]) == 3
        assert booking.metadata["ground_id"] == secondary_ground.ground_id
        assert booking.metadata["ground_name"] == secondary_ground.ground_name

        details = Booked_Details.objects.filter(booking=booking)
        assert details.count() == 9  # 3 slots * 3 players
        assert {detail.slot_id for detail in details} == {3, 4, 5}

        slots = Slot.objects.filter(ground=secondary_ground, date=tomorrow, slot_id__in=[3, 4, 5])
        assert slots.count() == 3
        assert all(slot.booked for slot in slots)
        
        # Verify all slots are marked as booked in Redis
        for slot in [3, 4, 5]:
            slot_key = f"slot:{secondary_ground.ground_id}:{tomorrow}:{slot}"
            assert fake_redis_client.get(slot_key) == b"booked"
    
    def test_booking_past_date_rejected(self, authenticated_client, fake_redis_client, ground, test_user):
        """Test that booking in the past is rejected."""
        yesterday = (timezone.now() - timedelta(days=1)).date()
        
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [5],
            "date": str(yesterday),
            "players": [{"name": "Test User", "email": test_user.email}],
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "past" in str(response.data).lower()
    
    def test_booking_too_far_advance_rejected(self, authenticated_client, fake_redis_client, ground, test_user):
        """Test that booking more than 14 days in advance is rejected."""
        far_future = (timezone.now() + timedelta(days=15)).date()
        
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [5],
            "date": str(far_future),
            "players": [{"name": "Test User", "email": test_user.email}],
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "14 days" in str(response.data)
    
    def test_double_booking_prevention(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test that double booking is prevented."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Create first booking via API to populate related tables
        _api_create_booking(
            authenticated_client,
            ground,
            [5],
            tomorrow,
            [{"name": "Test User", "email": test_user.email}],
        )
        
        # Try to create duplicate booking
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [5],
            "date": str(tomorrow),
            "players": [{"name": "Test User", "email": test_user.email}],
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_409_CONFLICT
        # Member lock catches this first, but slot-level check would also catch it
        error_msg = response.data["error"].lower()
        assert "already booked" in error_msg or "member lock" in error_msg
    
    def test_lock_conflict_returns_409(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test that concurrent booking attempt returns 409 when lock is held."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Simulate another user holding the lock
        lock_key = f"lock:slot:{ground.ground_id}:{tomorrow}:5"
        fake_redis_client.set(lock_key, "999", ex=10)  # Different user ID
        
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [5],
            "date": str(tomorrow),
            "players": [{"name": "Test User", "email": test_user.email}],
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_409_CONFLICT
        assert "being booked" in response.data["error"].lower()
    
    def test_authentication_required(self, api_client, fake_redis_client, ground):
        """Test that authentication is required for booking."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [5],
            "date": str(tomorrow),
            "players": [{"name": "Guest", "email": "guest@example.com"}],
        }
        
        response = api_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code in [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN]


@pytest.mark.django_db
class TestMemberLockSystem:
    """Tests for member lock system - preventing duplicate bookings for registered users."""
    
    def test_member_lock_prevents_duplicate_booking_same_ground_same_date(
        self, authenticated_client, test_user, another_user, fake_redis_client, ground
    ):
        """Test that a registered user cannot book the same ground on the same date twice."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Create first booking for test_user
        first_booking = _api_create_booking(
            authenticated_client,
            ground,
            [5, 6],
            tomorrow,
            [{"name": "Test User", "email": test_user.email}],
        )
        
        assert first_booking["booking_id"]
        
        # Try to create second booking with test_user in players list (different slots)
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [7, 8],  # Different slots
            "date": str(tomorrow),  # Same date
            "players": [
                {"name": "Test User", "email": test_user.email},  # Same user
                {"name": "Guest", "email": "guest@example.com"},
            ],
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_409_CONFLICT
        assert "Member lock violation" in response.data["error"]
        assert test_user.email.lower() in response.data["message"].lower()
        assert first_booking["booking_id"] == response.data["existing_booking_id"]
    
    def test_member_lock_prevents_duplicate_with_another_user_in_players(
        self, authenticated_client, test_user, another_user, fake_redis_client, ground
    ):
        """Test that member lock blocks if ANY registered player has existing booking."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Create first booking with another_user
        booking_payload = {
            "ground_id": ground.ground_id,
            "slot_id": [10, 11],
            "date": str(tomorrow),
            "players": [{"name": another_user.name, "email": another_user.email}],
        }
        
        # Create booking as test_user (creator auto-added)
        response1 = authenticated_client.post("/api/bookings/", booking_payload, format="json")
        assert response1.status_code == status.HTTP_200_OK
        first_booking_id = response1.data["booking_id"]
        
        # Now try to book again including another_user in players
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [12, 13],  # Different slots
            "date": str(tomorrow),  # Same date
            "players": [
                {"name": another_user.name, "email": another_user.email},  # Has existing booking
                {"name": "New Guest", "email": "newguest@example.com"},
            ],
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_409_CONFLICT
        assert "Member lock violation" in response.data["error"]
        assert another_user.email.lower() in response.data["conflicting_player"].lower()
        assert first_booking_id == response.data["existing_booking_id"]
    
    def test_member_lock_allows_different_ground_same_date(
        self, authenticated_client, test_user, fake_redis_client, ground, sport
    ):
        """Test that member can book different ground on same date."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Create another ground
        ground2 = Ground.objects.create(
            ground_name="Ground 2",
            sport=sport,
        )
        
        # Create first booking on ground 1
        _api_create_booking(
            authenticated_client,
            ground,
            [5],
            tomorrow,
            [{"name": "Test User", "email": test_user.email}],
        )
        
        # Try to book ground 2 on same date - should succeed
        data = {
            "ground_id": ground2.ground_id,
            "slot_id": [5],
            "date": str(tomorrow),
            "players": [{"name": "Test User", "email": test_user.email}],
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data["booking_id"]
    
    def test_member_lock_allows_same_ground_different_date(
        self, authenticated_client, test_user, fake_redis_client, ground
    ):
        """Test that member can book same ground on different date."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        day_after = (timezone.now() + timedelta(days=2)).date()
        
        # Create first booking for tomorrow
        _api_create_booking(
            authenticated_client,
            ground,
            [5],
            tomorrow,
            [{"name": "Test User", "email": test_user.email}],
        )
        
        # Try to book same ground for day after - should succeed
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [5],
            "date": str(day_after),
            "players": [{"name": "Test User", "email": test_user.email}],
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data["booking_id"]
    
    def test_member_lock_ignores_non_registered_players(
        self, api_client, fake_redis_client, ground
    ):
        """Test that member lock only applies to registered users, not guests."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Create a non-registered user for authentication
        guest_user = User.objects.create_user(
            email="guestuser@example.com",
            name="Guest User",
            sort_key="GUESTUS",
            password="testpass123",
        )
        api_client.force_authenticate(user=guest_user)
        
        # Create first booking with a non-registered guest email
        booking_payload = {
            "ground_id": ground.ground_id,
            "slot_id": [5],
            "date": str(tomorrow),
            "players": [{"name": "Non Registered Guest", "email": "nonreg@example.com"}],
        }
        response1 = api_client.post("/api/bookings/", booking_payload, format="json")
        assert response1.status_code == status.HTTP_200_OK
        
        # Authenticate as different user
        another_guest_user = User.objects.create_user(
            email="another_guest@example.com",
            name="Another Guest User",
            sort_key="ANOTHER",
            password="testpass123",
        )
        api_client.force_authenticate(user=another_guest_user)
        
        # Try to book with the same non-registered guest email
        # This should succeed because the guest is not a registered user and member lock doesn't apply
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [6],
            "date": str(tomorrow),
            "players": [{"name": "Non Registered Guest", "email": "nonreg@example.com"}],
        }
        
        response = api_client.post("/api/bookings/", data, format="json")
        
        # Should succeed because non-registered guests are not subject to member lock
        assert response.status_code == status.HTTP_200_OK
        assert response.data["booking_id"]
    
    def test_member_lock_ignores_cancelled_bookings(
        self, authenticated_client, test_user, fake_redis_client, ground
    ):
        """Test that member lock ignores cancelled/rejected bookings."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Create and then cancel a booking
        first_booking = _api_create_booking(
            authenticated_client,
            ground,
            [5],
            tomorrow,
            [{"name": "Test User", "email": test_user.email}],
        )
        
        booking_id = first_booking["booking_id"]
        
        # Cancel the booking
        cancel_response = authenticated_client.post(
            f"/api/bookings/{booking_id}/cancel/",
            format="json",
        )
        assert cancel_response.status_code == status.HTTP_200_OK
        
        # Now try to book again - should succeed because first booking is cancelled
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [6],
            "date": str(tomorrow),
            "players": [{"name": "Test User", "email": test_user.email}],
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data["booking_id"]
        assert response.data["booking_id"] != booking_id  # Different booking
    
    def test_member_lock_checks_creator_auto_inclusion(
        self, authenticated_client, test_user, fake_redis_client, ground
    ):
        """Test that member lock also checks the creator who is auto-included."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Create first booking (creator auto-included)
        first_booking = _api_create_booking(
            authenticated_client,
            ground,
            [5],
            tomorrow,
            [{"name": "Guest", "email": "guest@example.com"}],  # Only guest in payload
        )
        
        # Try to create another booking without creator in payload
        # Creator will be auto-included and should trigger member lock
        data = {
            "ground_id": ground.ground_id,
            "slot_id": [6],
            "date": str(tomorrow),
            "players": [{"name": "Another Guest", "email": "another@example.com"}],
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        # Should fail because creator (test_user) is auto-included and already has booking
        assert response.status_code == status.HTTP_409_CONFLICT
        assert "Member lock violation" in response.data["error"]


@pytest.mark.django_db
class TestBookingRetrieval:
    """Tests for retrieving user bookings."""
    
    def test_get_my_bookings(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test retrieving bookings for authenticated user."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        day_after = (timezone.now() + timedelta(days=2)).date()
        
        booking1 = _api_create_booking(
            authenticated_client,
            ground,
            [5],
            tomorrow,
            [{"name": "Test User", "email": test_user.email}],
        )

        second_ground = Ground.objects.create(ground_name="Secondary Turf", sport=ground.sport)
        booking2 = _api_create_booking(
            authenticated_client,
            second_ground,
            [7],
            day_after,
            [{"name": "Test User", "email": test_user.email}],
        )
        
        response = authenticated_client.get("/api/bookings/my/")
        
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 2
        
        booking_ids = [b["booking_id"] for b in response.data]
        assert booking1["booking_id"] in booking_ids
        assert booking2["booking_id"] in booking_ids
    
    def test_get_my_bookings_empty(self, authenticated_client, fake_redis_client):
        """Test retrieving bookings when user has none."""
        response = authenticated_client.get("/api/bookings/my/")
        
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 0
    
    def test_user_only_sees_own_bookings(self, authenticated_client, test_user, another_user, fake_redis_client, ground, api_client):
        """Test that users only see their own bookings."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Create booking for test_user
        user_booking = _api_create_booking(
            authenticated_client,
            ground,
            [5],
            tomorrow,
            [{"name": "Test User", "email": test_user.email}],
        )
        
        # Create booking for another_user via separate authenticated client
        client_for_other = APIClient()
        client_for_other.force_authenticate(user=another_user)
        _api_create_booking(
            client_for_other,
            ground,
            [6],
            tomorrow,
            [{"name": "Another User", "email": another_user.email}],
        )
        
        response = authenticated_client.get("/api/bookings/my/")
        
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 1
        assert response.data[0]["booking_id"] == user_booking["booking_id"]


@pytest.mark.django_db
class TestBookingCancellation:
    """Tests for booking cancellation."""
    
    def test_successful_cancellation(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test successful booking cancellation."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking_resp = _api_create_booking(
            authenticated_client,
            ground,
            [5],
            tomorrow,
            [{"name": "Test User", "email": test_user.email}],
        )
        booking_id = booking_resp["booking_id"]
        slot_key = f"slot:{ground.ground_id}:{tomorrow}:5"
        assert fake_redis_client.get(slot_key) == b"booked"

        response = authenticated_client.delete(f"/api/bookings/{booking_id}/")
        
        assert response.status_code == status.HTTP_200_OK
        assert "cancelled successfully" in response.data["message"].lower()
        
        # Verify booking status updated
        booking = Booking.objects.get(booking_id=booking_id)
        assert booking.status == Booking.STATUS_REJECTED
        
        slot = Slot.objects.get(ground=ground, date=tomorrow, slot_id=5)
        assert slot.booked is False
        
        # Verify Redis slot is marked as available
        assert fake_redis_client.get(slot_key) == b"available"
    
    def test_cannot_cancel_others_booking(self, authenticated_client, test_user, another_user, fake_redis_client, ground):
        """Test that user cannot cancel another user's booking."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        client_for_other = APIClient()
        client_for_other.force_authenticate(user=another_user)
        booking_resp = _api_create_booking(
            client_for_other,
            ground,
            [5],
            tomorrow,
            [{"name": "Another User", "email": another_user.email}],
        )
        
        response = authenticated_client.delete(f"/api/bookings/{booking_resp['booking_id']}/")
        
        assert response.status_code == status.HTTP_403_FORBIDDEN
        assert "own bookings" in response.data["error"].lower()
    
    def test_cannot_cancel_past_booking(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test that past bookings cannot be cancelled."""
        yesterday = (timezone.now() - timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            date=yesterday,
            status=Booking.STATUS_DONE,
            metadata={
                "slots": [5],
                "players": [{"name": "Test User", "email": test_user.email}],
                "ground_id": ground.ground_id,
                "ground_name": ground.ground_name,
            },
        )
        Slot.objects.create(ground=ground, date=yesterday, slot_id=5, booked=True)
        Booked_Details.objects.create(
            booking=booking,
            player_name="Test User",
            player_email=test_user.email.lower(),
            sort_key="TEST",
            ground=ground,
            is_user=True,
            date=yesterday,
            slot_id=5,
        )
        
        response = authenticated_client.delete(f"/api/bookings/{booking.booking_id}/")
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "cannot cancel past" in response.data["error"].lower()
    
    def test_cannot_cancel_rejected_booking(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test that already rejected bookings cannot be cancelled again."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            date=tomorrow,
            status=Booking.STATUS_REJECTED,
            metadata={
                "slots": [5],
                "players": [{"name": "Test User", "email": test_user.email}],
                "ground_id": ground.ground_id,
                "ground_name": ground.ground_name,
            },
        )
        Slot.objects.create(ground=ground, date=tomorrow, slot_id=5, booked=False)
        Booked_Details.objects.create(
            booking=booking,
            player_name="Test User",
            player_email=test_user.email.lower(),
            sort_key="TEST",
            ground=ground,
            is_user=True,
            date=tomorrow,
            slot_id=5,
        )
        
        response = authenticated_client.delete(f"/api/bookings/{booking.booking_id}/")
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
    
    def test_cancel_nonexistent_booking(self, authenticated_client, fake_redis_client):
        """Test cancelling a non-existent booking returns 404."""
        response = authenticated_client.delete("/api/bookings/INVALID123/")
        
        assert response.status_code == status.HTTP_404_NOT_FOUND


@pytest.mark.django_db
class TestCancelEndpoint:
    """Tests for the dedicated cancel endpoint POST /api/bookings/{id}/cancel/"""
    
    def test_cancel_endpoint_successful(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test successful cancellation via POST cancel endpoint."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking_resp = _api_create_booking(
            authenticated_client,
            ground,
            [5, 6],
            tomorrow,
            [{"name": "Test User", "email": test_user.email}],
        )
        booking_id = booking_resp["booking_id"]
        
        # Verify slots are booked
        slot5 = Slot.objects.get(ground=ground, date=tomorrow, slot_id=5)
        slot6 = Slot.objects.get(ground=ground, date=tomorrow, slot_id=6)
        assert slot5.booked is True
        assert slot6.booked is True
        
        response = authenticated_client.post(f"/api/bookings/{booking_id}/cancel/")
        
        assert response.status_code == status.HTTP_200_OK
        assert "cancelled successfully" in response.data["message"].lower()
        assert response.data["booking_id"] == booking_id
        assert response.data["status"] == "Rejected"
        assert set(response.data["slots_cancelled"]) == {5, 6}
        
        # Verify booking status updated
        booking = Booking.objects.get(booking_id=booking_id)
        assert booking.status == Booking.STATUS_REJECTED
        
        # Verify slots freed
        slot5.refresh_from_db()
        slot6.refresh_from_db()
        assert slot5.booked is False
        assert slot6.booked is False
        
        # Verify Redis cache updated
        assert fake_redis_client.get(f"slot:{ground.ground_id}:{tomorrow}:5") == b"available"
        assert fake_redis_client.get(f"slot:{ground.ground_id}:{tomorrow}:6") == b"available"
    
    def test_cancel_endpoint_multi_slot_booking(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test cancelling a booking with multiple slots via cancel endpoint."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking_resp = _api_create_booking(
            authenticated_client,
            ground,
            [10, 11, 12, 13],
            tomorrow,
            [
                {"name": "Player 1", "email": "p1@example.com"},
                {"name": "Player 2", "email": "p2@example.com"},
            ],
        )
        booking_id = booking_resp["booking_id"]
        
        response = authenticated_client.post(f"/api/bookings/{booking_id}/cancel/")
        
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data["slots_cancelled"]) == 4
        assert set(response.data["slots_cancelled"]) == {10, 11, 12, 13}
        
        # Verify all slots freed
        for slot_id in [10, 11, 12, 13]:
            slot = Slot.objects.get(ground=ground, date=tomorrow, slot_id=slot_id)
            assert slot.booked is False
    
    def test_cancel_endpoint_ownership_check(self, authenticated_client, test_user, another_user, fake_redis_client, ground):
        """Test cancel endpoint rejects unauthorized cancellation."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        client_for_other = APIClient()
        client_for_other.force_authenticate(user=another_user)
        booking_resp = _api_create_booking(
            client_for_other,
            ground,
            [5],
            tomorrow,
            [{"name": "Another User", "email": another_user.email}],
        )
        
        # Try to cancel with different user
        response = authenticated_client.post(f"/api/bookings/{booking_resp['booking_id']}/cancel/")
        
        assert response.status_code == status.HTTP_403_FORBIDDEN
        assert "own bookings" in response.data["error"].lower()
        
        # Verify booking not cancelled
        booking = Booking.objects.get(booking_id=booking_resp["booking_id"])
        assert booking.status == Booking.STATUS_DONE
    
    def test_cancel_endpoint_past_booking(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test cancel endpoint rejects past bookings."""
        yesterday = (timezone.now() - timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            date=yesterday,
            status=Booking.STATUS_DONE,
            metadata={
                "slots": [5],
                "players": [{"name": "Test User", "email": test_user.email}],
                "ground_id": ground.ground_id,
                "ground_name": ground.ground_name,
            },
        )
        Slot.objects.create(ground=ground, date=yesterday, slot_id=5, booked=True)
        Booked_Details.objects.create(
            booking=booking,
            player_name="Test User",
            player_email=test_user.email.lower(),
            sort_key="TEST",
            ground=ground,
            is_user=True,
            date=yesterday,
            slot_id=5,
        )
        
        response = authenticated_client.post(f"/api/bookings/{booking.booking_id}/cancel/")
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "cannot cancel past" in response.data["error"].lower()
    
    def test_cancel_endpoint_already_rejected(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test cancel endpoint handles already rejected bookings."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            date=tomorrow,
            status=Booking.STATUS_REJECTED,
            metadata={
                "slots": [5],
                "players": [{"name": "Test User", "email": test_user.email}],
                "ground_id": ground.ground_id,
                "ground_name": ground.ground_name,
            },
        )
        Slot.objects.create(ground=ground, date=tomorrow, slot_id=5, booked=False)
        Booked_Details.objects.create(
            booking=booking,
            player_name="Test User",
            player_email=test_user.email.lower(),
            sort_key="TEST",
            ground=ground,
            is_user=True,
            date=tomorrow,
            slot_id=5,
        )
        
        response = authenticated_client.post(f"/api/bookings/{booking.booking_id}/cancel/")
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "cannot cancel booking with status" in response.data["error"].lower()
    
    def test_cancel_endpoint_nonexistent_booking(self, authenticated_client, fake_redis_client):
        """Test cancel endpoint returns 404 for non-existent booking."""
        response = authenticated_client.post("/api/bookings/INVALID123/cancel/")
        
        assert response.status_code == status.HTTP_404_NOT_FOUND
        assert "not found" in response.data["error"].lower()
    
    def test_cancel_endpoint_waitlist_booking(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test cancel endpoint rejects waitlist bookings."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            date=tomorrow,
            status=Booking.STATUS_WAITLIST,
            metadata={
                "slots": [5],
                "players": [{"name": "Test User", "email": test_user.email}],
                "ground_id": ground.ground_id,
                "ground_name": ground.ground_name,
            },
        )
        Slot.objects.create(ground=ground, date=tomorrow, slot_id=5, booked=False)
        Booked_Details.objects.create(
            booking=booking,
            player_name="Test User",
            player_email=test_user.email.lower(),
            sort_key="TEST",
            ground=ground,
            is_user=True,
            date=tomorrow,
            slot_id=5,
        )
        
        response = authenticated_client.post(f"/api/bookings/{booking.booking_id}/cancel/")
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "cannot cancel booking with status" in response.data["error"].lower()
    
    def test_cancel_endpoint_idempotent_behavior(self, authenticated_client, test_user, fake_redis_client, ground):
        """Test that cancel endpoint handles already-cancelled bookings gracefully."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking_resp = _api_create_booking(
            authenticated_client,
            ground,
            [5],
            tomorrow,
            [{"name": "Test User", "email": test_user.email}],
        )
        booking_id = booking_resp["booking_id"]
        
        # First cancellation
        response1 = authenticated_client.post(f"/api/bookings/{booking_id}/cancel/")
        assert response1.status_code == status.HTTP_200_OK
        
        # Second cancellation attempt
        response2 = authenticated_client.post(f"/api/bookings/{booking_id}/cancel/")
        assert response2.status_code == status.HTTP_400_BAD_REQUEST
        assert "rejected" in response2.data["error"].lower()


@pytest.mark.django_db
class TestRedisLocking:
    """Tests for Redis locking mechanism."""
    
    def test_lock_auto_expires(self, fake_redis_client):
        """Test that locks automatically expire after TTL."""
        import time
        
        # Acquire lock with 1 second TTL
        acquired = RedisClient.acquire_slot_lock(
            ground_id=1,
            date="2025-11-01",
            slot_id=5,
            user_id=1,
            ttl=1,
        )
        
        assert acquired is True
        
        # Lock should exist immediately
        lock_key = "lock:slot:1:2025-11-01:5"
        assert fake_redis_client.get(lock_key) is not None
        
        # Wait for expiry
        time.sleep(1.1)
        
        # Lock should be expired
        assert fake_redis_client.get(lock_key) is None
    
    def test_lock_release(self, fake_redis_client):
        """Test manual lock release."""
        # Acquire lock
        RedisClient.acquire_slot_lock(
            ground_id=1,
            date="2025-11-01",
            slot_id=5,
            user_id=1,
            ttl=10,
        )
        
        lock_key = "lock:slot:1:2025-11-01:5"
        assert fake_redis_client.get(lock_key) is not None
        
        # Release lock
        RedisClient.release_slot_lock(
            ground_id=1,
            date="2025-11-01",
            slot_id=5,
        )
        
        assert fake_redis_client.get(lock_key) is None
    
    def test_slot_status_caching(self, fake_redis_client):
        """Test slot status caching in Redis."""
        # Set slot as booked
        RedisClient.mark_slot_booked(
            ground_id=1,
            date="2025-11-01",
            slot_id=5,
        )
        
        status = RedisClient.get_slot_status(
            ground_id=1,
            date="2025-11-01",
            slot_id=5,
        )
        
        assert status == "booked"
        
        # Set slot as available
        RedisClient.mark_slot_available(
            ground_id=1,
            date="2025-11-01",
            slot_id=5,
        )
        
        status = RedisClient.get_slot_status(
            ground_id=1,
            date="2025-11-01",
            slot_id=5,
        )
        
        assert status == "available"


@pytest.mark.django_db
class TestBookingModel:
    """Tests for Booking model."""
    
    def test_booking_id_generation(self, test_user):
        """Test that unique_id is auto-generated."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            date=tomorrow,
        )
        
        assert booking.booking_id is not None
        assert booking.booking_id.startswith("BK")
        assert len(booking.booking_id) > 10
    
    def test_booking_str_representation(self, test_user):
        """Test string representation of booking."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            date=tomorrow,
        )
        
        assert test_user.email in str(booking)
        assert str(tomorrow) in str(booking)
    
    def test_is_active_property(self, test_user):
        """Test is_active property."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            date=tomorrow,
            status=Booking.STATUS_DONE,
        )
        
        assert booking.is_active is True
        
        booking.status = Booking.STATUS_REJECTED
        booking.save()
        
        assert booking.is_active is False
    
    def test_can_be_cancelled_property(self, test_user):
        """Test can_be_cancelled property."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        yesterday = (timezone.now() - timedelta(days=1)).date()
        
        # Future booking can be cancelled
        future_booking = Booking.objects.create(
            user=test_user,
            date=tomorrow,
            status=Booking.STATUS_DONE,
        )
        
        assert future_booking.can_be_cancelled is True
        
        # Past booking cannot be cancelled
        past_booking = Booking.objects.create(
            user=test_user,
            date=yesterday,
            status=Booking.STATUS_DONE,
        )
        
        assert past_booking.can_be_cancelled is False
        
        # Rejected booking cannot be cancelled
        rejected_booking = Booking.objects.create(
            user=test_user,
            date=tomorrow,
            status=Booking.STATUS_REJECTED,
        )
        
        assert rejected_booking.can_be_cancelled is False
