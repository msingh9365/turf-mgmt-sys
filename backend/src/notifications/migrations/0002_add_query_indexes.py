# Generated migration for adding database indexes to optimize notification queries

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('notifications', '0001_initial'),
    ]

    operations = [
        # Add indexes to UserDevice model
        migrations.AddIndex(
            model_name='userdevice',
            index=models.Index(fields=['user', 'is_active'], name='userdevice_user_active_idx'),
        ),
        migrations.AddIndex(
            model_name='userdevice',
            index=models.Index(fields=['is_active'], name='userdevice_active_idx'),
        ),
        
        # Add indexes to Notification model
        migrations.AddIndex(
            model_name='notification',
            index=models.Index(fields=['user', '-created_at'], name='notif_user_created_idx'),
        ),
        migrations.AddIndex(
            model_name='notification',
            index=models.Index(fields=['user', 'is_read'], name='notif_user_read_idx'),
        ),
        migrations.AddIndex(
            model_name='notification',
            index=models.Index(fields=['user', 'is_read', '-created_at'], name='notif_user_read_created_idx'),
        ),
    ]
