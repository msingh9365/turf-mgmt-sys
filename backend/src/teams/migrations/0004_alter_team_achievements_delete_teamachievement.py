# Generated migration

from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('teams', '0003_team_achievements_alter_teamachievement_team'),
    ]

    operations = [
        migrations.DeleteModel(
            name='TeamAchievement',
        ),
        migrations.AlterField(
            model_name='team',
            name='achievements',
            field=models.JSONField(
                blank=True, 
                default=list, 
                help_text='Team achievements (max 2). Each achievement should have: title, description, date'
            ),
        ),
    ]
