"""Comprehensive tests for the broadcast looking-for-players endpoint.

Focus areas:
1. Single vs multiple slot handling
2. Merged contiguous time range formatting
3. Non-contiguous range formatting
4. Input normalization (list, comma-separated string, mixed slot_id + slot_ids)
5. Deduplication + sorting of slot IDs
6. No slot existence validation (out-of-range slot labels)
7. Payload structure & sender exclusion
8. Error handling for missing/invalid inputs
9. Edge cases (first slot, last slot, out-of-range slot)
"""

import pytest
from django.urls import reverse
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from bookings.models import Sport
from notifications.models import UserDevice, Notification
from unittest.mock import patch

User = get_user_model()


@pytest.mark.django_db
class TestBroadcastLookingForPlayers:
    def setup_method(self):
        self.client = APIClient()

        # Users
        self.user1 = User.objects.create_user(email='player1@example.com', password='testpass')
        self.user2 = User.objects.create_user(email='player2@example.com', password='testpass')
        self.user3 = User.objects.create_user(email='player3@example.com', password='testpass')

        # Sports
        self.football = Sport.objects.create(sport_name='Football', min_player=10)
        self.cricket = Sport.objects.create(sport_name='Cricket', min_player=11)

        # Devices
        UserDevice.objects.create(user=self.user1, device_token='token1', device_type='android', is_active=True)
        UserDevice.objects.create(user=self.user2, device_token='token2', device_type='android', is_active=True)
        UserDevice.objects.create(user=self.user3, device_token='token3', device_type='ios', is_active=True)

        self.client.force_authenticate(user=self.user1)

    @patch('notifications.utils.messaging.send')
    def test_single_slot_broadcast_success(self, mock_send):
        mock_send.return_value = 'mock_message_id'
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}

        response = self.client.post(url, data, format='json')

        assert response.status_code == 200
        assert 'Broadcast notification sent successfully' in response.data['detail']
        assert response.data['sport'] == 'Football'
        assert response.data['date'] == '2025-11-15'
        assert response.data['slot_time'] == '8:00 AM - 8:30 AM'
        assert response.data['slot_times'] == ['8:00 AM']
        assert 'slot_id' not in response.data and 'slot_ids' not in response.data

        # Notification recorded for other users
        notif = Notification.objects.filter(user=self.user2).first()
        assert notif is not None
        assert 'Football' in notif.title
        assert '8:00 AM - 8:30 AM' in notif.body

    @patch('notifications.utils.messaging.send')
    def test_multiple_continuous_slots_merged_range(self, mock_send):
        mock_send.return_value = 'mock_message_id'
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_ids': [1, 2, 3]}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 200
        assert response.data['slot_time'] == '8:00 AM - 9:30 AM'
        assert response.data['slot_times'] == ['8:00 AM', '8:30 AM', '9:00 AM']
        assert '8:00 AM - 9:30 AM' in Notification.objects.first().body

    @patch('notifications.utils.messaging.send')
    def test_multiple_non_continuous_slots_separate_ranges(self, mock_send):
        mock_send.return_value = 'mock_message_id'
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_ids': [1, 2, 5, 6, 10]}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 200
        slot_time = response.data['slot_time']
        assert '8:00 AM - 9:00 AM' in slot_time  # slots 1-2
        assert '10:00 AM - 11:00 AM' in slot_time  # slots 5-6
        assert '12:30 PM - 1:00 PM' in slot_time  # slot 10
        # Three ranges -> two commas
        assert slot_time.count(',') == 2

    @patch('notifications.utils.messaging.send')
    def test_slot_ids_as_comma_separated_string(self, mock_send):
        mock_send.return_value = 'mock_message_id'
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_ids': '1,2,3'}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 200
        assert response.data['slot_time'] == '8:00 AM - 9:30 AM'

    @patch('notifications.utils.messaging.send')
    def test_mixed_slot_id_and_slot_ids(self, mock_send):
        mock_send.return_value = 'mock_message_id'
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1, 'slot_ids': [2, 3]}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 200
        assert response.data['slot_time'] == '8:00 AM - 9:30 AM'

    @patch('notifications.utils.messaging.send')
    def test_duplicate_slot_ids_are_deduplicated(self, mock_send):
        mock_send.return_value = 'mock_message_id'
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_ids': [1, 2, 2, 3, 1]}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 200
        assert response.data['slot_time'] == '8:00 AM - 9:30 AM'
        assert len(response.data['slot_times']) == 3

    @patch('notifications.utils.messaging.send')
    def test_no_slot_validation_required(self, mock_send):
        mock_send.return_value = 'mock_message_id'
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 999}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 200
        assert response.data['slot_time'] == 'Slot 999 - Slot 999'

    @patch('notifications.utils.messaging.send')
    def test_notification_payload_structure(self, mock_send):
        mock_send.return_value = 'mock_message_id'
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_ids': [1, 2, 3]}
        response = self.client.post(url, data, format='json')
        notification = Notification.objects.first()
        payload = notification.data
        assert payload['type'] == 'looking_for_players'
        assert payload['sport_id'] == str(self.football.sport_id)
        assert payload['sport_name'] == 'Football'
        assert payload['date'] == '2025-11-15'
        assert payload['slot_time'] == '8:00 AM - 9:30 AM'
        assert payload['slot_times'] == ['8:00 AM', '8:30 AM', '9:00 AM']
        assert payload['user_name'] is not None
        assert payload['user_email'] == 'player1@example.com'
        assert 'slot_id' not in payload and 'slot_ids' not in payload

    @patch('notifications.utils.messaging.send')
    def test_sender_excluded_from_broadcast(self, mock_send):
        mock_send.return_value = 'mock_message_id'
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 200
        assert Notification.objects.filter(user=self.user1).count() == 0
        assert Notification.objects.filter(user=self.user2).count() >= 1

    def test_missing_sport_id(self):
        url = reverse('broadcast-looking-for-players')
        data = {'date': '2025-11-15', 'slot_id': 1}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 400
        assert 'required' in response.data['detail'].lower()

    def test_missing_date(self):
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'slot_id': 1}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 400
        assert 'required' in response.data['detail'].lower()

    def test_missing_slot_info(self):
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15'}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 400
        assert 'required' in response.data['detail'].lower()

    def test_invalid_sport_id(self):
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': 9999, 'date': '2025-11-15', 'slot_id': 1}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 404
        assert 'Sport not found' in response.data['detail']

    def test_invalid_slot_id_format(self):
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 'invalid'}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 400
        assert 'Invalid slot id' in response.data['detail']

    def test_invalid_slot_ids_format(self):
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_ids': {'bad': 'dict'}}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 400
        assert 'must be a list or comma-separated string' in response.data['detail']

    def test_requires_authentication(self):
        self.client.force_authenticate(user=None)
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 401

    @patch('notifications.utils.messaging.send')
    def test_recipient_count_accuracy(self, mock_send):
        mock_send.return_value = 'mock_message_id'
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 200
        assert response.data['recipients'] == 2  # user2 + user3

    @patch('notifications.utils.messaging.send')
    def test_edge_case_last_slot_28(self, mock_send):
        mock_send.return_value = 'mock_message_id'
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 28}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 200
        assert response.data['slot_time'] == '9:30 PM - 10:00 PM'

    @patch('notifications.utils.messaging.send')
    def test_unordered_slot_ids_are_sorted(self, mock_send):
        mock_send.return_value = 'mock_message_id'
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_ids': [3, 1, 2]}
        response = self.client.post(url, data, format='json')
        assert response.status_code == 200
        assert response.data['slot_time'] == '8:00 AM - 9:30 AM'
        assert response.data['slot_times'] == ['8:00 AM', '8:30 AM', '9:00 AM']

    @patch('notifications.utils.messaging.send')
    def test_failed_token_deactivation_and_reporting(self, mock_send):
        from firebase_admin import messaging

        def _raise_unregistered(message):  # message param ignored; FCM constructs internally
            raise messaging.UnregisteredError("Requested entity was not found.")

        mock_send.side_effect = _raise_unregistered

        # Add an extra stale token for user2
        from notifications.models import UserDevice
        UserDevice.objects.create(user=self.user2, device_token='stale_token', device_type='android', is_active=True)

        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}
        response = self.client.post(url, data, format='json')

        assert response.status_code == 200
        # All sends failed -> recipients should be 0
        assert response.data['recipients'] == 0
        assert 'failed_tokens' in response.data
        assert 'stale_token' in response.data['failed_tokens']

        # Token should now be inactive
        stale = UserDevice.objects.get(device_token='stale_token')
        assert stale.is_active is False
