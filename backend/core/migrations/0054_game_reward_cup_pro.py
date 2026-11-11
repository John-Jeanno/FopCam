from django.db import migrations, models
from django.utils.translation import gettext_lazy as _


def promote_existing_champions(apps, schema_editor):
    GameChallenge = apps.get_model('core', 'GameChallenge')
    GameReward = apps.get_model('core', 'GameReward')
    opponents_by_winner = {}
    completed = GameChallenge.objects.filter(
        status='completed',
        winner_id__isnull=False,
    ).values_list('winner_id', 'challenger_id', 'challenged_id')
    for winner_id, challenger_id, challenged_id in completed.iterator():
        if winner_id == challenger_id:
            opponent_id = challenged_id
        elif winner_id == challenged_id:
            opponent_id = challenger_id
        else:
            continue
        opponents_by_winner.setdefault(winner_id, set()).add(opponent_id)

    for winner_id, opponents in opponents_by_winner.items():
        reward = GameReward.objects.filter(user_id=winner_id).first()
        if reward is None:
            continue
        if len(opponents) >= 5:
            medals = list(reward.earned_duel_medals or [])
            if 'cup_pro' not in medals:
                medals.append('cup_pro')
            reward.duel_medal = 'cup_pro'
            reward.title = 'Champion League Pro'
            reward.earned_duel_medals = medals
            reward.save(
                update_fields=('duel_medal', 'earned_duel_medals', 'title')
            )
        elif reward.title == 'Champion 1ère Ligue':
            reward.title = 'Champion 1ère League'
            reward.save(update_fields=('title',))


class Migration(migrations.Migration):
    dependencies = [('core', '0053_jobseekerpost_resume')]

    operations = [
        migrations.AlterField(
            model_name='gamereward',
            name='duel_medal',
            field=models.CharField(
                choices=[
                    ('none', _('Aucune')),
                    ('bronze', _('Bronze')),
                    ('silver', _('Argent')),
                    ('gold', _('Or')),
                    ('cup', _('Coupe')),
                    ('cup_pro', _('Coupe Pro')),
                ],
                default='none',
                max_length=10,
            ),
        ),
        migrations.RunPython(
            promote_existing_champions,
            migrations.RunPython.noop,
        ),
    ]
