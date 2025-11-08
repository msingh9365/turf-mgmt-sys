from .fcm_service import send_fcm_notification

def send_team_invite_notification(recipient, sender, team, invitation):
    if recipient.fcm_token:
        send_fcm_notification(
            fcm_token=recipient.fcm_token,
            title=f'You have been invited to join {team.team_name}',
            body=f'{sender.name} has invited you to join their team.',
            payload={
                'invitation_id': str(invitation.invitation_id),
                'type': 'TEAM_INVITE',
                'action_link': f'myapp://teams/{team.team_id}/invite'
            }
        )

def send_join_request_notification(recipient, sender, team, invitation):
    if recipient.fcm_token:
        send_fcm_notification(
            fcm_token=recipient.fcm_token,
            title=f'New request to join {team.team_name}',
            body=f'{sender.name} has requested to join your team.',
            payload={
                'invitation_id': str(invitation.invitation_id),
                'type': 'TEAM_REQUEST',
                'action_link': f'myapp://teams/{team.team_id}/requests'
            }
        )

def send_match_invite_notification(recipient, sender_team, invitation):
    if recipient.fcm_token:
        recipient_team = recipient.teams.first()
        send_fcm_notification(
            fcm_token=recipient.fcm_token,
            title=f'New Match Invitation for {recipient_team.team_name}',
            body=f'{sender_team.team_name} has invited your team for a match.',
            payload={
                'invitation_id': str(invitation.invitation_id),
                'type': 'MATCH_INVITE',
                'action_link': f'myapp://invitations/{invitation.invitation_id}'
            }
        )

def send_invitation_response_notification(recipient, team_name, response, invitation):
    if recipient.fcm_token:
        send_fcm_notification(
            fcm_token=recipient.fcm_token,
            title=f'Team Invitation {response.capitalize()}',
            body=f'{recipient.name} has {response.lower()} your invitation to join {team_name}.',
            payload={'invitation_id': str(invitation.invitation_id), 'type': 'INVITATION_RESPONSE'}
        )

def send_join_request_response_notification(recipient, team_name, response, invitation):
    if recipient.fcm_token:
        send_fcm_notification(
            fcm_token=recipient.fcm_token,
            title=f'Team Request {response.capitalize()}',
            body=f'Your request to join {team_name} has been {response.lower()}.',
            payload={'invitation_id': str(invitation.invitation_id), 'type': 'INVITATION_RESPONSE'}
        )

def send_match_invitation_response_notification(recipient, sender_team, response, invitation):
    if recipient.fcm_token:
        send_fcm_notification(
            fcm_token=recipient.fcm_token,
            title=f'Match Invitation {response.capitalize()}',
            body=f'The captain of {sender_team.team_name} has {response.lower()} your match invitation.',
            payload={'invitation_id': str(invitation.invitation_id), 'type': 'INVITATION_RESPONSE'}
        )
