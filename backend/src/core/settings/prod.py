"""
Production settings for the playground backend.
Extends base with production-safe defaults.
"""
from .base import *  # noqa: F403,F401

DEBUG = False

# In production, do not allow all origins. Expect ALLOWED_HOSTS from env.
CORS_ALLOW_ALL_ORIGINS = False
