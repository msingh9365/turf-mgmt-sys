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
