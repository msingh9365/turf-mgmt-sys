# Booking API Documentation

## Overview
This document consolidates various booking-related APIs for better clarity and understanding.

## Booked Slots API
- Ground is stored per entry in Booked_Details (one row per player per slot).
- Player sort key = first 7 characters of the email local part, uppercased.
  - On create, the system:
    1) Filters candidate users by derived sort key,
    2) Then matches email within those candidates,

### Parameters
| Parameter  | Type   | Required | Description                              |
|-----------|--------|----------|------------------------------------------|
| date      | string | Yes      | Booking date in `YYYY-MM-DD` format     |
| ground_id | int    | Yes      | ID of the ground to check availability  |

### Example Request
```bash
GET /api/bookings/booked-slots/?date=2025-11-10&ground_id=1
Authorization: Bearer <your_jwt_token>
```

### Example Usage
#### Using cURL
```bash
curl -X GET "http://localhost:8000/api/bookings/booked-slots/?date=2025-11-10&ground_id=1" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

#### Using Python requests
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
```

## Booking API
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

---

## Additional Information
For more details, refer to the individual API documentation files that have been merged into this document.