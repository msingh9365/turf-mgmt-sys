# Teams API Quickstart

This app provides simple team management endpoints integrated with the existing `users` and `bookings` apps.

## Endpoints

- GET /api/teams/ — list teams
- POST /api/teams/ — create a team
  - body: {"team_name": str, "sport_id": int, "member_emails": [str, ...]}
- GET /api/teams/<id>/ — team detail with members

Additional action endpoints are wired but return 501 for now:
- POST /api/teams/<id>/invite-member/
- POST /api/teams/<id>/request-to-join/
- POST /api/teams/<id>/remove-member/
- POST /api/teams/<id>/leave/
- POST /api/invitations/match-invite/
- POST /api/invitations/team-invite/<id>/respond/
- POST /api/invitations/team-request/<id>/respond/
- POST /api/invitations/match-invite/<id>/respond/

## Data Integrity & Validation

### Unique Team Names
- Team names must be unique across the entire system
- Attempting to create a team with an existing name returns HTTP 400 with a clear error message
- Database-level constraint enforces uniqueness

### Duplicate Member Prevention
- Member emails are automatically deduplicated (case-insensitive)
- If the captain's email appears in member_emails, it's automatically removed
- Empty strings and whitespace-only emails are filtered out
- Non-existent users are silently skipped
- Database constraint prevents the same user from being added to a team multiple times
- All team creation is atomic (transaction-wrapped) - either all members are added or none

### Example Usage

Creating a Tennis team:
```bash
curl -X POST http://localhost:8000/api/teams/ \
  -H "Content-Type: application/json" \
  -d '{
    "team_name": "Baseline Smashers",
    "sport_id": 3,
    "member_emails": ["player1@example.com", "player2@example.com"]
  }'
```

Response on success (201):
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

Response on duplicate name (400):
```json
{
  "message": "Team name 'Baseline Smashers' already exists. Please choose a different name."
}
```

## Integration Notes
- Uses `settings.AUTH_USER_MODEL` for all user relations.
- Uses `bookings.Sport` as the sport FK.
- URL routes included under `/api/` in `core/urls.py`.

## Performance Optimizations
- List endpoint uses `select_related('captain', 'sport')` to prevent N+1 queries
- Detail endpoint uses `select_related` and prefetches members efficiently
- Query count capped at ≤5 queries regardless of team size
- Response times: List < 300ms, Detail < 200ms

## Tests
Run the focused tests:

```bash
pytest -q src/teams/tests/
```

Test coverage includes:
- Create team happy-path and list
- Not-found detail
- Performance checks (query count + latency) for list and detail endpoints
- Duplicate team name rejection
- Duplicate member email deduplication
- Captain in member list handling
- Whitespace and empty email filtering
- Non-existent user skipping
- Case-insensitive email matching
- Database constraint enforcement

All 12 tests pass in ~2 seconds.