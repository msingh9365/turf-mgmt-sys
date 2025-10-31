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
from fakeredis import FakeRedis
from unittest.mock import patch, MagicMock

from bookings.models import Booking
from core.redis_client import RedisClient

User = get_user_model()


@pytest.fixture
def fake_redis():
    """Fixture to provide fake Redis client for testing."""
    fake_client = FakeRedis(decode_responses=False)
    return fake_client


@pytest.fixture
def mock_redis_client(fake_redis):
    """Mock RedisClient to use fake Redis."""
    with patch.object(RedisClient, '_instance', fake_redis):
        with patch.object(RedisClient, 'get_client', return_value=fake_redis):
            yield fake_redis


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
        sort_key="TEST001",
        password="testpass123",
    )
    return user


@pytest.fixture
def another_user(db):
    """Fixture to create another test user."""
    user = User.objects.create_user(
        email="another@iitrpr.ac.in",
        name="Another User",
        sort_key="TEST002",
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
    
    def test_successful_booking_creation(self, authenticated_client, test_user, mock_redis_client):
        """Test successful booking creation with valid data."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        data = {
            "ground_id": 1,
            "slot_id": 5,
            "date": str(tomorrow),
            "player_ids": [2, 3, 4],
            "metadata": {"team_name": "Test Team"},
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_200_OK
        assert "booking_id" in response.data
        assert response.data["status"] == "Done"
        assert "Booking confirmed successfully" in response.data["message"]
        
        # Verify booking exists in database
        booking = Booking.objects.get(unique_id=response.data["booking_id"])
        assert booking.user == test_user
        assert booking.ground_id == 1
        assert booking.slot_id == 5
        assert booking.status == Booking.STATUS_DONE
        
        # Verify Redis slot is marked as booked
        slot_key = f"slot:1:{tomorrow}:5"
        assert mock_redis_client.get(slot_key) == b"booked"
    
    def test_booking_past_date_rejected(self, authenticated_client, mock_redis_client):
        """Test that booking in the past is rejected."""
        yesterday = (timezone.now() - timedelta(days=1)).date()
        
        data = {
            "ground_id": 1,
            "slot_id": 5,
            "date": str(yesterday),
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "past" in str(response.data).lower()
    
    def test_booking_too_far_advance_rejected(self, authenticated_client, mock_redis_client):
        """Test that booking more than 14 days in advance is rejected."""
        far_future = (timezone.now() + timedelta(days=15)).date()
        
        data = {
            "ground_id": 1,
            "slot_id": 5,
            "date": str(far_future),
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "14 days" in str(response.data)
    
    def test_double_booking_prevention(self, authenticated_client, test_user, mock_redis_client):
        """Test that double booking is prevented."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Create first booking
        Booking.objects.create(
            user=test_user,
            ground_id=1,
            slot_id=5,
            date=tomorrow,
            status=Booking.STATUS_DONE,
        )
        
        # Try to create duplicate booking
        data = {
            "ground_id": 1,
            "slot_id": 5,
            "date": str(tomorrow),
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_409_CONFLICT
        assert "already booked" in response.data["error"].lower()
    
    def test_lock_conflict_returns_409(self, authenticated_client, test_user, mock_redis_client):
        """Test that concurrent booking attempt returns 409 when lock is held."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Simulate another user holding the lock
        lock_key = f"lock:slot:1:{tomorrow}:5"
        mock_redis_client.set(lock_key, "999", ex=10)  # Different user ID
        
        data = {
            "ground_id": 1,
            "slot_id": 5,
            "date": str(tomorrow),
        }
        
        response = authenticated_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code == status.HTTP_409_CONFLICT
        assert "being booked" in response.data["error"].lower()
    
    def test_authentication_required(self, api_client, mock_redis_client):
        """Test that authentication is required for booking."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        data = {
            "ground_id": 1,
            "slot_id": 5,
            "date": str(tomorrow),
        }
        
        response = api_client.post("/api/bookings/", data, format="json")
        
        assert response.status_code in [status.HTTP_401_UNAUTHORIZED, status.HTTP_403_FORBIDDEN]


@pytest.mark.django_db
class TestBookingRetrieval:
    """Tests for retrieving user bookings."""
    
    def test_get_my_bookings(self, authenticated_client, test_user, mock_redis_client):
        """Test retrieving bookings for authenticated user."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Create test bookings
        booking1 = Booking.objects.create(
            user=test_user,
            ground_id=1,
            slot_id=5,
            date=tomorrow,
            status=Booking.STATUS_DONE,
        )
        
        booking2 = Booking.objects.create(
            user=test_user,
            ground_id=2,
            slot_id=7,
            date=tomorrow,
            status=Booking.STATUS_DONE,
        )
        
        response = authenticated_client.get("/api/bookings/my/")
        
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 2
        
        booking_ids = [b["booking_id"] for b in response.data]
        assert booking1.unique_id in booking_ids
        assert booking2.unique_id in booking_ids
    
    def test_get_my_bookings_empty(self, authenticated_client, mock_redis_client):
        """Test retrieving bookings when user has none."""
        response = authenticated_client.get("/api/bookings/my/")
        
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 0
    
    def test_user_only_sees_own_bookings(self, authenticated_client, test_user, another_user, mock_redis_client):
        """Test that users only see their own bookings."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        # Create booking for test_user
        user_booking = Booking.objects.create(
            user=test_user,
            ground_id=1,
            slot_id=5,
            date=tomorrow,
            status=Booking.STATUS_DONE,
        )
        
        # Create booking for another_user
        other_booking = Booking.objects.create(
            user=another_user,
            ground_id=1,
            slot_id=6,
            date=tomorrow,
            status=Booking.STATUS_DONE,
        )
        
        response = authenticated_client.get("/api/bookings/my/")
        
        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 1
        assert response.data[0]["booking_id"] == user_booking.unique_id


@pytest.mark.django_db
class TestBookingCancellation:
    """Tests for booking cancellation."""
    
    def test_successful_cancellation(self, authenticated_client, test_user, mock_redis_client):
        """Test successful booking cancellation."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            ground_id=1,
            slot_id=5,
            date=tomorrow,
            status=Booking.STATUS_DONE,
        )
        
        # Mark slot as booked in Redis
        slot_key = f"slot:1:{tomorrow}:5"
        mock_redis_client.set(slot_key, "booked")
        
        response = authenticated_client.delete(f"/api/bookings/{booking.unique_id}/")
        
        assert response.status_code == status.HTTP_200_OK
        assert "cancelled successfully" in response.data["message"].lower()
        
        # Verify booking status updated
        booking.refresh_from_db()
        assert booking.status == Booking.STATUS_REJECTED
        
        # Verify Redis slot is marked as available
        assert mock_redis_client.get(slot_key) == b"available"
    
    def test_cannot_cancel_others_booking(self, authenticated_client, test_user, another_user, mock_redis_client):
        """Test that user cannot cancel another user's booking."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=another_user,
            ground_id=1,
            slot_id=5,
            date=tomorrow,
            status=Booking.STATUS_DONE,
        )
        
        response = authenticated_client.delete(f"/api/bookings/{booking.unique_id}/")
        
        assert response.status_code == status.HTTP_403_FORBIDDEN
        assert "own bookings" in response.data["error"].lower()
    
    def test_cannot_cancel_past_booking(self, authenticated_client, test_user, mock_redis_client):
        """Test that past bookings cannot be cancelled."""
        yesterday = (timezone.now() - timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            ground_id=1,
            slot_id=5,
            date=yesterday,
            status=Booking.STATUS_DONE,
        )
        
        response = authenticated_client.delete(f"/api/bookings/{booking.unique_id}/")
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "cannot cancel past" in response.data["error"].lower()
    
    def test_cannot_cancel_rejected_booking(self, authenticated_client, test_user, mock_redis_client):
        """Test that already rejected bookings cannot be cancelled again."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            ground_id=1,
            slot_id=5,
            date=tomorrow,
            status=Booking.STATUS_REJECTED,
        )
        
        response = authenticated_client.delete(f"/api/bookings/{booking.unique_id}/")
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
    
    def test_cancel_nonexistent_booking(self, authenticated_client, mock_redis_client):
        """Test cancelling a non-existent booking returns 404."""
        response = authenticated_client.delete("/api/bookings/INVALID123/")
        
        assert response.status_code == status.HTTP_404_NOT_FOUND


@pytest.mark.django_db
class TestRedisLocking:
    """Tests for Redis locking mechanism."""
    
    def test_lock_auto_expires(self, mock_redis_client):
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
        assert mock_redis_client.get(lock_key) is not None
        
        # Wait for expiry
        time.sleep(1.1)
        
        # Lock should be expired
        assert mock_redis_client.get(lock_key) is None
    
    def test_lock_release(self, mock_redis_client):
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
        assert mock_redis_client.get(lock_key) is not None
        
        # Release lock
        RedisClient.release_slot_lock(
            ground_id=1,
            date="2025-11-01",
            slot_id=5,
        )
        
        assert mock_redis_client.get(lock_key) is None
    
    def test_slot_status_caching(self, mock_redis_client):
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
    
    def test_unique_id_generation(self, test_user):
        """Test that unique_id is auto-generated."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            ground_id=1,
            slot_id=5,
            date=tomorrow,
        )
        
        assert booking.unique_id is not None
        assert booking.unique_id.startswith("BK")
        assert len(booking.unique_id) > 10
    
    def test_booking_str_representation(self, test_user):
        """Test string representation of booking."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            ground_id=1,
            slot_id=5,
            date=tomorrow,
        )
        
        assert test_user.email in str(booking)
        assert str(tomorrow) in str(booking)
    
    def test_is_active_property(self, test_user):
        """Test is_active property."""
        tomorrow = (timezone.now() + timedelta(days=1)).date()
        
        booking = Booking.objects.create(
            user=test_user,
            ground_id=1,
            slot_id=5,
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
            ground_id=1,
            slot_id=5,
            date=tomorrow,
            status=Booking.STATUS_DONE,
        )
        
        assert future_booking.can_be_cancelled is True
        
        # Past booking cannot be cancelled
        past_booking = Booking.objects.create(
            user=test_user,
            ground_id=1,
            slot_id=6,
            date=yesterday,
            status=Booking.STATUS_DONE,
        )
        
        assert past_booking.can_be_cancelled is False
        
        # Rejected booking cannot be cancelled
        rejected_booking = Booking.objects.create(
            user=test_user,
            ground_id=1,
            slot_id=7,
            date=tomorrow,
            status=Booking.STATUS_REJECTED,
        )
        
        assert rejected_booking.can_be_cancelled is False
