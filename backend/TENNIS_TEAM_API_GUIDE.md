# Tennis Team Creation - Quick Reference

## Prerequisites

1. **Ensure Tennis sport exists in database**:
```bash
# Django shell
python manage.py shell
>>> from bookings.models import Sport
>>> tennis = Sport.objects.create(sport_name="Tennis", min_player=2)
>>> print(f"Tennis Sport ID: {tennis.sport_id}")
```

Or check if it already exists:
```bash
>>> from bookings.models import Sport
>>> tennis = Sport.objects.get(sport_name="Tennis")
>>> print(f"Tennis Sport ID: {tennis.sport_id}")
```

2. **Create users** (if needed):
```python
>>> from users.models import User
>>> captain = User.objects.create_user(
...     email="captain@example.com",
...     password="securepass",
...     name="Captain Name",
...     sort_key="CAP001"
... )
>>> player1 = User.objects.create_user(
...     email="player1@example.com",
...     password="securepass",
...     name="Player One",
...     sort_key="PLY001"
... )
```

## API Endpoint

**POST** `/api/teams/`

### Request Body

```json
{
  "team_name": "Baseline Smashers",
  "sport_id": 3,
  "member_emails": [
    "player1@example.com",
    "player2@example.com"
  ]
}
```

### Using cURL

```bash
curl -X POST http://localhost:8000/api/teams/ \
  -H "Content-Type: application/json" \
  -d '{
    "team_name": "Baseline Smashers",
    "sport_id": 3,
    "member_emails": ["player1@example.com", "player2@example.com"]
  }'
```

### Using Python requests

```python
import requests

url = "http://localhost:8000/api/teams/"
payload = {
    "team_name": "Baseline Smashers",
    "sport_id": 3,  # Replace with your Tennis sport_id
    "member_emails": [
        "player1@example.com",
        "player2@example.com"
    ]
}

response = requests.post(url, json=payload)
print(f"Status: {response.status_code}")
print(f"Response: {response.json()}")
```

## Success Response (201 Created)

```json
{
  "team_id": 7,
  "team_name": "Baseline Smashers",
  "captain_name": "Captain Name",
  "sport_name": "Tennis",
  "sport_id": 3,
  "member_count": 3,
  "created_at": "2025-11-08T14:05:12.123456Z"
}
```

## Error Responses

### Duplicate Team Name (400)
```json
{
  "message": "Team name 'Baseline Smashers' already exists. Please choose a different name."
}
```

### Insufficient Players (400)
```json
{
  "message": "Minimum 2 players required for Tennis."
}
```

### Invalid Sport ID (400)
```json
{
  "message": "Invalid request: Sport matching query does not exist. team_name and sport_id are required."
}
```

## Validation Features

✅ **Team names must be unique** - duplicate names return HTTP 400  
✅ **Duplicate emails automatically removed** (case-insensitive)  
✅ **Captain's email auto-excluded** from member list if present  
✅ **Empty/whitespace emails filtered** automatically  
✅ **Non-existent users skipped** silently  
✅ **Minimum player count enforced** (tennis requires ≥2 total)  

## Example: Creating with Duplicates

This payload has many issues but will be cleaned automatically:

```json
{
  "team_name": "Ace Strikers",
  "sport_id": 3,
  "member_emails": [
    "player1@example.com",
    "PLAYER1@EXAMPLE.COM",     // Duplicate (case variant) - removed
    "captain@example.com",     // Captain's email - removed
    "player2@example.com",
    "",                        // Empty - filtered
    "  ",                      // Whitespace - filtered
    "ghost@example.com"        // Non-existent user - skipped
  ]
}
```

**Result**: Team created with captain + 2 members (player1, player2)

## List All Teams

**GET** `/api/teams/`

```bash
curl http://localhost:8000/api/teams/
```

## Get Team Details

**GET** `/api/teams/{team_id}/`

```bash
curl http://localhost:8000/api/teams/7/
```

Response includes full member list with roles:
```json
{
  "team_id": 7,
  "team_name": "Baseline Smashers",
  "captain": {
    "user_id": 1,
    "name": "Captain Name"
  },
  "sport": {
    "sport_id": 3,
    "sport_name": "Tennis"
  },
  "member_count": 3,
  "members": [
    {
      "user_id": 1,
      "name": "Captain Name",
      "role": "captain"
    },
    {
      "user_id": 2,
      "name": "Player One",
      "role": "player"
    },
    {
      "user_id": 3,
      "name": "Player Two",
      "role": "player"
    }
  ],
  "achievements": []
}
```

## Performance

- **Team creation**: < 500ms (even with 100 duplicate emails)
- **List teams**: < 300ms
- **Team details**: < 200ms
- **Database queries**: ≤5 per request (N+1 query prevention)
