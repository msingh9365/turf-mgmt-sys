# need a utility function to send the email.

import random
from django.core.mail import send_mail
from django.conf import settings

def generate_otp():
    """Generate a random 6-digit OTP"""
    return str(random.randint(100000, 999999))

def send_verification_email(email, otp):
    """Send OTP email to user"""
    subject = "Your Verification Code"
    message = f"Your OTP code is {otp}. It will expire in 5 minutes."
    from_email = settings.DEFAULT_FROM_EMAIL
    send_mail(subject, message, from_email, [email])
