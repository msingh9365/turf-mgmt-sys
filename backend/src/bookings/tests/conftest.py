"""
Pytest configuration for bookings tests.
Uses FakeRedis in tests to avoid external Redis dependency. Cleans keys before/after.
"""
import pytest
from unittest.mock import patch
from django.core.cache import cache
from core.redis_client import RedisClient
from bookings.models import Sport, Ground
import fakeredis


@pytest.fixture(scope="function", autouse=True)
def clean_redis():
    """
    Automatically clean Redis before and after each test using FakeRedis.
    """
    # Initialize a fresh FakeRedis client per test and inject into RedisClient
    fake = fakeredis.FakeRedis()
    RedisClient._instance = fake
    redis_client = fake
    
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
    """Provide direct access to FakeRedis client for tests that need it."""
    return clean_redis


@pytest.fixture
def sport(db):
    """Create a default sport for grounds."""
    return Sport.objects.create(sport_name="Football", min_player=5)


@pytest.fixture
def ground(db, sport):
    """Create a default ground used in booking tests."""
    return Ground.objects.create(ground_name="Main Turf", sport=sport)
