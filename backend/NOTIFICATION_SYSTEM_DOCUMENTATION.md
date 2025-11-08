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

**Example:**
```bash
curl -X POST http://localhost:8000/api/notifications/register/ \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"device_token": "<ANDROID_DEVICE_TOKEN>", "device_type": "android"}'
```

### Send Notification
`POST /api/notifications/send/`
Sends a notification to a user or broadcasts to all users.

**To a specific user:**
```bash
curl -X POST http://localhost:8000/api/notifications/send/ \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Notification", "body": "Hello from backend!", "user_id": <USER_ID>}'
```

**Broadcast to all users:**
```bash
curl -X POST http://localhost:8000/api/notifications/send/ \
  -H "Authorization: Bearer <JWT_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"title": "Broadcast", "body": "This is a broadcast message"}'
```

### Get Notification History
`GET /api/notifications/`
Retrieves the authenticated user's notification history.

**Example:**
```bash
curl -X GET http://localhost:8000/api/notifications/ \
  -H "Authorization: Bearer <JWT_TOKEN>"
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
