import pytest
from django.urls import reverse
from rest_framework.test import APIClient
from django.contrib.auth import get_user_model
from notifications.models import UserDevice, Notification

@pytest.mark.django_db
class TestNotificationAPI:
    def setup_method(self):
        self.client = APIClient()
        User = get_user_model()
        self.user = User.objects.create_user(email='testuser@example.com', password='testpass')
        self.client.force_authenticate(user=self.user)

    def test_register_device(self):
        url = reverse('register-device')
        data = {'device_token': 'abc123', 'device_type': 'android'}
        response = self.client.post(url, data)
        assert response.status_code == 201
        assert UserDevice.objects.filter(user=self.user, device_token='abc123').exists()

    def test_send_notification(self):
        UserDevice.objects.create(user=self.user, device_token='abc123', device_type='android')
        url = reverse('send-notification')
        data = {'title': 'Test', 'body': 'Hello', 'user_id': self.user.id}
        response = self.client.post(url, data)
        assert response.status_code == 200
        assert Notification.objects.filter(user=self.user, title='Test').exists()

    def test_notification_history(self):
        Notification.objects.create(user=self.user, title='Test', body='Hello')
        url = reverse('notification-history')
        response = self.client.get(url)
        assert response.status_code == 200
        assert response.data[0]['title'] == 'Test'
