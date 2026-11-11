from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0069_add_sport_category'),
    ]

    operations = [
        migrations.AddField(
            model_name='userprofile',
            name='notification_sounds',
            field=models.JSONField(
                blank=True,
                default=dict,
                verbose_name='Sonneries des notifications',
            ),
        ),
    ]
