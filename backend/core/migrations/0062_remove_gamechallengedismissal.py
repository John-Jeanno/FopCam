from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0061_game_challenge_cancellation_and_message_cleanup'),
    ]

    operations = [
        migrations.DeleteModel(
            name='GameChallengeDismissal',
        ),
    ]
