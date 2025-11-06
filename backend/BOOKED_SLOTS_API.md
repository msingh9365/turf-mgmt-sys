# Booked Slots API

## Overview
This API endpoint retrieves the list of booked slot IDs for a specific ground on a given date. It queries the `Slot` table to find all slots that have been marked as booked.

## Endpoint

### Get Booked Slots
**URL:** `GET /api/bookings/booked-slots/`

**Authentication:** Required (JWT Token)

**Description:** Returns a list of slot IDs that are already booked for the specified ground and date.

---

## Request

### Query Parameters

| Parameter  | Type   | Required | Description                              |
|-----------|--------|----------|------------------------------------------|
| date      | string | Yes      | Booking date in `YYYY-MM-DD` format     |
| ground_id | int    | Yes      | ID of the ground to check availability  |

### Example Request

```bash
GET /api/bookings/booked-slots/?date=2025-11-10&ground_id=1
Authorization: Bearer <your_jwt_token>
```

---

## Response

### Success Response (200 OK)

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

### Error Responses

#### Missing Date Parameter (400 Bad Request)
```json
{
  "error": "Missing required parameter: date"
}
```

#### Missing Ground ID Parameter (400 Bad Request)
```json
{
  "error": "Missing required parameter: ground_id"
}
```

#### Invalid Date Format (400 Bad Request)
```json
{
  "error": "Invalid date format. Use YYYY-MM-DD"
}
```

#### Invalid Ground ID (400 Bad Request)
```json
{
  "error": "Invalid ground_id: must be an integer"
}
```

#### Ground Not Found (404 Not Found)
```json
{
  "error": "Ground with ID 999 does not exist"
}
```

#### Unauthorized (401 Unauthorized)
```json
{
  "detail": "Authentication credentials were not provided."
}
```

---

## Use Cases

### 1. Check Slot Availability
Before making a booking, clients can check which slots are already booked to show available slots to users.

```bash
curl -X GET "http://localhost:8000/api/bookings/booked-slots/?date=2025-11-10&ground_id=1" \
  -H "Authorization: Bearer your_jwt_token"
```

### 2. Display Booking Calendar
Frontend applications can use this endpoint to display a visual calendar showing booked vs. available slots.

```javascript
// Example: Fetch booked slots for a week
const dates = ['2025-11-10', '2025-11-11', '2025-11-12'];
const groundId = 1;

const bookedSlots = await Promise.all(
  dates.map(date => 
    fetch(`/api/bookings/booked-slots/?date=${date}&ground_id=${groundId}`)
      .then(r => r.json())
  )
);
```

### 3. Real-time Availability Updates
Check current availability before allowing users to proceed with booking.

---

## Implementation Details

### Database Query
The endpoint queries the `Slot` table with the following filters:
- `ground` = specified ground_id
- `date` = specified date
- `booked` = True

Results are ordered by `slot_id` in ascending order.

### Performance
- Uses indexed fields (`ground`, `date`, `booked`)
- Returns only slot IDs (lightweight response)
- No joins required (direct table query)

---

## Notes

1. **Slot ID Range**: Slots are numbered 1-48 based on 30-minute divisions of 24 hours
   - Slot 1: 00:00-00:30
   - Slot 2: 00:30-01:00
   - ...
   - Slot 48: 23:30-24:00

2. **Empty Results**: If no slots are booked for the given date and ground, `booked_slot_ids` will be an empty array `[]`

3. **Authentication**: This endpoint requires user authentication via JWT token

4. **Cross-Ground Independence**: Bookings are ground-specific; the same slot_id on different grounds are independent

---

## Testing

Run the test suite for this endpoint:

```bash
# Run all booked slots API tests
pytest backend/src/bookings/tests/test_booked_slots_api.py -v

# Run specific test
pytest backend/src/bookings/tests/test_booked_slots_api.py::TestBookedSlotsAPI::test_get_booked_slots_with_bookings -v
```

---

## Related Endpoints

- `POST /api/bookings/` - Create a new booking
- `GET /api/bookings/my/` - Get user's bookings
- `DELETE /api/bookings/{id}/` - Cancel a booking

---

## Version History

- **v1.0** (Nov 6, 2025): Initial release
