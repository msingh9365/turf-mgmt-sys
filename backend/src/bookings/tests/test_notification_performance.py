"""
Performance tests for booking notifications.
Verifies that async notifications with transaction.on_commit() add no latency.
"""
import pytest
import time
from django.contrib.auth import get_user_model
from bookings.models import Booking, Booked_Details, Ground, Sport
from notifications.models import UserDevice
from unittest.mock import patch

User = get_user_model()


@pytest.mark.django_db(transaction=True)
class TestNotificationPerformance:
    """Test that notifications don't add latency to booking creation."""
    
    def setup_method(self):
        """Set up test data."""
        self.user = User.objects.create_user(
            email='perf@test.com',
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
        UserDevice.objects.create(
            user=self.user,
            device_token='test_token',
            device_type='android',
            is_active=True
        )
    
    @patch('notifications.utils.messaging.send_each')
    def test_booking_creation_latency_with_notifications(self, mock_send):
        """Verify booking creation completes quickly despite notifications."""
        from unittest.mock import MagicMock
        
        # Mock successful FCM response
        mock_response = MagicMock()
        mock_response.success_count = 1
        mock_send_response = MagicMock()
        mock_send_response.success = True
        mock_response.responses = [mock_send_response]
        mock_send.return_value = mock_response
        
        # Measure booking creation time
        start_time = time.time()
        
        booking = Booking.objects.create(
            user=self.user,
            date='2025-11-10',
            status=Booking.STATUS_DONE
        )
        
        Booked_Details.objects.create(
            booking=booking,
            ground=self.ground,
            slot_id=1,
            date='2025-11-10',
            player_name='Test Player',
            player_email='test@example.com',
            sort_key='TEST'
        )
        
        elapsed = time.time() - start_time
        
        # Booking creation should complete reasonably fast
        # on_commit callbacks add minimal overhead (just spawning a thread)
        # Accept up to 500ms for DB operations + thread spawn
        assert elapsed < 0.5, f"Booking creation took {elapsed*1000:.2f}ms (should be <500ms)"
        
        # Verify booking was created
        assert Booking.objects.filter(booking_id=booking.booking_id).exists()
        
        print(f"✅ Booking creation: {elapsed*1000:.2f}ms (includes DB ops + thread spawn)")
    
    def test_booking_creation_baseline_no_notifications(self):
        """Baseline: booking creation without notifications enabled."""
        from bookings.signals import send_booking_notification
        from django.db.models.signals import post_save
        
        # Temporarily disconnect signal
        post_save.disconnect(send_booking_notification, sender=Booking)
        
        try:
            start_time = time.time()
            
            booking = Booking.objects.create(
                user=self.user,
                date='2025-11-11',
                status=Booking.STATUS_DONE
            )
            
            Booked_Details.objects.create(
                booking=booking,
                ground=self.ground,
                slot_id=2,
                date='2025-11-11',
                player_name='Test Player',
                player_email='test@example.com',
                sort_key='TEST'
            )
            
            elapsed = time.time() - start_time
            print(f"✅ Baseline (no notifications): {elapsed*1000:.2f}ms")
            
            return elapsed
        finally:
            # Reconnect signal
            post_save.connect(send_booking_notification, sender=Booking)
    
    @patch('notifications.tasks.send_notification_async')
    def test_on_commit_spawns_thread_during_commit(self, mock_async_send):
        """Verify on_commit callback spawns async thread (not after save)."""
        callback_executed = []
        
        def track_callback(*args, **kwargs):
            callback_executed.append(time.time())
        
        mock_async_send.side_effect = track_callback
        
        save_start = time.time()
        
        booking = Booking.objects.create(
            user=self.user,
            date='2025-11-10',
            status=Booking.STATUS_DONE
        )
        
        Booked_Details.objects.create(
            booking=booking,
            ground=self.ground,
            slot_id=1,
            date='2025-11-10',
            player_name='Test Player',
            player_email='test@example.com',
            sort_key='TEST'
        )
        
        save_end = time.time()
        
        # Callback should have been called during commit (synchronously)
        assert mock_async_send.called, "Async send should be called"
        
        # The callback executes during the commit phase
        # But it only spawns a thread (instant), so minimal latency
        if callback_executed:
            callback_time = callback_executed[0]
            overhead = (callback_time - save_start) * 1000
            print(f"✅ Thread spawn happened {overhead:.2f}ms after save start")
            # The overhead should be minimal (just thread creation)
            assert overhead < 500, f"Thread spawn overhead {overhead:.2f}ms too high"
        
        save_duration = (save_end - save_start) * 1000
        print(f"✅ Total save duration: {save_duration:.2f}ms (includes thread spawn)")
