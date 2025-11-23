# Generated manually to align models with new booking workflow
from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ("bookings", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="booked_details",
            name="player_name",
            field=models.CharField(db_column="player_name", default="", max_length=100),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name="booking",
            name="ground",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.RESTRICT,
                related_name="bookings",
                db_column="Ground_ID",
                to="bookings.ground",
            ),
        ),
    ]
