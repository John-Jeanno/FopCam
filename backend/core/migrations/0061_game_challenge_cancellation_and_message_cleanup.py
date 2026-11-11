from datetime import timedelta

from django.conf import settings
from django.db import migrations, models
from django.utils import timezone
import django.db.models.deletion
import core.models


SAMPLE_MESSAGES = (
    (
        'vet-chat-buyer2',
        'buyer2',
        'Bonjour, je cherche un vaccin adapté pour ma production de poulets bio.',
    ),
    (
        'vet-chat-buyer2',
        'vet1',
        'Bonjour Sophie, je vous recommande le vaccin contre la coccidiose et le sérum hydratant.',
    ),
    (
        'vet-chat-buyer3',
        'buyer3',
        'Quel produit pour améliorer la santé de mes cailles ?',
    ),
    (
        'vet-chat-buyer3',
        'producer5',
        'Je vous conseille les pansements antiseptiques et un traitement préventif.',
    ),
)


def remove_sample_messages(apps, schema_editor):
    Message = apps.get_model('core', 'Message')
    database = schema_editor.connection.alias
    for room, username, content in SAMPLE_MESSAGES:
        Message.objects.using(database).filter(
            room=room,
            user__username=username,
            content=content,
        ).delete()


def shorten_existing_pending_challenges(apps, schema_editor):
    GameChallenge = apps.get_model('core', 'GameChallenge')
    database = schema_editor.connection.alias
    now = timezone.now()
    batch = []
    for challenge in GameChallenge.objects.using(database).filter(
        status='pending',
    ).iterator(chunk_size=1000):
        challenge.expires_at = challenge.created_at + timedelta(minutes=30)
        if challenge.expires_at <= now:
            challenge.status = 'expired'
        batch.append(challenge)
        if len(batch) == 1000:
            GameChallenge.objects.using(database).bulk_update(
                batch,
                ('expires_at', 'status'),
            )
            batch.clear()
    if batch:
        GameChallenge.objects.using(database).bulk_update(
            batch,
            ('expires_at', 'status'),
        )


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0060_profile_privacy_settings'),
    ]

    operations = [
        migrations.RunPython(remove_sample_messages, migrations.RunPython.noop),
        migrations.RunPython(
            shorten_existing_pending_challenges,
            migrations.RunPython.noop,
        ),
        migrations.AlterField(
            model_name='gamechallenge',
            name='expires_at',
            field=models.DateTimeField(
                db_index=True,
                default=core.models.game_challenge_expiry,
            ),
        ),
        migrations.AlterField(
            model_name='gamechallenge',
            name='status',
            field=models.CharField(
                choices=[
                    ('pending', 'En attente'),
                    ('accepted', 'Accepté'),
                    ('playing', 'En cours'),
                    ('declined', 'Refusé'),
                    ('cancelled', 'Annulé'),
                    ('completed', 'Terminé'),
                    ('expired', 'Expiré'),
                ],
                default='pending',
                max_length=12,
            ),
        ),
        migrations.CreateModel(
            name='GameChallengeDismissal',
            fields=[
                (
                    'id',
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name='ID',
                    ),
                ),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                (
                    'challenge',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='dismissals',
                        to='core.gamechallenge',
                    ),
                ),
                (
                    'user',
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name='dismissed_game_challenges',
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                'constraints': [
                    models.UniqueConstraint(
                        fields=('challenge', 'user'),
                        name='unique_game_challenge_dismissal_per_user',
                    ),
                ],
            },
        ),
    ]
