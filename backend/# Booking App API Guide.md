# Booking App API Guide

Last updated: 2025-11-06

This document explains how to create, list, retrieve, and cancel bookings.

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

Typical success response (201 Created):
```json
{
  "booking_id": "BKG-20251106-000123",
  "booked_on": "2025-11-06T09:15:43.512Z",
  "user": {
    "id": 42,
    "email": "owner@example.com"
  },
  "date": "2025-11-20",
  "slots": [17, 18, 19],
  "details": [
    {
      "player_name": "Alex Morgan",
      "player_email": "alex@example.com",
      "sort_key": "ALEX",
      "ground_id": 3,
      "slot_id": 17,
      "is_user": false
    },
    {
      "player_name": "Alex Morgan",
      "player_email": "alex@example.com",
      "sort_key": "ALEX",
      "ground_id": 3,
      "slot_id": 18,
      "is_user": false
    },
    {
      "player_name": "Alex Morgan",
      "player_email": "alex@example.com",
      "sort_key": "ALEX",
      "ground_id": 3,
      "slot_id": 19,
      "is_user": false
    },
    {
      "player_name": "Sam Lee",
      "player_email": "sam.lee@example.com",
      "sort_key": "SAM.LEE",
      "ground_id": 3,
      "slot_id": 17,
      "is_user": true
    }
  ]
}
```

Common errors:
- 400 Bad Request: invalid date format, slots out of range, duplicate slots, empty players, unknown ground_id
- 401 Unauthorized: missing/invalid token
- 409 Conflict: at least one requested slot is already booked (response includes the conflicting `slot_id`)
- 422 Unprocessable Entity: combined validation failed (e.g., sport rules about min players, if enforced)

Notes:
- Sort keys are derived on the server; you don’t need to send them.
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
      "booking_id": "BKG-20251106-000123",
      "booked_on": "2025-11-06T09:15:43.512Z",
      "date": "2025-11-20",
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
      "booking_id": "BKG-20251101-000099",
      "booked_on": "2025-11-01T18:01:00.000Z",
      "date": "2025-11-05",
      "slots": [21, 22],
      "details": [ /* ... */ ]
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
curl -X GET http://localhost:8000/api/bookings/BKG-20251106-000123/ \
  -H "Authorization: Bearer $TOKEN"
```

Response matches the shape of a single item from `/my/`.

---

### 4) Cancel (delete) a booking

- Method: DELETE
- URL: `/api/bookings/{booking_id}/`
- Effects:
  - Only the user who created the booking can cancel it.
  - All associated Booked_Details rows are removed.
  - All booked slots in the booking are freed (set to available).

Example:
```bash
curl -X DELETE http://localhost:8000/api/bookings/BKG-20251106-000123/ \
  -H "Authorization: Bearer $TOKEN"
```

Typical responses:
- 204 No Content: booking cancelled; slots freed
- 403 Forbidden: you are not the owner
- 404 Not Found: booking_id doesn’t exist or is not accessible

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
  -d '{"date":"2025-11-20","ground_id":3,"slots":[17,18,19],"players":[{"name":"Alex","email":"alex@example.com"}]}'
```

List:
```bash
curl -sS -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/bookings/my/
```

Cancel:
```bash
curl -sS -X DELETE -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/bookings/BKG-20251106-000123/
```

---

## Troubleshooting

- 409 on create: at least one requested slot is already booked. Re-query availability and retry different slots.
- 400 on create: validate `date`, `ground_id`, slot range/uniqueness, players list, and email formats.
- 401/403: confirm token is valid and you own the booking.
- SQLite migrations (dev only): on schema drift errors (e.g., “no such table”), dump data if needed, remove `db.sqlite3`, and run `python manage.py migrate` again.