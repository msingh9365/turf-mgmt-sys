# API Documentation

## Base URL
```
http://localhost:8000/api
```

## Authentication

All API endpoints (except login and registration) require JWT authentication.

### Obtain Token
```http
POST /api/token/
Content-Type: application/json

{
  "username": "your_username",
  "password": "your_password"
}
```

**Response:**
```json
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

### Refresh Token
```http
POST /api/token/refresh/
Content-Type: application/json

{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

### Using Token
Include the access token in the Authorization header:
```http
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc...
```

## User Endpoints

### Get Current User
```http
GET /api/users/me/
Authorization: Bearer {token}
```

**Response:**
```json
{
  "id": 1,
  "username": "john_doe",
  "email": "john@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "user_type": "student",
  "phone_number": "+1234567890",
  "roll_number": "CS2021001",
  "department": "Computer Science",
  "fcm_token": null,
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

### Update Profile
```http
PUT /api/users/update_profile/
Authorization: Bearer {token}
Content-Type: application/json

{
  "first_name": "John",
  "last_name": "Doe",
  "phone_number": "+1234567890",
  "department": "Computer Science"
}
```

### Register New User
```http
POST /api/users/
Content-Type: application/json

{
  "username": "john_doe",
  "email": "john@example.com",
  "password": "secure_password",
  "first_name": "John",
  "last_name": "Doe",
  "user_type": "student",
  "phone_number": "+1234567890",
  "roll_number": "CS2021001",
  "department": "Computer Science"
}
```

## Sports Type Endpoints

### List Sports Types
```http
GET /api/sports-types/
Authorization: Bearer {token}
```

**Response:**
```json
[
  {
    "id": 1,
    "name": "Football",
    "description": "Football ground for 11-a-side matches",
    "icon": "/media/sports_icons/football.png",
    "is_active": true,
    "created_at": "2024-01-01T00:00:00Z",
    "updated_at": "2024-01-01T00:00:00Z"
  }
]
```

## Ground Endpoints

### List Grounds
```http
GET /api/grounds/
Authorization: Bearer {token}
```

**Query Parameters:**
- `sports_type`: Filter by sports type ID
- `is_available`: Filter by availability (true/false)
- `location`: Filter by location

**Response:**
```json
{
  "count": 10,
  "next": null,
  "previous": null,
  "results": [
    {
      "id": 1,
      "name": "Main Football Ground",
      "location": "Sports Complex A",
      "sports_type": 1,
      "sports_type_detail": {
        "id": 1,
        "name": "Football",
        "description": "Football ground"
      },
      "capacity": 22,
      "description": "Main football ground with floodlights",
      "image": "/media/grounds/football_ground.jpg",
      "is_available": true,
      "amenities": "Floodlights, Changing Rooms, Water Facility",
      "time_slots": [],
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

### Get Ground Details
```http
GET /api/grounds/{id}/
Authorization: Bearer {token}
```

### Get Available Time Slots
```http
GET /api/grounds/{id}/available_slots/?date=2024-01-15
Authorization: Bearer {token}
```

**Response:**
```json
[
  {
    "id": 1,
    "ground": 1,
    "start_time": "06:00:00",
    "end_time": "07:00:00",
    "is_available": true
  },
  {
    "id": 2,
    "ground": 1,
    "start_time": "07:00:00",
    "end_time": "08:00:00",
    "is_available": true
  }
]
```

## Booking Endpoints

### List Bookings
```http
GET /api/bookings/
Authorization: Bearer {token}
```

**Query Parameters:**
- `status`: Filter by status (pending, confirmed, cancelled, completed)
- `ground`: Filter by ground ID
- `booking_date`: Filter by date (YYYY-MM-DD)

### Create Booking
```http
POST /api/bookings/
Authorization: Bearer {token}
Content-Type: application/json

{
  "ground": 1,
  "time_slot": 1,
  "booking_date": "2024-01-15",
  "purpose": "Practice match",
  "number_of_players": 22
}
```

**Response:**
```json
{
  "id": 1,
  "user": 1,
  "user_detail": {
    "id": 1,
    "username": "john_doe"
  },
  "ground": 1,
  "ground_detail": {
    "id": 1,
    "name": "Main Football Ground"
  },
  "time_slot": 1,
  "time_slot_detail": {
    "id": 1,
    "start_time": "06:00:00",
    "end_time": "07:00:00"
  },
  "booking_date": "2024-01-15",
  "status": "confirmed",
  "purpose": "Practice match",
  "number_of_players": 22,
  "queue_position": 0,
  "created_at": "2024-01-01T00:00:00Z",
  "updated_at": "2024-01-01T00:00:00Z"
}
```

### Get My Bookings
```http
GET /api/bookings/my_bookings/
Authorization: Bearer {token}
```

### Cancel Booking
```http
POST /api/bookings/{id}/cancel/
Authorization: Bearer {token}
```

**Response:**
```json
{
  "status": "Booking cancelled successfully"
}
```

## Team Endpoints

### List Teams
```http
GET /api/teams/
Authorization: Bearer {token}
```

**Query Parameters:**
- `sports_type`: Filter by sports type ID
- `is_active`: Filter by active status

### Create Team
```http
POST /api/teams/
Authorization: Bearer {token}
Content-Type: application/json

{
  "name": "Campus Warriors",
  "sports_type": 1,
  "max_members": 15,
  "description": "Competitive football team"
}
```

### Get My Teams
```http
GET /api/teams/my_teams/
Authorization: Bearer {token}
```

### Join Team Request
```http
POST /api/teams/{id}/join_request/
Authorization: Bearer {token}
Content-Type: application/json

{
  "message": "I would like to join your team"
}
```

## Team Request Endpoints

### List Team Requests
```http
GET /api/team-requests/
Authorization: Bearer {token}
```

### Accept Team Request
```http
POST /api/team-requests/{id}/accept/
Authorization: Bearer {token}
```

### Reject Team Request
```http
POST /api/team-requests/{id}/reject/
Authorization: Bearer {token}
```

## Notification Endpoints

### List Notifications
```http
GET /api/notifications/
Authorization: Bearer {token}
```

**Query Parameters:**
- `is_read`: Filter by read status (true/false)
- `notification_type`: Filter by type

**Response:**
```json
{
  "count": 5,
  "results": [
    {
      "id": 1,
      "user": 1,
      "notification_type": "booking_confirmed",
      "title": "Booking Confirmed",
      "message": "Your booking for Main Football Ground has been confirmed.",
      "is_read": false,
      "data": {},
      "sent_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

### Mark Notification as Read
```http
POST /api/notifications/{id}/mark_read/
Authorization: Bearer {token}
```

### Mark All Notifications as Read
```http
POST /api/notifications/mark_all_read/
Authorization: Bearer {token}
```

## Booking Queue Endpoints

### List Booking Queue
```http
GET /api/booking-queue/
Authorization: Bearer {token}
```

**Query Parameters:**
- `booking__ground`: Filter by ground ID
- `booking__booking_date`: Filter by date

**Response:**
```json
{
  "count": 3,
  "results": [
    {
      "id": 1,
      "booking": 5,
      "booking_detail": {
        "id": 5,
        "ground_detail": {
          "name": "Main Football Ground"
        },
        "booking_date": "2024-01-15"
      },
      "position": 1,
      "estimated_wait_time": 60,
      "notified": false,
      "created_at": "2024-01-01T00:00:00Z",
      "updated_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

## Error Responses

### 400 Bad Request
```json
{
  "field_name": ["Error message"]
}
```

### 401 Unauthorized
```json
{
  "detail": "Authentication credentials were not provided."
}
```

### 403 Forbidden
```json
{
  "detail": "You do not have permission to perform this action."
}
```

### 404 Not Found
```json
{
  "detail": "Not found."
}
```

### 500 Internal Server Error
```json
{
  "detail": "Internal server error."
}
```
