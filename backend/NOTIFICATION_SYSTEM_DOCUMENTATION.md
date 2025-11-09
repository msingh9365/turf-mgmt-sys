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

## 2. Backend Setup

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

## 3. Frontend Integration Guide

### Step 1: Firebase Setup in Flutter/Android App

1. **Add Firebase to your Flutter project:**
   ```yaml
   # pubspec.yaml
   dependencies:
     firebase_core: ^latest_version
     firebase_messaging: ^latest_version
   ```

2. **Initialize Firebase in your app:**
   ```dart
   import 'package:firebase_core/firebase_core.dart';
   import 'package:firebase_messaging/firebase_messaging.dart';

   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp();
     runApp(MyApp());
   }
   ```

3. **Request notification permissions:**
   ```dart
   FirebaseMessaging messaging = FirebaseMessaging.instance;
   
   NotificationSettings settings = await messaging.requestPermission(
     alert: true,
     badge: true,
     sound: true,
   );
   ```

### Step 2: Get Device Token

After user login, obtain the FCM device token:

```dart
Future<String?> getFCMToken() async {
  try {
    String? token = await FirebaseMessaging.instance.getToken();
    print("FCM Token: $token");
    return token;
  } catch (e) {
    print("Error getting FCM token: $e");
    return null;
  }
}
```

### Step 3: Register Device Token with Backend

After successful login and obtaining FCM token, register it with the backend:

```dart
Future<void> registerDeviceToken(String jwtToken, String fcmToken) async {
  final url = Uri.parse('https://your-backend-url.com/api/notifications/register/');
  
  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'device_token': fcmToken,
      'device_type': 'android',
    }),
  );
  
  if (response.statusCode == 201) {
    print('Device registered successfully');
  } else {
    print('Failed to register device: ${response.body}');
  }
}
```

**When to call this:**
- After user logs in successfully
- When FCM token is refreshed (handle token refresh callback)

### Step 4: Handle Incoming Notifications

**Foreground notifications:**
```dart
FirebaseMessaging.onMessage.listen((RemoteMessage message) {
  print('Got a message in foreground!');
  print('Message data: ${message.data}');
  
  if (message.notification != null) {
    print('Title: ${message.notification!.title}');
    print('Body: ${message.notification!.body}');
    
    // Show local notification or update UI
    _showLocalNotification(message);
  }
  
  // Handle data payload
  _handleNotificationData(message.data);
});
```

**Background/Terminated notifications:**
```dart
FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
  print('Notification opened app from background');
  _handleNotificationData(message.data);
});

// Check if app was opened from terminated state
FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
  if (message != null) {
    print('App opened from terminated state');
    _handleNotificationData(message.data);
  }
});
```

**Handle notification data payload:**
```dart
void _handleNotificationData(Map<String, dynamic> data) {
  String type = data['type'] ?? '';
  
  switch (type) {
    case 'booking_confirmation':
      String bookingId = data['booking_id'] ?? '';
      String date = data['date'] ?? '';
      // Navigate to booking details screen
      Navigator.pushNamed(context, '/booking-details', arguments: bookingId);
      break;
      
    case 'looking_for_players':
      String sportId = data['sport_id'] ?? '';
      String sportName = data['sport_name'] ?? '';
      String date = data['date'] ?? '';
      String slotTime = data['slot_time'] ?? '';
      String userName = data['user_name'] ?? '';
      String userEmail = data['user_email'] ?? '';
      
      // Navigate to sport details or show contact dialog
      _showLookingForPlayersDialog(sportName, date, slotTime, userName, userEmail);
      break;
      
    default:
      print('Unknown notification type: $type');
  }
}
```

### Step 5: Fetch Notification History

Retrieve user's notification history:

```dart
Future<List<Notification>> getNotificationHistory(String jwtToken) async {
  final url = Uri.parse('https://your-backend-url.com/api/notifications/');
  
  final response = await http.get(
    url,
    headers: {
      'Authorization': 'Bearer $jwtToken',
    },
  );
  
  if (response.statusCode == 200) {
    List<dynamic> jsonList = jsonDecode(response.body);
    return jsonList.map((json) => Notification.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load notifications');
  }
}
```

### Step 6: Broadcast Looking for Players (Optional)

Allow users to broadcast that they're looking for players:

```dart
Future<void> broadcastLookingForPlayers({
  required String jwtToken,
  required int sportId,
  required String date,
  required int slotId,
}) async {
  final url = Uri.parse('https://your-backend-url.com/api/notifications/broadcast/looking-for-players/');
  
  final response = await http.post(
    url,
    headers: {
      'Authorization': 'Bearer $jwtToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'sport_id': sportId,
      'date': date,
      'slot_id': slotId,
    }),
  );
  
  if (response.statusCode == 200) {
    var data = jsonDecode(response.body);
    print('Broadcast sent to ${data['recipients']} users');
  } else {
    print('Failed to broadcast: ${response.body}');
  }
}
```

### Step 7: Handle Token Refresh

Firebase tokens can expire or change. Handle token refresh:

```dart
FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
  print('FCM Token refreshed: $newToken');
  // Register the new token with your backend
  registerDeviceToken(yourJwtToken, newToken);
});
```

### Step 8: Logout - Deactivate Device

When user logs out, you can optionally mark their device as inactive or delete the token:

```dart
Future<void> deactivateDevice(String jwtToken) async {
  // Option 1: Call a backend endpoint to mark device inactive
  // Option 2: Delete FCM token locally
  await FirebaseMessaging.instance.deleteToken();
}
```

---

## 4. API Endpoints

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
- **Note:** The user who initiates the broadcast will NOT receive the notification themselves

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

### Backend Issues
- Ensure the Firebase service account is set up correctly.
- Check backend logs for errors (notifications are logged extensively).
- Make sure device tokens are valid and current.
- Verify environment variable is set in production.
- If bookings create successfully but notifications don't send:
  - Check that the user has registered devices
  - Verify Firebase credentials are valid
  - Check application logs for signal errors

### Frontend/Mobile Issues
- **Notifications not received:**
  - Verify Firebase is initialized in the app
  - Check that FCM token was successfully retrieved
  - Ensure device token was registered with backend (check API response)
  - Verify notification permissions were granted
  - Check if the app is in foreground/background (different handlers needed)

- **Token registration fails:**
  - Ensure JWT token is valid and not expired
  - Check network connectivity
  - Verify backend API endpoint URL is correct

- **Data payload not accessible:**
  - Check `message.data` in notification handler
  - Ensure you're listening to the correct Firebase events
  - Verify data structure matches expected format

- **App doesn't open on notification tap:**
  - Implement `onMessageOpenedApp` listener
  - Check `getInitialMessage` for terminated state
  - Verify deep-linking/navigation logic

### Common Integration Issues

**Issue**: Device token keeps changing
- **Solution**: Implement token refresh listener and re-register with backend

**Issue**: Notifications received but not displayed
- **Solution**: For foreground notifications, implement local notification display

**Issue**: Can't get user details from notification
- **Solution**: Access `message.data` object, not just `message.notification`

---

## 7. Security Notes
- Never commit the service account JSON file to version control.
- Always use environment variables for secrets in production.
- All notification endpoints require authentication.
- Notification failures are logged but do not disrupt core functionality.
- **Frontend**: Never expose JWT tokens in logs or insecure storage.
- **Frontend**: Store FCM tokens securely on the device.

---

## 8. Complete Frontend Integration Checklist

### Initial Setup
- [ ] Add Firebase dependencies to pubspec.yaml
- [ ] Initialize Firebase in main.dart
- [ ] Configure Firebase project with Android app (google-services.json)
- [ ] Request notification permissions

### Authentication Flow
- [ ] After successful login, get FCM token
- [ ] Register FCM token with backend API
- [ ] Store JWT token securely for API calls

### Notification Handling
- [ ] Implement foreground notification listener
- [ ] Implement background notification listener (onMessageOpenedApp)
- [ ] Implement terminated state handler (getInitialMessage)
- [ ] Handle data payload and route to appropriate screens

### Token Management
- [ ] Implement token refresh listener
- [ ] Re-register new tokens with backend
- [ ] Delete token on logout

### User Features
- [ ] Display notification history screen
- [ ] Implement "Looking for Players" broadcast feature
- [ ] Handle notification tap navigation
- [ ] Show unread notification badge/count

### Testing
- [ ] Test foreground notifications
- [ ] Test background notifications
- [ ] Test terminated state notifications
- [ ] Test deep-linking from notifications
- [ ] Test token refresh flow
- [ ] Test logout and token deletion

---

## 9. References
- [Firebase Admin SDK Python Docs](https://firebase.google.com/docs/admin/setup)
- [Firebase Cloud Messaging Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/client)
- [FlutterFire Messaging Package](https://pub.dev/packages/firebase_messaging)
- [Django REST Framework Docs](https://www.django-rest-framework.org/)
- [Render Environment Variables](https://render.com/docs/environment-variables)
- [FCM Data Messages](https://firebase.google.com/docs/cloud-messaging/concept-options#data_messages)

---

**Maintainer:** Backend Team
