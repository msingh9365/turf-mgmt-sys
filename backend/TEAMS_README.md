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

## Integration Notes
- Uses `settings.AUTH_USER_MODEL` for all user relations.
- Uses `bookings.Sport` as the sport FK.
- URL routes included under `/api/` in `core/urls.py`.

## Tests
Run the focused tests:

```
pytest -q src/teams/tests/test_teams_api.py
```

These include:
- Create team happy-path and list
- Not-found detail
- Performance checks (query count + latency) for list and detail endpoints

