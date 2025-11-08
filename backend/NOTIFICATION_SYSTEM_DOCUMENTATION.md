# Notification System Documentation

This document describes the setup, integration, and testing of the push notification system for the Campus Court backend using Firebase Cloud Messaging (FCM).

---

## 1. Overview
- Sends push notifications to Android devices via FCM.
- Stores device tokens and notification history in the database.
- Uses Firebase service account for secure server-side authentication.
- API endpoints are protected by authentication (JWT/session).
- **Automatic notifications:** Users receive notifications when bookings are created.

---

## 2. Setup

### Local Development
- Place your Firebase service account JSON file (e.g. `campus-court-firebase-adminsdk-fbsvc-5a6d8c607a.json`) in the `src/notifications/` directory.
- Ensure this file is listed in `.gitignore`.

### Production/Render Deployment
- Add the entire JSON content as an environment variable in Render:
  - Key: `FIREBASE_SERVICE_ACCOUNT_JSON`
  - Value: Paste the complete JSON content
- The backend will automatically detect and use the environment variable.

### Install Dependencies
```bash
pip install -r requirements.txt
```

---

## 3. API Endpoints

### Register Device
`POST /api/notifications/register/`

Registers or updates a device token for the logged-in user.

**Request Body:**
```json
{
  "device_token": "string (required) - FCM device token from Android app",
  "device_type": "string (required) - 'android' or 'ios'"
}
```

**Response (201 Created):**
```json
{
  "detail": "Device registered."
}
```

**Error Response (400 Bad Request):**
```json
{
  "device_token": ["This field is required."],
  "device_type": ["This field is required."]
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/api/notifications/register/ \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"device_token": "<ANDROID_DEVICE_TOKEN>", "device_type": "android"}'
```

---

### Send Notification
`POST /api/notifications/send/`

Sends a notification to a specific user or broadcasts to all users.

**Request Body:**
```json
{
  "title": "string (required) - Notification title",
  "body": "string (required) - Notification message body",
  "data": "object (optional) - Additional data payload",
  "user_id": "integer (optional) - Target user ID. If omitted, broadcasts to all users"
}
```

**Response (200 OK):**
```json
{
  "detail": "Notification sent."
}
```

**Error Response (404 Not Found):**
```json
{
  "detail": "User not found."
}
```

**Example - To a specific user:**
```bash
curl -X POST http://localhost:8000/api/notifications/send/ \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Notification", "body": "Hello from backend!", "user_id": <USER_ID>}'
```

**Example - Broadcast to all users:**
```bash
curl -X POST http://localhost:8000/api/notifications/send/ \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"title": "Broadcast", "body": "This is a broadcast message"}'
```

---

### Get Notification History
`GET /api/notifications/`

Retrieves the authenticated user's notification history.

**Request:** No body required.

**Response (200 OK):**
```json
[
  {
    "id": 1,
    "user": 5,
    "title": "Booking Confirmed!",
    "body": "Your booking BK20251109ABC123 for Main Ground on 2025-11-15 is confirmed.",
    "data": {
      "booking_id": "BK20251109ABC123",
      "date": "2025-11-15",
      "status": "Done",
      "type": "booking_confirmation"
    },
    "is_read": false,
    "created_at": "2025-11-09T10:30:00Z"
  },
  {
    "id": 2,
    "user": 5,
    "title": "Players Needed for Football!",
    "body": "John Doe (john@example.com) is looking for players for Football on 2025-11-15 at 18:00. Interested? Contact them!",
    "data": {
      "type": "looking_for_players",
      "sport_id": "1",
      "sport_name": "Football",
      "date": "2025-11-15",
      "slot_id": "36",
      "slot_time": "18:00",
      "user_name": "John Doe",
      "user_email": "john@example.com"
    },
    "is_read": false,
    "created_at": "2025-11-09T09:15:00Z"
  }
]
```

**Example:**
```bash
curl -X GET http://localhost:8000/api/notifications/ \
  -H "Authorization: Bearer <JWT_TOKEN>"
```

---

### Broadcast Looking for Players
`POST /api/notifications/broadcast/looking-for-players/`

Broadcasts a notification to all app users that the authenticated user is looking for players for a specific sport, date, and time.

**Request Body:**
```json
{
  "sport_id": "integer (required) - ID of the sport",
  "date": "string (required) - Date of the game in YYYY-MM-DD format",
  "slot_id": "integer (required) - Time slot ID for the game"
}
```

**Response (200 OK):**
```json
{
  "detail": "Broadcast notification sent successfully.",
  "recipients": 25,
  "sport": "Football",
  "date": "2025-11-15",
  "slot_time": "18:00"
}
```

**Error Response (400 Bad Request - Missing fields):**
```json
{
  "detail": "sport_id, date, and slot_id are required."
}
```

**Error Response (404 Not Found - Invalid sport):**
```json
{
  "detail": "Sport not found."
}
```

**Error Response (404 Not Found - Invalid slot):**
```json
{
  "detail": "Slot not found."
}
```

**Example:**
```bash
curl -X POST http://localhost:8000/api/notifications/broadcast/looking-for-players/ \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"sport_id": 1, "date": "2025-11-15", "slot_id": 36}'
```

**Notification Message Sent to All Users:**
- **Title:** "Players Needed for Football!"
- **Body:** "John Doe (john@example.com) is looking for players for Football on 2025-11-15 at 18:00. Interested? Contact them!"
- **Data Payload:**
```json
{
  "type": "looking_for_players",
  "sport_id": "1",
  "sport_name": "Football",
  "date": "2025-11-15",
  "slot_id": "36",
  "slot_time": "18:00",
  "user_name": "John Doe",
  "user_email": "john@example.com"
}
```

---

## 4. Automatic Notifications

### Booking Confirmation
Users automatically receive a push notification when a new booking is created with "Done" status.

**Notification Details:**
- **Title:** "Booking Confirmed!"
- **Body:** Includes booking ID, ground name, and date
- **Data Payload:** Contains booking_id, date, status, and type

**Implementation:**
- Uses Django signals (`post_save` on `Booking` model)
- Located in `bookings/signals.py`
- Error-safe: Notification failures do not prevent booking creation

### Looking for Players Broadcast
Users can broadcast to all app users that they're looking for players for a specific sport, date, and time slot.

**Notification Details:**
- **Title:** "Players Needed for [Sport]!"
- **Body:** "[User Name] ([User Email]) is looking for players for [Sport] on [Date] at [Time]. Interested? Contact them!"
- **Data Payload:** Contains sport details, date, slot info, user name, and user contact information

**API Endpoint:** `POST /api/notifications/broadcast/looking-for-players/`

**Future Enhancement:** Can be extended to target specific user segments based on:
- Sport preferences
- Location/ground preferences
- Skill level
- Past playing history

---

## 5. Testing

### Manual Testing
1. Register a device token using the API.
2. Create a booking via the booking API.
3. Verify the notification is received on the Android device.
4. Check notification history via API.
5. Check Django Admin for device and notification records.

### Automated Testing
Run unit tests:
```bash
pytest src/notifications/tests/
pytest src/bookings/tests/test_notifications.py
```

**Test Coverage:**
- Device registration and management
- Notification sending and history
- Automatic booking notifications
- Broadcast looking for players functionality
- Error handling and edge cases

---

## 6. Troubleshooting
- Ensure the Firebase service account is set up correctly.
- Check backend logs for errors (notifications are logged extensively).
- Make sure device tokens are valid and current.
- Verify environment variable is set in production.
- If bookings create successfully but notifications don't send:
  - Check that the user has registered devices
  - Verify Firebase credentials are valid
  - Check application logs for signal errors

---

## 7. Security Notes
- Never commit the service account JSON file to version control.
- Always use environment variables for secrets in production.
- All notification endpoints require authentication.
- Notification failures are logged but do not disrupt core functionality.

---

## 8. References
- [Firebase Admin SDK Python Docs](https://firebase.google.com/docs/admin/setup)
- [Django REST Framework Docs](https://www.django-rest-framework.org/)
- [Render Environment Variables](https://render.com/docs/environment-variables)

---

**Maintainer:** Backend Team
