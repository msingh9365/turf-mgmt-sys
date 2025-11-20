"""
Unit tests for booking notifications.
"""
import pytest
from django.contrib.auth import get_user_model
from bookings.models import Booking, Booked_Details, Ground, Sport, Slot
from notifications.models import Notification, UserDevice
from unittest.mock import patch, MagicMock

User = get_user_model()


@pytest.mark.django_db
class TestBookingNotifications:
    """Test that notifications are sent when bookings are created."""
    
    def setup_method(self):
        """Set up test data."""
        self.user = User.objects.create_user(
            email='testuser@example.com',
            password='testpass'
        )
        self.sport = Sport.objects.create(
            sport_name='Football',
            min_player=10
        )
        self.ground = Ground.objects.create(
            ground_name='Test Ground',
            sport=self.sport
        )
        self.device = UserDevice.objects.create(
            user=self.user,
            device_token='test_token_123',
            device_type='android',
            is_active=True
        )
    
    @patch('notifications.utils.messaging.send')
    def test_notification_sent_on_booking_creation(self, mock_send):
        """Test that a notification is sent when a booking is created."""
        mock_send.return_value = 'mock_message_id'
        
        # Create a booking
        booking = Booking.objects.create(
            user=self.user,
            date='2025-11-10',
            status=Booking.STATUS_DONE
        )
        
        # Create booking details
        Booked_Details.objects.create(
            booking=booking,
            ground=self.ground,
            slot_id=1,
            date='2025-11-10',
            player_name='Test Player',
            player_email='test@example.com',
            sort_key='TEST'
        )
        
        # Verify notification was created
        notifications = Notification.objects.filter(user=self.user)
        assert notifications.exists()
        assert 'Booking Confirmed' in notifications.first().title
        assert booking.booking_id in notifications.first().body
    
    @patch('notifications.utils.messaging.send')
    def test_no_notification_for_cancelled_booking(self, mock_send):
        """Test that no notification is sent for cancelled bookings."""
        # Create a rejected booking (no STATUS_CANCELLED constant)
        booking = Booking.objects.create(
            user=self.user,
            date='2025-11-10',
            status=Booking.STATUS_REJECTED
        )
        
        # Verify no notification was created
        notifications = Notification.objects.filter(user=self.user)
        assert not notifications.exists()
    
    @patch('notifications.utils.messaging.send')
    def test_notification_failure_does_not_prevent_booking(self, mock_send):
        """Test that booking creation succeeds even if notification fails."""
        mock_send.side_effect = Exception('FCM error')
        
        # Create a booking (should succeed despite notification error)
        booking = Booking.objects.create(
            user=self.user,
            date='2025-11-10',
            status=Booking.STATUS_DONE
        )
        
        # Verify booking was created
        assert Booking.objects.filter(booking_id=booking.booking_id).exists()
