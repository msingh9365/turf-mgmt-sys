from django.urls import path
from . import views

urlpatterns = [
    # Teams
    path("teams/", views.list_or_create_team, name="team-list-create"),
    path("teams/<int:id>/", views.retrieve_team_details, name="team-detail"),
    path("teams/by-sport/", views.list_teams_by_sport, name="teams-by-sport"),

    # Team actions
    path("teams/<int:id>/invite-member/", views.invite_player_to_team, name="team-invite-member"),
    path("teams/<int:id>/request-to-join/", views.request_to_join_team, name="team-request-to-join"),
    path("teams/<int:id>/remove-member/", views.remove_member, name="team-remove-member"),
    path("teams/<int:id>/leave/", views.leave_team, name="team-leave"),
    path("teams/<int:team_id>/bulk-update-members/", views.bulk_update_members, name="team-bulk-update-members"),
    path("teams/<int:team_id>/transfer-captain/", views.transfer_captain, name="team-transfer-captain"),

    # Invitations
    path("invitations/match-invite/", views.invite_team_for_match, name="match-invite"),
    path("invitations/team-invite/<int:id>/respond/", views.respond_to_team_invitation, name="respond-to-team-invite"),
    path("invitations/team-request/<int:id>/respond/", views.respond_to_join_request, name="respond-to-team-request"),
    path("invitations/match-invite/<int:id>/respond/", views.respond_to_match_invitation, name="respond-to-match-invite"),
]
