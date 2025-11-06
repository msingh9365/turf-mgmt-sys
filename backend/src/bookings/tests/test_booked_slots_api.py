"""
Tests for the booked slots API endpoint.
"""
import pytest
from datetime import date, timedelta
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model

from bookings.models import Ground, Sport, Slot

User = get_user_model()


@pytest.mark.django_db
class TestBookedSlotsAPI:
    """Test cases for GET /api/bookings/booked-slots/ endpoint."""

    @pytest.fixture(autouse=True)
    def setup(self):
        """Set up test data."""
        self.client = APIClient()
        
        # Create test user
        self.user = User.objects.create_user(
            email="test@example.com",
            password="testpass123",
            name="Test User"
        )
        
        # Create sport
        self.sport = Sport.objects.create(
            sport_name="Football",
            min_player=10
        )
        
        # Create ground
        self.ground = Ground.objects.create(
            ground_name="Test Ground",
            sport=self.sport
        )
        
        # Create test date
        self.test_date = date.today() + timedelta(days=1)
        
        # Authenticate client
        self.client.force_authenticate(user=self.user)
    
    def test_get_booked_slots_no_bookings(self):
        """Test endpoint returns empty list when no slots are booked."""
        url = reverse("booking-booked-slots")
        response = self.client.get(url, {
            "date": self.test_date.strftime("%Y-%m-%d"),
            "ground_id": self.ground.ground_id
        })
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data["ground_id"] == self.ground.ground_id
        assert response.data["ground_name"] == self.ground.ground_name
        assert response.data["date"] == self.test_date.strftime("%Y-%m-%d")
        assert response.data["booked_slot_ids"] == []
    
    def test_get_booked_slots_with_bookings(self):
        """Test endpoint returns correct booked slot IDs."""
        # Create some booked slots
        Slot.objects.create(
            slot_id=1,
            ground=self.ground,
            date=self.test_date,
            booked=True
        )
        Slot.objects.create(
            slot_id=3,
            ground=self.ground,
            date=self.test_date,
            booked=True
        )
        Slot.objects.create(
            slot_id=5,
            ground=self.ground,
            date=self.test_date,
            booked=True
        )
        # Create an unbooked slot
        Slot.objects.create(
            slot_id=2,
            ground=self.ground,
            date=self.test_date,
            booked=False
        )
        
        url = reverse("booking-booked-slots")
        response = self.client.get(url, {
            "date": self.test_date.strftime("%Y-%m-%d"),
            "ground_id": self.ground.ground_id
        })
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data["ground_id"] == self.ground.ground_id
        assert response.data["booked_slot_ids"] == [1, 3, 5]
    
    def test_get_booked_slots_different_dates(self):
        """Test endpoint only returns slots for the specified date."""
        # Create slots for different dates
        Slot.objects.create(
            slot_id=1,
            ground=self.ground,
            date=self.test_date,
            booked=True
        )
        Slot.objects.create(
            slot_id=1,
            ground=self.ground,
            date=self.test_date + timedelta(days=1),
            booked=True
        )
        
        url = reverse("booking-booked-slots")
        response = self.client.get(url, {
            "date": self.test_date.strftime("%Y-%m-%d"),
            "ground_id": self.ground.ground_id
        })
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data["booked_slot_ids"] == [1]
    
    def test_get_booked_slots_different_grounds(self):
        """Test endpoint only returns slots for the specified ground."""
        # Create another ground
        ground2 = Ground.objects.create(
            ground_name="Ground 2",
            sport=self.sport
        )
        
        # Create slots for different grounds
        Slot.objects.create(
            slot_id=1,
            ground=self.ground,
            date=self.test_date,
            booked=True
        )
        Slot.objects.create(
            slot_id=2,
            ground=ground2,
            date=self.test_date,
            booked=True
        )
        
        url = reverse("booking-booked-slots")
        response = self.client.get(url, {
            "date": self.test_date.strftime("%Y-%m-%d"),
            "ground_id": self.ground.ground_id
        })
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data["booked_slot_ids"] == [1]
    
    def test_missing_date_parameter(self):
        """Test endpoint returns 400 when date parameter is missing."""
        url = reverse("booking-booked-slots")
        response = self.client.get(url, {
            "ground_id": self.ground.ground_id
        })
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "date" in response.data["error"].lower()
    
    def test_missing_ground_id_parameter(self):
        """Test endpoint returns 400 when ground_id parameter is missing."""
        url = reverse("booking-booked-slots")
        response = self.client.get(url, {
            "date": self.test_date.strftime("%Y-%m-%d")
        })
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "ground_id" in response.data["error"].lower()
    
    def test_invalid_date_format(self):
        """Test endpoint returns 400 for invalid date format."""
        url = reverse("booking-booked-slots")
        response = self.client.get(url, {
            "date": "2024/01/01",  # Wrong format
            "ground_id": self.ground.ground_id
        })
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "date format" in response.data["error"].lower()
    
    def test_invalid_ground_id(self):
        """Test endpoint returns 400 for non-integer ground_id."""
        url = reverse("booking-booked-slots")
        response = self.client.get(url, {
            "date": self.test_date.strftime("%Y-%m-%d"),
            "ground_id": "abc"
        })
        
        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "ground_id" in response.data["error"].lower()
    
    def test_nonexistent_ground(self):
        """Test endpoint returns 404 for non-existent ground."""
        url = reverse("booking-booked-slots")
        response = self.client.get(url, {
            "date": self.test_date.strftime("%Y-%m-%d"),
            "ground_id": 99999
        })
        
        assert response.status_code == status.HTTP_404_NOT_FOUND
        assert "does not exist" in response.data["error"].lower()
    
    def test_unauthenticated_access(self):
        """Test endpoint requires authentication."""
        self.client.force_authenticate(user=None)
        url = reverse("booking-booked-slots")
        response = self.client.get(url, {
            "date": self.test_date.strftime("%Y-%m-%d"),
            "ground_id": self.ground.ground_id
        })
        
        # Should require authentication
        assert response.status_code == status.HTTP_401_UNAUTHORIZED
    
    def test_slots_returned_in_order(self):
        """Test that slot IDs are returned in ascending order."""
        # Create slots in random order
        for slot_id in [10, 3, 7, 1, 5]:
            Slot.objects.create(
                slot_id=slot_id,
                ground=self.ground,
                date=self.test_date,
                booked=True
            )
        
        url = reverse("booking-booked-slots")
        response = self.client.get(url, {
            "date": self.test_date.strftime("%Y-%m-%d"),
            "ground_id": self.ground.ground_id
        })
        
        assert response.status_code == status.HTTP_200_OK
        assert response.data["booked_slot_ids"] == [1, 3, 5, 7, 10]
