"""
Pytest configuration for bookings tests.
Uses actual Redis connection for testing (clears test data before/after each test).
"""
import pytest
from unittest.mock import patch
from django.core.cache import cache
from core.redis_client import RedisClient
from bookings.models import Sport, Ground


@pytest.fixture(scope="function", autouse=True)
def clean_redis():
    """
    Automatically clean Redis before and after each test.
    Uses the actual Redis connection from settings.
    """
    # Get the real Redis client
    redis_client = RedisClient.get_client()
    
    # Clear all test keys before test
    # Use a pattern to only delete booking-related keys
    test_patterns = [
        "lock:slot:*",
        "slot:*",
        "turf_mgmt:*",  # Django cache keys
    ]
    
    for pattern in test_patterns:
        keys = redis_client.keys(pattern)
        if keys:
            redis_client.delete(*keys)
    
    yield redis_client
    
    # Clear all test keys after test
    for pattern in test_patterns:
        keys = redis_client.keys(pattern)
        if keys:
            redis_client.delete(*keys)


@pytest.fixture
def fake_redis_client(clean_redis):
    """Provide direct access to redis client for tests that need it."""
    return clean_redis


@pytest.fixture
def sport(db):
    """Create a default sport for grounds."""
    return Sport.objects.create(sport_name="Football", min_player=5)


@pytest.fixture
def ground(db, sport):
    """Create a default ground used in booking tests."""
    return Ground.objects.create(ground_name="Main Turf", sport=sport)
