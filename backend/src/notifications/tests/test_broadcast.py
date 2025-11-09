"""
Unit tests for broadcast looking for players API.
Tests cover:
- Single and multiple slot broadcasts
- Merged time range formatting
- Slot validation removal (slots don't need to exist in DB)
- Error handling for missing fields and invalid data
"""
import pytest
from django.urls import reverse
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from bookings.models import Sport, Ground, Slot
from notifications.models import UserDevice, Notification
from unittest.mock import patch, MagicMock

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
        self.user3 = User.objects.create_user(
            email='player3@example.com',
            password='testpass'
        )
        
        # Create sports
        self.football = Sport.objects.create(
            sport_name='Football',
            min_player=10
        )
        self.cricket = Sport.objects.create(
            sport_name='Cricket',
            min_player=11
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
        UserDevice.objects.create(
            user=self.user3,
            device_token='token3',
            device_type='ios',
            is_active=True
        )
        
        self.client.force_authenticate(user=self.user1)
    
    @patch('notifications.utils.messaging.send')
    def test_single_slot_broadcast_success(self, mock_send):
        """Test successful broadcast with a single slot."""
        mock_send.return_value = 'mock_message_id'
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_id': 1  # 00:00 - 00:30
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 200
        assert 'Broadcast notification sent successfully' in response.data['detail']
        assert response.data['sport'] == 'Football'
        assert response.data['date'] == '2025-11-15'
        assert 'slot_time' in response.data
        assert 'slot_times' in response.data
        # Verify merged time range format for single slot
        assert response.data['slot_time'] == '00:00 - 00:30'
        assert response.data['slot_times'] == ['00:00']
        
        # Verify slot_id is NOT in response (as per requirement)
        assert 'slot_id' not in response.data
        assert 'slot_ids' not in response.data
        
        # Verify notifications were created for other users (not sender)
        notifications = Notification.objects.filter(user=self.user2)
        assert notifications.count() >= 1
        notification = notifications.first()
        assert 'Football' in notification.title
        assert 'player1@example.com' in notification.body
        assert '00:00 - 00:30' in notification.body
    
    @patch('notifications.utils.messaging.send')
    def test_multiple_continuous_slots_merged_range(self, mock_send):
        """Test broadcast with continuous slots showing merged time range."""
        mock_send.return_value = 'mock_message_id'
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_ids': [1, 2, 3]  # 00:00, 00:30, 01:00 -> merged to 00:00 - 01:30
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 200
        # Verify merged time range
        assert response.data['slot_time'] == '00:00 - 01:30'
        assert response.data['slot_times'] == ['00:00', '00:30', '01:00']
        assert '00:00 - 01:30' in Notification.objects.first().body
    
    @patch('notifications.utils.messaging.send')
    def test_multiple_non_continuous_slots_separate_ranges(self, mock_send):
        """Test broadcast with non-continuous slots showing separate ranges."""
        mock_send.return_value = 'mock_message_id'
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_ids': [1, 2, 5, 6, 10]  # Two ranges + one slot
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 200
        # Verify separate ranges are comma-separated
        slot_time = response.data['slot_time']
        assert '00:00 - 01:00' in slot_time  # slots 1-2
        assert '02:00 - 03:00' in slot_time  # slots 5-6
        assert '04:30 - 05:00' in slot_time  # slot 10
        assert slot_time.count(',') == 2  # Two commas separating three ranges
    
    @patch('notifications.utils.messaging.send')
    def test_slot_ids_as_comma_separated_string(self, mock_send):
        """Test accepting slot_ids as comma-separated string."""
        mock_send.return_value = 'mock_message_id'
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_ids': "1,2,3"  # String format
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 200
        assert response.data['slot_time'] == '00:00 - 01:30'
    
    @patch('notifications.utils.messaging.send')
    def test_mixed_slot_id_and_slot_ids(self, mock_send):
        """Test accepting both slot_id and slot_ids together."""
        mock_send.return_value = 'mock_message_id'
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_id': 1,
            'slot_ids': [2, 3]
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 200
        # Should merge all slots: 1, 2, 3
        assert response.data['slot_time'] == '00:00 - 01:30'
    
    @patch('notifications.utils.messaging.send')
    def test_duplicate_slot_ids_are_deduplicated(self, mock_send):
        """Test that duplicate slot IDs are handled correctly."""
        mock_send.return_value = 'mock_message_id'
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_ids': [1, 2, 2, 3, 1]  # Duplicates
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 200
        assert response.data['slot_time'] == '00:00 - 01:30'
        assert len(response.data['slot_times']) == 3  # Deduplicated
    
    @patch('notifications.utils.messaging.send')
    def test_no_slot_validation_required(self, mock_send):
        """Test that slots don't need to exist in DB (key requirement)."""
        mock_send.return_value = 'mock_message_id'
        
        # Don't create any Slot objects in DB
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_id': 999  # Non-existent slot ID
        }
        
        response = self.client.post(url, data, format='json')
        
        # Should succeed without checking slot existence
        assert response.status_code == 200
        assert response.data['slot_time'] == '499:00 - 499:30'  # Still formats time
    
    @patch('notifications.utils.messaging.send')
    def test_notification_payload_structure(self, mock_send):
        """Test that notification data payload has correct structure."""
        mock_send.return_value = 'mock_message_id'
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_ids': [1, 2, 3]
        }
        
        response = self.client.post(url, data, format='json')
        
        # Capture the notification data sent
        notification = Notification.objects.first()
        payload = notification.data
        
        # Verify payload structure
        assert payload['type'] == 'looking_for_players'
        assert payload['sport_id'] == str(self.football.sport_id)
        assert payload['sport_name'] == 'Football'
        assert payload['date'] == '2025-11-15'
        assert payload['slot_time'] == '00:00 - 01:30'
        assert payload['slot_times'] == ['00:00', '00:30', '01:00']
        assert payload['user_name'] is not None
        assert payload['user_email'] == 'player1@example.com'
        
        # Verify slot_id and slot_ids are NOT in payload
        assert 'slot_id' not in payload
        assert 'slot_ids' not in payload
    
    @patch('notifications.utils.messaging.send')
    def test_sender_excluded_from_broadcast(self, mock_send):
        """Test that sender doesn't receive their own broadcast."""
        mock_send.return_value = 'mock_message_id'
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_id': 1
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 200
        
        # Verify sender (user1) didn't receive notification
        sender_notifications = Notification.objects.filter(user=self.user1)
        assert sender_notifications.count() == 0
        
        # Verify other users received notification
        other_notifications = Notification.objects.filter(user=self.user2)
        assert other_notifications.count() >= 1
    
    def test_missing_sport_id(self):
        """Test error when sport_id is missing."""
        url = reverse('broadcast-looking-for-players')
        data = {
            'date': '2025-11-15',
            'slot_id': 1
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 400
        assert 'required' in response.data['detail'].lower()
    
    def test_missing_date(self):
        """Test error when date is missing."""
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'slot_id': 1
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 400
        assert 'required' in response.data['detail'].lower()
    
    def test_missing_slot_info(self):
        """Test error when both slot_id and slot_ids are missing."""
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15'
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 400
        assert 'required' in response.data['detail'].lower()
    
    def test_invalid_sport_id(self):
        """Test error when sport doesn't exist."""
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': 9999,
            'date': '2025-11-15',
            'slot_id': 1
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 404
        assert 'Sport not found' in response.data['detail']
    
    def test_invalid_slot_id_format(self):
        """Test error when slot_id is not a valid integer."""
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_id': 'invalid'
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 400
        assert 'Invalid slot id' in response.data['detail']
    
    def test_invalid_slot_ids_format(self):
        """Test error when slot_ids has invalid format."""
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_ids': {'invalid': 'dict'}  # Should be list or string
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 400
        assert 'must be a list or comma-separated string' in response.data['detail']
    
    def test_requires_authentication(self):
        """Test that broadcast requires authentication."""
        self.client.force_authenticate(user=None)
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_id': 1
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 401
    
    @patch('notifications.utils.messaging.send')
    def test_recipient_count_accuracy(self, mock_send):
        """Test that recipient count is accurate."""
        mock_send.return_value = 'mock_message_id'
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_id': 1
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 200
        # Should send to user2 and user3 (not user1 who is sender)
        assert response.data['recipients'] == 2
    
    @patch('notifications.utils.messaging.send')
    def test_edge_case_slot_48(self, mock_send):
        """Test edge case with slot 48 (last slot of day: 23:30 - 24:00)."""
        mock_send.return_value = 'mock_message_id'
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_id': 48
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 200
        assert response.data['slot_time'] == '23:30 - 24:00'
    
    @patch('notifications.utils.messaging.send')
    def test_unordered_slot_ids_are_sorted(self, mock_send):
        """Test that slot IDs are sorted before processing."""
        mock_send.return_value = 'mock_message_id'
        
        url = reverse('broadcast-looking-for-players')
        data = {
            'sport_id': self.football.sport_id,
            'date': '2025-11-15',
            'slot_ids': [3, 1, 2]  # Unordered
        }
        
        response = self.client.post(url, data, format='json')
        
        assert response.status_code == 200
        # Should still merge correctly after sorting
        assert response.data['slot_time'] == '00:00 - 01:30'
        assert response.data['slot_times'] == ['00:00', '00:30', '01:00']
