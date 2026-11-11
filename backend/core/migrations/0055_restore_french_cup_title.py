from django.db import migrations


def restore_french_title(apps, schema_editor):
    GameReward = apps.get_model('core', 'GameReward')
    GameDuelReward = apps.get_model('core', 'GameDuelReward')
    GameReward.objects.filter(title='Champion 1ère League').update(
        title='Champion 1ère Ligue',
    )
    GameDuelReward.objects.filter(title='Champion 1ère League').update(
        title='Champion 1ère Ligue',
    )


def restore_previous_title(apps, schema_editor):
    GameReward = apps.get_model('core', 'GameReward')
    GameDuelReward = apps.get_model('core', 'GameDuelReward')
    GameReward.objects.filter(title='Champion 1ère Ligue').update(
        title='Champion 1ère League',
    )
    GameDuelReward.objects.filter(title='Champion 1ère Ligue').update(
        title='Champion 1ère League',
    )


class Migration(migrations.Migration):
    dependencies = [('core', '0054_game_reward_cup_pro')]

    operations = [
        migrations.RunPython(restore_french_title, restore_previous_title),
    ]
