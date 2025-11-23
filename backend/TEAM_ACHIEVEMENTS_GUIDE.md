# Team Achievements Usage Guide

## Overview
Teams can now store up to 2 achievements using a JSONField in the database. This provides a simple, flexible way to track team accomplishments without requiring a separate database table.

## Data Structure

Achievements are stored as a JSON array of objects. Each achievement object should have:
- `title` (required): The name of the achievement
- `description` (optional): Details about the achievement
- `date` (optional): When the achievement was earned

### Example Structure
```json
[
  {
    "title": "Regional Champions 2024",
    "description": "Won the regional tournament",
    "date": "2024-11-05"
  },
  {
    "title": "Undefeated Season",
    "description": "10-0 record in regular season",
    "date": "2024-10-20"
  }
]
```

## API Usage

### Creating a Team with Achievements
```bash
POST /api/teams/
Content-Type: application/json

{
  "team_name": "Thunder Hawks",
  "sport_id": 1,
  "member_emails": ["player1@example.com", "player2@example.com"],
  "achievements": [
    {
      "title": "League Champions",
      "description": "2024 Spring League Winners",
      "date": "2024-05-15"
    }
  ]
}
```

### Updating Team Achievements
```bash
PATCH /api/teams/{team_id}/
Content-Type: application/json

{
  "achievements": [
    {
      "title": "Tournament Winners",
      "description": "City Championship 2024",
      "date": "2024-11-08"
    },
    {
      "title": "Best Defense Award",
      "description": "Lowest goals conceded in season",
      "date": "2024-10-30"
    }
  ]
}
```

### Getting Team with Achievements
```bash
GET /api/teams/{team_id}/

Response:
{
  "team_id": 1,
  "team_name": "Thunder Hawks",
  "captain_name": "John Doe",
  "sport_name": "Soccer",
  "sport_id": 1,
  "member_count": 11,
  "created_at": "2024-11-01T10:00:00Z",
  "achievements": [
    {
      "title": "League Champions",
      "description": "2024 Spring League Winners",
      "date": "2024-05-15"
    }
  ],
  "members": [...]
}
```

## Validation Rules

1. **Maximum 2 achievements** - Teams can have at most 2 achievements
2. **Must be a list** - The achievements field must be a JSON array
3. **Each achievement must be an object** - Each item in the array must be a dictionary/object
4. **Title is required** - Each achievement must have a `title` field
5. **Optional fields** - `description` and `date` are optional

## Example in Python/Django

### Creating a team with achievements
```python
from teams.models import Team
from bookings.models import Sport
from users.models import User

team = Team.objects.create(
    team_name="Thunder Hawks",
    captain=captain_user,
    sport=sport,
    achievements=[
        {
            "title": "Regional Champions",
            "description": "Won the 2024 regional tournament",
            "date": "2024-11-05"
        }
    ]
)
```

### Adding an achievement
```python
team = Team.objects.get(team_id=1)
team.achievements.append({
    "title": "Best Team Spirit Award",
    "description": "Voted by league members",
    "date": "2024-11-08"
})
team.save()
```

### Filtering teams with achievements
```python
# Get all teams that have achievements
teams_with_achievements = Team.objects.exclude(achievements=[])

# Get teams with specific achievement title
teams = Team.objects.all()
champions = [t for t in teams if any(a.get('title') == 'League Champions' for a in t.achievements)]
```

## Migration Notes

The achievements field was changed from `CharField` to `JSONField` in migration `0004_alter_team_achievements_delete_teamachievement.py`.

If you had existing text in the achievements field, you'll need to manually convert it to the JSON format.
