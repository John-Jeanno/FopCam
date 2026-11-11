from django.db import migrations, models
from django.utils.translation import gettext_lazy as _


def award_cup_to_existing_champions(apps, schema_editor):
    GameChallenge = apps.get_model('core', 'GameChallenge')
    GameReward = apps.get_model('core', 'GameReward')
    opponents_by_winner = {}

    completed_challenges = GameChallenge.objects.filter(
        status='completed',
        winner_id__isnull=False,
    ).values_list(
        'winner_id',
        'challenger_id',
        'challenged_id',
    )
    for winner_id, challenger_id, challenged_id in completed_challenges:
        if winner_id == challenger_id:
            opponent_id = challenged_id
        elif winner_id == challenged_id:
            opponent_id = challenger_id
        else:
            continue
        opponents_by_winner.setdefault(winner_id, set()).add(opponent_id)

    qualifying_winner_ids = [
        winner_id
        for winner_id, opponent_ids in opponents_by_winner.items()
        if len(opponent_ids) >= 4
    ]
    for reward in GameReward.objects.filter(
        user_id__in=qualifying_winner_ids,
    ).iterator():
        earned_medals = list(reward.earned_duel_medals or [])
        if 'cup' not in earned_medals:
            earned_medals.append('cup')
        reward.duel_medal = 'cup'
        reward.earned_duel_medals = earned_medals
        reward.title = 'Champion 1ère Ligue'
        reward.save(
            update_fields=('duel_medal', 'earned_duel_medals', 'title')
        )


class Migration(migrations.Migration):
    dependencies = [
        ('core', '0048_gameduelreward'),
    ]

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
                ],
                default='none',
                max_length=10,
            ),
        ),
        migrations.RunPython(
            award_cup_to_existing_champions,
            migrations.RunPython.noop,
        ),
    ]
