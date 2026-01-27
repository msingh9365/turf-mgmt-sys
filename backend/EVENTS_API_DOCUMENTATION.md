# Events API - Complete Documentation

**Last Updated:** 2025-11-28  
**Version:** 2.0  
**Status:** Production Ready - Captain-Only Event Creation

---

## Table of Contents

1. [Overview](#overview)
2. [Authentication & Permissions](#authentication--permissions)
3. [API Endpoints](#api-endpoints)
4. [Request/Response Examples](#requestresponse-examples)
5. [Error Handling](#error-handling)
6. [Business Rules](#business-rules)
7. [Code Examples](#code-examples)

---

## Overview

### Purpose
The Events API provides functionality for creating, managing, and discovering sports events and tournaments. Only team captains can create events, ensuring event quality and accountability.

### Key Features
✅ **Captain-Only Event Creation** - Only users who are captains of at least one team can create events  
✅ **Unauthenticated Read Access** - Anyone can view and discover events  
✅ **Creator Ownership** - Event creators maintain full control regardless of future captain status  
✅ **Admin Override** - Admin users can modify any event  
✅ **Automatic Date Validation** - Ensures event dates are logical and in the future  
✅ **Lifecycle Management** - Auto-completion and auto-deletion of old events  
✅ **Sport Filtering** - Filter events by sport ID  
✅ **Featured Events** - Curated list of upcoming events  

### Tech Stack
- **Framework**: Django 5 + Django REST Framework
- **Database**: PostgreSQL (Supabase) / SQLite (local)
- **Authentication**: JWT (via rest_framework_simplejwt)
- **Testing**: pytest + pytest-django

---

## Authentication & Permissions

### Permission Model

The Events API uses a custom permission class `IsCaptainOrReadOnly` with the following rules:

| Action | Anonymous | Authenticated Non-Captain | Captain | Admin |
|--------|-----------|---------------------------|---------|-------|
| **List Events** (GET /api/events/) | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Retrieve Event** (GET /api/events/{id}/) | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Create Event** (POST /api/events/) | ❌ No | ❌ No | ✅ Yes | ✅ Yes* |
| **Update Event** (PUT/PATCH /api/events/{id}/) | ❌ No | ❌ No (unless creator) | ✅ Yes (if creator) | ✅ Yes |
| **Delete Event** (DELETE /api/events/{id}/) | ❌ No | ❌ No (unless creator) | ✅ Yes (if creator) | ✅ Yes |
| **My Events** (GET /api/events/mine/) | ❌ No | ✅ Yes | ✅ Yes | ✅ Yes |
| **Featured Events** (GET /api/events/featured/) | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |

\* Admin users must still be captains to create events

### Captain Status Verification

**At Event Creation:**
- System checks: `Team.objects.filter(captain=request.user).exists()`
- User must be captain of **at least one team** in any sport
- Validation occurs at both permission class level (403 error) and serializer level (400 error)

**After Event Creation:**
- Event creator maintains full ownership via `created_by` field
- Former captains can still update/delete their existing events
- Former captains **cannot** create new events until they become captain again
- Captain status is only checked at creation time

### Authentication
All write operations require JWT authentication:
```http
Authorization: Bearer <jwt_access_token>
```

Obtain JWT tokens via:
```http
POST /api/auth/token/
{
  "email": "user@example.com",
  "password": "password123"
}
```

---

## API Endpoints

### 1. List Events
Retrieve all published and recently completed events.

**Endpoint:** `GET /api/events/`  
**Authentication:** None required  
**Permissions:** Public access

**Query Parameters:**
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `sport_id` | integer | No | Filter events by sport ID (e.g., 101=Football, 102=Cricket) |

**Response:** `200 OK`
```json
[
  {
    "id": 1,
    "sport_id": 101,
    "title": "Inter-College Football Championship",
    "description": "Annual football tournament",
    "poster_id": "poster_football_2025.jpg",
    "starts_at": "2025-12-15T10:00:00Z",
    "ends_at": "2025-12-17T18:00:00Z",
    "location_text": "Main Sports Ground",
    "organizer_name": "John Doe",
    "organizer_contact": "+91-9876543210",
    "status": "published",
    "is_completed": false,
    "days_until_start": 17
  }
]
```

**Lifecycle Filtering:**
- Only shows events within 3 days of completion
- Auto-excludes events older than 3 days past `ends_at`
- Shows `published` and `completed` status events

---

### 2. Retrieve Event Details
Get detailed information about a specific event.

**Endpoint:** `GET /api/events/{id}/`  
**Authentication:** None required  
**Permissions:** Public access

**Response:** `200 OK`
```json
{
  "id": 1,
  "sport_id": 101,
  "title": "Inter-College Football Championship",
  "poster_id": "poster_football_2025.jpg",
  "description": "Annual football tournament with prizes",
  "location_text": "Main Sports Ground",
  "starts_at": "2025-12-15T10:00:00Z",
  "ends_at": "2025-12-17T18:00:00Z",
  "organizer_name": "John Doe",
  "organizer_contact": "+91-9876543210",
  "status": "published",
  "is_completed": false,
  "creator_name": "John Doe",
  "created_at": "2025-11-20T14:30:00Z",
  "updated_at": "2025-11-20T14:30:00Z"
}
```

**Error Response:** `404 Not Found`
```json
{
  "detail": "Not found."
}
```

---

### 3. Create Event
Create a new event. **Requires team captain status.**

**Endpoint:** `POST /api/events/`  
**Authentication:** Required (JWT)  
**Permissions:** User must be captain of at least one team

**Request Body:**
```json
{
  "sport_id": 101,
  "poster_id": "poster_football_2025.jpg",
  "title": "Inter-College Football Championship",
  "description": "Annual football tournament with prizes",
  "location_text": "Main Sports Ground",
  "starts_at": "2025-12-15T10:00:00Z",
  "ends_at": "2025-12-17T18:00:00Z",
  "organizer_name": "John Doe",
  "organizer_contact": "+91-9876543210"
}
```

**Field Validation:**
| Field | Type | Required | Constraints |
|-------|------|----------|-------------|
| `sport_id` | integer | Yes | Sport ID reference (e.g., 101, 102) |
| `poster_id` | string | Yes | Poster filename/identifier (max 200 chars) |
| `title` | string | Yes | Event title (max 120 chars) |
| `description` | string | No | Event description (text) |
| `location_text` | string | Yes | Venue location (max 200 chars) |
| `starts_at` | datetime (ISO 8601) | Yes | Must be in the future |
| `ends_at` | datetime (ISO 8601) | Yes | Must be after `starts_at` |
| `organizer_name` | string | No* | Organizer name (max 100 chars) |
| `organizer_contact` | string | Yes | Contact number (max 30 chars) |

\* Auto-filled with user's name if not provided

**Success Response:** `201 Created`
```json
{
  "id": 1,
  "sport_id": 101,
  "poster_id": "poster_football_2025.jpg",
  "title": "Inter-College Football Championship",
  "description": "Annual football tournament with prizes",
  "location_text": "Main Sports Ground",
  "starts_at": "2025-12-15T10:00:00Z",
  "ends_at": "2025-12-17T18:00:00Z",
  "organizer_name": "John Doe",
  "organizer_contact": "+91-9876543210"
}
```

**Error Responses:**

**403 Forbidden** - User is not a team captain
```json
{
  "detail": "You must be a team captain to create events"
}
```

**400 Bad Request** - Validation error (non-captain)
```json
{
  "non_field_errors": [
    "You must be a team captain to create events"
  ]
}
```

**400 Bad Request** - Invalid dates
```json
{
  "starts_at": [
    "Event start time must be in the future."
  ]
}
```

```json
{
  "ends_at": [
    "Event end time must be after start time."
  ]
}
```

---

### 4. Update Event
Update an existing event. **Requires creator or admin.**

**Endpoint:** `PUT /api/events/{id}/` or `PATCH /api/events/{id}/`  
**Authentication:** Required (JWT)  
**Permissions:** User must be the event creator or admin

**Request Body:** (same as Create Event)

**Success Response:** `200 OK`
```json
{
  "id": 1,
  "sport_id": 101,
  "poster_id": "poster_football_2025_updated.jpg",
  "title": "Updated Championship Title",
  "description": "Updated description",
  "location_text": "Updated Ground",
  "starts_at": "2025-12-15T10:00:00Z",
  "ends_at": "2025-12-17T18:00:00Z",
  "organizer_name": "John Doe",
  "organizer_contact": "+91-9876543210"
}
```

**Error Response:** `403 Forbidden` - Not the creator or admin
```json
{
  "detail": "You do not have permission to perform this action."
}
```

**Note:** Former captains can update their own events even after losing captain status.

---

### 5. Delete Event
Delete an existing event. **Requires creator or admin.**

**Endpoint:** `DELETE /api/events/{id}/`  
**Authentication:** Required (JWT)  
**Permissions:** User must be the event creator or admin

**Success Response:** `204 No Content`

**Error Response:** `403 Forbidden` - Not the creator or admin
```json
{
  "detail": "You do not have permission to perform this action."
}
```

---

### 6. My Events
Retrieve all events created by the authenticated user.

**Endpoint:** `GET /api/events/mine/`  
**Authentication:** Required (JWT)  
**Permissions:** Authenticated users only

**Response:** `200 OK`
```json
[
  {
    "id": 1,
    "sport_id": 101,
    "title": "My First Tournament",
    "description": "Tournament I organized",
    "poster_id": "poster_1.jpg",
    "starts_at": "2025-12-15T10:00:00Z",
    "ends_at": "2025-12-17T18:00:00Z",
    "location_text": "Main Ground",
    "organizer_name": "John Doe",
    "organizer_contact": "+91-9876543210",
    "status": "published",
    "is_completed": false,
    "days_until_start": 17
  },
  {
    "id": 5,
    "sport_id": 102,
    "title": "My Cricket Event",
    "description": "Cricket tournament",
    "poster_id": "poster_5.jpg",
    "starts_at": "2026-01-10T09:00:00Z",
    "ends_at": "2026-01-12T17:00:00Z",
    "location_text": "Cricket Stadium",
    "organizer_name": "John Doe",
    "organizer_contact": "+91-9876543210",
    "status": "published",
    "is_completed": false,
    "days_until_start": 43
  }
]
```

**Notes:**
- Events are ordered by creation date (most recent first)
- Includes events from when user was captain, even if they are no longer captain
- Useful for managing personal event portfolio

---

### 7. Featured Events
Retrieve a limited list of upcoming featured events.

**Endpoint:** `GET /api/events/featured/`  
**Authentication:** None required  
**Permissions:** Public access

**Query Parameters:**
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `limit` | integer | No | 5 | Maximum number of events to return |

**Response:** `200 OK`
```json
[
  {
    "id": 1,
    "sport_id": 101,
    "title": "Inter-College Football Championship",
    "description": "Annual football tournament",
    "poster_id": "poster_football_2025.jpg",
    "starts_at": "2025-12-15T10:00:00Z",
    "ends_at": "2025-12-17T18:00:00Z",
    "location_text": "Main Sports Ground",
    "organizer_name": "John Doe",
    "organizer_contact": "+91-9876543210",
    "status": "published",
    "is_completed": false,
    "days_until_start": 17
  }
]
```

**Notes:**
- Only returns published events with `starts_at >= now()`
- Ordered by start date (earliest first)
- Useful for home page or dashboard displays

---

## Request/Response Examples

### Example 1: Non-Captain Attempts to Create Event

**Request:**
```http
POST /api/events/
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc...
Content-Type: application/json

{
  "sport_id": 101,
  "poster_id": "poster.jpg",
  "title": "My Tournament",
  "description": "A great tournament",
  "location_text": "Main Ground",
  "starts_at": "2025-12-15T10:00:00Z",
  "ends_at": "2025-12-17T18:00:00Z",
  "organizer_name": "Non Captain",
  "organizer_contact": "1234567890"
}
```

**Response:**
```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{
  "detail": "You must be a team captain to create events"
}
```

---

### Example 2: Captain Creates Event Successfully

**Request:**
```http
POST /api/events/
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc...
Content-Type: application/json

{
  "sport_id": 101,
  "poster_id": "poster.jpg",
  "title": "Football Championship",
  "description": "Annual tournament",
  "location_text": "Main Ground",
  "starts_at": "2025-12-15T10:00:00Z",
  "ends_at": "2025-12-17T18:00:00Z",
  "organizer_contact": "9876543210"
}
```

**Response:**
```http
HTTP/1.1 201 Created
Content-Type: application/json

{
  "id": 1,
  "sport_id": 101,
  "poster_id": "poster.jpg",
  "title": "Football Championship",
  "description": "Annual tournament",
  "location_text": "Main Ground",
  "starts_at": "2025-12-15T10:00:00Z",
  "ends_at": "2025-12-17T18:00:00Z",
  "organizer_name": "Captain Name",
  "organizer_contact": "9876543210"
}
```

---

### Example 3: Former Captain Updates Their Event

**Scenario:** User created event as captain, then transferred captaincy to another user.

**Request:**
```http
PUT /api/events/1/
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc...
Content-Type: application/json

{
  "sport_id": 101,
  "poster_id": "poster_updated.jpg",
  "title": "Updated Championship",
  "description": "Updated description",
  "location_text": "Updated Ground",
  "starts_at": "2025-12-15T10:00:00Z",
  "ends_at": "2025-12-17T18:00:00Z",
  "organizer_name": "Updated Name",
  "organizer_contact": "9876543210"
}
```

**Response:**
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "id": 1,
  "sport_id": 101,
  "poster_id": "poster_updated.jpg",
  "title": "Updated Championship",
  "description": "Updated description",
  "location_text": "Updated Ground",
  "starts_at": "2025-12-15T10:00:00Z",
  "ends_at": "2025-12-17T18:00:00Z",
  "organizer_name": "Updated Name",
  "organizer_contact": "9876543210"
}
```

**Note:** Update succeeds because `created_by` field matches the authenticated user, regardless of current captain status.

---

### Example 4: Different Captain Attempts to Update Another's Event

**Request:**
```http
PUT /api/events/1/
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc...
Content-Type: application/json

{
  "sport_id": 101,
  "poster_id": "hacked.jpg",
  "title": "Hacked Event",
  ...
}
```

**Response:**
```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{
  "detail": "You do not have permission to perform this action."
}
```

---

### Example 5: Admin Deletes Any Event

**Request:**
```http
DELETE /api/events/1/
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc... (admin token)
```

**Response:**
```http
HTTP/1.1 204 No Content
```

**Note:** Admin users can modify/delete any event, even if they didn't create it.

---

## Error Handling

### Error Response Format

All error responses follow DRF standard format:

**Single Field Error:**
```json
{
  "field_name": [
    "Error message"
  ]
}
```

**Multiple Field Errors:**
```json
{
  "starts_at": [
    "Event start time must be in the future."
  ],
  "ends_at": [
    "Event end time must be after start time."
  ]
}
```

**Non-Field Errors:**
```json
{
  "non_field_errors": [
    "You must be a team captain to create events"
  ]
}
```

**Permission Denied:**
```json
{
  "detail": "You must be a team captain to create events"
}
```

### HTTP Status Codes

| Code | Meaning | When Used |
|------|---------|-----------|
| `200 OK` | Success | GET requests, successful updates |
| `201 Created` | Resource created | Successful POST to create event |
| `204 No Content` | Success, no body | Successful DELETE |
| `400 Bad Request` | Validation error | Invalid data in request body |
| `401 Unauthorized` | Authentication required | Missing or invalid JWT token |
| `403 Forbidden` | Permission denied | Non-captain creating event, non-creator updating event |
| `404 Not Found` | Resource not found | Event ID doesn't exist |
| `500 Internal Server Error` | Server error | Unexpected server-side error |

### Common Error Scenarios

#### 1. Not Authenticated
**Cause:** Missing or invalid JWT token for protected endpoints

**Error:**
```json
{
  "detail": "Authentication credentials were not provided."
}
```

#### 2. Not a Captain
**Cause:** User attempting to create event without being a team captain

**Error (Permission Level):**
```json
{
  "detail": "You must be a team captain to create events"
}
```

**Error (Validation Level):**
```json
{
  "non_field_errors": [
    "You must be a team captain to create events"
  ]
}
```

#### 3. Invalid Date
**Cause:** Event start date in the past

**Error:**
```json
{
  "starts_at": [
    "Event start time must be in the future."
  ]
}
```

#### 4. Invalid Date Range
**Cause:** Event end date before start date

**Error:**
```json
{
  "ends_at": [
    "Event end time must be after start time."
  ]
}
```

#### 5. Unauthorized Modification
**Cause:** User attempting to modify event they didn't create (and not admin)

**Error:**
```json
{
  "detail": "You do not have permission to perform this action."
}
```

---

## Business Rules

### Captain Verification

**Rule:** Only users who are captains of at least one team can create events.

**Implementation:**
- Checked via: `Team.objects.filter(captain=request.user).exists()`
- Verified at permission class level (403 response)
- Verified at serializer level (400 response)
- Captain status across **all sports** counts (not sport-specific)

**Example Scenarios:**

| Scenario | Can Create Event? |
|----------|-------------------|
| User is captain of Football team | ✅ Yes |
| User is captain of Cricket team | ✅ Yes |
| User is captain of multiple teams | ✅ Yes |
| User is member but not captain | ❌ No |
| User has no team affiliations | ❌ No |
| User was captain but transferred role | ❌ No (for new events) |

### Ownership Persistence

**Rule:** Event creators maintain ownership regardless of captain status changes.

**Implications:**
- Former captains can update their existing events
- Former captains can delete their existing events
- Former captains **cannot** create new events
- Ownership tracked via `created_by` field (immutable)

**Lifecycle:**
1. User is captain → Creates event → `created_by` set to user
2. User transfers captaincy → No longer captain
3. User can still modify their event (ownership preserved)
4. User cannot create new events (captain check fails)

### Admin Override

**Rule:** Admin users (`is_admin=True`) can modify any event.

**Permissions:**
- Can update any event regardless of `created_by`
- Can delete any event regardless of `created_by`
- Must still be captain to create events (no exception)

### Date Validation

**Rules:**
1. `starts_at` must be in the future (> `now()`)
2. `ends_at` must be after `starts_at`
3. Validated on both create and update

**Example:**
```python
# Invalid: Past date
"starts_at": "2020-01-01T10:00:00Z"  # ❌ Error

# Invalid: End before start
"starts_at": "2025-12-17T10:00:00Z"
"ends_at": "2025-12-15T10:00:00Z"     # ❌ Error

# Valid
"starts_at": "2025-12-15T10:00:00Z"
"ends_at": "2025-12-17T18:00:00Z"     # ✅ OK
```

### Event Lifecycle

**Auto-Completion:**
- Events automatically change to `completed` status when `ends_at` passes
- Implemented in `Event.save()` method

**Auto-Deletion Threshold:**
- Events older than 3 days past `ends_at` are excluded from list queries
- Not physically deleted (for data retention)
- Filtered at queryset level

**Status Transitions:**
```
published → completed (automatic when ends_at passes)
published → cancelled (manual by creator/admin)
completed → (excluded from list after 3 days)
```

### Sport Filtering

**Rule:** Events can be filtered by `sport_id` query parameter.

**Behavior:**
- Optional parameter: `/api/events/?sport_id=101`
- Invalid sport IDs are silently ignored (no error)
- Returns empty list if no events match

---

## Code Examples

### 1. Create Event as Captain (Python)

```python
import requests

# Authenticate and get JWT token
auth_response = requests.post(
    "https://api.example.com/api/auth/token/",
    json={
        "email": "captain@example.com",
        "password": "password123"
    }
)
token = auth_response.json()["access"]

# Create event
headers = {"Authorization": f"Bearer {token}"}
event_data = {
    "sport_id": 101,
    "poster_id": "poster_football.jpg",
    "title": "Winter Football Championship",
    "description": "Annual winter tournament",
    "location_text": "Main Sports Complex",
    "starts_at": "2025-12-20T09:00:00Z",
    "ends_at": "2025-12-22T18:00:00Z",
    "organizer_contact": "+91-9876543210"
}

response = requests.post(
    "https://api.example.com/api/events/",
    json=event_data,
    headers=headers
)

if response.status_code == 201:
    event = response.json()
    print(f"Event created with ID: {event['id']}")
else:
    print(f"Error: {response.json()}")
```

### 2. List Events with Sport Filter (JavaScript)

```javascript
// Fetch football events (sport_id=101)
fetch('https://api.example.com/api/events/?sport_id=101')
  .then(response => response.json())
  .then(events => {
    console.log(`Found ${events.length} football events`);
    events.forEach(event => {
      console.log(`${event.title} - ${event.starts_at}`);
    });
  })
  .catch(error => console.error('Error:', error));
```

### 3. Update Event (cURL)

```bash
curl -X PUT https://api.example.com/api/events/1/ \
  -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc..." \
  -H "Content-Type: application/json" \
  -d '{
    "sport_id": 101,
    "poster_id": "updated_poster.jpg",
    "title": "Updated Championship Title",
    "description": "Updated description",
    "location_text": "Updated Venue",
    "starts_at": "2025-12-20T09:00:00Z",
    "ends_at": "2025-12-22T18:00:00Z",
    "organizer_name": "John Doe",
    "organizer_contact": "+91-9876543210"
  }'
```

### 4. Get My Events (Python)

```python
import requests

headers = {"Authorization": f"Bearer {token}"}
response = requests.get(
    "https://api.example.com/api/events/mine/",
    headers=headers
)

my_events = response.json()
print(f"You have created {len(my_events)} events")
for event in my_events:
    print(f"- {event['title']} ({event['status']})")
```

### 5. Check if User Can Create Events (Django)

```python
from teams.models import Team

def can_user_create_events(user):
    """Check if user is a captain of any team."""
    if not user.is_authenticated:
        return False
    return Team.objects.filter(captain=user).exists()

# Usage
if can_user_create_events(request.user):
    # Show "Create Event" button
    pass
else:
    # Show "Become a captain to create events" message
    pass
```

### 6. Handle Event Creation with Error Handling (Python)

```python
import requests

def create_event(token, event_data):
    """Create event with comprehensive error handling."""
    headers = {"Authorization": f"Bearer {token}"}
    
    try:
        response = requests.post(
            "https://api.example.com/api/events/",
            json=event_data,
            headers=headers
        )
        
        if response.status_code == 201:
            event = response.json()
            return {"success": True, "event": event}
        
        elif response.status_code == 403:
            return {
                "success": False,
                "error": "captain_required",
                "message": "You must be a team captain to create events"
            }
        
        elif response.status_code == 400:
            errors = response.json()
            return {
                "success": False,
                "error": "validation_error",
                "details": errors
            }
        
        else:
            return {
                "success": False,
                "error": "unknown",
                "status_code": response.status_code
            }
    
    except requests.exceptions.RequestException as e:
        return {
            "success": False,
            "error": "network_error",
            "message": str(e)
        }

# Usage
result = create_event(token, event_data)
if result["success"]:
    print(f"Event created: {result['event']['id']}")
else:
    if result["error"] == "captain_required":
        print("Error: You need to be a team captain")
    elif result["error"] == "validation_error":
        print(f"Validation errors: {result['details']}")
    else:
        print(f"Error: {result.get('message', 'Unknown error')}")
```

---

## Testing

### Test Coverage

The Events module includes comprehensive pytest test suite:

**Test File:** `events/tests/test_events.py`

**Test Classes:**
- `TestCaptainOnlyEventCreation` - 15 test cases

**Coverage Areas:**
1. ✅ Unauthenticated read access (list, retrieve, featured)
2. ✅ Captain-only event creation
3. ✅ Non-captain rejection with appropriate message
4. ✅ Creator permissions (update, delete)
5. ✅ Former captain ownership persistence
6. ✅ Admin override capabilities
7. ✅ Non-creator blocking
8. ✅ My events endpoint
9. ✅ Date validation (covered by serializer tests)

### Running Tests

```bash
# Run all event tests
pytest events/tests/test_events.py -v

# Run specific test
pytest events/tests/test_events.py::TestCaptainOnlyEventCreation::test_captain_can_create_event -v

# Run with coverage
pytest events/tests/test_events.py --cov=events --cov-report=html
```

---

## Integration Points

### 1. Teams Module
**Dependency:** Events creation requires captain status from Teams module

**Integration:**
```python
from teams.models import Team

# Check captain status
is_captain = Team.objects.filter(captain=request.user).exists()
```

### 2. Sports Module (Bookings)
**Dependency:** Events reference sports via `sport_id`

**Note:** 
- `sport_id` is stored as integer (not foreign key)
- Mapping handled by frontend (101=Football, 102=Cricket, etc.)
- No database constraint enforcement

### 3. Authentication (Users)
**Dependency:** Events track creator via `created_by` foreign key

**Integration:**
```python
from django.contrib.auth import get_user_model

User = get_user_model()
event.created_by  # Returns User instance
```

---

## Future Enhancements

### Potential Features
1. **Event Registration** - Allow users to register/RSVP for events
2. **Team-Event Association** - Link events to specific teams
3. **Event Comments** - Discussion threads for events
4. **Event Categories** - Tag events (tournament, practice, friendly)
5. **Recurring Events** - Support for recurring tournaments
6. **Event Capacity** - Max participants with waitlist
7. **Event Photos** - Gallery of event photos/results
8. **Event Ratings** - Post-event feedback and ratings

---

## Changelog

### Version 2.0 (2025-11-28)
- ✅ Added captain-only event creation requirement
- ✅ Implemented dual validation (permission + serializer)
- ✅ Added ownership persistence after captain transfer
- ✅ Added admin override capabilities
- ✅ Maintained backward compatibility (no breaking changes)
- ✅ Comprehensive test coverage (15 tests)
- ✅ Complete API documentation

### Version 1.0 (Previous)
- Initial events module with authenticated creation
- Basic CRUD operations
- Date validation
- Lifecycle management

---

## Support & Contact

For issues, questions, or contributions related to the Events API:

- **GitHub Issues:** [turf-mgmt-sys/issues](https://github.com/msingh9365/turf-mgmt-sys/issues)
- **Branch:** `feature/events`
- **Documentation:** This file

---

**End of Events API Documentation**
