# Match Invitation API Documentation

## Overview
The match invitation system allows team captains to invite other teams to play matches. When an invitation is sent, all members of the target team receive a Firebase notification with the captain's contact information and match details.

## Endpoints

### 1. Send Match Invitation

**Endpoint:** `POST /api/teams/invitations/match-invite/`

**Authentication:** Required (JWT Token)

**Permission:** User must be a team captain

**Request Body:**
```json
{
  "target_team_id": 2,
  "message": "Let's play a friendly match this Saturday!",
  "preferred_date": "2025-12-01",
  "ground_id": 1
}
```

**Required Fields:**
- `target_team_id` (integer): ID of the team to invite

**Optional Fields:**
- `message` (string, max 500 chars): Custom message to include with invitation
- `preferred_date` (date, YYYY-MM-DD): Suggested match date
- `ground_id` (integer): Preferred venue/ground ID

**Validation Rules:**
- Sender must be captain of a team
- Cannot invite own team
- Teams must play the same sport
- Target team must exist
- Ground must exist (if provided)

**Success Response (201 Created):**
```json
{
  "message": "Match invitation sent successfully.",
  "invitation_id": 42,
  "target_team": "Lightning Bolts",
  "members_notified": 5
}
```

**Error Responses:**
- `400 Bad Request`: Invalid data, self-invitation, or different sports
- `403 Forbidden`: User is not a team captain
- `404 Not Found`: Target team not found

---

### 2. List Sent Invitations

**Endpoint:** `GET /api/teams/invitations/sent/`

**Authentication:** Required (JWT Token)

**Permission:** User must be a team captain

**Description:** Returns all match invitations sent by the requesting user's captained teams.

**Success Response (200 OK):**
```json
{
  "message": "Sent invitations retrieved successfully.",
  "count": 3,
  "invitations": [
    {
      "invitation_id": 42,
      "sender_name": "John Doe",
      "sender_email": "john@example.com",
      "recipient_name": "Jane Smith",
      "recipient_email": "jane@example.com",
      "type": "MATCH_INVITE",
      "type_display": "Match Invite",
      "team_name": "Lightning Bolts",
      "sport_name": "Tennis",
      "status": "SENT",
      "status_display": "Sent",
      "match_details": {
        "sender_team_id": 1,
        "sender_team_name": "Thunder Strikers",
        "sender_captain_email": "john@example.com",
        "sender_captain_name": "John Doe",
        "message": "Let's play this Saturday!",
        "preferred_date": "2025-12-01",
        "ground_id": 1,
        "ground_name": "Court 1"
      },
      "created_at": "2025-11-26T10:30:00Z",
      "expiry_time": null
    }
  ]
}
```

**Non-Captain Response:**
```json
{
  "message": "You are not a captain of any team.",
  "invitations": []
}
```

---

### 3. List Received Invitations

**Endpoint:** `GET /api/teams/invitations/received/`

**Authentication:** Required (JWT Token)

**Permission:** User must be a team captain

**Description:** Returns all pending match invitations received by teams where the requesting user is captain.

**Success Response (200 OK):**
```json
{
  "message": "Received invitations retrieved successfully.",
  "count": 2,
  "invitations": [
    {
      "invitation_id": 43,
      "sender_name": "Alice Cooper",
      "sender_email": "alice@example.com",
      "recipient_name": "John Doe",
      "recipient_email": "john@example.com",
      "type": "MATCH_INVITE",
      "type_display": "Match Invite",
      "team_name": "Thunder Strikers",
      "sport_name": "Tennis",
      "status": "SENT",
      "status_display": "Sent",
      "match_details": {
        "sender_team_id": 3,
        "sender_team_name": "Ace Masters",
        "sender_captain_email": "alice@example.com",
        "sender_captain_name": "Alice Cooper",
        "message": "Challenge accepted?",
        "preferred_date": "2025-12-05"
      },
      "created_at": "2025-11-26T11:15:00Z",
      "expiry_time": null
    }
  ]
}
```

**Non-Captain Response:**
```json
{
  "message": "You are not a captain of any team.",
  "invitations": []
}
```

---

## Firebase Notification Format

When a match invitation is sent, all members of the target team receive a Firebase Cloud Messaging (FCM) notification:

**Notification Title:**
```
Match Invitation from Thunder Strikers
```

**Notification Body:**
```
Thunder Strikers wants to play a match with your team (Lightning Bolts).

Message: Let's play a friendly match this Saturday!

Preferred Date: 2025-12-01
Venue: Court 1

Contact John Doe at john@example.com to arrange the match.
```

**Data Payload:**
```json
{
  "type": "MATCH_INVITE_RECEIVED",
  "invitation_id": "42",
  "sender_team_id": "1",
  "sender_team_name": "Thunder Strikers",
  "sender_captain_email": "john@example.com",
  "sender_captain_name": "John Doe",
  "preferred_date": "2025-12-01",
  "ground_id": "1",
  "ground_name": "Court 1",
  "team_id": "2",
  "team_name": "Lightning Bolts",
  "notification_type": "MATCH_INVITE_RECEIVED"
}
```

**Note:** All values in the data payload are strings (FCM requirement).

---

## Database Schema

### Invitation Model Extension

The `Invitation` model has been extended with a `match_details` JSONField:

```python
match_details = models.JSONField(
    null=True, 
    blank=True,
    help_text="For MATCH_INVITE type: stores sender_team_id, sender_captain_email, message, preferred_date, ground_id"
)
```

**Match Details Structure:**
```json
{
  "sender_team_id": 1,
  "sender_team_name": "Thunder Strikers",
  "sender_captain_email": "john@example.com",
  "sender_captain_name": "John Doe",
  "message": "Optional custom message",
  "preferred_date": "2025-12-01",
  "ground_id": 1,
  "ground_name": "Court 1"
}
```

---

## Usage Example

### Python/Requests
```python
import requests

# Login and get token
auth_response = requests.post(
    "http://localhost:8000/api/auth/login/",
    json={"email": "captain@example.com", "password": "password123"}
)
token = auth_response.json()["token"]

# Send match invitation
headers = {"Authorization": f"Bearer {token}"}
invitation_data = {
    "target_team_id": 5,
    "message": "Let's have a friendly match!",
    "preferred_date": "2025-12-15",
    "ground_id": 2
}

response = requests.post(
    "http://localhost:8000/api/teams/invitations/match-invite/",
    json=invitation_data,
    headers=headers
)

print(response.json())
# Output: {"message": "Match invitation sent successfully.", "invitation_id": 42, ...}

# List sent invitations
sent = requests.get(
    "http://localhost:8000/api/teams/invitations/sent/",
    headers=headers
)
print(sent.json())

# List received invitations
received = requests.get(
    "http://localhost:8000/api/teams/invitations/received/",
    headers=headers
)
print(received.json())
```

### cURL
```bash
# Send match invitation
curl -X POST http://localhost:8000/api/teams/invitations/match-invite/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "target_team_id": 5,
    "message": "Let'\''s play!",
    "preferred_date": "2025-12-15"
  }'

# List sent invitations
curl -X GET http://localhost:8000/api/teams/invitations/sent/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"

# List received invitations
curl -X GET http://localhost:8000/api/teams/invitations/received/ \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

---

## Future Enhancements

The following features are planned for future releases:

1. **Accept/Decline Invitations:** Allow target team captains to respond to invitations
2. **Invitation Expiry:** Auto-expire invitations after X days
3. **Duplicate Prevention:** Check for pending invitations between same teams
4. **Notification Preferences:** Allow users to opt-in/out of match invitation notifications
5. **Booking Integration:** Optionally create slot bookings when invitation is accepted

---

## Testing

Comprehensive test suite available in `teams/tests/test_match_invitations.py` covering:

- Successful invitation creation
- Captain-only permission enforcement
- Self-invitation prevention
- Same-sport validation
- Ground preference handling
- Sent/received invitation listing
- Authentication requirements
- Edge cases and error handling

Run tests:
```bash
python manage.py test teams.tests.test_match_invitations
# or
pytest teams/tests/test_match_invitations.py -v
```

---

## Migration

Migration file: `teams/migrations/0007_invitation_match_details.py`

Adds the `match_details` JSONField to the `Invitation` model. Run migration:
```bash
python manage.py migrate teams
```
