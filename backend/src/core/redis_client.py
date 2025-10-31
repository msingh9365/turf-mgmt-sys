"""
Redis client helper for distributed locking and caching.
Used by the bookings module for concurrency control and slot availability caching.
"""
import logging
from typing import Optional

import redis
from django.conf import settings

logger = logging.getLogger(__name__)


class RedisClient:
    """
    Wrapper for Redis connection with helper methods for booking management.
    Provides distributed locking and slot status caching.
    """

    _instance: Optional[redis.Redis] = None

    @classmethod
    def get_client(cls) -> redis.Redis:
        """
        Get or create a singleton Redis client instance.
        Uses connection pooling for efficiency.
        """
        if cls._instance is None:
            try:
                redis_host = getattr(settings, "REDIS_HOST", "localhost")
                redis_port = getattr(settings, "REDIS_PORT", 6379)
                redis_db = getattr(settings, "REDIS_DB", 0)

                cls._instance = redis.Redis(
                    host=redis_host,
                    port=redis_port,
                    db=redis_db,
                    decode_responses=False,  # We'll handle decoding manually
                    socket_connect_timeout=5,
                    socket_timeout=5,
                )
                # Test connection
                cls._instance.ping()
                logger.info(f"Redis connected successfully at {redis_host}:{redis_port}")
            except redis.ConnectionError as e:
                logger.error(f"Failed to connect to Redis: {e}")
                raise

        return cls._instance

    @classmethod
    def acquire_slot_lock(cls, ground_id: int, date: str, slot_id: int, user_id: int, ttl: int = 10) -> bool:
        """
        Acquire a distributed lock for a specific slot.

        Args:
            ground_id: Ground identifier
            date: Booking date (YYYY-MM-DD)
            slot_id: Slot identifier
            user_id: User trying to acquire the lock
            ttl: Time to live in seconds (default: 10)

        Returns:
            True if lock acquired, False if already locked
        """
        client = cls.get_client()
        lock_key = f"lock:slot:{ground_id}:{date}:{slot_id}"
        
        # SET with NX (only if not exists) and EX (expiry)
        acquired = client.set(lock_key, str(user_id), nx=True, ex=ttl)
        
        if acquired:
            logger.debug(f"Lock acquired: {lock_key} by user {user_id}")
        else:
            logger.debug(f"Lock failed: {lock_key} (already held)")
        
        return bool(acquired)

    @classmethod
    def release_slot_lock(cls, ground_id: int, date: str, slot_id: int) -> None:
        """
        Release a distributed lock for a specific slot.

        Args:
            ground_id: Ground identifier
            date: Booking date (YYYY-MM-DD)
            slot_id: Slot identifier
        """
        client = cls.get_client()
        lock_key = f"lock:slot:{ground_id}:{date}:{slot_id}"
        client.delete(lock_key)
        logger.debug(f"Lock released: {lock_key}")

    @classmethod
    def get_slot_status(cls, ground_id: int, date: str, slot_id: int) -> Optional[str]:
        """
        Get the booking status of a slot from cache.

        Args:
            ground_id: Ground identifier
            date: Booking date (YYYY-MM-DD)
            slot_id: Slot identifier

        Returns:
            "available", "booked", or None if not cached
        """
        client = cls.get_client()
        slot_key = f"slot:{ground_id}:{date}:{slot_id}"
        status = client.get(slot_key)
        
        if status:
            return status.decode('utf-8')
        return None

    @classmethod
    def set_slot_status(cls, ground_id: int, date: str, slot_id: int, status: str, ttl: int = 86400) -> None:
        """
        Set the booking status of a slot in cache.

        Args:
            ground_id: Ground identifier
            date: Booking date (YYYY-MM-DD)
            slot_id: Slot identifier
            status: "available" or "booked"
            ttl: Time to live in seconds (default: 24 hours)
        """
        client = cls.get_client()
        slot_key = f"slot:{ground_id}:{date}:{slot_id}"
        client.set(slot_key, status, ex=ttl)
        logger.debug(f"Slot status set: {slot_key} = {status}")

    @classmethod
    def mark_slot_booked(cls, ground_id: int, date: str, slot_id: int) -> None:
        """Mark a slot as booked in Redis cache."""
        cls.set_slot_status(ground_id, date, slot_id, "booked")

    @classmethod
    def mark_slot_available(cls, ground_id: int, date: str, slot_id: int) -> None:
        """Mark a slot as available in Redis cache."""
        cls.set_slot_status(ground_id, date, slot_id, "available")

    @classmethod
    def store_pending_booking(cls, unique_id: str, booking_data: dict, ttl: int = 300) -> None:
        """
        Store pending booking data temporarily.

        Args:
            unique_id: Unique booking identifier
            booking_data: Booking metadata as dict
            ttl: Time to live in seconds (default: 5 minutes)
        """
        import json
        
        client = cls.get_client()
        pending_key = f"pending:booking:{unique_id}"
        client.set(pending_key, json.dumps(booking_data), ex=ttl)
        logger.debug(f"Pending booking stored: {pending_key}")

    @classmethod
    def get_pending_booking(cls, unique_id: str) -> Optional[dict]:
        """Retrieve pending booking data."""
        import json
        
        client = cls.get_client()
        pending_key = f"pending:booking:{unique_id}"
        data = client.get(pending_key)
        
        if data:
            return json.loads(data.decode('utf-8'))
        return None

    @classmethod
    def clear_pending_booking(cls, unique_id: str) -> None:
        """Remove pending booking data."""
        client = cls.get_client()
        pending_key = f"pending:booking:{unique_id}"
        client.delete(pending_key)
        logger.debug(f"Pending booking cleared: {pending_key}")


# Convenience function to get Redis client
def get_redis_client() -> redis.Redis:
    """Get the Redis client instance."""
    return RedisClient.get_client()
