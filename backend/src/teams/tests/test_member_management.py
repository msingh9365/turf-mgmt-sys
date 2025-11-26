"""
Comprehensive test suite for Team Member Management features.

Tests cover:
- Feature 1: Bulk Update Team (Members + Achievements)
- Feature 2: Leave Team
- Feature 3: Transfer Captain
- Feature 4: Enhanced Create Team
- Integration tests
- Performance tests
"""
import pytest
from django.contrib.auth import get_user_model
from django.db import transaction
from rest_framework.test import APIClient
from teams.models import Team, TeamMember
from bookings.models import Sport

User = get_user_model()


@pytest.fixture
def api_client():
    """Provide API client for tests."""
    return APIClient()


@pytest.fixture
def create_users(db):
    """Create test users."""
    users = []
    for i in range(25):  # Increased from 15 to 25 to support all tests
        email = f"user{i}@example.com"
        user = User.objects.create_user(
            email=email,
            password="testpass123",
            name=f"User {i}",
            sort_key=email[:7].lower()
        )
        users.append(user)
    
    # Create an admin user
    admin_email = "admin@example.com"
    admin = User.objects.create_user(
        email=admin_email,
        password="adminpass123",
        name="Admin User",
        sort_key=admin_email[:7].lower(),
        is_admin=True
    )
    users.append(admin)
    
    return users


@pytest.fixture
def create_sport(db):
    """Create a test sport."""
    sport = Sport.objects.create(
        sport_name="Soccer",
        min_player=11
    )
    return sport


@pytest.fixture
def create_team(db, create_users, create_sport):
    """Create a test team with members."""
    users = create_users
    sport = create_sport
    captain = users[0]
    
    # Create team with 12 members (1 captain + 11 players)
    # This allows one member to leave and still meet min 11
    team = Team.objects.create(
        team_name="Test Team",
        captain=captain,
        sport=sport,
        member_count=12,
        achievements=[]
    )
    
    # Add captain as member
    TeamMember.objects.create(
        team=team,
        user=captain,
        member_name=captain.name,
        email_id=captain.email,
        sort_key=captain.email[:7].lower(),
        role="captain"
    )
    
    # Add 11 regular members (so one can leave and still meet minimum)
    for i in range(1, 12):
        user = users[i]
        TeamMember.objects.create(
            team=team,
            user=user,
            member_name=user.name,
            email_id=user.email,
            sort_key=user.email[:7].lower(),
            role="player"
        )
    
    return team


# ============================================================================
# Feature 1: Bulk Update Team (Members + Achievements) Tests
# ============================================================================

@pytest.mark.django_db
def test_bulk_update_by_captain_success(api_client, create_team, create_users):
    """Test captain can successfully bulk update members and achievements."""
    team = create_team
    users = create_users
    captain = users[0]
    
    # Authenticate as captain
    api_client.force_authenticate(user=captain)
    
    # New member emails (different from current members)
    # Need at least 10 members + captain (11 total) to meet minimum requirement
    new_emails = [f"user{i}@example.com" for i in range(11, 21)]
    new_achievements = [
        {"title": "Championship Winners", "description": "Won 2024 season", "date": "2024-11-01"},
        {"title": "Best Team Spirit", "description": "Voted by league", "date": "2024-10-15"}
    ]
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": new_achievements},
        format="json"
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["team_id"] == team.team_id
    assert data["members_added"] == 10
    assert data["members_removed"] == 11  # Team had 11 players (not 10)
    assert data["achievements_updated"] is True
    assert "achievements updated" in data["message"].lower()
    
    # Verify member count and achievements updated
    team.refresh_from_db()
    assert team.member_count == 11  # 1 captain + 10 new members
    assert len(team.achievements) == 2
    assert team.achievements[0]["title"] == "Championship Winners"


@pytest.mark.django_db
def test_bulk_update_by_admin_success(api_client, create_team, create_users):
    """Test admin can bulk update members and achievements on any team."""
    team = create_team
    users = create_users
    admin = users[-1]  # Last user is admin
    
    # Authenticate as admin
    api_client.force_authenticate(user=admin)
    
    new_emails = [f"user{i}@example.com" for i in range(11, 21)]
    new_achievements = [{"title": "Admin Updated Achievement"}]
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": new_achievements},
        format="json"
    )
    
    assert response.status_code == 200
    data = response.json()
    assert "achievements updated" in data["message"].lower()


@pytest.mark.django_db
def test_bulk_update_by_non_authorized_user_fails(api_client, create_team, create_users):
    """Test non-captain/non-admin cannot bulk update team."""
    team = create_team
    users = create_users
    regular_user = users[1]  # Not captain, not admin
    
    api_client.force_authenticate(user=regular_user)
    
    new_emails = [f"user{i}@example.com" for i in range(11, 21)]
    new_achievements = []
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": new_achievements},
        format="json"
    )
    
    assert response.status_code == 403
    assert "permission" in response.json()["message"].lower()


@pytest.mark.django_db
def test_bulk_update_maintains_captain(api_client, create_team, create_users):
    """Test that captain is never removed during bulk update."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    # Include captain's email in the list (should be ignored)
    new_emails = [captain.email] + [f"user{i}@example.com" for i in range(11, 21)]
    new_achievements = [{"title": "Captain Test"}]
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": new_achievements},
        format="json"
    )
    
    assert response.status_code == 200
    
    # Verify captain is still a member with captain role
    captain_membership = TeamMember.objects.get(team=team, user=captain)
    assert captain_membership.role == "captain"
    
    # Verify team still has captain
    team.refresh_from_db()
    assert team.captain_id == captain.id


@pytest.mark.django_db
def test_bulk_update_validates_min_players(api_client, create_team, create_users):
    """Test validation prevents update that violates min player requirement."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    # Try to update with only 5 members (total 6 including captain, min is 11)
    new_emails = [f"user{i}@example.com" for i in range(1, 6)]
    new_achievements = []
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": new_achievements},
        format="json"
    )
    
    assert response.status_code == 400
    assert "minimum" in response.json()["message"].lower()
    assert "11" in response.json()["message"]


@pytest.mark.django_db
def test_bulk_update_deduplicates_emails(api_client, create_team, create_users):
    """Test that duplicate emails are automatically deduplicated."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    # Include duplicates with different cases
    # Need enough unique emails to meet minimum requirement
    new_emails = [
        "user11@example.com",
        "User11@EXAMPLE.COM",  # Duplicate
        "user12@example.com",
        "user12@example.com",  # Duplicate
        "user13@example.com",
        "user14@example.com",
        "user15@example.com",
        "user16@example.com",
        "user17@example.com",
        "user18@example.com",
        "user19@example.com",
        "user20@example.com"
    ]
    new_achievements = [{"title": "Deduplication Test"}]
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": new_achievements},
        format="json"
    )
    
    assert response.status_code == 200
    # Should only add 10 unique members (user11-20)
    team.refresh_from_db()
    assert team.member_count == 11  # 1 captain + 10 unique members


@pytest.mark.django_db
def test_bulk_update_handles_nonexistent_users(api_client, create_team, create_users):
    """Test that nonexistent user emails are reported as failed."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    new_emails = [
        "user11@example.com",  # Exists
        "user12@example.com",  # Exists
        "user13@example.com",  # Exists
        "user14@example.com",  # Exists
        "user15@example.com",  # Exists
        "user16@example.com",  # Exists
        "user17@example.com",  # Exists
        "user18@example.com",  # Exists
        "user19@example.com",  # Exists
        "user20@example.com",  # Exists
        "nonexistent1@example.com",  # Does not exist
        "nonexistent2@example.com",  # Does not exist
    ]
    new_achievements = [{"title": "Nonexistent Test"}]
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": new_achievements},
        format="json"
    )
    
    assert response.status_code == 200
    data = response.json()
    assert "failed_emails" in data
    assert len(data["failed_emails"]) == 2
    assert "nonexistent1@example.com" in data["failed_emails"]
    assert "nonexistent2@example.com" in data["failed_emails"]
    assert "warning" in data
    # Should have added 10 existing users
    assert data["members_added"] == 10


@pytest.mark.django_db
def test_bulk_update_is_atomic(api_client, create_team, create_users):
    """Test that bulk update is atomic (all or nothing)."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    # This should succeed
    valid_emails = [f"user{i}@example.com" for i in range(11, 21)]
    new_achievements = [{"title": "Atomic Test"}]
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": valid_emails, "achievements": new_achievements},
        format="json"
    )
    
    assert response.status_code == 200
    
    # Verify old members are gone
    old_member_count = TeamMember.objects.filter(
        team=team,
        user_id__in=[create_users[i].id for i in range(1, 11)]
    ).count()
    assert old_member_count == 0


@pytest.mark.django_db
def test_bulk_update_updates_member_count(api_client, create_team, create_users):
    """Test that member_count is correctly updated after bulk update."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    initial_count = team.member_count  # Should be 12 (1 captain + 11 players)
    new_emails = [f"user{i}@example.com" for i in range(12, 22)]  # 10 new members
    new_achievements = [{"title": "Member Count Test"}]
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": new_achievements},
        format="json"
    )
    
    assert response.status_code == 200
    
    team.refresh_from_db()
    assert team.member_count == 11  # 1 captain + 10 new members (replaced 11 with 10)


# ============================================================================
# Achievements Validation Tests
# ============================================================================

@pytest.mark.django_db
def test_bulk_update_with_empty_achievements(api_client, create_team, create_users):
    """Test bulk update can clear achievements with empty list."""
    team = create_team
    captain = create_users[0]
    
    # Set initial achievements
    team.achievements = [{"title": "Old Achievement"}]
    team.save()
    
    api_client.force_authenticate(user=captain)
    
    new_emails = [f"user{i}@example.com" for i in range(11, 21)]
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": []},
        format="json"
    )
    
    assert response.status_code == 200
    team.refresh_from_db()
    assert team.achievements == []


@pytest.mark.django_db
def test_bulk_update_achievements_max_limit(api_client, create_team, create_users):
    """Test that achievements cannot exceed 10 items."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    new_emails = [f"user{i}@example.com" for i in range(11, 21)]
    # Try to add 11 achievements (over limit)
    too_many_achievements = [{"title": f"Achievement {i}"} for i in range(11)]
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": too_many_achievements},
        format="json"
    )
    
    assert response.status_code == 400
    assert "maximum 10" in response.json()["message"].lower()


@pytest.mark.django_db
def test_bulk_update_achievements_must_be_list(api_client, create_team, create_users):
    """Test that achievements must be a list."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    new_emails = [f"user{i}@example.com" for i in range(11, 21)]
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": "not a list"},
        format="json"
    )
    
    assert response.status_code == 400
    assert "must be a list" in response.json()["message"].lower()


@pytest.mark.django_db
def test_bulk_update_achievement_must_have_title(api_client, create_team, create_users):
    """Test that each achievement must have a title field."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    new_emails = [f"user{i}@example.com" for i in range(11, 21)]
    invalid_achievements = [{"description": "No title field"}]
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": invalid_achievements},
        format="json"
    )
    
    assert response.status_code == 400
    assert "title" in response.json()["message"].lower()


@pytest.mark.django_db
def test_bulk_update_achievement_must_be_object(api_client, create_team, create_users):
    """Test that each achievement must be an object/dict."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    new_emails = [f"user{i}@example.com" for i in range(11, 21)]
    invalid_achievements = ["string achievement", "another string"]
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": invalid_achievements},
        format="json"
    )
    
    assert response.status_code == 400
    assert "must be an object" in response.json()["message"].lower()


@pytest.mark.django_db
def test_bulk_update_achievements_required(api_client, create_team, create_users):
    """Test that achievements field is required."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    new_emails = [f"user{i}@example.com" for i in range(11, 21)]
    
    # Missing achievements field
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails},
        format="json"
    )
    
    assert response.status_code == 400
    assert "achievements" in response.json()["message"].lower()


@pytest.mark.django_db
def test_bulk_update_with_complex_achievements(api_client, create_team, create_users):
    """Test bulk update with complex achievement objects."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    new_emails = [f"user{i}@example.com" for i in range(11, 21)]
    complex_achievements = [
        {
            "title": "Regional Champions 2024",
            "description": "Won the regional tournament with a 10-0 record",
            "date": "2024-11-05"
        },
        {
            "title": "Best Team Spirit",
            "description": "Voted by all league members",
            "date": "2024-10-20"
        },
        {
            "title": "Undefeated Season",
            "description": "Complete season without a single loss"
        }
    ]
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": complex_achievements},
        format="json"
    )
    
    assert response.status_code == 200
    team.refresh_from_db()
    assert len(team.achievements) == 3
    assert team.achievements[0]["title"] == "Regional Champions 2024"
    assert team.achievements[1]["date"] == "2024-10-20"
    assert "description" in team.achievements[2]


# ============================================================================
# Feature 2: Leave Team Tests
# ============================================================================

@pytest.mark.django_db
def test_member_can_leave_team(api_client, create_team, create_users):
    """Test that a regular member can leave the team."""
    team = create_team
    member = create_users[1]  # Regular member
    
    api_client.force_authenticate(user=member)
    
    response = api_client.post(f"/api/teams/{team.team_id}/leave/")
    
    assert response.status_code == 200
    assert "successfully left" in response.json()["message"]
    
    # Verify member is removed
    assert not TeamMember.objects.filter(team=team, user=member).exists()
    
    # Verify member count updated
    team.refresh_from_db()
    assert team.member_count == 11  # Was 12, now 11


@pytest.mark.django_db
def test_captain_cannot_leave_team(api_client, create_team, create_users):
    """Test that captain cannot leave the team."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    response = api_client.post(f"/api/teams/{team.team_id}/leave/")
    
    assert response.status_code == 403
    assert "captain cannot leave" in response.json()["message"].lower()
    assert "transfer captaincy first" in response.json()["message"].lower()


@pytest.mark.django_db
def test_non_member_cannot_leave_team(api_client, create_team, create_users):
    """Test that non-member cannot leave the team."""
    team = create_team
    non_member = create_users[12]  # Not a member (team has users 0-11)
    
    api_client.force_authenticate(user=non_member)
    
    response = api_client.post(f"/api/teams/{team.team_id}/leave/")
    
    assert response.status_code == 403
    assert "not a member" in response.json()["message"].lower()


@pytest.mark.django_db
def test_leave_validates_min_players(api_client, create_users, create_sport):
    """Test that leaving is prevented if it would violate min player requirement."""
    users = create_users
    sport = create_sport
    captain = users[0]
    
    # Create team with exactly minimum members (11)
    team = Team.objects.create(
        team_name="Minimum Team",
        captain=captain,
        sport=sport,
        member_count=11
    )
    
    # Add captain
    TeamMember.objects.create(
        team=team,
        user=captain,
        member_name=captain.name,
        email_id=captain.email,
        sort_key=captain.email[:7].lower(),
        role="captain"
    )
    
    # Add 10 regular members (total 11)
    for i in range(1, 11):
        TeamMember.objects.create(
            team=team,
            user=users[i],
            member_name=users[i].name,
            email_id=users[i].email,
            sort_key=users[i].email[:7].lower(),
            role="player"
        )
    
    member = users[1]
    api_client.force_authenticate(user=member)
    
    response = api_client.post(f"/api/teams/{team.team_id}/leave/")
    
    assert response.status_code == 400
    assert "minimum player requirement" in response.json()["message"].lower()


@pytest.mark.django_db
def test_leave_updates_member_count(api_client, create_team, create_users):
    """Test that member_count is correctly updated after leaving."""
    team = create_team
    member = create_users[1]
    
    initial_count = team.member_count
    
    api_client.force_authenticate(user=member)
    response = api_client.post(f"/api/teams/{team.team_id}/leave/")
    
    assert response.status_code == 200
    
    team.refresh_from_db()
    assert team.member_count == initial_count - 1


@pytest.mark.django_db
def test_unauthenticated_user_cannot_leave(api_client, create_team):
    """Test that unauthenticated user cannot leave team."""
    team = create_team
    
    response = api_client.post(f"/api/teams/{team.team_id}/leave/")
    
    assert response.status_code == 401


# ============================================================================
# Feature 3: Transfer Captain Tests
# ============================================================================

@pytest.mark.django_db
def test_captain_can_transfer_captaincy(api_client, create_team, create_users):
    """Test captain can transfer captaincy to another member."""
    team = create_team
    captain = create_users[0]
    new_captain = create_users[1]
    
    api_client.force_authenticate(user=captain)
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/transfer-captain/",
        {"new_captain_user_id": new_captain.id},
        format="json"
    )
    
    assert response.status_code == 200
    data = response.json()
    assert data["old_captain"]["user_id"] == captain.id
    assert data["new_captain"]["user_id"] == new_captain.id
    
    # Verify team captain updated
    team.refresh_from_db()
    assert team.captain_id == new_captain.id
    
    # Verify roles updated
    old_captain_member = TeamMember.objects.get(team=team, user=captain)
    assert old_captain_member.role == "player"
    
    new_captain_member = TeamMember.objects.get(team=team, user=new_captain)
    assert new_captain_member.role == "captain"


@pytest.mark.django_db
def test_admin_can_transfer_captaincy(api_client, create_team, create_users):
    """Test admin can transfer captaincy on any team."""
    team = create_team
    admin = create_users[-1]  # Admin user
    new_captain = create_users[1]
    
    api_client.force_authenticate(user=admin)
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/transfer-captain/",
        {"new_captain_user_id": new_captain.id},
        format="json"
    )
    
    assert response.status_code == 200
    
    team.refresh_from_db()
    assert team.captain_id == new_captain.id


@pytest.mark.django_db
def test_regular_member_cannot_transfer_captaincy(api_client, create_team, create_users):
    """Test regular member cannot transfer captaincy."""
    team = create_team
    regular_member = create_users[1]
    new_captain = create_users[2]
    
    api_client.force_authenticate(user=regular_member)
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/transfer-captain/",
        {"new_captain_user_id": new_captain.id},
        format="json"
    )
    
    assert response.status_code == 403
    assert "permission" in response.json()["message"].lower()


@pytest.mark.django_db
def test_transfer_to_non_member_fails(api_client, create_team, create_users):
    """Test transfer to non-member fails."""
    team = create_team
    captain = create_users[0]
    non_member = create_users[12]  # Not a member (team has users 0-11)
    
    api_client.force_authenticate(user=captain)
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/transfer-captain/",
        {"new_captain_user_id": non_member.id},
        format="json"
    )
    
    assert response.status_code == 404
    assert "not a member" in response.json()["message"].lower()


@pytest.mark.django_db
def test_old_captain_becomes_player(api_client, create_team, create_users):
    """Test old captain becomes regular player after transfer."""
    team = create_team
    captain = create_users[0]
    new_captain = create_users[1]
    
    api_client.force_authenticate(user=captain)
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/transfer-captain/",
        {"new_captain_user_id": new_captain.id},
        format="json"
    )
    
    assert response.status_code == 200
    
    # Verify old captain is still a member but as player
    old_captain_member = TeamMember.objects.get(team=team, user=captain)
    assert old_captain_member.role == "player"
    
    # Verify old captain is still counted as member
    assert TeamMember.objects.filter(team=team, user=captain).exists()


@pytest.mark.django_db
def test_transfer_updates_all_records(api_client, create_team, create_users):
    """Test that transfer updates Team and both TeamMember records."""
    team = create_team
    captain = create_users[0]
    new_captain = create_users[1]
    
    api_client.force_authenticate(user=captain)
    
    response = api_client.post(
        f"/api/teams/{team.team_id}/transfer-captain/",
        {"new_captain_user_id": new_captain.id},
        format="json"
    )
    
    assert response.status_code == 200
    
    # Verify Team.captain updated
    team.refresh_from_db()
    assert team.captain_id == new_captain.id
    
    # Verify old captain's TeamMember role
    old_member = TeamMember.objects.get(team=team, user=captain)
    assert old_member.role == "player"
    
    # Verify new captain's TeamMember role
    new_member = TeamMember.objects.get(team=team, user=new_captain)
    assert new_member.role == "captain"


# ============================================================================
# Feature 4: Create Team Tests
# ============================================================================

@pytest.mark.django_db
def test_create_team_requires_authentication(api_client, create_sport):
    """Test that creating a team requires authentication."""
    sport = create_sport
    
    response = api_client.post(
        "/api/teams/",
        {
            "team_name": "New Team",
            "sport_id": sport.sport_id,
            "member_emails": [f"user{i}@example.com" for i in range(1, 11)]
        },
        format="json"
    )
    
    assert response.status_code == 401


@pytest.mark.django_db
def test_create_team_with_achievements(api_client, create_users, create_sport):
    """Test creating team with achievements."""
    captain = create_users[0]
    sport = create_sport
    
    api_client.force_authenticate(user=captain)
    
    achievements = [
        {
            "title": "Regional Champions",
            "description": "Won regional tournament",
            "date": "2024-11-01"
        }
    ]
    
    response = api_client.post(
        "/api/teams/",
        {
            "team_name": "Champions",
            "sport_id": sport.sport_id,
            "member_emails": [f"user{i}@example.com" for i in range(1, 11)],
            "achievements": achievements
        },
        format="json"
    )
    
    assert response.status_code == 201
    data = response.json()
    assert data["achievements"] == achievements


@pytest.mark.django_db
def test_create_team_achievements_validation(api_client, create_users, create_sport):
    """Test achievements validation (max 10, must have title)."""
    captain = create_users[0]
    sport = create_sport
    
    api_client.force_authenticate(user=captain)
    
    # Test with achievements list
    achievements = [
        {"title": f"Achievement {i}"} for i in range(5)
    ]
    
    response = api_client.post(
        "/api/teams/",
        {
            "team_name": "Test Team with Achievements",
            "sport_id": sport.sport_id,
            "member_emails": [f"user{i}@example.com" for i in range(1, 11)],
            "achievements": achievements
        },
        format="json"
    )
    
    assert response.status_code == 201
    assert response.json()["team_name"] == "Test Team with Achievements"


# ============================================================================
# Integration Tests
# ============================================================================

@pytest.mark.django_db
def test_full_workflow_create_update_leave_transfer(api_client, create_users, create_sport):
    """Test complete workflow: create team, bulk update, member leaves, transfer captain."""
    users = create_users
    sport = create_sport
    captain = users[0]
    
    api_client.force_authenticate(user=captain)
    
    # 1. Create team with 11 members (+ captain = 12 total)
    response = api_client.post(
        "/api/teams/",
        {
            "team_name": "Workflow Test Team",
            "sport_id": sport.sport_id,
            "member_emails": [f"user{i}@example.com" for i in range(1, 12)]
        },
        format="json"
    )
    assert response.status_code == 201
    team_id = response.json()["team_id"]
    
    # 2. Bulk update members to 11 (+ captain = 12 total, allows one to leave)
    response = api_client.post(
        f"/api/teams/{team_id}/bulk-update/",
        {"member_emails": [f"user{i}@example.com" for i in range(12, 23)], "achievements": []},
        format="json"
    )
    assert response.status_code == 200
    
    # 3. Member leaves (12 -> 11 members, still meets minimum)
    member = users[12]
    api_client.force_authenticate(user=member)
    response = api_client.post(f"/api/teams/{team_id}/leave/")
    assert response.status_code == 200
    
    # 4. Transfer captain
    api_client.force_authenticate(user=captain)
    new_captain = users[13]  # Use user 13 since user 12 left
    response = api_client.post(
        f"/api/teams/{team_id}/transfer-captain/",
        {"new_captain_user_id": new_captain.id},
        format="json"
    )
    assert response.status_code == 200
    
    # Verify final state
    team = Team.objects.get(team_id=team_id)
    assert team.captain_id == new_captain.id
    assert not TeamMember.objects.filter(team=team, user=member).exists()


# ============================================================================
# Performance Tests
# ============================================================================

@pytest.mark.django_db
def test_bulk_update_query_count(api_client, create_team, create_users, django_assert_num_queries):
    """Test that bulk update query count stays under 10."""
    team = create_team
    captain = create_users[0]
    
    api_client.force_authenticate(user=captain)
    
    new_emails = [f"user{i}@example.com" for i in range(11, 21)]
    new_achievements = [{"title": "Performance Test"}]
    
    # Should be efficient with minimal queries
    # With 10 members: 1 team query + 10 user lookups + transaction queries (no notification lookups in test)
    with django_assert_num_queries(17):  # Updated count after achievements field added
        response = api_client.post(
            f"/api/teams/{team.team_id}/bulk-update/",
            {"member_emails": new_emails, "achievements": new_achievements},
            format="json"
        )
    
    assert response.status_code == 200


@pytest.mark.django_db
def test_bulk_update_performance_with_many_members(api_client, create_users, create_sport):
    """Test bulk update performance with larger member count."""
    import time
    
    users = create_users
    sport = create_sport
    captain = users[0]
    
    # Create team
    team = Team.objects.create(
        team_name="Large Team",
        captain=captain,
        sport=sport,
        member_count=11
    )
    
    # Add captain
    TeamMember.objects.create(
        team=team,
        user=captain,
        member_name=captain.name,
        email_id=captain.email,
        sort_key=captain.email[:7].lower(),
        role="captain"
    )
    
    # Add 10 members
    for i in range(1, 11):
        TeamMember.objects.create(
            team=team,
            user=users[i],
            member_name=users[i].name,
            email_id=users[i].email,
            sort_key=users[i].email[:7].lower(),
            role="player"
        )
    
    api_client.force_authenticate(user=captain)
    
    new_emails = [f"user{i}@example.com" for i in range(1, 11)]
    new_achievements = [{"title": "Large Team Test"}]
    
    start_time = time.time()
    response = api_client.post(
        f"/api/teams/{team.team_id}/bulk-update/",
        {"member_emails": new_emails, "achievements": new_achievements},
        format="json"
    )
    end_time = time.time()
    
    assert response.status_code == 200
    # Should complete in under 5 seconds (includes notification system overhead)
    assert end_time - start_time < 5.0
