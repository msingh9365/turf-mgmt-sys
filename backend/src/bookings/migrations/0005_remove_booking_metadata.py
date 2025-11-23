from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("bookings", "0004_booked_details_idx_member_lock_and_more"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="booking",
            name="metadata",
        ),
    ]
