# Notification System Documentation

This document describes the setup, integration, and testing of the push notification system for the Campus Court backend using Firebase Cloud Messaging (FCM).

---

## 1. Overview
- Sends push notifications to Android devices via FCM.
- Stores device tokens and notification history in the database.
- Uses Firebase service account for secure server-side authentication.
- API endpoints are protected by authentication (JWT/session).

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

## 4. Testing

### Manual Testing
1. Register a device token using the API.
2. Send a notification to the device/user.
3. Check notification history via API.
4. Verify the notification is received on the Android device.
5. Check Django Admin for device and notification records.

### Automated Testing
Run unit tests:
```bash
pytest src/notifications/tests/
```

---

## 5. Troubleshooting
- Ensure the Firebase service account is set up correctly.
- Check backend logs for errors.
- Make sure device tokens are valid and current.
- Verify environment variable is set in production.

---

## 6. Security Notes
- Never commit the service account JSON file to version control.
- Always use environment variables for secrets in production.
- All notification endpoints require authentication.

---

## 7. References
- [Firebase Admin SDK Python Docs](https://firebase.google.com/docs/admin/setup)
- [Django REST Framework Docs](https://www.django-rest-framework.org/)
- [Render Environment Variables](https://render.com/docs/environment-variables)

---

**Maintainer:** Backend Team
