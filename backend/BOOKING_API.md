# Booking App API Guide

Last updated: 2025-11-06

This document explains how to create, list, retrieve, and cancel bookings.

**Test Status**: ✅ 30/30 tests passing  
**Test Documentation**: See [BOOKING_TESTS.md](./BOOKING_TESTS.md) for comprehensive test coverage details.

## Overview

- Base URL (dev): http://localhost:8000/api/bookings/
- Auth: Bearer token (Authorization: Bearer <token>)
- Content-Type: application/json
- Time slots: integers 1–48 represent 30-minute blocks over a day
  - 1 = 00:00–00:30, 2 = 00:30–01:00, …, 48 = 23:30–00:00

## Data Rules

- Booking stores only booking metadata (booking_id, user who booked, timestamps).
- Ground is stored per entry in Booked_Details (one row per player per slot).
- Player sort key = first 7 characters of the email local part, uppercased.
  - On create, the system:
    1) Filters candidate users by derived sort key,
    2) Then matches email within those candidates,
    3) Sets `is_user` in Booked_Details accordingly.
- Atomicity: a booking either reserves all requested slots or none.
- Concurrency: distributed locks prevent overlapping reservations.

## Endpoints

### 1) Create a booking

- Method: POST
- URL: `/api/bookings/`
- Body:
  - `date` (string, YYYY-MM-DD) — date of play
  - `ground_id` (integer) — ground to book
  - `slots` (array[int]) — requested slot IDs (1–48), unique
  - `players` (array[{ name: string, email: string }]) — list of players

Example request:
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
      { "name": "Sam Lee", "email": "sam.lee@example.com" },
      { "name": "Jordan P", "email": "jordanp@example.org" }
    ]
  }'
```

Typical success response (200 OK):
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

Common errors:
- 400 Bad Request: invalid date format, slots out of range, duplicate slots, empty players, unknown ground_id
- 401 Unauthorized: missing/invalid token
- 409 Conflict: at least one requested slot is already booked (response includes the conflicting `slot_id`)
- 422 Unprocessable Entity: combined validation failed (e.g., sport rules about min players, if enforced)

Notes:
- Sort keys are derived on the server; you don't need to send them.
- If a conflict occurs during processing, the entire booking is rolled back.

---

### 2) List my bookings

- Method: GET
- URL: `/api/bookings/my/`
- Optional query params: `page`, `page_size` (if pagination is enabled)

Example:
```bash
curl -X GET "http://localhost:8000/api/bookings/my/?page=1&page_size=10" \
  -H "Authorization: Bearer $TOKEN"
```

Typical response (200 OK):
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
    },
    {
      "booking_id": "BK20251101B9C4D2",
      "user": {
        "id": 42,
        "email": "owner@example.com"
      },
      "date": "2025-11-05",
      "status": "Done",
      "created_at": "2025-11-01T18:01:00.000Z",
      "ground_id": 2,
      "ground_name": "Field B",
      "sport_name": "Football",
      "slots": [21, 22]
    }
  ]
}
```

---

### 3) Retrieve a single booking

- Method: GET
- URL: `/api/bookings/{booking_id}/`

Example:
```bash
curl -X GET http://localhost:8000/api/bookings/BK20251106A3F2E1/ \
  -H "Authorization: Bearer $TOKEN"
```

Response matches the shape of a single item from `/my/`.

---

### 4) Cancel a booking (NEW dedicated endpoint)

- Method: POST
- URL: `/api/bookings/{booking_id}/cancel/`
- Effects:
  - Only the user who created the booking can cancel it.
  - Booking status is set to "Rejected".
  - All associated slots are freed (set to available).
  - Redis cache is updated to reflect availability.

Example:
```bash
curl -X POST http://localhost:8000/api/bookings/BK20251106A3F2E1/cancel/ \
  -H "Authorization: Bearer $TOKEN"
```

Typical success response (200 OK):
```json
{
  "message": "Booking cancelled successfully (3 slot(s))",
  "booking_id": "BK20251106A3F2E1",
  "status": "Rejected",
  "slots_cancelled": [17, 18, 19]
}
```

Common responses:
- 200 OK: booking cancelled; slots freed
- 400 Bad Request: booking is not in "Done" status or date is in the past
- 403 Forbidden: you are not the owner
- 404 Not Found: booking_id doesn't exist

---

### 5) Delete a booking (existing endpoint)

- Method: DELETE
- URL: `/api/bookings/{booking_id}/`
- Same behavior as cancel endpoint above (sets status to "Rejected", frees slots)

Example:
```bash
curl -X DELETE http://localhost:8000/api/bookings/BK20251106A3F2E1/ \
  -H "Authorization: Bearer $TOKEN"
```

Typical success response (200 OK):
```json
{
  "message": "Booking cancelled successfully (3 slot(s))",
  "booking_id": "BK20251106A3F2E1",
  "slots_cancelled": [17, 18, 19]
}
```

---

## Field and Validation Details

- `date`: required, YYYY-MM-DD, cannot be in the past
- `ground_id`: required, must reference an existing Ground
- `slots`: required, unique list of integers 1–48; server checks existence and availability of each (ground_id, date, slot_id)
- `players`: required, non-empty list of objects with:
  - `name`: non-empty string
  - `email`: valid email
- Internals for each player:
  - `sort_key` = first 7 chars of email local part, uppercased
  - Users are matched by filtering on `sort_key` first, then comparing `email` among those candidates; `is_user` is set accordingly

---

## Operational Notes

- Concurrency: distributed locks protect slot reservation during create/cancel.
- Atomicity: if any slot fails, no Booked_Details or Slot changes are persisted.
- Performance: Booked_Details are bulk-created; slot updates are transactional.

---

## Quick Local Test (macOS)

Create:
```bash
TOKEN="your_jwt_token"
curl -sS -X POST http://localhost:8000/api/bookings/ \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "date":"2025-11-20",
    "ground_id":3,
    "slots":[17,18,19],
    "players":[
      {"name":"Alex","email":"alex@example.com"},
      {"name":"Sam","email":"sam@example.com"}
    ]
  }'
```

List:
```bash
curl -sS -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/bookings/my/
```

Cancel (new endpoint):
```bash
curl -sS -X POST -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/bookings/BK20251106A3F2E1/cancel/
```

Delete (existing endpoint):
```bash
curl -sS -X DELETE -H "Authorization: Bearer $TOKEN" \
  http://localhost:8000/api/bookings/BK20251106A3F2E1/
```

---

## Troubleshooting

- 409 on create: at least one requested slot is already booked. Re-query availability and retry different slots.
- 400 on create: validate `date`, `ground_id`, slot range/uniqueness, players list, and email formats.
- 400 on cancel: booking status is not "Done" or booking date is in the past.
- 401/403: confirm token is valid and you own the booking.
- SQLite migrations (dev only): on schema drift errors (e.g., "no such table"), dump data if needed, remove `db.sqlite3`, and run `python manage.py migrate` again.

---

## Cancel vs Delete

Both endpoints achieve the same result (setting booking status to "Rejected" and freeing slots):

- **POST /api/bookings/{booking_id}/cancel/** - Semantic cancel endpoint (recommended for user-facing apps)
- **DELETE /api/bookings/{booking_id}/** - RESTful delete endpoint (follows standard REST conventions)

Use whichever fits your API design philosophy. The cancel endpoint is more explicit about the action being performed.
