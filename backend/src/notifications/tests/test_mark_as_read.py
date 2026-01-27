"""Tests for marking notifications as read functionality."""

import pytest
from django.urls import reverse
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from notifications.models import Notification

User = get_user_model()


@pytest.mark.django_db
class TestMarkNotificationAsRead:
    """Test marking a single notification as read."""
    
    def setup_method(self):
        self.client = APIClient()
        self.user = User.objects.create_user(email='testuser@example.com', password='testpass')
        self.other_user = User.objects.create_user(email='otheruser@example.com', password='testpass')
        self.client.force_authenticate(user=self.user)
        
        # Create test notifications
        self.notification1 = Notification.objects.create(
            user=self.user,
            title='Test Notification 1',
            body='This is a test notification',
            is_read=False
        )
        self.notification2 = Notification.objects.create(
            user=self.user,
            title='Test Notification 2',
            body='Another test notification',
            is_read=False
        )
        self.other_notification = Notification.objects.create(
            user=self.other_user,
            title='Other User Notification',
            body='This belongs to another user',
            is_read=False
        )
    
    def test_mark_single_notification_as_read(self):
        """Test marking a single notification as read."""
        url = reverse('mark-notification-read', kwargs={'notification_id': self.notification1.id})
        response = self.client.patch(url)
        
        assert response.status_code == 200
        assert response.data['is_read'] is True
        
        # Verify in database
        self.notification1.refresh_from_db()
        assert self.notification1.is_read is True
        
        # Other notification should remain unread
        self.notification2.refresh_from_db()
        assert self.notification2.is_read is False
    
    def test_mark_already_read_notification(self):
        """Test marking an already read notification (idempotent)."""
        self.notification1.is_read = True
        self.notification1.save()
        
        url = reverse('mark-notification-read', kwargs={'notification_id': self.notification1.id})
        response = self.client.patch(url)
        
        assert response.status_code == 200
        assert response.data['is_read'] is True
    
    def test_mark_nonexistent_notification(self):
        """Test marking a non-existent notification."""
        url = reverse('mark-notification-read', kwargs={'notification_id': 99999})
        response = self.client.patch(url)
        
        assert response.status_code == 404
        assert 'not found' in response.data['detail'].lower()
    
    def test_mark_other_users_notification(self):
        """Test that users cannot mark other users' notifications as read."""
        url = reverse('mark-notification-read', kwargs={'notification_id': self.other_notification.id})
        response = self.client.patch(url)
        
        assert response.status_code == 404
        assert 'not found' in response.data['detail'].lower()
        
        # Verify it's still unread
        self.other_notification.refresh_from_db()
        assert self.other_notification.is_read is False
    
    def test_unauthenticated_user_cannot_mark_as_read(self):
        """Test that unauthenticated users cannot mark notifications as read."""
        self.client.force_authenticate(user=None)
        url = reverse('mark-notification-read', kwargs={'notification_id': self.notification1.id})
        response = self.client.patch(url)
        
        assert response.status_code == 401


@pytest.mark.django_db
class TestMarkAllNotificationsRead:
    """Test marking all notifications as read."""
    
    def setup_method(self):
        self.client = APIClient()
        self.user = User.objects.create_user(email='testuser@example.com', password='testpass')
        self.other_user = User.objects.create_user(email='otheruser@example.com', password='testpass')
        self.client.force_authenticate(user=self.user)
        
        # Create multiple test notifications
        for i in range(5):
            Notification.objects.create(
                user=self.user,
                title=f'Test Notification {i}',
                body=f'Test body {i}',
                is_read=False
            )
        
        # Create one already read notification
        Notification.objects.create(
            user=self.user,
            title='Already Read',
            body='This is already read',
            is_read=True
        )
        
        # Create notifications for other user
        Notification.objects.create(
            user=self.other_user,
            title='Other User Notification',
            body='Should not be affected',
            is_read=False
        )
    
    def test_mark_all_notifications_as_read(self):
        """Test marking all unread notifications as read."""
        url = reverse('mark-all-notifications-read')
        response = self.client.post(url)
        
        assert response.status_code == 200
        assert response.data['count'] == 5
        assert '5 notification(s) marked as read' in response.data['detail']
        
        # Verify all user's notifications are read
        unread_count = Notification.objects.filter(user=self.user, is_read=False).count()
        assert unread_count == 0
        
        total_count = Notification.objects.filter(user=self.user).count()
        assert total_count == 6  # 5 newly marked + 1 already read
    
    def test_mark_all_when_no_unread_notifications(self):
        """Test marking all as read when there are no unread notifications."""
        # Mark all as read first
        Notification.objects.filter(user=self.user).update(is_read=True)
        
        url = reverse('mark-all-notifications-read')
        response = self.client.post(url)
        
        assert response.status_code == 200
        assert response.data['count'] == 0
        assert '0 notification(s) marked as read' in response.data['detail']
    
    def test_mark_all_does_not_affect_other_users(self):
        """Test that marking all as read doesn't affect other users' notifications."""
        url = reverse('mark-all-notifications-read')
        response = self.client.post(url)
        
        assert response.status_code == 200
        
        # Verify other user's notifications are still unread
        other_unread = Notification.objects.filter(user=self.other_user, is_read=False).count()
        assert other_unread == 1
    
    def test_unauthenticated_user_cannot_mark_all_as_read(self):
        """Test that unauthenticated users cannot mark all notifications as read."""
        self.client.force_authenticate(user=None)
        url = reverse('mark-all-notifications-read')
        response = self.client.post(url)
        
        assert response.status_code == 401


@pytest.mark.django_db
class TestUnreadNotificationCount:
    """Test getting unread notification count."""
    
    def setup_method(self):
        self.client = APIClient()
        self.user = User.objects.create_user(email='testuser@example.com', password='testpass')
        self.other_user = User.objects.create_user(email='otheruser@example.com', password='testpass')
        self.client.force_authenticate(user=self.user)
        
        # Create unread notifications
        for i in range(3):
            Notification.objects.create(
                user=self.user,
                title=f'Unread Notification {i}',
                body=f'Test body {i}',
                is_read=False
            )
        
        # Create read notifications
        for i in range(2):
            Notification.objects.create(
                user=self.user,
                title=f'Read Notification {i}',
                body=f'Test body {i}',
                is_read=True
            )
        
        # Create notifications for other user
        Notification.objects.create(
            user=self.other_user,
            title='Other User Notification',
            body='Should not be counted',
            is_read=False
        )
    
    def test_get_unread_count(self):
        """Test getting the correct unread notification count."""
        url = reverse('unread-notification-count')
        response = self.client.get(url)
        
        assert response.status_code == 200
        assert response.data['unread_count'] == 3
    
    def test_get_unread_count_when_all_read(self):
        """Test getting unread count when all notifications are read."""
        Notification.objects.filter(user=self.user).update(is_read=True)
        
        url = reverse('unread-notification-count')
        response = self.client.get(url)
        
        assert response.status_code == 200
        assert response.data['unread_count'] == 0
    
    def test_get_unread_count_when_no_notifications(self):
        """Test getting unread count when user has no notifications."""
        new_user = User.objects.create_user(email='newuser@example.com', password='testpass')
        self.client.force_authenticate(user=new_user)
        
        url = reverse('unread-notification-count')
        response = self.client.get(url)
        
        assert response.status_code == 200
        assert response.data['unread_count'] == 0
    
    def test_unread_count_updates_after_marking_as_read(self):
        """Test that unread count updates after marking notifications as read."""
        url = reverse('unread-notification-count')
        
        # Initial count
        response = self.client.get(url)
        assert response.data['unread_count'] == 3
        
        # Mark one as read
        notification = Notification.objects.filter(user=self.user, is_read=False).first()
        notification.is_read = True
        notification.save()
        
        # Count should decrease
        response = self.client.get(url)
        assert response.data['unread_count'] == 2
    
    def test_unauthenticated_user_cannot_get_unread_count(self):
        """Test that unauthenticated users cannot get unread count."""
        self.client.force_authenticate(user=None)
        url = reverse('unread-notification-count')
        response = self.client.get(url)
        
        assert response.status_code == 401
