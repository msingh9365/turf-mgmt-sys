# Bookings Module Documentation

## Overview

The bookings module implements a robust booking system for turf management with **Redis-based distributed locking** to prevent double bookings and ensure concurrency safety.

## Features

✅ **Distributed Locking**: Redis-based locks prevent race conditions  
✅ **Double Booking Prevention**: Atomic checks in both Redis and PostgreSQL  
✅ **Booking Management**: Create, view, and cancel bookings  
✅ **14-Day Booking Window**: Users can book up to 14 days in advance  
✅ **User Authentication**: JWT-based authentication required  
✅ **Comprehensive Tests**: Full pytest coverage with fakeredis  

## Architecture

### Tech Stack
- **Framework**: Django 5 + Django REST Framework
- **Database**: Supabase (PostgreSQL)
- **Cache/Locking**: Redis
- **Auth**: Django + JWT (existing)
- **Testing**: pytest + fakeredis

### Database Schema

```sql
CREATE TABLE Booking (
  Unique_ID VARCHAR(50) PRIMARY KEY,
  Booking_ID SERIAL UNIQUE,
  User_ID INT REFERENCES "User"(User_ID) ON DELETE RESTRICT,
  Ground_ID INT,
  Slot_ID INT,
  Date DATE NOT NULL,
  Metadata JSONB,
  Status VARCHAR(30) DEFAULT 'Waitlist Processing',
  Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT unique_active_booking_per_slot 
    UNIQUE (Ground_ID, Slot_ID, Date) WHERE Status = 'Done'
);
```

### Redis Keys

| Purpose | Key Pattern | Example | TTL |
|---------|-------------|---------|-----|
| Slot Lock | `lock:slot:{ground_id}:{date}:{slot_id}` | `lock:slot:1:2025-11-01:5` | 10s |
| Slot Status | `slot:{ground_id}:{date}:{slot_id}` | `slot:1:2025-11-01:5` | 24h |
| Pending Booking | `pending:booking:{unique_id}` | `pending:booking:BK20251101ABC123` | 5m |

## API Endpoints

### 1. Create Booking

**POST** `/api/bookings/`

Creates a new booking with distributed locking.

**Request:**
```json
{
  "ground_id": 1,
  "slot_id": 5,
  "date": "2025-11-01",
  "player_ids": [2, 3, 4],
  "metadata": {"team_name": "Hostel 5 FC"}
}
```

**Success Response (200):**
```json
{
  "booking_id": "BK20251101ABC123",
  "status": "Done",
  "message": "Booking confirmed successfully"
}
```

**Conflict Response (409):**
```json
{
  "error": "Slot already booked"
}
```

**Validation Errors (400):**
- Date in the past
- Date more than 14 days in advance
- Invalid ground_id or slot_id

### 2. Get My Bookings

**GET** `/api/bookings/my/`

Returns all bookings for the authenticated user.

**Response (200):**
```json
[
  {
    "booking_id": "BK20251101ABC123",
    "ground_id": 1,
    "slot_id": 5,
    "date": "2025-11-01",
    "status": "Done",
    "metadata": {"team_name": "Hostel 5 FC"},
    "created_at": "2025-10-31T10:30:00Z",
    "user_email": "user@iitrpr.ac.in",
    "user_name": "John Doe"
  }
]
```

### 3. Cancel Booking

**DELETE** `/api/bookings/{booking_id}/`

Cancels a booking (only by its owner, before slot time).

**Response (200):**
```json
{
  "message": "Booking cancelled successfully",
  "booking_id": "BK20251101ABC123"
}
```

**Error Responses:**
- **403**: Not the booking owner
- **400**: Cannot cancel (past booking or already rejected)
- **404**: Booking not found

## Booking Flow

### Successful Booking Flow

```
1. User sends POST /api/bookings/
2. Validate input (date, ground_id, slot_id)
3. Acquire Redis lock (10s TTL)
   ├─ Lock acquired → Continue
   └─ Lock failed → Return 409 "Slot is being booked"
4. Check Redis slot status
   ├─ "booked" → Release lock, Return 409
   └─ Not booked → Continue
5. Check database for existing booking
   ├─ Exists → Update Redis, Release lock, Return 409
   └─ Not exists → Continue
6. Create booking in DB (atomic transaction)
7. Mark slot as "booked" in Redis
8. Release lock
9. Return 200 with booking_id
```

### Cancellation Flow

```
1. User sends DELETE /api/bookings/{id}/
2. Verify ownership (booking.user == request.user)
3. Check status (must be "Done")
4. Check if future booking
5. Update status to "Rejected" in DB
6. Mark slot as "available" in Redis
7. Return 200 success
```

## Setup Instructions

### Prerequisites

- Python 3.8+
- PostgreSQL (Supabase)
- Redis server running on localhost:6379

### Installation

1. **Install dependencies:**
   ```bash
   cd backend
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Configure environment variables (.env):**
   ```env
   REDIS_HOST=localhost
   REDIS_PORT=6379
   REDIS_DB=0
   ```

3. **Run migrations:**
   ```bash
   cd src
   python manage.py migrate bookings
   ```

4. **Start Redis (if not running):**
   ```bash
   redis-server
   ```

5. **Start Django development server:**
   ```bash
   python manage.py runserver
   ```

## Testing

### Run All Tests

```bash
cd src
pytest bookings/tests/test_bookings.py -v
```

### Run Specific Test Classes

```bash
# Test booking creation
pytest bookings/tests/test_bookings.py::TestBookingCreation -v

# Test locking mechanism
pytest bookings/tests/test_bookings.py::TestRedisLocking -v

# Test cancellation
pytest bookings/tests/test_bookings.py::TestBookingCancellation -v
```

### Test Coverage

```bash
pytest bookings/tests/ --cov=bookings --cov-report=html
```

### Test Scenarios Covered

✅ Successful booking creation  
✅ Double booking prevention  
✅ Lock conflict handling (409 response)  
✅ Date validation (past dates, >14 days)  
✅ Authentication required  
✅ User can only see own bookings  
✅ Successful cancellation  
✅ Cannot cancel others' bookings  
✅ Cannot cancel past bookings  
✅ Lock auto-expiry  
✅ Slot status caching  

## Manual Testing with Postman/cURL

### 1. Create a User and Get JWT Token

```bash
# Register/Login to get JWT token
curl -X POST http://localhost:8000/api/users/login/ \
  -H "Content-Type: application/json" \
  -d '{"email": "user@iitrpr.ac.in", "password": "password123"}'
```

### 2. Create a Booking

```bash
curl -X POST http://localhost:8000/api/bookings/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ground_id": 1,
    "slot_id": 5,
    "date": "2025-11-01",
    "player_ids": [2, 3, 4],
    "metadata": {"team_name": "Test Team"}
  }'
```

### 3. Get My Bookings

```bash
curl -X GET http://localhost:8000/api/bookings/my/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### 4. Cancel a Booking

```bash
curl -X DELETE http://localhost:8000/api/bookings/BK20251101ABC123/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### 5. Test Concurrent Booking (Race Condition)

Open two terminals and run simultaneously:

```bash
# Terminal 1
curl -X POST http://localhost:8000/api/bookings/ \
  -H "Authorization: Bearer TOKEN1" \
  -H "Content-Type: application/json" \
  -d '{"ground_id": 1, "slot_id": 5, "date": "2025-11-01"}'

# Terminal 2 (run immediately)
curl -X POST http://localhost:8000/api/bookings/ \
  -H "Authorization: Bearer TOKEN2" \
  -H "Content-Type: application/json" \
  -d '{"ground_id": 1, "slot_id": 5, "date": "2025-11-01"}'
```

**Expected**: One succeeds (200), one fails (409 Conflict)

## Redis Commands for Debugging

```bash
# Connect to Redis
redis-cli

# Check if a slot is locked
GET "lock:slot:1:2025-11-01:5"

# Check slot status
GET "slot:1:2025-11-01:5"

# Clear all booking-related keys
KEYS "slot:*" | xargs redis-cli DEL
KEYS "lock:*" | xargs redis-cli DEL

# Monitor Redis commands in real-time
MONITOR
```

## File Structure

```
backend/src/
├── bookings/
│   ├── __init__.py
│   ├── admin.py              # Django admin configuration
│   ├── apps.py               # App configuration
│   ├── models.py             # Booking model
│   ├── serializers.py        # DRF serializers
│   ├── views.py              # API views with Redis locking
│   ├── urls.py               # URL routing
│   ├── migrations/
│   │   ├── __init__.py
│   │   └── 0001_initial.py   # Database migration
│   └── tests/
│       ├── __init__.py
│       └── test_bookings.py  # Comprehensive tests
├── core/
│   ├── redis_client.py       # Redis client helper
│   ├── settings/
│   │   └── base.py           # Updated with Redis config
│   └── urls.py               # Updated with bookings routes
└── pytest.ini                # Pytest configuration
```

## Key Implementation Details

### Distributed Locking

```python
# Acquire lock (atomic operation)
lock_acquired = redis_client.set(
    lock_key,
    user_id,
    nx=True,  # Only set if not exists
    ex=10     # Expire after 10 seconds
)

if not lock_acquired:
    return 409  # Conflict - slot is locked
```

### Atomic Booking Creation

```python
with transaction.atomic():
    booking = Booking.objects.create(
        user=request.user,
        ground_id=ground_id,
        slot_id=slot_id,
        date=date,
        status="Done"
    )

redis_client.set(slot_key, "booked")
```

### Lock Auto-Release

Locks automatically expire after 10 seconds (TTL), preventing deadlocks if a process crashes.

## Troubleshooting

### Issue: "Connection refused" to Redis

**Solution**: Start Redis server
```bash
redis-server
```

### Issue: Migration fails

**Solution**: Check database connection and run migrations
```bash
python manage.py migrate
```

### Issue: Lock not releasing

**Solution**: Locks auto-expire after 10s. Manually clear if needed:
```bash
redis-cli FLUSHDB
```

### Issue: Tests failing

**Solution**: Ensure fakeredis is installed and pytest is using the correct settings:
```bash
pip install fakeredis pytest-django
pytest bookings/tests/ -v
```

## Production Considerations

1. **Redis Persistence**: Configure Redis with AOF or RDB for data durability
2. **Redis Cluster**: Use Redis Cluster for high availability
3. **Lock Timeout**: Adjust lock TTL based on expected booking transaction time
4. **Monitoring**: Add logging and metrics for lock acquisition failures
5. **Rate Limiting**: Implement rate limiting to prevent booking spam
6. **Webhook/Notifications**: Add booking confirmation emails/notifications

## Acceptance Criteria

✅ No double bookings occur (verified by Redis lock)  
✅ Bookings persist in Supabase (PostgreSQL)  
✅ Cancelling updates both DB and Redis  
✅ Locking logic works atomically with nx=True, ex=10  
✅ All unit tests pass  
✅ Django modular app structure maintained  
✅ No changes to existing Supabase/Django auth or settings  

## License

This module is part of the Turf Management System.
