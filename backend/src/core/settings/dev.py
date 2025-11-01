"""
Development settings for the playground backend.
Extends base and enables debug-specific options.
"""
from .base import *  # noqa: F403,F401

DEBUG = True

# In dev, allow localhost and 127.0.0.1 by default
if "localhost" not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append("localhost")
if "127.0.0.1" not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append("127.0.0.1")
if "testserver" not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append("testserver")

# Gmail's SMTP server for development
EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
# Use a specific application password from your Gmail account
EMAIL_HOST_USER = 'your_iitrpr_email@gmail.com' 
EMAIL_HOST_PASSWORD = 'your_app_password' # NOT your main password