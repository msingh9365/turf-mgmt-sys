"""Tests for sport-based filtering in broadcast looking-for-players notifications.

Focus areas:
1. Users with matching sport interest receive notifications
2. Users without any sport interest don't receive notifications
3. Users with different sport interest are excluded
4. Backward compatibility when sport_filter is None (broadcast to all)
5. Invalid sport_id handling (falls back to no filter)
6. Zero recipients scenario (no users interested in sport)
7. Performance monitoring logs
"""

import pytest
import time
from django.urls import reverse
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from bookings.models import Sport
from notifications.models import UserDevice, Notification
from profile_app.models import Profile
from unittest.mock import patch

User = get_user_model()


@pytest.mark.django_db(transaction=True)
class TestSportFilteredBroadcast:
    def setup_method(self):
        from unittest.mock import MagicMock
        self.client = APIClient()

        # Users
        self.user1 = User.objects.create_user(email='player1@example.com', password='testpass')
        self.user2 = User.objects.create_user(email='player2@example.com', password='testpass')
        self.user3 = User.objects.create_user(email='player3@example.com', password='testpass')
        self.user4 = User.objects.create_user(email='player4@example.com', password='testpass')

        # Sports
        self.football = Sport.objects.create(sport_name='Football', min_player=10)
        self.cricket = Sport.objects.create(sport_name='Cricket', min_player=11)
        self.basketball = Sport.objects.create(sport_name='Basketball', min_player=5)

        # Setup sport interests
        # user1: interested in Football (sender - will be excluded)
        # user2: interested in Football (should receive)
        # user3: interested in Cricket (should NOT receive)
        # user4: no sport interests (should NOT receive)
        
        self.user1.profile.interested_sports.add(self.football)
        self.user2.profile.interested_sports.add(self.football)
        self.user3.profile.interested_sports.add(self.cricket)
        # user4 has no interested sports

        # Devices
        UserDevice.objects.create(user=self.user1, device_token='token1', device_type='android', is_active=True)
        UserDevice.objects.create(user=self.user2, device_token='token2', device_type='android', is_active=True)
        UserDevice.objects.create(user=self.user3, device_token='token3', device_type='ios', is_active=True)
        UserDevice.objects.create(user=self.user4, device_token='token4', device_type='android', is_active=True)

        self.client.force_authenticate(user=self.user1)
    
    def _mock_batch_success(self, count):
        """Helper to create a successful batch response mock"""
        from unittest.mock import MagicMock
        mock_response = MagicMock()
        mock_response.success_count = count
        mock_send_response = MagicMock()
        mock_send_response.success = True
        mock_response.responses = [mock_send_response] * count
        return mock_response

    @patch('notifications.utils.messaging.send_each')
    def test_only_interested_users_receive_football_notification(self, mock_send):
        """Test that only users interested in Football receive the notification"""
        mock_send.return_value = self._mock_batch_success(1)
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}

        response = self.client.post(url, data, format='json')

        assert response.status_code == 202
        time.sleep(1.5)
        
        # Only user2 should receive (user1 is sender, user3 likes Cricket, user4 has no interests)
        assert Notification.objects.filter(user=self.user1).count() == 0  # Sender excluded
        assert Notification.objects.filter(user=self.user2).count() == 1  # Interested in Football
        assert Notification.objects.filter(user=self.user3).count() == 0  # Interested in Cricket only
        assert Notification.objects.filter(user=self.user4).count() == 0  # No sport interests

    @patch('notifications.utils.messaging.send_each')
    def test_users_without_sport_interest_dont_receive(self, mock_send):
        """Test that users with no sport interests don't receive any notifications"""
        mock_send.return_value = self._mock_batch_success(1)
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}

        response = self.client.post(url, data, format='json')

        assert response.status_code == 202
        time.sleep(1.5)
        
        # user4 has no interested_sports, should not receive
        assert Notification.objects.filter(user=self.user4).count() == 0

    @patch('notifications.utils.messaging.send_each')
    def test_users_with_different_sport_interest_excluded(self, mock_send):
        """Test that users interested in different sports are excluded"""
        mock_send.return_value = self._mock_batch_success(1)
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}

        response = self.client.post(url, data, format='json')

        assert response.status_code == 202
        time.sleep(1.5)
        
        # user3 only interested in Cricket, not Football
        assert Notification.objects.filter(user=self.user3).count() == 0

    @patch('notifications.utils.messaging.send_each')
    def test_users_with_multiple_sport_interests(self, mock_send):
        """Test that users interested in multiple sports including the target sport receive notification"""
        # user3 now interested in both Cricket and Football
        self.user3.profile.interested_sports.add(self.football)
        
        mock_send.return_value = self._mock_batch_success(2)
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}

        response = self.client.post(url, data, format='json')

        assert response.status_code == 202
        time.sleep(1.5)
        
        # user2 and user3 should receive (both interested in Football)
        assert Notification.objects.filter(user=self.user2).count() == 1
        assert Notification.objects.filter(user=self.user3).count() == 1

    @patch('notifications.utils.messaging.send_each')
    def test_zero_recipients_for_unpopular_sport(self, mock_send):
        """Test zero recipients scenario when no users are interested in the sport"""
        # Basketball has no interested users
        mock_send.return_value = self._mock_batch_success(0)
        
        self.client.force_authenticate(user=self.user2)  # Change sender to user2
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.basketball.sport_id, 'date': '2025-11-15', 'slot_id': 1}

        response = self.client.post(url, data, format='json')

        assert response.status_code == 202
        time.sleep(1.5)
        
        # No notifications should be created (no users interested in Basketball)
        assert Notification.objects.count() == 0

    @patch('notifications.utils.messaging.send_each')
    def test_notification_payload_contains_sport_info(self, mock_send):
        """Test that the notification payload contains correct sport information"""
        mock_send.return_value = self._mock_batch_success(1)
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}

        response = self.client.post(url, data, format='json')

        assert response.status_code == 202
        time.sleep(1.5)
        
        notification = Notification.objects.filter(user=self.user2).first()
        assert notification is not None
        payload = notification.data
        assert payload['type'] == 'looking_for_players'
        assert payload['sport_id'] == str(self.football.sport_id)
        assert payload['sport_name'] == 'Football'

    @patch('notifications.utils.messaging.send_each')
    def test_sender_excluded_even_with_sport_filter(self, mock_send):
        """Test that sender is always excluded even when they match sport interest"""
        mock_send.return_value = self._mock_batch_success(1)
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}

        response = self.client.post(url, data, format='json')

        assert response.status_code == 202
        time.sleep(1.5)
        
        # user1 is sender and interested in Football, but should not receive
        assert Notification.objects.filter(user=self.user1).count() == 0

    @patch('notifications.utils.messaging.send_each')
    def test_multiple_devices_per_user_sport_filtered(self, mock_send):
        """Test that sport filtering works correctly when user has multiple devices"""
        # Add second device for user2
        UserDevice.objects.create(user=self.user2, device_token='token2_second', device_type='ios', is_active=True)
        
        mock_send.return_value = self._mock_batch_success(2)
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}

        response = self.client.post(url, data, format='json')

        assert response.status_code == 202
        time.sleep(1.5)
        
        # user2 should have exactly 1 notification (not 2, even with 2 devices)
        assert Notification.objects.filter(user=self.user2).count() == 1

    @patch('notifications.utils.messaging.send_each')
    def test_inactive_devices_excluded_with_sport_filter(self, mock_send):
        """Test that inactive devices are excluded even when user matches sport interest"""
        # Deactivate user2's device
        UserDevice.objects.filter(user=self.user2).update(is_active=False)
        
        mock_send.return_value = self._mock_batch_success(0)
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}

        response = self.client.post(url, data, format='json')

        assert response.status_code == 202
        time.sleep(1.5)
        
        # user2 interested in Football but has no active devices
        assert Notification.objects.filter(user=self.user2).count() == 0


@pytest.mark.django_db(transaction=True)
class TestBackwardCompatibility:
    """Test backward compatibility when sport_filter is None"""
    
    def setup_method(self):
        from unittest.mock import MagicMock
        from notifications.utils import FCMNotificationSender
        self.sender = FCMNotificationSender()

        # Users
        self.user1 = User.objects.create_user(email='player1@example.com', password='testpass')
        self.user2 = User.objects.create_user(email='player2@example.com', password='testpass')
        self.user3 = User.objects.create_user(email='player3@example.com', password='testpass')

        # Sport
        self.football = Sport.objects.create(sport_name='Football', min_player=10)
        
        # Only user2 interested in Football
        self.user2.profile.interested_sports.add(self.football)

        # Devices
        UserDevice.objects.create(user=self.user1, device_token='token1', device_type='android', is_active=True)
        UserDevice.objects.create(user=self.user2, device_token='token2', device_type='android', is_active=True)
        UserDevice.objects.create(user=self.user3, device_token='token3', device_type='ios', is_active=True)

    def _mock_batch_success(self, count):
        """Helper to create a successful batch response mock"""
        from unittest.mock import MagicMock
        mock_response = MagicMock()
        mock_response.success_count = count
        mock_send_response = MagicMock()
        mock_send_response.success = True
        mock_response.responses = [mock_send_response] * count
        return mock_response

    @patch('notifications.utils.messaging.send_each')
    def test_broadcast_without_sport_filter_reaches_all_users(self, mock_send):
        """Test that broadcast without sport_filter reaches all users (backward compatible)"""
        mock_send.return_value = self._mock_batch_success(3)
        
        # Call broadcast without sport_filter
        self.sender.broadcast(
            title="Test Notification",
            body="Test body",
            data=None,
            exclude_user=None,
            sport_filter=None
        )
        
        time.sleep(0.5)
        
        # All users should receive
        assert Notification.objects.filter(user=self.user1).count() == 1
        assert Notification.objects.filter(user=self.user2).count() == 1
        assert Notification.objects.filter(user=self.user3).count() == 1

    @patch('notifications.utils.messaging.send_each')
    def test_broadcast_with_sport_filter_only_reaches_interested_users(self, mock_send):
        """Test that broadcast with sport_filter only reaches interested users"""
        mock_send.return_value = self._mock_batch_success(1)
        
        # Call broadcast with sport_filter
        self.sender.broadcast(
            title="Football Notification",
            body="Looking for Football players",
            data={'sport_id': str(self.football.sport_id)},
            exclude_user=None,
            sport_filter=self.football.sport_id
        )
        
        time.sleep(0.5)
        
        # Only user2 (interested in Football) should receive
        assert Notification.objects.filter(user=self.user1).count() == 0
        assert Notification.objects.filter(user=self.user2).count() == 1
        assert Notification.objects.filter(user=self.user3).count() == 0


@pytest.mark.django_db(transaction=True)
class TestInvalidSportIdHandling:
    """Test handling of invalid sport_id in data payload"""
    
    def setup_method(self):
        from unittest.mock import MagicMock
        self.client = APIClient()

        # Users
        self.user1 = User.objects.create_user(email='player1@example.com', password='testpass')
        self.user2 = User.objects.create_user(email='player2@example.com', password='testpass')

        # Sport
        self.football = Sport.objects.create(sport_name='Football', min_player=10)

        # Devices
        UserDevice.objects.create(user=self.user1, device_token='token1', device_type='android', is_active=True)
        UserDevice.objects.create(user=self.user2, device_token='token2', device_type='android', is_active=True)

        self.client.force_authenticate(user=self.user1)

    @patch('notifications.utils.messaging.send_each')
    def test_valid_sport_id_in_endpoint(self, mock_send):
        """Test that valid sport_id works correctly"""
        self.user2.profile.interested_sports.add(self.football)
        
        mock_send.return_value = self._mock_batch_success(1)
        url = reverse('broadcast-looking-for-players')
        data = {'sport_id': self.football.sport_id, 'date': '2025-11-15', 'slot_id': 1}

        response = self.client.post(url, data, format='json')

        assert response.status_code == 202
        time.sleep(1.5)
        
        # user2 should receive
        assert Notification.objects.filter(user=self.user2).count() == 1

    def _mock_batch_success(self, count):
        """Helper to create a successful batch response mock"""
        from unittest.mock import MagicMock
        mock_response = MagicMock()
        mock_response.success_count = count
        mock_send_response = MagicMock()
        mock_send_response.success = True
        mock_response.responses = [mock_send_response] * count
        return mock_response

    @patch('notifications.utils.messaging.send_each')
    @patch('notifications.tasks.logger')
    def test_invalid_sport_id_logs_warning_and_broadcasts_to_all(self, mock_logger, mock_send):
        """Test that invalid sport_id in data payload logs warning and falls back to broadcast all"""
        from notifications.tasks import broadcast_notification_async
        
        mock_send.return_value = self._mock_batch_success(1)
        
        # Manually call with invalid sport_id in data
        broadcast_notification_async(
            title="Test",
            body="Test body",
            data={'sport_id': 'invalid_string'},
            exclude_user_id=self.user1.id
        )
        
        time.sleep(1.5)
        
        # Should log warning about invalid sport_id
        warning_calls = [call for call in mock_logger.warning.call_args_list 
                        if 'Invalid sport_id' in str(call)]
        assert len(warning_calls) > 0
        
        # Should still broadcast to all (fallback behavior)
        assert Notification.objects.filter(user=self.user2).count() == 1
