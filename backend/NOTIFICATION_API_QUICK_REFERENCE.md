# Notification API Quick Reference

Quick reference guide for the Campus Court notification system API.

---

## Base URL
```
https://your-backend-url.com/api/notifications/
```

## Authentication
All endpoints require JWT Bearer token:
```
Authorization: Bearer <your_jwt_token>
```

---

## Endpoints Summary

| Method | Endpoint | Description | Auth Required |
|--------|----------|-------------|---------------|
| POST | `/register/` | Register device for push notifications | ✅ |
| GET | `/` | Get notification history | ✅ |
| GET | `/unread-count/` | Get unread notification count | ✅ |
| PATCH | `/<id>/mark-read/` | Mark single notification as read | ✅ |
| POST | `/mark-all-read/` | Mark all notifications as read | ✅ |
| POST | `/send/` | Send notification (admin) | ✅ |
| POST | `/broadcast/looking-for-players/` | Broadcast player recruitment | ✅ |

---

## Quick Examples

### 1. Register Device
```bash
POST /api/notifications/register/
{
  "device_token": "fcm_token_here",
  "device_type": "android"
}
→ 201: {"detail": "Device registered."}
```

### 2. Get Unread Count
```bash
GET /api/notifications/unread-count/
→ 200: {"unread_count": 5}
```

### 3. Get Notifications
```bash
GET /api/notifications/
→ 200: {
  "count": 25,
  "results": [
    {
      "id": 123,
      "title": "Booking Confirmed!",
      "is_read": false,
      ...
    }
  ]
}
```

### 4. Mark as Read
```bash
PATCH /api/notifications/123/mark-read/
→ 200: {"id": 123, "is_read": true, ...}
```

### 5. Mark All as Read
```bash
POST /api/notifications/mark-all-read/
→ 200: {"detail": "5 notification(s) marked as read.", "count": 5}
```

### 6. Broadcast Looking for Players
```bash
POST /api/notifications/broadcast/looking-for-players/
{
  "sport_id": 1,
  "date": "2025-11-26",
  "slot_ids": [5, 6, 7]
}
→ 202: {
  "detail": "Broadcast notification queued successfully.",
  "sport": "Football",
  "slot_time": "10:00 AM - 11:30 AM"
}
```

---

## Common Response Codes

| Code | Meaning | Common Causes |
|------|---------|---------------|
| 200 | OK | Request successful |
| 201 | Created | Device registered |
| 202 | Accepted | Notification queued |
| 400 | Bad Request | Invalid data, missing fields |
| 401 | Unauthorized | Missing/invalid token |
| 404 | Not Found | Resource doesn't exist or no permission |

---

## Notification Object Structure

```json
{
  "id": 123,
  "user": 45,
  "title": "Notification Title",
  "body": "Notification body text",
  "data": {"custom": "payload"},
  "is_read": false,
  "created_at": "2025-11-25T10:30:00Z"
}
```

---

## Typical Mobile App Flow

```
1. User Login
   ↓
2. Get FCM Token
   ↓
3. POST /register/ (register device)
   ↓
4. GET /unread-count/ (show badge)
   ↓
5. User opens notifications
   ↓
6. GET / (list notifications)
   ↓
7. User taps notification
   ↓
8. PATCH /<id>/mark-read/
   ↓
9. GET /unread-count/ (update badge)
```

---

## Error Handling

### 401 Unauthorized
```json
{"detail": "Authentication credentials were not provided."}
```
**Fix:** Include valid JWT token in Authorization header

### 404 Not Found
```json
{"detail": "Notification not found or you do not have permission to access it."}
```
**Fix:** Check notification ID and ensure it belongs to the authenticated user

### 400 Bad Request
```json
{"device_token": ["This field is required."]}
```
**Fix:** Ensure all required fields are included in request

---

## Testing with cURL

### Test Authentication
```bash
curl -X GET https://api.example.com/api/notifications/unread-count/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Test Device Registration
```bash
curl -X POST https://api.example.com/api/notifications/register/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"device_token": "test_token", "device_type": "android"}'
```

### Test Mark as Read
```bash
curl -X PATCH https://api.example.com/api/notifications/123/mark-read/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## Key Features

✅ Push notifications via FCM  
✅ Read/unread status tracking  
✅ Notification history with pagination  
✅ Bulk mark-all-read operation  
✅ Player recruitment broadcasting  
✅ Automatic booking notifications  
✅ Asynchronous delivery  
✅ Multi-device support per user  

---

For detailed documentation, see: `NOTIFICATION_API_DOCUMENTATION.md`
