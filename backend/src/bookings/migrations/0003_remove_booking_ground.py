# Generated to drop ground reference from Booking model
from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("bookings", "0003_alter_booking_ground_to_ground_id"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="booking",
            name="ground",
        ),
    ]
