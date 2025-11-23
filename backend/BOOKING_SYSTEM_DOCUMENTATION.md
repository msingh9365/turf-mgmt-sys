# Booking System - Complete Documentation

**Last Updated:** 2025-11-09  
**Test Status:** ✅ 30/30 tests passing  
**Version:** 1.2

---

## Table of Contents

1. [Overview](#overview)
2. [Features](#features)
3. [Architecture](#architecture)
4. [API Reference](#api-reference)
   - [Create Booking](#1-create-a-booking)
   - [List My Bookings](#2-list-my-bookings)
   - [Get Single Booking](#3-retrieve-a-single-booking)
   - [Cancel Booking](#4-cancel-a-booking)
   - [Delete Booking](#5-delete-a-booking)
   - [Get Booked Slots](#6-get-booked-slots)
5. [Test Documentation](#test-documentation)
6. [Setup Instructions](#setup-instructions)
7. [Troubleshooting](#troubleshooting)

---

## Overview

The bookings module implements a robust booking system for turf management with **Redis-based distributed locking** to prevent double bookings and ensure concurrency safety.

### Key Capabilities
- Create, view, and cancel bookings
- Real-time slot availability checking
- Distributed locking for concurrent requests
- 14-day advance booking window
- Multi-slot and multi-player bookings
- Player management with automatic user detection

---

## Features

✅ **Distributed Locking**: Redis-based locks prevent race conditions  
✅ **Double Booking Prevention**: Atomic checks in both Redis and PostgreSQL  
✅ **Booking Management**: Create, view, and cancel bookings  
✅ **14-Day Booking Window**: Users can book up to 14 days in advance  
✅ **User Authentication**: JWT-based authentication required  
✅ **Comprehensive Tests**: Full pytest coverage with fakeredis  
✅ **Slot Availability API**: Query booked slots before making reservations  
✅ **Multi-Slot Bookings**: Book multiple consecutive slots atomically  
✅ **Player Tracking**: Track all players in a booking with automatic user detection

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
  Booking_ID VARCHAR(50) UNIQUE,
  User_ID INT REFERENCES "User"(User_ID) ON DELETE RESTRICT,
  Date DATE NOT NULL,
  Status VARCHAR(30) DEFAULT 'Done',
  Created_At TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE Booked_Details (
  Detail_ID SERIAL PRIMARY KEY,
  Booking_ID VARCHAR(50) REFERENCES Booking(Booking_ID) ON DELETE CASCADE,
  Ground_ID INT REFERENCES Ground(Ground_ID),
  Slot_ID INT,
  Date DATE NOT NULL,
  Player_Name VARCHAR(100),
  Player_Email VARCHAR(100),
  Sort_Key VARCHAR(7),
  Is_User BOOLEAN DEFAULT FALSE,
  CONSTRAINT unique_slot_booking 
    UNIQUE (Ground_ID, Slot_ID, Date)
);

CREATE INDEX idx_member_lock ON Booked_Details(Sort_Key, Ground_ID, Date);
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

- **Booking** stores only booking metadata (booking_id, user who booked, timestamps)
- **Ground** is stored per entry in Booked_Details (one row per player per slot)
- **Player sort key** = first 7 characters of the email local part, uppercased
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

Create a new booking for one or multiple slots. All slots will share the same Booking_ID.

#### Request Body

```json
{
  "date": "2025-11-20",
  "ground_id": 3,
  "slot_id": [17, 18, 19],
  "players": [
    { "name": "Alex Morgan", "email": "alex@example.com" },
    { "name": "Sam Lee", "email": "sam.lee@example.com" },
    { "name": "Jordan P", "email": "jordanp@example.org" }
  ]
}
```

#### Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| date | string | Yes | Date in YYYY-MM-DD format (not in past, max 14 days ahead) |
| ground_id | integer | Yes | ID of the ground to book |
| slot_id | array[int] | Yes | Slot IDs (1–48), must be unique |
| players | array[object] | Yes | List of players (non-empty) |
| players[].name | string | Yes | Player name (non-blank) |
| players[].email | string | Yes | Valid email address |

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
      "sort_key": "SAMLEE",
      "is_user": true
    },
    {
      "name": "Jordan P",
      "email": "jordanp@example.org",
      "sort_key": "JORDANP",
      "is_user": false
    }
  ],
  "message": "Successfully booked 3 slot(s)"
}
```

#### Error Responses

| Status Code | Description |
|-------------|-------------|
| 400 Bad Request | Invalid date format, slots out of range, duplicate slots, empty players, unknown ground_id, past date, or date too far in advance |
| 401 Unauthorized | Missing/invalid authentication token |
| 409 Conflict | At least one requested slot is already booked or locked by another user |
| 500 Internal Server Error | Server error (booking rolled back) |

#### Example cURL

```bash
curl -X POST http://localhost:8000/api/bookings/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2025-11-20",
    "ground_id": 3,
    "slot_id": [17, 18, 19],
    "players": [
      { "name": "Alex Morgan", "email": "alex@example.com" },
      { "name": "Sam Lee", "email": "sam.lee@example.com" }
    ]
  }'
```

#### Flow
1. Validate input (date, slot_ids, ground_id)
2. Acquire Redis locks for ALL slots (fail if any slot locked/booked)
3. Create booking records with same Booking_ID (one row per slot per player)
4. Mark all slots as booked in Redis
5. Release all locks

---

### 2. List My Bookings

**Method:** `GET`  
**URL:** `/api/bookings/my/`

Get all bookings for the authenticated user in a compact summary format.

#### Query Parameters (Optional)

| Parameter | Type | Description |
|-----------|------|-------------|
| page | integer | Page number (if pagination enabled) |
| page_size | integer | Results per page (if pagination enabled) |

#### Success Response (200 OK)

Returns a list of bookings ordered by created_at (newest first).

```json
[
  {
    "booking_id": "BK20251106A3F2E1",
    "slots": [17, 18, 19],
    "ground_id": 3,
    "date": "2025-11-20",
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
        "sort_key": "SAMLEE",
        "is_user": true
      }
    ],
    "num_slots": 3,
    "created_at": "2025-11-06T09:15:43.512Z",
    "status": "Done"
  },
  {
    "booking_id": "BK20251105B2D1C3",
    "slots": [10, 11],
    "ground_id": 2,
    "date": "2025-11-15",
    "players": [
      {
        "name": "John Doe",
        "email": "john@example.com",
        "sort_key": "JOHN",
        "is_user": true
      }
    ],
    "num_slots": 2,
    "created_at": "2025-11-05T14:30:00.000Z",
    "status": "Done"
  }
]
```

#### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| booking_id | string | Unique identifier for the booking |
| slots | array[int] | Sorted list of slot IDs that were booked |
| ground_id | int | ID of the ground/turf where booking was made |
| date | string | Date for which the slots are booked (YYYY-MM-DD) |
| players | array[object] | List of player objects with details |
| players[].name | string | Player's name |
| players[].email | string | Player's email address |
| players[].sort_key | string | First 7 characters of email local part (uppercase) |
| players[].is_user | boolean | Whether this player is the booking user |
| num_slots | int | Total number of slots booked |
| created_at | string | Timestamp when booking was created (ISO 8601) |
| status | string | Current status of booking ("Done", "Rejected", etc.) |

#### Example cURL

```bash
curl -X GET "http://localhost:8000/api/bookings/my/" \
  -H "Authorization: Bearer $TOKEN"
```

#### Example with Python

```python
import requests

url = "http://localhost:8000/api/bookings/my/"
headers = {"Authorization": "Bearer YOUR_JWT_TOKEN"}
response = requests.get(url, headers=headers)
bookings = response.json()
```

---

### 3. Retrieve a Single Booking

**Method:** `GET`  
**URL:** `/api/bookings/{booking_id}/`

Retrieve details of a specific booking. User can only retrieve their own bookings.

#### Example cURL

```bash
curl -X GET http://localhost:8000/api/bookings/BK20251106A3F2E1/ \
  -H "Authorization: Bearer $TOKEN"
```

#### Response

Response matches the shape of a single item from the `/my/` endpoint.

---

### 4. Cancel a Booking

**Method:** `POST`  
**URL:** `/api/bookings/{booking_id}/cancel/`

Cancel a booking by setting its status to 'Rejected' and freeing all associated slots.

#### Validations
1. Booking must belong to the authenticated user
2. Booking must be in 'Done' status
3. Booking date must be in the future

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

| Status Code | Description |
|-------------|-------------|
| 200 OK | Booking cancelled; slots freed |
| 400 Bad Request | Booking is not in "Done" status or date is in the past |
| 403 Forbidden | You are not the owner of this booking |
| 404 Not Found | booking_id doesn't exist |

#### Example cURL

```bash
curl -X POST http://localhost:8000/api/bookings/BK20251106A3F2E1/cancel/ \
  -H "Authorization: Bearer $TOKEN"
```

#### Effects
- Database: Status = 'Rejected'
- Slots: booked = False
- Redis: All slots marked as 'available'

---

### 5. Delete a Booking

**Method:** `DELETE`  
**URL:** `/api/bookings/{booking_id}/`

Alternative endpoint for cancelling a booking. Performs the same action as the cancel endpoint.

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

#### Cancel vs Delete

Both endpoints achieve the same result (setting booking status to "Rejected" and freeing slots):

- **POST /api/bookings/{booking_id}/cancel/** - Semantic cancel endpoint (recommended)
- **DELETE /api/bookings/{booking_id}/** - RESTful delete endpoint

Use whichever fits your API design philosophy. The cancel endpoint is more explicit about the action being performed.

---

### 6. Get Booked Slots

**Method:** `GET`  
**URL:** `/api/bookings/booked-slots/`

Retrieve the list of booked slot IDs for a specific ground on a given date.

#### Query Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| date | string | Yes | Booking date in YYYY-MM-DD format |
| ground_id | int | Yes | ID of the ground to check availability |

#### Success Response (200 OK)

```json
{
  "ground_id": 1,
  "ground_name": "Main Football Ground",
  "date": "2025-11-10",
  "booked_slot_ids": [1, 3, 5, 10, 15, 20]
}
```

#### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| ground_id | int | ID of the ground |
| ground_name | string | Name of the ground |
| date | string | The requested date in YYYY-MM-DD format |
| booked_slot_ids | array[int] | List of slot IDs that are booked, sorted in ascending order |

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

#### Use Cases

1. **Check Slot Availability**: Before making a booking, check which slots are already booked
2. **Display Booking Calendar**: Frontend applications can display a visual calendar showing booked vs. available slots
3. **Real-time Availability Updates**: Check current availability before allowing users to proceed with booking

#### Implementation Details

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

#### 4. TestCancelEndpoint (8 tests)

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

**test_booked_details_relationship**
- ✅ Tests one-to-many relationship
- Validates prefetch_related optimization

**test_can_be_cancelled_property**
- ✅ Tests cancellation eligibility logic
- Future + Done status = True
- Past or Rejected status = False

**test_booking_ordering**
- ✅ Tests default ordering by created_at (descending)

---

### Running Tests

**Run all booking tests:**
```bash
cd src
pytest bookings/tests/ -v
```

**Run specific test class:**
```bash
pytest bookings/tests/test_bookings.py::TestBookingCreation -v
```

**Run booked slots API tests:**
```bash
pytest bookings/tests/test_booked_slots_api.py -v
```

**Run with coverage:**
```bash
pytest bookings/tests/ --cov=bookings --cov-report=html
```

**Run specific test:**
```bash
pytest bookings/tests/test_bookings.py::TestBookingCreation::test_successful_booking_creation -v
```

---

## Setup Instructions

### Prerequisites

- Python 3.8+
- PostgreSQL (Supabase)
- Redis server

### Installation

1. **Clone repository and navigate to backend:**
   ```bash
   cd backend
   ```

2. **Create virtual environment:**
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   ```

3. **Install dependencies:**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables (.env):**
   ```env
   # Redis Configuration
   REDIS_HOST=localhost
   REDIS_PORT=6379
   REDIS_DB=0
   
   # Database Configuration (PostgreSQL/Supabase)
   DATABASE_URL=postgresql://user:password@host:port/dbname
   
   # Django Settings
   SECRET_KEY=your-secret-key
   DEBUG=True
   ALLOWED_HOSTS=localhost,127.0.0.1
   ```

5. **Run migrations:**
   ```bash
   cd src
   python manage.py migrate
   ```

6. **Start Redis (if not running):**
   ```bash
   # macOS (with Homebrew)
   brew services start redis
   
   # Linux
   sudo systemctl start redis
   
   # Manual start
   redis-server
   ```

7. **Run development server:**
   ```bash
   python manage.py runserver
   ```

8. **Verify Redis connection:**
   ```bash
   redis-cli ping
   # Should return: PONG
   ```

### Docker Setup (Alternative)

```bash
# Build and run with Docker Compose
docker-compose up --build

# Run in detached mode
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

---

## Troubleshooting

### Common Issues

#### 409 Conflict on Create
**Cause:** At least one requested slot is already booked  
**Solution:**
- Re-query availability using `/api/bookings/booked-slots/`
- Select different slots
- Check if another user booked simultaneously

#### 400 Bad Request on Create
**Possible Causes:**
- Invalid date format (must be YYYY-MM-DD)
- Past date
- Date more than 14 days in advance
- Slot IDs out of range (1-48)
- Duplicate slot IDs
- Empty players list
- Invalid email format
- Unknown ground_id

**Solution:** Validate all input parameters before sending request

#### 400 on Cancel
**Cause:** Booking status is not "Done" or booking date is in the past  
**Solution:**
- Verify booking status is "Done"
- Check booking date is in the future
- Cannot cancel already rejected/cancelled bookings

#### 401/403 Authentication Errors
**Cause:** Missing or invalid authentication token  
**Solution:**
- Confirm token is valid and not expired
- Include token in Authorization header: `Bearer YOUR_TOKEN`
- For cancel/delete: ensure you own the booking

#### Redis Connection Error
**Cause:** Redis server not running  
**Solution:**
```bash
# Check if Redis is running
redis-cli ping

# Start Redis
redis-server

# Check Redis configuration
redis-cli CONFIG GET "*"
```

#### Database Migration Issues
**Cause:** Schema drift or missing migrations  
**Solution:**
```bash
# For development (SQLite)
rm db.sqlite3
python manage.py migrate

# For production
python manage.py makemigrations
python manage.py migrate
```

#### Lock Timeout (Rare)
**Cause:** Redis lock held too long  
**Solution:**
- Locks auto-expire after 10 seconds
- Check Redis server performance
- Verify network connectivity

---

### Booking Flow Diagrams

#### Successful Booking Flow

```
1. User sends POST /api/bookings/
2. Validate input (date, ground_id, slot_id)
3. Acquire Redis locks for ALL slots (10s TTL)
   ├─ Lock acquired → Continue
   └─ Lock failed → Return 409 "Slot is being booked by another user"
4. Check Redis slot status for each slot
   ├─ Any "booked" → Release locks, Return 409
   └─ All available → Continue
5. Check database for existing bookings
   ├─ Any exists → Update Redis, Release locks, Return 409
   └─ None exist → Continue
6. Create Booking record in DB (atomic transaction)
7. Create Booked_Details records (player × slot combinations)
8. Mark all slots as "booked" in Redis (24h TTL)
9. Release all locks
10. Return 200 with booking_id and details
```

#### Cancellation Flow

```
1. User sends DELETE /api/bookings/{id}/ or POST /cancel/
2. Verify ownership (booking.user == request.user)
   ├─ Not owner → Return 403 Forbidden
   └─ Owner → Continue
3. Check status (must be "Done")
   ├─ Not "Done" → Return 400 Bad Request
   └─ "Done" → Continue
4. Check if future booking
   ├─ Past date → Return 400 Bad Request
   └─ Future → Continue
5. Update Booking status to "Rejected" in DB (atomic transaction)
6. Update Booked_Details (if applicable)
7. Mark all slots as "available" in Redis
8. Return 200 success with slots_cancelled list
```

#### Get Booked Slots Flow

```
1. User sends GET /api/bookings/booked-slots/?date=...&ground_id=...
2. Validate date format
   ├─ Invalid → Return 400 Bad Request
   └─ Valid → Continue
3. Validate ground_id exists
   ├─ Not found → Return 404 Not Found
   └─ Exists → Continue
4. Query Booked_Details for (ground_id, date) where active
5. Extract unique slot_ids and sort
6. Return 200 with booked_slot_ids array
```

---

## Best Practices

### For Frontend Developers

1. **Check Availability First**
   ```javascript
   // Step 1: Get booked slots
   const bookedSlots = await getBookedSlots(groundId, date);
   
   // Step 2: Show available slots to user
   const availableSlots = allSlots.filter(slot => !bookedSlots.includes(slot));
   
   // Step 3: Create booking with selected slots
   await createBooking(date, groundId, selectedSlots, players);
   ```

2. **Handle 409 Conflicts Gracefully**
   ```javascript
   try {
     const booking = await createBooking(...);
   } catch (error) {
     if (error.status === 409) {
       // Refresh availability and retry
       await refreshAvailability();
       showMessage("Slot just booked by someone else. Please select again.");
     }
   }
   ```

3. **Use Optimistic Updates**
   - Update UI immediately when user books
   - Revert if request fails
   - Show loading state during API call

4. **Validate Before Submit**
   - Check date is not in past
   - Check date is within 14 days
   - Ensure at least one player
   - Validate email formats

### For Backend Developers

1. **Always Use Transactions**
   - Wrap booking creation in database transaction
   - Ensure atomicity of multi-slot bookings
   - Rollback on any error

2. **Lock Ordering**
   - Always acquire locks in consistent order (sorted by slot_id)
   - Prevents deadlocks

3. **Timeout Handling**
   - Set appropriate lock TTL (currently 10s)
   - Use try-finally to ensure lock release
   - Log lock acquisition failures

4. **Cache Invalidation**
   - Update Redis when booking created
   - Update Redis when booking cancelled
   - Set appropriate TTLs

---

## Performance Optimization

### Database Indexes

```sql
-- Essential indexes for performance
CREATE INDEX idx_booking_user ON Booking(User_ID);
CREATE INDEX idx_booking_date ON Booking(Date);
CREATE INDEX idx_booking_status ON Booking(Status);
CREATE INDEX idx_booked_details_booking ON Booked_Details(Booking_ID);
CREATE INDEX idx_booked_details_slot ON Booked_Details(Ground_ID, Date, Slot_ID);
CREATE INDEX idx_member_lock ON Booked_Details(Sort_Key, Ground_ID, Date);
```

### Query Optimization

- Use `select_related()` for user relationship
- Use `prefetch_related()` for booked_details
- Filter inactive bookings at database level
- Limit queryset to necessary fields

### Redis Optimization

- Use pipeline for bulk operations
- Set appropriate TTLs (10s for locks, 24h for slot status)
- Use Redis commands efficiently (SET NX for locks)

---

## API Quick Reference

| Endpoint | Method | Purpose | Auth Required |
|----------|--------|---------|---------------|
| `/api/bookings/` | POST | Create booking | ✅ Yes |
| `/api/bookings/my/` | GET | List my bookings | ✅ Yes |
| `/api/bookings/{id}/` | GET | Get single booking | ✅ Yes |
| `/api/bookings/{id}/cancel/` | POST | Cancel booking | ✅ Yes |
| `/api/bookings/{id}/` | DELETE | Delete booking | ✅ Yes |
| `/api/bookings/booked-slots/` | GET | Get booked slots | ✅ Yes |

---

## Version History

- **v1.0** (Nov 6, 2025): Initial release with full booking management
- **v1.1** (Nov 6, 2025): Added Booked Slots API endpoint
- **v1.2** (Nov 9, 2025): 
  - Added `date` field to My Bookings response
  - Consolidated all documentation into single file
  - Updated test documentation

---

## Related Documentation

- [Member Lock System](MEMBER_LOCK_SYSTEM.md) - Details on the sort_key based locking mechanism
- [Performance Optimizations](PERFORMANCE_OPTIMIZATIONS.md) - Database and Redis optimization details
- Django REST Framework: https://www.django-rest-framework.org/
- Redis Python Client: https://redis-py.readthedocs.io/
- pytest Documentation: https://docs.pytest.org/

---

**End of Documentation**
