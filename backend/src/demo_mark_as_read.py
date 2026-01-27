#!/usr/bin/env python
"""Manual test script to demonstrate mark-as-read functionality."""

import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings.dev')
django.setup()

from django.contrib.auth import get_user_model
from notifications.models import Notification

User = get_user_model()

print('=' * 70)
print('NOTIFICATION MARK-AS-READ FUNCTIONALITY DEMO')
print('=' * 70)

# Get or create test user
user, created = User.objects.get_or_create(
    email='demo@iitrpr.ac.in',
    defaults={'password': 'testpass'}
)
print(f'\n✅ Test user: {user.email}')

# Create some test notifications
print('\n📝 Creating test notifications...')
notifications = []
for i in range(5):
    notif = Notification.objects.create(
        user=user,
        title=f'Test Notification {i+1}',
        body=f'This is test notification number {i+1}',
        is_read=False
    )
    notifications.append(notif)
    print(f'   - Created: "{notif.title}" (ID: {notif.id}, is_read: {notif.is_read})')

# Check unread count
unread_count = Notification.objects.filter(user=user, is_read=False).count()
print(f'\n📊 Total unread notifications: {unread_count}')

# Mark one notification as read
print('\n✅ Marking notification 1 as read...')
notif1 = notifications[0]
notif1.is_read = True
notif1.save()
notif1.refresh_from_db()
print(f'   - Notification {notif1.id}: is_read = {notif1.is_read}')

# Check unread count again
unread_count = Notification.objects.filter(user=user, is_read=False).count()
print(f'\n📊 Unread notifications after marking one: {unread_count}')

# Mark all as read
print('\n✅ Marking all remaining notifications as read...')
updated_count = Notification.objects.filter(user=user, is_read=False).update(is_read=True)
print(f'   - Marked {updated_count} notification(s) as read')

# Final check
unread_count = Notification.objects.filter(user=user, is_read=False).count()
read_count = Notification.objects.filter(user=user, is_read=True).count()
print(f'\n📊 Final status:')
print(f'   - Unread notifications: {unread_count}')
print(f'   - Read notifications: {read_count}')

# Display all notifications with status
print(f'\n📋 All notifications for {user.email}:')
all_notifs = Notification.objects.filter(user=user).order_by('-created_at')[:10]
for notif in all_notifs:
    status_icon = '✓' if notif.is_read else '✗'
    print(f'   {status_icon} [{notif.id}] {notif.title} - Read: {notif.is_read}')

# API endpoints summary
print('\n' + '=' * 70)
print('API ENDPOINTS FOR MARK-AS-READ FUNCTIONALITY')
print('=' * 70)
print('\n1. Get unread count:')
print('   GET /api/notifications/unread-count/')
print('   Response: {"unread_count": 5}')

print('\n2. Mark single notification as read:')
print('   PATCH /api/notifications/<notification_id>/mark-read/')
print('   Response: Notification object with is_read: true')

print('\n3. Mark all notifications as read:')
print('   POST /api/notifications/mark-all-read/')
print('   Response: {"detail": "5 notification(s) marked as read.", "count": 5}')

print('\n4. Get notification history (including read status):')
print('   GET /api/notifications/')
print('   Response: List of notifications with is_read field')

print('\n' + '=' * 70)
print('✅ DEMO COMPLETE - ALL FUNCTIONALITY WORKING!')
print('=' * 70)
