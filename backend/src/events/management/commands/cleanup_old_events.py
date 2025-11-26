"""
Management command to delete events that are more than 3 days past their end date.

Usage:
    python manage.py cleanup_old_events

Schedule this command to run daily via cron or task scheduler:
    - Linux/Mac cron: 0 2 * * * cd /path/to/project && python manage.py cleanup_old_events
    - Windows Task Scheduler: Run daily at 2 AM
"""
from django.core.management.base import BaseCommand
from django.utils import timezone
from datetime import timedelta
from events.models import Event


class Command(BaseCommand):
    help = 'Delete events that ended more than 3 days ago'

    def add_arguments(self, parser):
        parser.add_argument(
            '--dry-run',
            action='store_true',
            help='Show what would be deleted without actually deleting',
        )
        parser.add_argument(
            '--days',
            type=int,
            default=3,
            help='Number of days after event end to keep (default: 3)',
        )

    def handle(self, *args, **options):
        dry_run = options['dry_run']
        days_threshold = options['days']
        
        # Calculate the cutoff date
        cutoff_date = timezone.now() - timedelta(days=days_threshold)
        
        # Find events that should be deleted
        old_events = Event.objects.filter(ends_at__lt=cutoff_date)
        
        count = old_events.count()
        
        if count == 0:
            self.stdout.write(self.style.SUCCESS('No events to delete.'))
            return
        
        if dry_run:
            self.stdout.write(
                self.style.WARNING(f'DRY RUN: Would delete {count} event(s):')
            )
            for event in old_events:
                self.stdout.write(
                    f'  - [{event.id}] {event.title} (ended: {event.ends_at})'
                )
        else:
            # Delete the events
            deleted_events = []
            for event in old_events:
                deleted_events.append(f'{event.title} (ID: {event.id})')
            
            old_events.delete()
            
            self.stdout.write(
                self.style.SUCCESS(f'Successfully deleted {count} event(s):')
            )
            for event_info in deleted_events:
                self.stdout.write(f'  - {event_info}')
        
        self.stdout.write(
            self.style.SUCCESS(
                f'\nCleanup complete. Events older than {days_threshold} days after end date have been processed.'
            )
        )
