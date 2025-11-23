# Notifications App

This app provides push notification support for the backend using Firebase Cloud Messaging (FCM).

## Setup

1. **Add to INSTALLED_APPS**
   - Already done: `notifications`

2. **Firebase Service Account**
   
   **For Local Development:**
   - Place your service account JSON file (e.g. `campus-court-firebase-adminsdk-fbsvc-5a6d8c607a.json`) in the `notifications/` directory.
   - **Do NOT commit this file to git.** It is already in `.gitignore`.
   
   **For Production/Render Deployment:**
   - Add the entire JSON content as an environment variable in Render:
     - Variable name: `FIREBASE_SERVICE_ACCOUNT_JSON`
     - Value: Paste the complete JSON content from your service account file
   - The app will automatically detect and use the environment variable in production.3. **Install Dependency**
  - Install the required package:
    ```bash
    pip install firebase-admin
    ```

4. **Migrations**
   - Run:
     ```bash
     python manage.py makemigrations notifications
     python manage.py migrate
     ```

## API Endpoints

All endpoints require authentication (JWT/session).

### Register Device
- `POST /api/notifications/register/`
- Registers or updates a device token for the logged-in user.
- Example:
  ```bash
  curl -X POST http://localhost:8000/api/notifications/register/ \
    -H "Authorization: Bearer <JWT_TOKEN>" \
    -H "Content-Type: application/json" \
    -d '{"device_token": "abc123", "device_type": "android"}'
  ```

### Send Notification
- `POST /api/notifications/send/`
- Sends a notification to a user or broadcasts to all users.
- Example (to user):
  ```bash
  curl -X POST http://localhost:8000/api/notifications/send/ \
    -H "Authorization: Bearer <JWT_TOKEN>" \
    -H "Content-Type: application/json" \
    -d '{"title": "Hello", "body": "World", "user_id": 1}'
  ```
- Example (broadcast):
  ```bash
  curl -X POST http://localhost:8000/api/notifications/send/ \
    -H "Authorization: Bearer <JWT_TOKEN>" \
    -H "Content-Type: application/json" \
    -d '{"title": "Hello", "body": "World"}'
  ```

### Get Notification History
- `GET /api/notifications/`
- Retrieves the authenticated user's notification history.
- Example:
  ```bash
  curl -X GET http://localhost:8000/api/notifications/ \
    -H "Authorization: Bearer <JWT_TOKEN>"
  ```

## FCM Integration
- Uses the Firebase service account for secure server-side authentication with FCM.
- See `notifications/utils.py` for sending logic using `firebase-admin`.

## Testing
- Unit tests are in `notifications/tests/test_api.py`.
- Run with:
  ```bash
  pytest src/notifications/tests/
  ```

## Admin
- Manage devices and notifications in Django Admin.

## Code Comments
- All major integration points have docstrings and inline comments for clarity.
