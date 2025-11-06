from django.db import migrations


class Migration(migrations.Migration):
    # This migration is superseded by 0005_remove_booking_metadata to resolve graph conflicts.
    # Make it depend on 0005 and perform no operations.
    dependencies = [
        ("bookings", "0005_remove_booking_metadata"),
    ]

    operations = []
