# Booked Slots API - Quick Start Guide

## Overview
The new Booked Slots API endpoint allows you to retrieve a list of booked slot IDs for a specific ground on a given date.

## API Endpoint

```
GET /api/bookings/booked-slots/
```

## Authentication
Requires JWT token authentication.

## Request Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `date` | string | Yes | Date in YYYY-MM-DD format |
| `ground_id` | integer | Yes | ID of the ground |

## Example Usage

### Using cURL

```bash
curl -X GET "http://localhost:8000/api/bookings/booked-slots/?date=2025-11-10&ground_id=1" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Using Python requests

```python
import requests

url = "http://localhost:8000/api/bookings/booked-slots/"
headers = {
    "Authorization": "Bearer YOUR_JWT_TOKEN"
}
params = {
    "date": "2025-11-10",
    "ground_id": 1
}

response = requests.get(url, headers=headers, params=params)
print(response.json())
```

### Using JavaScript/Fetch

```javascript
const url = new URL('http://localhost:8000/api/bookings/booked-slots/');
url.searchParams.append('date', '2025-11-10');
url.searchParams.append('ground_id', '1');

fetch(url, {
  method: 'GET',
  headers: {
    'Authorization': 'Bearer YOUR_JWT_TOKEN'
  }
})
  .then(response => response.json())
  .then(data => console.log(data));
```

## Response Format

### Success (200 OK)

```json
{
  "ground_id": 1,
  "ground_name": "Main Football Ground",
  "date": "2025-11-10",
  "booked_slot_ids": [1, 3, 5, 10, 15, 20]
}
```

### No Bookings (200 OK)

```json
{
  "ground_id": 1,
  "ground_name": "Main Football Ground",
  "date": "2025-11-10",
  "booked_slot_ids": []
}
```

### Error Responses

**Missing date parameter (400)**
```json
{
  "error": "Missing required parameter: date"
}
```

**Invalid ground_id (400)**
```json
{
  "error": "Invalid ground_id: must be an integer"
}
```

**Ground not found (404)**
```json
{
  "error": "Ground with ID 999 does not exist"
}
```

## Slot ID Reference

Slots are numbered 1-48, representing 30-minute intervals throughout the day:

- Slot 1: 00:00 - 00:30
- Slot 2: 00:30 - 01:00
- Slot 3: 01:00 - 01:30
- ...
- Slot 48: 23:30 - 24:00

## Implementation Details

The endpoint queries the `Slot` table directly:
- Filters by ground, date, and `booked=True`
- Returns slot IDs in ascending order
- Lightweight and fast (no complex joins)

## Use Cases

1. **Check availability before booking**: Display available slots to users
2. **Calendar view**: Show booked vs. available time slots
3. **Real-time updates**: Verify current availability before proceeding with booking
