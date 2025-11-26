# Teams Module - Technical Documentation

**Last Updated:** 2025-11-24  
**Version:** 2.0  
**Status:** Production Ready - Core Features Complete (Member Management Implemented)

---

## Table of Contents

1. [Module Overview](#module-overview)
2. [Architecture & Design](#architecture--design)
3. [Database Schema](#database-schema)
4. [Models Reference](#models-reference)
5. [API Endpoints](#api-endpoints)
6. [Business Logic & Workflows](#business-logic--workflows)
7. [Data Validation & Constraints](#data-validation--constraints)
8. [Performance Optimizations](#performance-optimizations)
9. [Integration Points](#integration-points)
10. [Testing Strategy](#testing-strategy)
11. [Future Implementation Roadmap](#future-implementation-roadmap)
12. [Code Examples & Usage](#code-examples--usage)

---

## Module Overview

### Purpose
The Teams module provides comprehensive team management functionality for the turf management system, enabling users to create sports teams, manage memberships, track achievements, and handle team-related invitations.

### Key Features
✅ **Team Creation & Management** - Create teams with JWT-authenticated captains  
✅ **Sport-Specific Teams** - Teams linked to specific sports with min player validation  
✅ **Bulk Member Management** - Replace all members (except captain) atomically  
✅ **Leave Team** - Members can leave (with min player validation)  
✅ **Transfer Captaincy** - Transfer captain role to another member  
✅ **Permission System** - Role-based access (captain, admin, member)  
✅ **Achievement Tracking** - JSON-based achievement storage (max 10 per team)  
✅ **Unique Team Names** - Database-enforced uniqueness across all teams  
✅ **Duplicate Prevention** - Automatic deduplication of member emails  
✅ **Performance Optimized** - Query optimization to prevent N+1 problems  
✅ **Notification Integration** - FCM notifications for all member changes  
🚧 **Invitation System** - API endpoints wired but not yet implemented  

### Tech Stack
- **Framework**: Django 5 + Django REST Framework
- **Database**: PostgreSQL (Supabase)
- **Authentication**: JWT (via rest_framework_simplejwt)
- **Testing**: pytest + pytest-django

---

## Architecture & Design

### Module Structure
```
teams/
├── __init__.py
├── admin.py                    # Django admin configuration
├── apps.py                     # App configuration
├── models.py                   # Team, TeamMember, Invitation models
├── serializers.py              # DRF serializers for API
├── urls.py                     # URL routing
├── views.py                    # API view functions
├── migrations/                 # Database migrations
│   ├── 0001_initial.py
│   ├── 0002_team_unique_team_name_...py
│   ├── 0003_team_achievements_...py
│   └── 0004_alter_team_achievements_...py
└── tests/                      # Test suite
    ├── test_teams_api.py
    ├── test_team_uniqueness.py
    └── test_integration.py
```

### Design Principles
1. **Atomic Transactions** - Team creation with members uses `transaction.atomic()` for all-or-nothing behavior
2. **Defensive Programming** - Validates all inputs, handles missing users gracefully
3. **Performance First** - Uses `select_related()`, `prefetch_related()`, and indexed lookups
4. **Flexible Schema** - JSONField for achievements allows extensibility without migrations
5. **Case-Insensitive Matching** - All email lookups are case-insensitive using `__iexact`

---

## Database Schema

### Table: `teams`
```sql
CREATE TABLE teams (
    team_id SERIAL PRIMARY KEY,
    team_name VARCHAR(100) NOT NULL,
    captain_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    member_count INTEGER DEFAULT 0,
    sport_id INTEGER NOT NULL REFERENCES Sport(Sport_ID) ON DELETE PROTECT,
    created_at TIMESTAMP DEFAULT NOW(),
    achievements JSONB DEFAULT '[]',
    CONSTRAINT unique_team_name UNIQUE (team_name)
);

CREATE INDEX idx_teams_sport ON teams(sport_id);
CREATE INDEX idx_teams_captain ON teams(captain_id);
```

### Table: `team_members`
```sql
CREATE TABLE team_members (
    id SERIAL PRIMARY KEY,
    team_id INTEGER NOT NULL REFERENCES teams(team_id) ON DELETE CASCADE,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    member_name VARCHAR(100) NOT NULL,
    email_id VARCHAR(100) NOT NULL,
    sort_key VARCHAR(20) NOT NULL,
    role VARCHAR(20) DEFAULT 'player',
    date_joined TIMESTAMP DEFAULT NOW(),
    CONSTRAINT unique_team_member UNIQUE (team_id, user_id)
);

CREATE INDEX idx_team_members_team ON team_members(team_id);
CREATE INDEX idx_team_members_user ON team_members(user_id);
CREATE INDEX idx_team_members_sort_key ON team_members(sort_key);
```

### Table: `invitations`
```sql
CREATE TABLE invitations (
    invitation_id SERIAL PRIMARY KEY,
    sender_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    recipient_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('PLAYER_INVITE', 'MATCH_INVITE', 'TEAM_INVITE', 'TEAM_REQUEST')),
    related_team_id INTEGER REFERENCES teams(team_id) ON DELETE CASCADE,
    status VARCHAR(10) DEFAULT 'SENT' CHECK (status IN ('SENT', 'ACCEPTED', 'DECLINED', 'EXPIRED')),
    expiry_time TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_invitations_recipient ON invitations(recipient_id);
CREATE INDEX idx_invitations_sender ON invitations(sender_id);
CREATE INDEX idx_invitations_team ON invitations(related_team_id);
CREATE INDEX idx_invitations_status ON invitations(status);
```

### Entity Relationships
```
User (1) ----< (N) Team [as captain]
User (N) ----< (N) TeamMember
Team (1) ----< (N) TeamMember
Sport (1) ----< (N) Team
Team (1) ----< (N) Invitation [optional]
User (1) ----< (N) Invitation [as sender]
User (1) ----< (N) Invitation [as recipient]
```

---

## Models Reference

### Team Model

```python
class Team(models.Model):
    team_id = models.AutoField(primary_key=True)
    team_name = models.CharField(max_length=100)
    captain = models.ForeignKey(User, on_delete=models.CASCADE, related_name='captained_teams')
    member_count = models.IntegerField(default=0)
    sport = models.ForeignKey(Sport, on_delete=models.PROTECT)
    created_at = models.DateTimeField(default=timezone.now)
    achievements = models.JSONField(default=list, blank=True)
```

**Fields:**
- `team_id` - Auto-incrementing primary key
- `team_name` - Unique team name (database constraint enforced)
- `captain` - Foreign key to User model (team creator/leader)
- `member_count` - Cached count of total members including captain
- `sport` - Foreign key to Sport model (PROTECT prevents deletion if teams exist)
- `created_at` - Timestamp of team creation
- `achievements` - JSON array storing up to 10 team achievements

**Constraints:**
- `unique_team_name` - Ensures no duplicate team names across the system

**Related Names:**
- `captained_teams` - Reverse relation from User to teams they captain
- `members` - Reverse relation to TeamMember objects

**Meta Options:**
```python
db_table = 'teams'
```

---

### TeamMember Model

```python
class TeamMember(models.Model):
    team = models.ForeignKey(Team, on_delete=models.CASCADE, related_name='members')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='team_memberships', 
                             null=True, blank=True)
    member_name = models.CharField(max_length=100)
    email_id = models.EmailField(max_length=100)
    sort_key = models.CharField(max_length=20, db_index=True, default='')
    role = models.CharField(max_length=20, default='player')  # 'captain' or 'player'
    date_joined = models.DateTimeField(default=timezone.now)
```

**Fields:**
- `team` - Foreign key to Team (CASCADE deletion)
- `user` - Foreign key to User (nullable for non-registered members)
- `member_name` - Display name for the member
- `email_id` - Email address (for lookup and identification)
- `sort_key` - First 7 characters of email (lowercase) for optimized queries
- `role` - Either 'captain' or 'player'
- `date_joined` - Timestamp when member joined

**Constraints:**
- `unique_team_member` - Prevents same user from being added to a team multiple times

**Related Names:**
- `members` - Reverse relation from Team to its members
- `team_memberships` - Reverse relation from User to their team memberships

**Meta Options:**
```python
db_table = 'team_members'
```

**Sort Key Pattern:**
The `sort_key` field stores the first 7 characters of the email (lowercase) to enable efficient indexed lookups:
```python
email_l = email.strip().lower()
sort_key = email_l[:7] if len(email_l) >= 7 else email_l
```

---

### Invitation Model

```python
class Invitation(models.Model):
    invitation_id = models.AutoField(primary_key=True)
    sender = models.ForeignKey(User, on_delete=models.CASCADE, related_name='sent_invitations',
                               null=True, blank=True)
    recipient = models.ForeignKey(User, on_delete=models.CASCADE, related_name='received_invitations')
    type = models.CharField(max_length=20, choices=INVITATION_TYPES)
    related_team = models.ForeignKey(Team, on_delete=models.CASCADE, null=True, blank=True)
    status = models.CharField(max_length=10, choices=STATUS_CHOICES, default='SENT')
    expiry_time = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
```

**Invitation Types:**
- `PLAYER_INVITE` - Invite a player to join a team
- `MATCH_INVITE` - Invite a team for a match
- `TEAM_INVITE` - Team invitation
- `TEAM_REQUEST` - Request to join a team

**Status Values:**
- `SENT` - Invitation sent, awaiting response
- `ACCEPTED` - Invitation accepted
- `DECLINED` - Invitation declined
- `EXPIRED` - Invitation expired (past expiry_time)

**Note:** Invitation system endpoints are wired but not yet implemented (return 501 Not Implemented).

---

## API Endpoints

### Base URL
```
/api/teams/
```

### Endpoint Summary

| Method | Endpoint | Status | Description |
|--------|----------|--------|-------------|
| GET | `/teams/` | ✅ Implemented | List all teams |
| POST | `/teams/` | ✅ Implemented | Create a new team (JWT required) |
| GET | `/teams/{id}/` | ✅ Implemented | Get team details with members |
| GET | `/teams/by-sport/?sport_id={id}` | ✅ Implemented | List teams for a specific sport |
| POST | `/teams/{team_id}/bulk-update/` | ✅ Implemented | Replace all members and update achievements (captain/admin only) |
| POST | `/teams/{team_id}/transfer-captain/` | ✅ Implemented | Transfer captaincy (captain/admin only) |
| POST | `/teams/{id}/leave/` | ✅ Implemented | Leave a team (members only) |
| POST | `/teams/{id}/invite-member/` | 🚧 Placeholder | Invite player to team |
| POST | `/teams/{id}/request-to-join/` | 🚧 Placeholder | Request to join team |
| POST | `/teams/{id}/remove-member/` | 🚧 Placeholder | Remove member from team |
| POST | `/invitations/match-invite/` | 🚧 Placeholder | Invite team for match |
| POST | `/invitations/team-invite/{id}/respond/` | 🚧 Placeholder | Respond to team invitation |
| POST | `/invitations/team-request/{id}/respond/` | 🚧 Placeholder | Respond to join request |
| POST | `/invitations/match-invite/{id}/respond/` | 🚧 Placeholder | Respond to match invitation |

---

### 1. List All Teams

**Endpoint:** `GET /api/teams/`  
**Authentication:** Not required  
**Description:** Returns a list of all teams with basic information

**Query Optimization:**
- Uses `select_related('captain', 'sport')` to prevent N+1 queries
- Query count: ≤5 regardless of number of teams
- Response time: <300ms

**Request:**
```http
GET /api/teams/ HTTP/1.1
```

**Response (200 OK):**
```json
[
  {
    "team_id": 1,
    "team_name": "Thunder Hawks",
    "captain_name": "John Doe",
    "sport_name": "Soccer",
    "sport_id": 1,
    "member_count": 11,
    "created_at": "2024-11-01T10:00:00Z"
  },
  {
    "team_id": 2,
    "team_name": "Lightning Strikers",
    "captain_name": "Jane Smith",
    "sport_name": "Basketball",
    "sport_id": 2,
    "member_count": 8,
    "created_at": "2024-11-05T14:30:00Z"
  }
]
```

**Empty Response:**
```json
[]
```

---

### 2. Create Team

**Endpoint:** `POST /api/teams/`  
**Authentication:** JWT required (authenticated user becomes captain)  
**Description:** Creates a new team with captain and optional members

**Request Body:**
```json
{
  "team_name": "Thunder Hawks",
  "sport_id": 1,
  "member_emails": [
    "player1@example.com",
    "player2@example.com",
    "player3@example.com"
  ],
  "achievements": [
    {
      "title": "Regional Champions 2024",
      "description": "Won the regional tournament",
      "date": "2024-11-05"
    }
  ]
}
```

**Field Validation:**
- `team_name` (required) - Must be unique across all teams
- `sport_id` (required) - Must reference an existing sport
- `member_emails` (optional) - Array of email addresses
- `achievements` (optional) - Array of achievement objects (max 10)

**Response (201 Created):**
```json
{
  "team_id": 3,
  "team_name": "Thunder Hawks",
  "captain_name": "Current User",
  "sport_name": "Soccer",
  "sport_id": 1,
  "member_count": 4,
  "created_at": "2024-11-24T10:00:00Z",
  "achievements": [
    {
      "title": "Regional Champions 2024",
      "description": "Won the regional tournament",
      "date": "2024-11-05"
    }
  ]
}
```

**Response with Warnings:**
If some member emails don't exist in the system:
```json
{
  "team_id": 3,
  "team_name": "Thunder Hawks",
  "captain_name": "Current User",
  "sport_name": "Soccer",
  "sport_id": 1,
  "member_count": 2,
  "created_at": "2024-11-24T10:00:00Z",
  "achievements": [],
  "warning": "Team created but 2 member(s) not found and were not added.",
  "rejected_members": [
    "nonexistent1@example.com",
    "nonexistent2@example.com"
  ]
}
```

**Note:** The `rejected_members` array contains the email addresses of users who are not registered in the system and were therefore not added to the team. The captain can use this information to inform those users to register before being added to the team.

**Error Responses:**

**400 Bad Request - Duplicate Team Name:**
```json
{
  "message": "Team name 'Thunder Hawks' already exists. Please choose a different name."
}
```

**400 Bad Request - Minimum Players:**
```json
{
  "message": "Minimum 11 players required for Soccer."
}
```

**400 Bad Request - Invalid Data:**
```json
{
  "message": "Invalid request: <error details>. team_name and sport_id are required."
}
```

---

### 3. Get Team Details

**Endpoint:** `GET /api/teams/{id}/`  
**Authentication:** Not required  
**Description:** Returns detailed information about a specific team including all members

**Query Optimization:**
- Uses `select_related('captain', 'sport')` for FK efficiency
- Uses `select_related('user')` on members prefetch
- Query count: ≤5 regardless of member count
- Response time: <200ms

**Request:**
```http
GET /api/teams/3/ HTTP/1.1
```

**Response (200 OK):**
```json
{
  "team_id": 3,
  "team_name": "Thunder Hawks",
  "captain": {
    "user_id": 5,
    "name": "John Doe"
  },
  "sport": {
    "sport_id": 1,
    "sport_name": "Soccer"
  },
  "member_count": 4,
  "members": [
    {
      "user_id": 5,
      "name": "John Doe",
      "role": "captain"
    },
    {
      "user_id": 12,
      "name": "Jane Smith",
      "role": "player"
    },
    {
      "user_id": 18,
      "name": "Mike Johnson",
      "role": "player"
    },
    {
      "user_id": 24,
      "name": "Sarah Williams",
      "role": "player"
    }
  ],
  "created_at": "2024-11-24T10:00:00Z",
  "achievements": [
    {
      "title": "Regional Champions 2024",
      "description": "Won the regional tournament",
      "date": "2024-11-05"
    }
  ]
}
```

**Response (404 Not Found):**
```json
{
  "message": "Team not found."
}
```

---

### 4. List Teams by Sport

**Endpoint:** `GET /api/teams/by-sport/?sport_id={id}`  
**Authentication:** Not required  
**Description:** Returns a lean list of teams for a specific sport (optimized for dropdowns/selectors)

**Query Optimization:**
- Filters by FK index on `sport_id`
- Uses `only()` to fetch minimal fields
- Uses `values()` to return lean dictionaries
- Query count: ≤5 total (including framework overhead)
- Response time: <100ms

**Query Parameters:**
- `sport_id` (required) - Integer ID of the sport

**Request:**
```http
GET /api/teams/by-sport/?sport_id=1 HTTP/1.1
```

**Response (200 OK):**
```json
[
  {
    "team_id": 1,
    "team_name": "Thunder Hawks"
  },
  {
    "team_id": 3,
    "team_name": "Lightning Strikers"
  },
  {
    "team_id": 5,
    "team_name": "Storm Chasers"
  }
]
```

**Empty Response (Sport has no teams):**
```json
[]
```

**Error Response (400 Bad Request - Missing Parameter):**
```json
{
  "message": "sport_id is required as a query parameter"
}
```

**Error Response (400 Bad Request - Invalid Type):**
```json
{
  "message": "sport_id must be an integer"
}
```

---

### 5. Bulk Update Team Members

**Endpoint:** `POST /api/teams/{team_id}/bulk-update/`  
**Authentication:** JWT required  
**Authorization:** Team captain or admin users only  
**Description:** Replace all team members (except captain) with a new list of members

**Request Body:**
```json
{
  "member_emails": [
    "player1@example.com",
    "player2@example.com",
    "player3@example.com"
  ]
}
```

**Field Validation:**
- `member_emails` (required) - Array of email addresses (non-empty)
- Automatically deduplicates emails (case-insensitive)
- Captain's email is ignored if included
- Pre-validates minimum player count before any deletion

**Response (200 OK):**
```json
{
  "team_id": 1,
  "team_name": "Thunder Hawks",
  "member_count": 11,
  "members_added": 8,
  "members_removed": 10,
  "message": "Team roster updated successfully"
}
```

**Response with Warnings:**
If some emails don't exist:
```json
{
  "team_id": 1,
  "team_name": "Thunder Hawks",
  "member_count": 9,
  "members_added": 6,
  "members_removed": 10,
  "failed_emails": ["notfound1@example.com", "notfound2@example.com"],
  "warning": "2 email(s) not found: notfound1@example.com, notfound2@example.com",
  "message": "Team roster updated successfully"
}
```

**Error Responses:**

**403 Forbidden - Not Authorized:**
```json
{
  "message": "You do not have permission to perform this action. Only team captain or admin can update members."
}
```

**400 Bad Request - Minimum Players:**
```json
{
  "message": "Cannot update members. Minimum 11 players required for Soccer. You provided 8 total members."
}
```

**400 Bad Request - Invalid Data:**
```json
{
  "message": "Invalid request data: {'member_emails': ['This field is required.']}"
}
```

**404 Not Found:**
```json
{
  "message": "Team not found."
}
```

**Business Logic:**
- Complete replacement strategy: ALL existing members (except captain) are deleted
- Captain is automatically preserved and never deleted
- Atomic transaction: either all changes succeed or all fail
- Member count is updated after changes
- Notifications sent to all team members (existing + new)
- Uses optimized database queries with indexed lookups

---

### 6. Leave Team

**Endpoint:** `POST /api/teams/{id}/leave/`  
**Authentication:** JWT required  
**Authorization:** Must be a team member (but NOT the captain)  
**Description:** Remove yourself from the team

**No Request Body Required**

**Response (200 OK):**
```json
{
  "message": "You have successfully left Thunder Hawks",
  "team_name": "Thunder Hawks"
}
```

**Error Responses:**

**403 Forbidden - Captain Cannot Leave:**
```json
{
  "message": "Captain cannot leave the team. Transfer captaincy first."
}
```

**403 Forbidden - Not a Member:**
```json
{
  "message": "You are not a member of this team."
}
```

**400 Bad Request - Minimum Players:**
```json
{
  "message": "Cannot leave - team would fall below minimum player requirement of 11 for Soccer."
}
```

**404 Not Found:**
```json
{
  "message": "Team not found."
}
```

**Business Logic:**
- Validates user is a member but not captain
- Calculates remaining member count before deletion
- Rejects if leaving would violate sport's minimum player requirement
- Atomic transaction: delete member record and update count
- Notifications sent to remaining team members

---

### 7. Transfer Team Captaincy

**Endpoint:** `POST /api/teams/{team_id}/transfer-captain/`  
**Authentication:** JWT required  
**Authorization:** Current captain or admin users only  
**Description:** Transfer team captaincy to another existing team member

**Request Body:**
```json
{
  "new_captain_user_id": 25
}
```

**Field Validation:**
- `new_captain_user_id` (required) - Integer user ID
- Must be an existing member of the team
- Cannot be the current captain (already captain)

**Response (200 OK):**
```json
{
  "message": "Team captaincy transferred successfully",
  "team_id": 1,
  "team_name": "Thunder Hawks",
  "old_captain": {
    "user_id": 5,
    "name": "John Doe"
  },
  "new_captain": {
    "user_id": 25,
    "name": "Jane Smith"
  }
}
```

**Error Responses:**

**403 Forbidden - Not Authorized:**
```json
{
  "message": "You do not have permission to perform this action. Only team captain or admin can transfer captaincy."
}
```

**400 Bad Request - Already Captain:**
```json
{
  "message": "The specified user is already the captain of this team."
}
```

**400 Bad Request - Invalid Data:**
```json
{
  "message": "Invalid request data: {'new_captain_user_id': ['This field is required.']}"
}
```

**404 Not Found - Team:**
```json
{
  "message": "Team not found."
}
```

**404 Not Found - User:**
```json
{
  "message": "New captain user does not exist."
}
```

**404 Not Found - Not a Member:**
```json
{
  "message": "New captain is not a member of this team."
}
```

**Business Logic:**
- Validates new captain is an existing team member
- Atomic transaction updates three records:
  1. Old captain's TeamMember role → 'player'
  2. New captain's TeamMember role → 'captain'
  3. Team.captain foreign key → new captain
- Old captain remains as a regular member
- Notifications sent to all team members

---

### 8. Placeholder Endpoints (Not Yet Implemented)

The following invitation and member management endpoints return:

**Response (501 Not Implemented):**
```json
{
  "detail": "<Action> not implemented yet."
}
```

These endpoints include:
- `/teams/{id}/invite-member/`
- `/teams/{id}/request-to-join/`
- `/teams/{id}/remove-member/`
- `/invitations/match-invite/`
- `/invitations/team-invite/{id}/respond/`
- `/invitations/team-request/{id}/respond/`
- `/invitations/match-invite/{id}/respond/`

---

## Business Logic & Workflows

### Permission System

The Teams module implements a role-based permission system with three levels:

**1. Captain Permissions**
- Create team (becomes captain automatically)
- Bulk update team members
- Transfer captaincy to another member
- Remove individual members (future feature)
- Invite players to team (future feature)
- Respond to join requests (future feature)

**2. Admin Permissions (is_admin=True)**
- All captain permissions on ANY team
- Can bulk update members and achievements on any team
- Can transfer captaincy on any team
- Override captain-only restrictions

**3. Member Permissions**
- Leave team (if not captain and min_player maintained)
- View team details
- Request to join team (future feature)
- Respond to invitations (future feature)

**4. Public Permissions**
- List all teams (no authentication required)
- View team details (no authentication required)
- List teams by sport (no authentication required)

**Permission Helper Functions** (`teams/permissions.py`):
```python
def is_team_captain(user, team):
    """Check if user is the captain of the team"""
    return team.captain_id == user.id

def is_admin_user(user):
    """Check if user has admin privileges"""
    return getattr(user, 'is_admin', False)

def is_team_member(user, team):
    """Check if user is a member of the team"""
    return team.members.filter(user_id=user.id).exists()

def can_modify_team(user, team):
    """Check if user can modify team settings (captain or admin)"""
    return is_team_captain(user, team) or is_admin_user(user)
```

---

### Team Creation Workflow

```
1. Validate Request Data
   ├─ Check team_name provided
   ├─ Check sport_id exists
   └─ Validate member_emails format

2. Retrieve Captain
   ├─ Use request.user if authenticated
   └─ Fallback to first user (temporary, for testing)

3. Retrieve Sport & Validate Min Players
   ├─ Fetch Sport by sport_id
   ├─ Count members = len(member_emails) + 1 (captain)
   └─ Assert members >= sport.min_player

4. Deduplicate & Clean Member Emails
   ├─ Convert to lowercase
   ├─ Remove whitespace
   ├─ Remove duplicates
   └─ Remove captain's email if present

5. Begin Atomic Transaction
   ├─ Create Team record
   ├─ Add captain as TeamMember (role='captain')
   └─ Add other members as TeamMember (role='player')

6. Process Member Emails
   ├─ For each email:
   │  ├─ Lookup user by sort_key index + email
   │  ├─ If found: Create TeamMember
   │  └─ If not found: Track as failed_email
   └─ Update team.member_count with actual count

7. Commit Transaction
   └─ Return success response with optional warnings

8. Handle Errors
   ├─ IntegrityError (duplicate team name)
   ├─ Sport.DoesNotExist
   └─ Other validation errors
```

### Member Lookup Strategy

The module uses a two-step optimized lookup for member emails:

```python
# Step 1: Filter by indexed sort_key (first 7 chars)
email_l = email.strip().lower()
prefix = email_l[:7] if len(email_l) >= 7 else email_l

# Step 2: Exact match on email within filtered set
try:
    member = User.objects.filter(sort_key__iexact=prefix).get(email__iexact=email_l)
except User.DoesNotExist:
    # Fallback: direct email lookup (handles edge cases)
    member = User.objects.get(email__iexact=email_l)
```

**Benefits:**
- Leverages database index on `sort_key` for fast filtering
- Case-insensitive matching via `__iexact`
- Fallback ensures compatibility with legacy data

### Duplicate Prevention

The system prevents duplicates at multiple levels:

1. **Request Level** - Deduplicates emails in request data
   ```python
   member_emails = list(set(email.strip().lower() for email in member_emails if email and email.strip()))
   ```

2. **Captain Removal** - Removes captain from member list
   ```python
   if captain_email in member_emails:
       member_emails.remove(captain_email)
   ```

3. **Database Level** - Unique constraint on (team, user)
   ```python
   constraints = [
       models.UniqueConstraint(fields=['team', 'user'], name='unique_team_member')
   ]
   ```

---

### Bulk Update Members Workflow

```
1. Validate Request & Authorization
   ├─ Validate member_emails list format
   ├─ Check user is captain OR admin
   └─ Fetch team with related data

2. Pre-Process Member Emails
   ├─ Remove captain's email if present
   ├─ Deduplicate emails (case-insensitive)
   └─ Convert to lowercase

3. Pre-Validation: Minimum Player Count
   ├─ Calculate: total = 1 (captain) + len(new_members)
   ├─ Get sport.min_player requirement
   └─ Reject if total < min_player

4. Lookup Users by Email
   ├─ For each email:
   │  ├─ Use optimized sort_key lookup
   │  ├─ If found: Add to found_users list
   │  └─ If not found: Add to failed_emails list
   └─ Track successful and failed lookups

5. Begin Atomic Transaction
   ├─ Get existing member IDs (for notification)
   ├─ Delete ALL members except captain
   ├─ Bulk create new TeamMember records
   └─ Update team.member_count

6. Commit Transaction
   └─ All changes succeed or all rollback

7. Send Notifications
   ├─ Notify all affected members (old + new)
   ├─ Message: roster updated details
   └─ Continue even if notification fails

8. Return Response
   ├─ Success data with counts
   └─ Warning if failed_emails exist
```

---

### Leave Team Workflow

```
1. Validate Request & Authorization
   ├─ Check user is authenticated
   ├─ Fetch team with related data
   └─ Verify team exists

2. Authorization Checks
   ├─ Check user is NOT captain
   │  └─ Reject: "Captain cannot leave. Transfer captaincy first."
   └─ Check user IS a member
      └─ Reject: "You are not a member of this team."

3. Validate Minimum Player Count
   ├─ Calculate: remaining = current_count - 1
   ├─ Get sport.min_player requirement
   └─ Reject if remaining < min_player

4. Begin Atomic Transaction
   ├─ Delete user's TeamMember record
   └─ Update team.member_count

5. Commit Transaction
   └─ All changes succeed or all rollback

6. Send Notifications
   ├─ Notify remaining team members
   ├─ Exclude user who left
   └─ Message: "{user} has left the team"

7. Return Success Response
   └─ Confirmation message with team name
```

---

### Transfer Captaincy Workflow

```
1. Validate Request & Authorization
   ├─ Validate new_captain_user_id provided
   ├─ Check user is captain OR admin
   └─ Fetch team with related data

2. Validate New Captain
   ├─ Check new captain exists (User lookup)
   ├─ Check new captain != current captain
   └─ Check new captain is team member

3. Begin Atomic Transaction
   ├─ Update old captain's TeamMember.role → 'player'
   ├─ Update new captain's TeamMember.role → 'captain'
   └─ Update Team.captain → new captain

4. Commit Transaction
   └─ All three updates succeed or all rollback

5. Send Notifications
   ├─ Notify ALL team members
   ├─ Message: "Captaincy transferred from X to Y"
   └─ Include both old and new captain

6. Return Success Response
   ├─ Old captain details
   └─ New captain details
```

---

### Notification Integration

All member management operations send notifications using the notifications module:

```python
from teams.notifications import send_team_notification

# Usage
send_team_notification(
    team=team,
    notification_type='ROSTER_UPDATED',  # or MEMBER_LEFT, CAPTAIN_CHANGED
    message="Human-readable message",
    exclude_user_ids=[user.id]  # Optional: exclude specific users
)
```

**Notification Types:**
- `ROSTER_UPDATED` - Bulk member update
- `MEMBER_LEFT` - Member left team
- `CAPTAIN_CHANGED` - Captaincy transferred
- `MEMBER_ADDED` - Single member added (future)
- `MEMBER_REMOVED` - Member removed (future)

**Integration Details:**
- Uses FCM (Firebase Cloud Messaging) via `notifications.utils.FCMNotificationSender`
- Sends to all active devices for each team member
- Creates persistent Notification records in database
- Non-blocking: failures don't affect the main operation
- Logs all notification attempts for debugging

---

## Data Validation & Constraints

### Model-Level Constraints

**Team Model:**
- `team_name` must be unique (database constraint)
- `captain` must reference existing User
- `sport` must reference existing Sport
- `achievements` must be valid JSON array

**TeamMember Model:**
- `(team, user)` combination must be unique
- `role` must be 'captain' or 'player'
- `email_id` format validated by EmailField

**Invitation Model:**
- `type` must be one of: PLAYER_INVITE, MATCH_INVITE, TEAM_INVITE, TEAM_REQUEST
- `status` must be one of: SENT, ACCEPTED, DECLINED, EXPIRED
- `recipient` must reference existing User

### Serializer-Level Validation

**TeamCreateSerializer:**
```python
def validate_achievements(self, value):
    # Must be a list
    if not isinstance(value, list):
        raise ValidationError("Achievements must be a list")
    
    # Max 10 achievements
    if len(value) > 10:
        raise ValidationError("Maximum 10 achievements allowed")
    
    # Each achievement must be a dict with 'title'
    for achievement in value:
        if not isinstance(achievement, dict):
            raise ValidationError("Each achievement must be an object")
        if 'title' not in achievement:
            raise ValidationError("Each achievement must have a 'title' field")
    
    return value

def validate(self, attrs):
    # Validate sport exists
    sport_id = attrs.get('sport_id')
    sport = Sport.objects.get(sport_id=sport_id)
    
    # Validate min players
    member_emails = attrs.get('member_emails', [])
    if len(member_emails) + 1 < sport.min_player:
        raise ValidationError({
            "member_emails": f"Minimum {sport.min_player} players required for {sport.sport_name}."
        })
    
    return attrs
```

### Business Rules

1. **Minimum Team Size**
   - Team must have at least `sport.min_player` members (including captain)
   - Validated before team creation

2. **Unique Team Names**
   - No two teams can have the same name
   - Enforced by database constraint
   - Case-sensitive matching

3. **Captain Membership**
   - Captain is automatically added as a team member with role='captain'
   - Cannot be removed from member list

4. **Non-Existent Users**
   - Member emails that don't match any registered user are silently skipped
   - Warning returned in response with list of failed emails

5. **Achievement Limit**
   - Teams can have maximum 10 achievements
   - Each achievement must have at least a 'title' field

---

## Performance Optimizations

### Query Optimization Techniques

#### 1. Select Related (FK Optimization)
Prevents N+1 queries by eagerly loading related objects:

```python
# List Teams View
teams = Team.objects.select_related("captain", "sport").all()
# Executes: 1 query with JOIN instead of N+1 queries

# Team Detail View
team = Team.objects.select_related('captain', 'sport').get(team_id=id)
members = team.members.select_related('user').all()
# Executes: 2 queries total instead of 1 + N queries
```

#### 2. Values Optimization (Lean Queries)
For dropdown/selector endpoints, fetch only required fields:

```python
# By Sport Endpoint
qs = (
    Team.objects
    .filter(sport_id=sport_id_int)
    .only("team_id", "team_name")  # Defer other fields
    .order_by("team_name")
)
data = list(qs.values("team_id", "team_name"))  # Return dicts, not model instances
```

#### 3. Indexed Lookups
All lookups leverage database indexes:

```python
# sort_key is indexed for fast prefix matching
member = User.objects.filter(sort_key__iexact=prefix).get(email__iexact=email_l)

# sport_id uses FK index
teams = Team.objects.filter(sport_id=sport_id)
```

#### 4. Bulk Operations
When creating teams with multiple members:

```python
# Single INSERT with multiple rows instead of N INSERTs
TeamMember.objects.bulk_create([
    TeamMember(team=team, user=captain, ...),
    TeamMember(team=team, user=member1, ...),
    TeamMember(team=team, user=member2, ...),
])
```

### Performance Benchmarks

| Operation | Query Count | Response Time | Notes |
|-----------|-------------|---------------|-------|
| List Teams | ≤5 | <300ms | Regardless of team count |
| Team Detail | ≤5 | <200ms | Regardless of member count |
| Teams by Sport | ≤5 | <100ms | Lean response, indexed filter |
| Create Team | ~5-10 | <500ms | Depends on member count |

### Database Indexes

```sql
-- Automatically created by Django
CREATE INDEX teams_captain_id ON teams(captain_id);
CREATE INDEX teams_sport_id ON teams(sport_id);
CREATE INDEX team_members_team_id ON team_members(team_id);
CREATE INDEX team_members_user_id ON team_members(user_id);
CREATE INDEX team_members_sort_key ON team_members(sort_key);

-- Unique constraints also create indexes
CREATE UNIQUE INDEX unique_team_name ON teams(team_name);
CREATE UNIQUE INDEX unique_team_member ON team_members(team_id, user_id);
```

---

## Integration Points

### 1. Users Module Integration

**Model Dependency:**
```python
from django.contrib.auth import get_user_model
User = get_user_model()  # Uses settings.AUTH_USER_MODEL
```

**Relationships:**
- `Team.captain` → `User` (CASCADE)
- `TeamMember.user` → `User` (CASCADE, nullable)
- `Invitation.sender` → `User` (CASCADE, nullable)
- `Invitation.recipient` → `User` (CASCADE)

**Usage:**
```python
# Get user's captained teams
user.captained_teams.all()

# Get user's team memberships
user.team_memberships.all()

# Get user's sent invitations
user.sent_invitations.all()

# Get user's received invitations
user.received_invitations.all()
```

### 2. Bookings Module Integration

**Model Dependency:**
```python
from bookings.models import Sport
```

**Relationship:**
- `Team.sport` → `Sport` (PROTECT)

**Usage:**
```python
# Get all teams for a sport
sport.team_set.all()

# Sport protection
# Cannot delete a sport if teams reference it
```

**Sport Model Reference:**
```python
class Sport(models.Model):
    sport_id = models.AutoField(primary_key=True)
    sport_name = models.CharField(max_length=100)
    min_player = models.IntegerField()  # Used for team validation
```

### 3. Authentication Integration

**Current State:**
```python
# Temporary fallback for testing
captain = request.user if request.user and request.user.is_authenticated else User.objects.first()
```

**Production Implementation (TODO):**
```python
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import permission_classes

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def create_team(request):
    captain = request.user  # Guaranteed to be authenticated
    # ...
```

### 4. URL Routing

**Mounted in:** `core/urls.py`
```python
urlpatterns = [
    path("api/", include("teams.urls")),  # Mounts all /api/teams/* endpoints
]
```

---

## Testing Strategy

### Test Coverage

**Test Files:**
- `test_teams_api.py` - Core API functionality tests
- `test_team_uniqueness.py` - Duplicate prevention tests
- `test_integration.py` - Cross-module integration tests
- `test_member_management.py` - Member management features (bulk update, leave, transfer captain)

**Coverage Target:** ≥90% for all new code

**Test Count:** 30+ tests covering all member management features

### Test Scenarios

#### 1. Basic CRUD Operations
```python
def test_list_teams_initially_empty():
    # Verify empty response when no teams exist

def test_create_team_with_min_members():
    # Create team with minimum required players
    # Verify all fields returned correctly

def test_team_detail_not_found():
    # Verify 404 for non-existent team
```

#### 2. Performance Tests
```python
def test_list_teams_query_count_and_latency():
    # Create 5 teams with members
    # Assert query count ≤5
    # Assert response time <300ms

def test_team_detail_query_efficiency():
    # Create team with multiple members
    # Assert query count ≤5
    # Assert response time <200ms
```

#### 3. Validation Tests
```python
def test_duplicate_team_name_rejection():
    # Create team with name "Alpha"
    # Attempt to create another team with same name
    # Assert 400 error with clear message

def test_minimum_players_validation():
    # Attempt to create team with fewer than sport.min_player members
    # Assert 400 error with helpful message
```

#### 4. Data Integrity Tests
```python
def test_duplicate_member_email_deduplication():
    # Create team with duplicate emails in member list
    # Verify only unique members added

def test_captain_in_member_list_handling():
    # Include captain's email in member_emails
    # Verify captain not duplicated

def test_nonexistent_user_skipping():
    # Include non-existent emails in member_emails
    # Verify team created with warning
    # Verify only existing users added
```

#### 5. Bulk Update Members Tests
```python
def test_bulk_update_by_captain_success():
    # Captain successfully replaces all members
    
def test_bulk_update_by_admin_success():
    # Admin can bulk update any team
    
def test_bulk_update_by_non_authorized_user_fails():
    # Regular member cannot bulk update
    
def test_bulk_update_maintains_captain():
    # Captain is never removed during bulk update
    
def test_bulk_update_validates_min_players():
    # Rejects update that violates min player count
    
def test_bulk_update_deduplicates_emails():
    # Duplicate emails are automatically deduplicated
    
def test_bulk_update_handles_nonexistent_users():
    # Returns warning for emails that don't exist
    
def test_bulk_update_is_atomic():
    # Verify all-or-nothing transaction behavior
    
def test_bulk_update_updates_member_count():
    # Member count correctly updated after bulk update
```

#### 6. Leave Team Tests
```python
def test_member_can_leave_team():
    # Regular member successfully leaves team
    
def test_captain_cannot_leave_team():
    # Captain is blocked from leaving
    
def test_non_member_cannot_leave_team():
    # Non-member cannot leave team they're not in
    
def test_leave_validates_min_players():
    # Rejects leave if it violates min player count
    
def test_leave_updates_member_count():
    # Member count correctly updated after leaving
    
def test_unauthenticated_user_cannot_leave():
    # Requires authentication
```

#### 7. Transfer Captain Tests
```python
def test_captain_can_transfer_captaincy():
    # Captain successfully transfers to another member
    
def test_admin_can_transfer_captaincy():
    # Admin can transfer captaincy on any team
    
def test_regular_member_cannot_transfer_captaincy():
    # Regular member is blocked
    
def test_transfer_to_non_member_fails():
    # Cannot transfer to user not on team
    
def test_old_captain_becomes_player():
    # Old captain becomes regular member after transfer
    
def test_transfer_updates_all_records():
    # Team and both TeamMember records updated atomically
```

#### 8. Integration Tests
```python
def test_full_workflow_create_update_leave_transfer():
    # Complete workflow testing all features together
    
def test_concurrent_bulk_updates():
    # Test race conditions with atomic transactions
    
def test_notification_integration():
    # Verify notifications sent for all operations
```

#### 9. Performance Tests
```python
def test_bulk_update_query_count():
    # Ensure query count stays under 15
    
def test_bulk_update_performance_with_many_members():
    # Should complete in under 2 seconds
```

### Running Tests

```bash
# Run all team tests
pytest src/teams/tests/ -v

# Run specific test file
pytest src/teams/tests/test_teams_api.py -v

# Run with coverage
pytest src/teams/tests/ --cov=teams --cov-report=html

# Run performance tests only
pytest src/teams/tests/ -k "performance or query" -v
```

### Test Database

Tests use either:
1. SQLite (fast, in-memory) - `PYTEST_USE_SQLITE=1`
2. PostgreSQL (production-like) - default

```bash
# Fast SQLite tests
PYTEST_USE_SQLITE=1 pytest src/teams/tests/ -q

# Full PostgreSQL tests
pytest src/teams/tests/ -q
```

---

## Future Implementation Roadmap

### Phase 1: Member Management (Priority: High)

#### Endpoints to Implement:

**1. Invite Member to Team**
```
POST /api/teams/{id}/invite-member/
Body: {"email": "player@example.com"}
```
**Logic:**
- Verify requester is captain
- Create Invitation record (type='PLAYER_INVITE')
- Send notification to recipient
- Return invitation ID

**2. Remove Member from Team**
```
POST /api/teams/{id}/remove-member/
Body: {"user_id": 123}
```
**Logic:**
- Verify requester is captain
- Verify user is not the captain
- Delete TeamMember record
- Update team.member_count
- Validate team still meets min_player requirement

**3. Leave Team**
```
POST /api/teams/{id}/leave/
```
**Logic:**
- Verify requester is a member
- Verify requester is not the captain (or handle captain transfer)
- Delete TeamMember record
- Update team.member_count

### Phase 2: Invitation System (Priority: Medium)

#### Endpoints to Implement:

**1. Request to Join Team**
```
POST /api/teams/{id}/request-to-join/
```
**Logic:**
- Create Invitation record (type='TEAM_REQUEST')
- Notify team captain
- Return request ID

**2. Respond to Team Invitation**
```
POST /api/invitations/team-invite/{id}/respond/
Body: {"response": "accept" | "decline"}
```
**Logic:**
- Verify requester is recipient
- Update invitation status
- If accepted: Create TeamMember record
- If declined: Just update status

**3. Respond to Join Request**
```
POST /api/invitations/team-request/{id}/respond/
Body: {"response": "accept" | "decline"}
```
**Logic:**
- Verify requester is captain
- Update invitation status
- If accepted: Create TeamMember record
- If declined: Just update status

### Phase 3: Match System (Priority: Low)

#### Endpoints to Implement:

**1. Invite Team for Match**
```
POST /api/invitations/match-invite/
Body: {
  "recipient_team_id": 2,
  "match_date": "2024-12-01",
  "ground_id": 1,
  "slot_ids": [5, 6, 7]
}
```
**Logic:**
- Verify requester is captain of a team
- Create Invitation record (type='MATCH_INVITE')
- Notify recipient team captain
- Store match details in Invitation metadata

**2. Respond to Match Invitation**
```
POST /api/invitations/match-invite/{id}/respond/
Body: {"response": "accept" | "decline"}
```
**Logic:**
- Verify requester is recipient team captain
- Update invitation status
- If accepted: Create booking for both teams (integration with bookings module)

### Phase 4: Additional Features

**1. Team Updates**
```
PATCH /api/teams/{id}/
Body: {"team_name": "New Name", "achievements": [...]}
```

**2. Transfer Captain**
```
POST /api/teams/{id}/transfer-captain/
Body: {"new_captain_user_id": 123}
```

**3. Team Statistics**
```
GET /api/teams/{id}/stats/
Response: {
  "total_matches": 10,
  "wins": 7,
  "losses": 2,
  "draws": 1,
  "win_rate": 0.7
}
```

**4. Team Search**
```
GET /api/teams/search/?q=thunder&sport_id=1
```

### Implementation Considerations

**For All New Features:**
1. Add authentication requirement: `@permission_classes([IsAuthenticated])`
2. Implement proper permission checks (is captain, is member, etc.)
3. Add comprehensive tests for happy path and edge cases
4. Update this documentation
5. Consider notification integration (via notifications module)
6. Handle race conditions with transactions where needed
7. Add logging for audit trail

**Database Migrations:**
- May need to add fields to Invitation model for match details
- Consider adding Team.stats JSONField for match statistics
- Add indexes for any new frequently-queried fields

---

## Code Examples & Usage

### Creating a Team (Python)

```python
import requests

# Authenticate and get JWT token
login_response = requests.post('https://api.example.com/api/auth/login/', json={
    'email': 'captain@example.com',
    'password': 'password123'
})
token = login_response.json()['access']

# Create team
response = requests.post('https://api.example.com/api/teams/', 
    headers={'Authorization': f'Bearer {token}'},
    json={
        'team_name': 'Thunder Hawks',
        'sport_id': 1,
        'member_emails': [
            'player1@example.com',
            'player2@example.com',
            'player3@example.com'
        ],
        'achievements': [
            {
                'title': 'Regional Champions 2024',
                'description': 'Won the regional tournament',
                'date': '2024-11-05'
            }
        ]
    }
)

team = response.json()
print(f"Created team: {team['team_name']} (ID: {team['team_id']})")
```

### Querying Teams (Django ORM)

```python
from teams.models import Team, TeamMember
from bookings.models import Sport

# Get all soccer teams
soccer = Sport.objects.get(sport_name='Soccer')
soccer_teams = Team.objects.filter(sport=soccer)

# Get teams captained by a user
user_teams = user.captained_teams.all()

# Get all teams a user is a member of (including as captain)
user_memberships = user.team_memberships.select_related('team', 'team__sport')
teams = [membership.team for membership in user_memberships]

# Get team with all members (optimized)
team = Team.objects.select_related('captain', 'sport').prefetch_related(
    Prefetch('members', queryset=TeamMember.objects.select_related('user'))
).get(team_id=1)

# Count teams by sport
from django.db.models import Count
sport_stats = Sport.objects.annotate(team_count=Count('team')).values('sport_name', 'team_count')
```

### Working with Achievements

```python
# Adding achievements when creating team
team = Team.objects.create(
    team_name='Champions',
    captain=user,
    sport=sport,
    achievements=[
        {
            'title': 'City Tournament Winners',
            'description': 'First place in city-wide competition',
            'date': '2024-11-01'
        },
        {
            'title': 'Best Defense Award',
            'description': 'Lowest goals conceded in season',
            'date': '2024-10-15'
        }
    ]
)

# Updating achievements
team.achievements.append({
    'title': 'League Champions',
    'description': 'Won the league championship',
    'date': '2024-12-01'
})
team.save(update_fields=['achievements'])

# Querying teams with specific achievements
from django.db.models import Q
teams_with_championships = Team.objects.filter(
    achievements__contains=[{'title': 'League Champions'}]
)
```

### Custom Queries

```python
# Get teams that need more members
from django.db.models import F
teams_below_min = Team.objects.select_related('sport').filter(
    member_count__lt=F('sport__min_player')
)

# Get most popular sports by team count
popular_sports = Sport.objects.annotate(
    team_count=Count('team')
).order_by('-team_count')

# Get newest teams
recent_teams = Team.objects.select_related('captain', 'sport').order_by('-created_at')[:10]

# Search teams by name (case-insensitive)
search_term = 'thunder'
matching_teams = Team.objects.filter(team_name__icontains=search_term)
```

---

## Appendix

### Environment Variables

No team-specific environment variables currently required.

### Dependencies

- Django 5.0.6
- djangorestframework 3.15.1
- djangorestframework-simplejwt 5.3.1
- PostgreSQL (via psycopg 3.2.3)

### Related Documentation

- [Booking System Documentation](BOOKING_SYSTEM_DOCUMENTATION.md)
- [Notification System Documentation](NOTIFICATION_SYSTEM_DOCUMENTATION.md)
- [Team Achievements Guide](TEAM_ACHIEVEMENTS_GUIDE.md)
- [Team Uniqueness Summary](TEAM_UNIQUENESS_SUMMARY.md)
- [Tennis Team API Guide](TENNIS_TEAM_API_GUIDE.md)

### API Response Codes

| Code | Description |
|------|-------------|
| 200 | Success (GET requests) |
| 201 | Created (POST requests) |
| 400 | Bad Request (validation errors) |
| 404 | Not Found |
| 501 | Not Implemented (placeholder endpoints) |

### Common Error Messages

```json
// Duplicate team name
{"message": "Team name 'X' already exists. Please choose a different name."}

// Missing parameters
{"message": "Invalid request: <details>. team_name and sport_id are required."}

// Minimum players not met
{"message": "Minimum X players required for Y."}

// Sport filter missing
{"message": "sport_id is required as a query parameter"}

// Invalid sport_id type
{"message": "sport_id must be an integer"}

// Team not found
{"message": "Team not found."}
```

---

**Document Version:** 1.0  
**Last Updated:** 2025-11-24  
**Maintainer:** Development Team  
**Status:** Production Ready (Core Features), Placeholder (Advanced Features)
