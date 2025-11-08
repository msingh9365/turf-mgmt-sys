# Booking System - Complete Documentation

**Last Updated:** 2025-11-06  
**Test Status:** ✅ 30/30 tests passing

---

## Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Architecture](#architecture)
4. [API Reference](#api-reference)
5. [Booked Slots API](#booked-slots-api)
6. [Test Documentation](#test-documentation)
7. [Setup Instructions](#setup-instructions)
8. [Troubleshooting](#troubleshooting)

---

## Overview

The bookings module implements a robust booking system for turf management with **Redis-based distributed locking** to prevent double bookings and ensure concurrency safety.

### Key Capabilities
- Create, view, and cancel bookings
- Real-time slot availability checking
- Distributed locking for concurrent requests
- 14-day advance booking window
- Multi-slot and multi-player bookings

---

## Features

✅ **Distributed Locking**: Redis-based locks prevent race conditions  
✅ **Double Booking Prevention**: Atomic checks in both Redis and PostgreSQL  
✅ **Booking Management**: Create, view, and cancel bookings  
✅ **14-Day Booking Window**: Users can book up to 14 days in advance  
✅ **User Authentication**: JWT-based authentication required  
✅ **Comprehensive Tests**: Full pytest coverage with fakeredis  
✅ **Slot Availability API**: Query booked slots before making reservations

---

## Architecture

### Tech Stack
- **Framework**: Django 5 + Django REST Framework
- **Database**: PostgreSQL (Supabase)
- **Cache/Locking**: Redis
- **Auth**: JWT (Django + JWT)
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

### Time Slot System

Time slots: integers 1–48 represent 30-minute blocks over a day
- Slot 1 = 00:00–00:30
- Slot 2 = 00:30–01:00
- ...
- Slot 48 = 23:30–00:00

---

## API Reference

**Base URL (dev):** `http://localhost:8000/api/bookings/`  
**Authentication:** Bearer token (Authorization: Bearer <token>)  
**Content-Type:** application/json

### Data Rules

- Booking stores only booking metadata (booking_id, user who booked, timestamps)
- Ground is stored per entry in Booked_Details (one row per player per slot)
- Player sort key = first 7 characters of the email local part, uppercased
  - On create, the system:
    1. Filters candidate users by derived sort key
    2. Then matches email within those candidates
    3. Sets `is_user` in Booked_Details accordingly
- **Atomicity**: a booking either reserves all requested slots or none
- **Concurrency**: distributed locks prevent overlapping reservations

---

### 1. Create a Booking

**Method:** `POST`  
**URL:** `/api/bookings/`

#### Request Body

```json
{
  "date": "2025-11-20",
  "ground_id": 3,
  "slots": [17, 18, 19],
  "players": [
    { "name": "Alex Morgan", "email": "alex@example.com" },
    { "name": "Sam Lee", "email": "sam.lee@example.com" },
    { "name": "Jordan P", "email": "jordanp@example.org" }
  ]
}
```

#### Parameters

- `date` (string, required): Date in YYYY-MM-DD format
- `ground_id` (integer, required): ID of the ground to book
- `slots` (array[int], required): Slot IDs (1–48), must be unique
- `players` (array[object], required): List of players
  - `name` (string): Player name
  - `email` (string): Valid email address

#### Success Response (200 OK)

```json
{
  "booking_id": "BK20251106A3F2E1",
  "status": "Done",
  "slots_booked": [17, 18, 19],
  "players": [
    {
      "name": "Alex Morgan",
      "email": "alex@example.com",
      "sort_key": "ALEX",
      "is_user": false
    },
    {
      "name": "Sam Lee",
      "email": "sam.lee@example.com",
      "sort_key": "SAM.LEE",
      "is_user": true
    }
  ],
  "message": "Successfully booked 3 slot(s)"
}
```

#### Error Responses

- **400 Bad Request**: Invalid date format, slots out of range, duplicate slots, empty players, unknown ground_id
- **401 Unauthorized**: Missing/invalid token
- **409 Conflict**: At least one requested slot is already booked (response includes conflicting `slot_id`)
- **422 Unprocessable Entity**: Combined validation failed

#### Example cURL

```bash
curl -X POST http://localhost:8000/api/bookings/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2025-11-20",
    "ground_id": 3,
    "slots": [17, 18, 19],
    "players": [
      { "name": "Alex Morgan", "email": "alex@example.com" },
      { "name": "Sam Lee", "email": "sam.lee@example.com" }
    ]
  }'
```

---

### 2. List My Bookings

**Method:** `GET`  
**URL:** `/api/bookings/my/`

#### Query Parameters (Optional)

- `page` (integer): Page number
- `page_size` (integer): Results per page

#### Success Response (200 OK)

```json
{
  "count": 2,
  "next": null,
  "previous": null,
  "results": [
    {
      "booking_id": "BK20251106A3F2E1",
      "user": {
        "id": 42,
        "email": "owner@example.com"
      },
      "date": "2025-11-20",
      "status": "Done",
      "created_at": "2025-11-06T09:15:43.512Z",
      "ground_id": 3,
      "ground_name": "Court A",
      "sport_name": "Basketball",
      "slots": [17, 18, 19],
      "details": [
        {
          "player_name": "Alex Morgan",
          "player_email": "alex@example.com",
          "sort_key": "ALEX",
          "ground_id": 3,
          "slot_id": 17,
          "is_user": false
        }
      ]
    }
  ]
}
```

#### Example cURL

```bash
curl -X GET "http://localhost:8000/api/bookings/my/?page=1&page_size=10" \
  -H "Authorization: Bearer $TOKEN"
```

---

### 3. Retrieve a Single Booking

**Method:** `GET`  
**URL:** `/api/bookings/{booking_id}/`

#### Example cURL

```bash
curl -X GET http://localhost:8000/api/bookings/BK20251106A3F2E1/ \
  -H "Authorization: Bearer $TOKEN"
```

Response matches the shape of a single item from `/my/`.

---

### 4. Cancel a Booking (Dedicated Endpoint)

**Method:** `POST`  
**URL:** `/api/bookings/{booking_id}/cancel/`

#### Effects
- Only the user who created the booking can cancel it
- Booking status is set to "Rejected"
- All associated slots are freed (set to available)
- Redis cache is updated to reflect availability

#### Success Response (200 OK)

```json
{
  "message": "Booking cancelled successfully (3 slot(s))",
  "booking_id": "BK20251106A3F2E1",
  "status": "Rejected",
  "slots_cancelled": [17, 18, 19]
}
```

#### Error Responses

- **200 OK**: Booking cancelled; slots freed
- **400 Bad Request**: Booking is not in "Done" status or date is in the past
- **403 Forbidden**: You are not the owner
- **404 Not Found**: booking_id doesn't exist

#### Example cURL

```bash
curl -X POST http://localhost:8000/api/bookings/BK20251106A3F2E1/cancel/ \
  -H "Authorization: Bearer $TOKEN"
```

---

### 5. Delete a Booking (Alternative Endpoint)

**Method:** `DELETE`  
**URL:** `/api/bookings/{booking_id}/`

Same behavior as cancel endpoint (sets status to "Rejected", frees slots).

#### Success Response (200 OK)

```json
{
  "message": "Booking cancelled successfully (3 slot(s))",
  "booking_id": "BK20251106A3F2E1",
  "slots_cancelled": [17, 18, 19]
}
```

#### Example cURL

```bash
curl -X DELETE http://localhost:8000/api/bookings/BK20251106A3F2E1/ \
  -H "Authorization: Bearer $TOKEN"
```

---

### Cancel vs Delete

Both endpoints achieve the same result (setting booking status to "Rejected" and freeing slots):

- **POST /api/bookings/{booking_id}/cancel/** - Semantic cancel endpoint (recommended for user-facing apps)
- **DELETE /api/bookings/{booking_id}/** - RESTful delete endpoint (follows standard REST conventions)

Use whichever fits your API design philosophy. The cancel endpoint is more explicit about the action being performed.

---

## Booked Slots API

### Overview

This API endpoint retrieves the list of booked slot IDs for a specific ground on a given date. It queries the `Slot` table to find all slots that have been marked as booked.

### Get Booked Slots

**Method:** `GET`  
**URL:** `/api/bookings/booked-slots/`  
**Authentication:** Required (JWT Token)

#### Query Parameters

| Parameter  | Type   | Required | Description                              |
|-----------|--------|----------|------------------------------------------|
| date      | string | Yes      | Booking date in `YYYY-MM-DD` format     |
| ground_id | int    | Yes      | ID of the ground to check availability  |

#### Success Response (200 OK)

```json
{
  "ground_id": 1,
  "ground_name": "Main Football Ground",
  "date": "2025-11-10",
  "booked_slot_ids": [1, 3, 5, 10, 15, 20]
}
```

**Fields:**
- `ground_id` (int): ID of the ground
- `ground_name` (string): Name of the ground
- `date` (string): The requested date in YYYY-MM-DD format
- `booked_slot_ids` (array): List of slot IDs that are booked, sorted in ascending order

#### Error Responses

**Missing Date Parameter (400 Bad Request)**
```json
{
  "error": "Missing required parameter: date"
}
```

**Invalid Date Format (400 Bad Request)**
```json
{
  "error": "Invalid date format. Use YYYY-MM-DD"
}
```

**Ground Not Found (404 Not Found)**
```json
{
  "error": "Ground with ID 999 does not exist"
}
```

#### Example Requests

**cURL:**
```bash
curl -X GET "http://localhost:8000/api/bookings/booked-slots/?date=2025-11-10&ground_id=1" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Python:**
```python
import requests

url = "http://localhost:8000/api/bookings/booked-slots/"
headers = {"Authorization": "Bearer YOUR_JWT_TOKEN"}
params = {"date": "2025-11-10", "ground_id": 1}

response = requests.get(url, headers=headers, params=params)
print(response.json())
```

**JavaScript:**
```javascript
const url = new URL('http://localhost:8000/api/bookings/booked-slots/');
url.searchParams.append('date', '2025-11-10');
url.searchParams.append('ground_id', '1');

fetch(url, {
  method: 'GET',
  headers: {'Authorization': 'Bearer YOUR_JWT_TOKEN'}
})
  .then(response => response.json())
  .then(data => console.log(data));
```

### Use Cases

1. **Check Slot Availability**: Before making a booking, clients can check which slots are already booked
2. **Display Booking Calendar**: Frontend applications can display a visual calendar showing booked vs. available slots
3. **Real-time Availability Updates**: Check current availability before allowing users to proceed with booking

### Implementation Details

- Uses indexed fields (`ground`, `date`, `booked`)
- Returns only slot IDs (lightweight response)
- No joins required (direct table query)
- Empty results return `booked_slot_ids: []`

---

## Test Documentation

### Test Coverage Summary

**Total Tests:** 30 tests across 6 test classes  
**Status:** ✅ All passing  
**Execution Time:** ~30 seconds

---

### Test Classes Overview

#### 1. TestBookingCreation (7 tests)

Tests for booking creation with Redis distributed locking and concurrency control.

**test_successful_booking_creation**
- ✅ Creates booking with valid data
- Validates booking_id generation
- Verifies player normalization (is_user flag)
- Checks sort_key derivation
- Confirms metadata storage

**test_multi_slot_booking_creation**
- ✅ Creates booking spanning multiple time slots
- Verifies all slots share same booking_id
- Validates Booked_Details expansion (player × slot)
- Confirms all slots marked as booked

**test_booking_past_date_rejected**
- ✅ Rejects bookings for past dates
- Returns 400 Bad Request
- Validates date validation logic

**test_booking_too_far_advance_rejected**
- ✅ Rejects bookings beyond 14-day advance window
- Enforces business rule for advance booking limit
- Returns 400 with appropriate error message

**test_double_booking_prevention**
- ✅ Prevents duplicate bookings for same slot
- First booking succeeds (200)
- Second booking returns 409 Conflict
- Validates database-level conflict detection

**test_lock_conflict_returns_409**
- ✅ Tests Redis lock contention
- Simulates concurrent booking attempt
- Returns 409 when lock held by another user
- Validates distributed locking mechanism

**test_authentication_required**
- ✅ Enforces authentication for booking creation
- Unauthenticated requests return 401/403
- Validates permission classes

---

#### 2. TestBookingRetrieval (3 tests)

Tests for retrieving user bookings.

**test_get_my_bookings**
- ✅ Retrieves all bookings for authenticated user
- Returns bookings with complete details
- Validates prefetch optimization
- Confirms ordering (newest first)

**test_get_my_bookings_empty**
- ✅ Returns empty list when user has no bookings
- Validates edge case handling
- Returns 200 with empty array

**test_user_only_sees_own_bookings**
- ✅ Enforces user isolation
- User A cannot see User B's bookings
- Validates queryset filtering by user
- Tests authorization boundaries

---

#### 3. TestBookingCancellation (5 tests)

Tests for the DELETE /api/bookings/{id}/ endpoint.

**test_successful_cancellation**
- ✅ Cancels booking successfully
- Updates status to "Rejected"
- Frees all associated slots
- Updates Redis cache to "available"
- Returns 200 with cancellation summary

**test_cannot_cancel_others_booking**
- ✅ Prevents unauthorized cancellation
- Returns 403 Forbidden
- Validates ownership check
- Protects other users' bookings

**test_cannot_cancel_past_booking**
- ✅ Rejects cancellation of past bookings
- Returns 400 Bad Request
- Validates can_be_cancelled property
- Enforces temporal business rules

**test_cannot_cancel_rejected_booking**
- ✅ Prevents re-cancellation of already cancelled bookings
- Returns 400 for non-"Done" status
- Validates state machine constraints

**test_cancel_nonexistent_booking**
- ✅ Returns 404 for invalid booking_id
- Validates error handling

---

#### 4. TestCancelEndpoint (8 tests) ⭐ NEW

Tests for the dedicated POST /api/bookings/{id}/cancel/ endpoint.

**test_cancel_endpoint_successful**
- ✅ Cancels booking via POST endpoint
- Updates status to "Rejected"
- Frees multiple slots
- Updates Redis cache for all slots
- Returns detailed response with slots_cancelled list

**test_cancel_endpoint_multi_slot_booking**
- ✅ Handles bookings with 4+ slots
- Verifies all slots freed atomically
- Tests bulk update performance
- Confirms transaction consistency

**test_cancel_endpoint_ownership_check**
- ✅ Enforces authorization
- Returns 403 when non-owner attempts cancellation
- Validates booking remains unchanged

**test_cancel_endpoint_past_booking**
- ✅ Rejects cancellation of expired bookings
- Returns 400 with descriptive error

**test_cancel_endpoint_already_rejected**
- ✅ Handles already-cancelled bookings
- Returns 400 with status-specific error

**test_cancel_endpoint_nonexistent_booking**
- ✅ Returns 404 for invalid booking_id

**test_cancel_endpoint_waitlist_booking**
- ✅ Rejects cancellation of "Waitlist Processing" bookings
- Returns 400 with status error

**test_cancel_endpoint_idempotent_behavior**
- ✅ Tests double-cancellation scenario
- First cancellation succeeds (200)
- Second cancellation fails gracefully (400)

---

#### 5. TestRedisLocking (3 tests)

Tests for Redis distributed locking mechanism.

**test_lock_auto_expires**
- ✅ Validates TTL expiration
- Lock expires after configured timeout
- Prevents indefinite lock holding

**test_lock_release**
- ✅ Tests manual lock release
- Validates lock cleanup after booking
- Ensures locks are freed in finally block

**test_slot_status_caching**
- ✅ Tests Redis slot status cache
- Validates mark_slot_booked()
- Validates mark_slot_available()
- Confirms cache consistency with database

---

#### 6. TestBookingModel (4 tests)

Tests for Booking model business logic.

**test_booking_id_generation**
- ✅ Validates auto-generated booking IDs
- Confirms format: BK{YYYYMMDD}{6-hex}
- Tests uniqueness

---

### Running Tests

**Run all booking tests:**
```bash
pytest backend/src/bookings/tests/ -v
```

**Run specific test class:**
```bash
pytest backend/src/bookings/tests/test_bookings.py::TestBookingCreation -v
```

**Run booked slots API tests:**
```bash
pytest backend/src/bookings/tests/test_booked_slots_api.py -v
```

**Run with coverage:**
```bash
pytest backend/src/bookings/tests/ --cov=bookings --cov-report=html
```

---

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

5. **Run development server:**
   ```bash
   python manage.py runserver
   ```

---

## Troubleshooting

### Common Issues

**409 on create:**
- At least one requested slot is already booked
- Re-query availability and retry different slots

**400 on create:**
- Validate `date`, `ground_id`, slot range/uniqueness, players list, and email formats

**400 on cancel:**
- Booking status is not "Done" or booking date is in the past

**401/403:**
- Confirm token is valid and you own the booking

**SQLite migrations (dev only):**
- On schema drift errors (e.g., "no such table")
- Remove `db.sqlite3` and run `python manage.py migrate` again

### Booking Flow Diagrams

**Successful Booking Flow:**
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

**Cancellation Flow:**
```
1. User sends DELETE or POST /cancel/
2. Verify ownership (booking.user == request.user)
3. Check status (must be "Done")
4. Check if future booking
5. Update status to "Rejected" in DB
6. Mark slot as "available" in Redis
7. Return 200 success
```

---

## Version History

- **v1.0** (Nov 6, 2025): Initial release with full booking management
- **v1.1** (Nov 6, 2025): Added Booked Slots API endpoint
- **v1.2** (Nov 6, 2025): Added dedicated cancel endpoint

---

## Related Documentation

- Django REST Framework: https://www.django-rest-framework.org/
- Redis Python Client: https://redis-py.readthedocs.io/
- pytest Documentation: https://docs.pytest.org/

---

**End of Documentation**
