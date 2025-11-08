"""
Unit tests for broadcast looking for players API.
"""
import pytest
from django.urls import reverse
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from bookings.models import Sport, Ground, Slot
from notifications.models import UserDevice, Notification
from unittest.mock import patch

User = get_user_model()


@pytest.mark.django_db
class TestBroadcastLookingForPlayers:
    """Test broadcast looking for players functionality."""
    
    def setup_method(self):
        """Set up test data."""
        self.client = APIClient()
        
        # Create test users
        self.user1 = User.objects.create_user(
            email='player1@example.com',
            password='testpass'
        )
        self.user2 = User.objects.create_user(
            email='player2@example.com',
            password='testpass'
        )
        
        # Create sport
        self.sport = Sport.objects.create(
            sport_name='Football',
            min_player=10
        )
        
        # Create ground
        self.ground = Ground.objects.create(
            ground_name='Test Ground',
            sport=self.sport
        )
        
        # Create slot
        self.slot = Slot.objects.create(
            slot_id=10,  # 04:30 - 05:00
            ground=self.ground,
            price=100
        )
        
        # Register devices for users
        UserDevice.objects.create(
            user=self.user1,
            device_token='token1',
            device_type='android',
            is_active=True
        )
        UserDevice.objects.create(
            user=self.user2,
            device_token='token2',
            device_type='android',
            is_active=True
        )
        
        self.client.force_authenticate(user=self.user1)
    
    @patch('notifications.utils.messaging.send')
    def test_broadcast_looking_for_players_success(self, mock_send):
        """Test successful broadcast for looking for players."""
        mock_send.return_value = 'mock_message_id'
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.sport.sport_id,
            'date': '2025-11-15',
            'slot_id': self.slot.slot_id
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 200
        assert 'Broadcast notification sent successfully' in response.data['detail']
        assert response.data['sport'] == 'Football'
        assert response.data['date'] == '2025-11-15'
        assert 'slot_time' in response.data
        
        # Verify notifications were created
        notifications = Notification.objects.all()
        assert notifications.count() >= 1
    
    def test_broadcast_missing_fields(self):
        """Test broadcast with missing required fields."""
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.sport.sport_id,
            # Missing date and slot_id
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 400
        assert 'required' in response.data['detail'].lower()
    
    def test_broadcast_invalid_sport(self):
        """Test broadcast with non-existent sport."""
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': 9999,
            'date': '2025-11-15',
            'slot_id': self.slot.slot_id
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 404
        assert 'Sport not found' in response.data['detail']
    
    def test_broadcast_invalid_slot(self):
        """Test broadcast with non-existent slot."""
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.sport.sport_id,
            'date': '2025-11-15',
            'slot_id': 9999
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 404
        assert 'Slot not found' in response.data['detail']
    
    def test_broadcast_requires_authentication(self):
        """Test that broadcast requires authentication."""
        self.client.force_authenticate(user=None)
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.sport.sport_id,
            'date': '2025-11-15',
            'slot_id': self.slot.slot_id
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 401
