from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APITestCase
from django.urls import reverse
from users.models import User
from .models import EmailOTP
from datetime import timedelta


@override_settings(EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend')
class OTPTests(APITestCase):
	def setUp(self):
		self.user = User.objects.create_user(email="alice@iitrpr.ac.in", name="Alice", sort_key="a1")

	def test_send_otp_success(self):
		url = reverse('send-otp')
		resp = self.client.post(url, {"email": "alice@iitrpr.ac.in"}, format='json')
		self.assertEqual(resp.status_code, 200)
		self.assertIn('message', resp.data)
		self.assertTrue(EmailOTP.objects.filter(email__iexact='alice@iitrpr.ac.in').exists())

	def test_send_otp_rate_limit(self):
		url = reverse('send-otp')
		# First send
		resp1 = self.client.post(url, {"email": "alice@iitrpr.ac.in"}, format='json')
		self.assertEqual(resp1.status_code, 200)
		# Second send should be rate-limited
		resp2 = self.client.post(url, {"email": "alice@iitrpr.ac.in"}, format='json')
		self.assertEqual(resp2.status_code, 429)

	def test_send_otp_non_college_domain(self):
		url = reverse('send-otp')
		resp = self.client.post(url, {"email": "bob@example.com"}, format='json')
		self.assertEqual(resp.status_code, 400)

	def test_send_otp_without_user(self):
		# Should allow sending OTP even if user isn't yet created (signup flow)
		url = reverse('send-otp')
		resp = self.client.post(url, {"email": "charlie@iitrpr.ac.in"}, format='json')
		self.assertEqual(resp.status_code, 200)

	def test_verify_otp_success_and_delete(self):
		# create OTP
		otp = EmailOTP.objects.create(email='alice@iitrpr.ac.in', otp='123456', expires_at=timezone.now()+timedelta(minutes=5))
		url = reverse('verify-otp')
		resp = self.client.post(url, {"email": "alice@iitrpr.ac.in", "otp": "123456"}, format='json')
		self.assertEqual(resp.status_code, 200)
		# OTP should be deleted
		self.assertFalse(EmailOTP.objects.filter(pk=otp.pk).exists())

	def test_verify_otp_wrong(self):
		EmailOTP.objects.create(email='alice@iitrpr.ac.in', otp='123456', expires_at=timezone.now()+timedelta(minutes=5))
		url = reverse('verify-otp')
		resp = self.client.post(url, {"email": "alice@iitrpr.ac.in", "otp": "000000"}, format='json')
		self.assertEqual(resp.status_code, 400)

	def test_verify_otp_expired(self):
		EmailOTP.objects.create(email='alice@iitrpr.ac.in', otp='123456', expires_at=timezone.now()-timedelta(minutes=1))
		url = reverse('verify-otp')
		resp = self.client.post(url, {"email": "alice@iitrpr.ac.in", "otp": "123456"}, format='json')
		self.assertEqual(resp.status_code, 400)
