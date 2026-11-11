from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0042_userprofile_last_seen_at'),
    ]

    operations = [
        migrations.AddField(
            model_name='gamechallenge',
            name='round_number',
            field=models.PositiveSmallIntegerField(default=1),
        ),
        migrations.AddField(
            model_name='gamechallenge',
            name='challenger_round_complete',
            field=models.BooleanField(default=False),
        ),
        migrations.AddField(
            model_name='gamechallenge',
            name='challenged_round_complete',
            field=models.BooleanField(default=False),
        ),
    ]
