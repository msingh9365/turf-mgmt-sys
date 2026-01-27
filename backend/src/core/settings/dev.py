"""
Development settings for the playground backend.
Extends base and enables debug-specific options.
"""
from .base import *  # noqa: F403,F401

DEBUG = True

# Use base.py database settings by default (Postgres or SQLite via DB_USE_SQLITE).
# You can force SQLite (commonly when running pytest) by setting env PYTEST_USE_SQLITE=1.
if env.bool("PYTEST_USE_SQLITE", default=False):  # noqa: F405
    # Force SQLite to avoid external DB dependency
    DATABASES = {  # noqa: F405
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": str(BASE_DIR / "db.sqlite3"),  # noqa: F405
        }
    }

# In dev, allow localhost and 127.0.0.1 by default
if "localhost" not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append("localhost")
if "127.0.0.1" not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append("127.0.0.1")
if "testserver" not in ALLOWED_HOSTS:
    ALLOWED_HOSTS.append("testserver")
