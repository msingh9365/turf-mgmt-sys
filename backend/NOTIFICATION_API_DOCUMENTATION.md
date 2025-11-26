# Notification System API Documentation

Complete API reference for the Campus Court notification system using Firebase Cloud Messaging (FCM).

---

## Table of Contents
1. [Overview](#overview)
2. [Authentication](#authentication)
3. [API Endpoints](#api-endpoints)
   - [Register Device](#1-register-device)
   - [Get Notification History](#2-get-notification-history)
   - [Get Unread Count](#3-get-unread-notification-count)
   - [Mark Single Notification as Read](#4-mark-single-notification-as-read)
   - [Mark All Notifications as Read](#5-mark-all-notifications-as-read)
   - [Send Notification (Admin)](#6-send-notification-admin)
   - [Broadcast Looking for Players](#7-broadcast-looking-for-players)
4. [Error Codes](#error-codes)
5. [Data Models](#data-models)

---

## Overview

The notification system provides:
- Push notifications via Firebase Cloud Messaging (FCM)
- Device token management
- Notification history with read/unread status
- Automatic notifications for booking events
- Broadcasting for player recruitment
- Asynchronous notification delivery

**Base URL:** `https://your-backend-url.com/api/notifications/`

---

## Authentication

All endpoints require authentication using JWT Bearer tokens.

```http
Authorization: Bearer <your_jwt_token>
```

**Error Response (401 Unauthorized):**
```json
{
  "detail": "Authentication credentials were not provided."
}
```

---

## API Endpoints

### 1. Register Device

Register a device token for push notifications.

**Endpoint:** `POST /api/notifications/register/`

**Request Body:**
```json
{
  "device_token": "fcm_device_token_string",
  "device_type": "android"
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| device_token | string | Yes | FCM device token |
| device_type | string | Yes | Device type: `android` or `ios` |

**Success Response (201 Created):**
```json
{
  "detail": "Device registered."
}
```

**Error Responses:**

**400 Bad Request** - Invalid data:
```json
{
  "device_token": ["This field is required."],
  "device_type": ["This field is required."]
}
```

**Example:**
```bash
curl -X POST https://your-backend-url.com/api/notifications/register/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "device_token": "eXmXpl3T0k3n...",
    "device_type": "android"
  }'
```

---

### 2. Get Notification History

Retrieve all notifications for the authenticated user.

**Endpoint:** `GET /api/notifications/`

**Query Parameters:** None

**Success Response (200 OK):**
```json
{
  "count": 25,
  "next": "http://api/notifications/?page=2",
  "previous": null,
  "results": [
    {
      "id": 123,
      "user": 45,
      "title": "Booking Confirmed!",
      "body": "Your booking for Football on 2025-11-25 at 8:00 AM has been confirmed.",
      "data": {
        "type": "booking_confirmation",
        "booking_id": "789",
        "sport": "Football"
      },
      "is_read": false,
      "created_at": "2025-11-25T10:30:00Z"
    },
    {
      "id": 122,
      "user": 45,
      "title": "Players Needed for Cricket!",
      "body": "John (john@iitrpr.ac.in) is looking for players...",
      "data": {
        "type": "looking_for_players",
        "sport_id": "2",
        "date": "2025-11-26"
      },
      "is_read": true,
      "created_at": "2025-11-24T15:20:00Z"
    }
  ]
}
```

**Example:**
```bash
curl -X GET https://your-backend-url.com/api/notifications/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

### 3. Get Unread Notification Count

Get the count of unread notifications for badge display.

**Endpoint:** `GET /api/notifications/unread-count/`

**Query Parameters:** None

**Success Response (200 OK):**
```json
{
  "unread_count": 5
}
```

**Example:**
```bash
curl -X GET https://your-backend-url.com/api/notifications/unread-count/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Use Case:** Display notification badge count in your app UI.

---

### 4. Mark Single Notification as Read

Mark a specific notification as read.

**Endpoint:** `PATCH /api/notifications/<notification_id>/mark-read/`

**Path Parameters:**
| Parameter | Type | Description |
|-----------|------|-------------|
| notification_id | integer | ID of the notification to mark as read |

**Request Body:** None

**Success Response (200 OK):**
```json
{
  "id": 123,
  "user": 45,
  "title": "Booking Confirmed!",
  "body": "Your booking for Football on 2025-11-25 at 8:00 AM has been confirmed.",
  "data": {
    "type": "booking_confirmation",
    "booking_id": "789"
  },
  "is_read": true,
  "created_at": "2025-11-25T10:30:00Z"
}
```

**Error Responses:**

**404 Not Found** - Notification doesn't exist or belongs to another user:
```json
{
  "detail": "Notification not found or you do not have permission to access it."
}
```

**Example:**
```bash
curl -X PATCH https://your-backend-url.com/api/notifications/123/mark-read/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

### 5. Mark All Notifications as Read

Mark all unread notifications for the authenticated user as read.

**Endpoint:** `POST /api/notifications/mark-all-read/`

**Request Body:** None

**Success Response (200 OK):**
```json
{
  "detail": "5 notification(s) marked as read.",
  "count": 5
}
```

**Example:**
```bash
curl -X POST https://your-backend-url.com/api/notifications/mark-all-read/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

**Use Case:** "Mark all as read" button in your notification center.

---

### 6. Send Notification (Admin)

Send a notification to a specific user or broadcast to all users.

**Endpoint:** `POST /api/notifications/send/`

**Request Body:**
```json
{
  "title": "System Maintenance",
  "body": "The system will be under maintenance on Nov 30.",
  "data": {
    "type": "announcement",
    "priority": "high"
  },
  "user_id": 45
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| title | string | Yes | Notification title |
| body | string | Yes | Notification body text |
| data | object | No | Additional data payload |
| user_id | integer | No | Specific user ID (omit to broadcast to all) |

**Success Response (202 Accepted):**
```json
{
  "detail": "Notification queued for delivery."
}
```

**Error Responses:**

**404 Not Found** - User doesn't exist:
```json
{
  "detail": "User not found."
}
```

**Example (to specific user):**
```bash
curl -X POST https://your-backend-url.com/api/notifications/send/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "System Maintenance",
    "body": "Scheduled maintenance tonight at 10 PM",
    "user_id": 45
  }'
```

**Example (broadcast to all):**
```bash
curl -X POST https://your-backend-url.com/api/notifications/send/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "New Feature Available!",
    "body": "Check out the new team formation feature"
  }'
```

---

### 7. Broadcast Looking for Players

Broadcast a notification that you're looking for players for a specific sport and time.

**Endpoint:** `POST /api/notifications/broadcast/looking-for-players/`

**Request Body:**
```json
{
  "sport_id": 1,
  "date": "2025-11-26",
  "slot_ids": [5, 6, 7]
}
```

**Parameters:**
| Field | Type | Required | Description |
|-------|------|----------|-------------|
| sport_id | integer | Yes | ID of the sport |
| date | string | Yes | Date in YYYY-MM-DD format |
| slot_id | integer | No* | Single slot ID |
| slot_ids | array/string | No* | Multiple slot IDs as array or comma-separated string |

*Either `slot_id` or `slot_ids` must be provided.

**Success Response (202 Accepted):**
```json
{
  "detail": "Broadcast notification queued successfully.",
  "sport": "Football",
  "date": "2025-11-26",
  "slot_time": "10:00 AM - 11:30 AM",
  "slot_times": ["10:00 AM", "10:30 AM", "11:00 AM"]
}
```

**Error Responses:**

**400 Bad Request** - Missing required fields:
```json
{
  "detail": "sport_id, date, and at least one slot_id/slot_ids are required."
}
```

**400 Bad Request** - Invalid slot ID format:
```json
{
  "detail": "Invalid slot id: abc"
}
```

**404 Not Found** - Sport doesn't exist:
```json
{
  "detail": "Sport not found."
}
```

**Examples:**

**Single slot:**
```bash
curl -X POST https://your-backend-url.com/api/notifications/broadcast/looking-for-players/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sport_id": 1,
    "date": "2025-11-26",
    "slot_id": 5
  }'
```

**Multiple continuous slots (array):**
```bash
curl -X POST https://your-backend-url.com/api/notifications/broadcast/looking-for-players/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sport_id": 1,
    "date": "2025-11-26",
    "slot_ids": [5, 6, 7]
  }'
```

**Multiple slots (comma-separated string):**
```bash
curl -X POST https://your-backend-url.com/api/notifications/broadcast/looking-for-players/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "sport_id": 1,
    "date": "2025-11-26",
    "slot_ids": "5,6,7"
  }'
```

**Note:** The sender is automatically excluded from receiving the broadcast.

---

## Error Codes

### HTTP Status Codes

| Code | Description | When It Occurs |
|------|-------------|----------------|
| 200 | OK | Request succeeded |
| 201 | Created | Resource created successfully (device registration) |
| 202 | Accepted | Request queued for async processing (notifications) |
| 400 | Bad Request | Invalid request data or missing required fields |
| 401 | Unauthorized | Missing or invalid authentication token |
| 403 | Forbidden | Valid token but insufficient permissions |
| 404 | Not Found | Resource doesn't exist or user lacks access |
| 500 | Internal Server Error | Server-side error occurred |

### Common Error Response Format

```json
{
  "detail": "Error message describing what went wrong"
}
```

### Field-Specific Validation Errors

```json
{
  "field_name": ["Error message for this field"],
  "another_field": ["Another error message"]
}
```

---

## Data Models

### Notification Object

```json
{
  "id": 123,
  "user": 45,
  "title": "Notification Title",
  "body": "Notification body text",
  "data": {
    "key": "value",
    "custom": "data"
  },
  "is_read": false,
  "created_at": "2025-11-25T10:30:00Z"
}
```

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| id | integer | Unique notification ID |
| user | integer | User ID who received the notification |
| title | string | Notification title (max 255 chars) |
| body | string | Notification body text |
| data | object | Optional JSON data payload |
| is_read | boolean | Read status (true/false) |
| created_at | datetime | ISO 8601 timestamp when notification was created |

### UserDevice Object

```json
{
  "id": 10,
  "user": 45,
  "device_token": "fcm_token_string",
  "device_type": "android",
  "last_active": "2025-11-25T10:30:00Z",
  "is_active": true,
  "created_at": "2025-11-01T08:00:00Z"
}
```

**Fields:**
| Field | Type | Description |
|-------|------|-------------|
| id | integer | Unique device ID |
| user | integer | User ID who owns the device |
| device_token | string | FCM device token (max 255 chars) |
| device_type | string | Device type: "android" or "ios" |
| last_active | datetime | Last activity timestamp (auto-updated) |
| is_active | boolean | Whether device is active |
| created_at | datetime | Registration timestamp |

---

## Typical Workflows

### Workflow 1: User Registration & Device Setup

1. User logs in → Receive JWT token
2. Get FCM token from device
3. Call `POST /api/notifications/register/` with device token
4. App is ready to receive notifications

### Workflow 2: Viewing Notifications

1. Call `GET /api/notifications/unread-count/` → Display badge count
2. User opens notification center
3. Call `GET /api/notifications/` → Display notification list
4. User taps a notification → Call `PATCH /api/notifications/<id>/mark-read/`
5. Call `GET /api/notifications/unread-count/` → Update badge

### Workflow 3: Looking for Players

1. User selects sport, date, and time slots
2. Call `POST /api/notifications/broadcast/looking-for-players/`
3. All other users receive push notification
4. Notification saved in database for history
5. Users can view in notification list

### Workflow 4: Automatic Booking Notifications

1. User creates a booking
2. Backend automatically triggers notification
3. User receives push notification
4. Notification appears in history
5. User can mark as read when viewed

---

## Best Practices

### For Mobile/Web Clients:

1. **Register device token immediately after login**
2. **Handle token refresh** - Re-register if FCM token changes
3. **Update unread count on app launch** and after marking notifications as read
4. **Implement pull-to-refresh** in notification list
5. **Store notification data locally** for offline access
6. **Mark as read on tap** - Call mark-read endpoint when user views notification
7. **Handle deep links** - Use notification `data` payload to navigate to relevant screens

### For Backend/Admin:

1. **Use broadcast sparingly** - Avoid spamming users
2. **Include meaningful data payloads** - Help clients handle notifications appropriately
3. **Monitor notification delivery** - Check logs for failed sends
4. **Clean up inactive devices** - Remove devices that haven't been active
5. **Batch operations** - Use mark-all-read for efficiency

---

## Rate Limiting

Currently, there are no rate limits enforced. However, best practices suggest:
- Max 1 broadcast per user per minute
- Max 10 notification list requests per minute per user

---

## Support

For issues or questions:
- Check server logs for detailed error messages
- Verify JWT token is valid and not expired
- Ensure FCM credentials are properly configured
- Test endpoints using curl or Postman before mobile integration

---

**Last Updated:** November 25, 2025
**API Version:** 1.0
