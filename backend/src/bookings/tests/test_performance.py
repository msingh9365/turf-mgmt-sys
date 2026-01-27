"""Performance-oriented tests for booking operations.
Run with: PYTEST_ENABLE_PERF=1 pytest bookings/tests/test_performance.py -q
Skip by default unless env flag set to avoid slowing normal CI.
"""
import os
import time
from django.utils import timezone
from django.contrib.auth import get_user_model
from rest_framework.test import APIClient
import pytest
from bookings.models import Ground, Sport

User = get_user_model()

pytestmark = pytest.mark.django_db

PERF_ENABLED = os.getenv("PYTEST_ENABLE_PERF") == "1"

pytest.skip("Performance tests skipped (set PYTEST_ENABLE_PERF=1 to enable)", allow_module_level=True) if not PERF_ENABLED else None

@pytest.fixture
def perf_user(db):
    return User.objects.create_user(
        email="perf@iitrpr.ac.in", name="Perf User", sort_key="PERFUSR", password="testpass123"
    )

@pytest.fixture
def perf_client(perf_user):
    client = APIClient()
    client.force_authenticate(user=perf_user)
    return client

@pytest.fixture
def perf_ground(db):
    sport = Sport.objects.create(sport_name="Football", min_player=5)
    return Ground.objects.create(ground_name="Perf Turf", sport=sport)


def _create_booking(client, ground, slot_ids, date):
    payload = {
        "ground_id": ground.ground_id,
        "slot_id": slot_ids,
        "date": str(date),
        "players": [
            {"name": "Perf User", "email": "perf@iitrpr.ac.in"},
            {"name": "Guest", "email": "guest@example.com"},
        ],
    }
    return client.post("/api/bookings/", payload, format="json")


def test_single_booking_latency(perf_client, perf_ground):
    """Assert single-slot booking completes within reasonable time (e.g., < 500ms)."""
    tomorrow = (timezone.now() + timezone.timedelta(days=1)).date()
    start = time.perf_counter()
    resp = _create_booking(perf_client, perf_ground, [5], tomorrow)
    elapsed_ms = (time.perf_counter() - start) * 1000
    assert resp.status_code == 200, resp.data
    # Loose upper bound to catch regressions; adjust as needed.
    assert elapsed_ms < 500, f"Single booking latency high: {elapsed_ms:.2f}ms"


def test_multi_slot_booking_latency(perf_client, perf_ground):
    """Assert multi-slot booking (5 slots) completes within reasonable time (< 800ms)."""
    tomorrow = (timezone.now() + timezone.timedelta(days=1)).date()
    slots = [10,11,12,13,14]
    start = time.perf_counter()
    resp = _create_booking(perf_client, perf_ground, slots, tomorrow)
    elapsed_ms = (time.perf_counter() - start) * 1000
    assert resp.status_code == 200, resp.data
    assert elapsed_ms < 800, f"Multi-slot booking latency high: {elapsed_ms:.2f}ms"


def test_my_bookings_list_latency(perf_client, perf_ground):
    """Create multiple bookings then measure /my endpoint (< 300ms)."""
    tomorrow = (timezone.now() + timezone.timedelta(days=1)).date()
    day_after = (timezone.now() + timezone.timedelta(days=2)).date()
    _create_booking(perf_client, perf_ground, [5], tomorrow)
    _create_booking(perf_client, perf_ground, [6,7], day_after)
    start = time.perf_counter()
    resp = perf_client.get("/api/bookings/my/")
    elapsed_ms = (time.perf_counter() - start) * 1000
    assert resp.status_code == 200
    assert len(resp.data) >= 2
    assert elapsed_ms < 300, f"/my latency high: {elapsed_ms:.2f}ms"
