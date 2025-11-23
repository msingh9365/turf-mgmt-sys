from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone
from notifications.models import UserDevice

class Command(BaseCommand):
    help = "Prune inactive or stale FCM device tokens."

    def add_arguments(self, parser):
        parser.add_argument(
            "--days-inactive",
            type=int,
            default=7,
            help="Days since last_active after which inactive tokens are deleted or active tokens are marked inactive.",
        )
        parser.add_argument(
            "--delete",
            action="store_true",
            help="Delete matching tokens instead of only marking them inactive.",
        )

    def handle(self, *args, **options):
        days = options["days_inactive"]
        delete = options["delete"]
        cutoff = timezone.now() - timedelta(days=days)

        # First mark stale active tokens inactive
        stale_active_qs = UserDevice.objects.filter(is_active=True, last_active__lt=cutoff)
        marked_count = stale_active_qs.update(is_active=False)

        # Collect all inactive tokens older than cutoff
        inactive_qs = UserDevice.objects.filter(is_active=False, last_active__lt=cutoff)
        inactive_count = inactive_qs.count()

        if delete:
            deleted = 0
            for device in inactive_qs.iterator():
                device.delete()
                deleted += 1
            self.stdout.write(self.style.SUCCESS(
                f"Marked {marked_count} active tokens inactive; deleted {deleted} fully inactive stale tokens (> {days} days)."
            ))
        else:
            self.stdout.write(self.style.SUCCESS(
                f"Marked {marked_count} active tokens inactive; {inactive_count} inactive stale tokens retained (use --delete to remove)."
            ))
