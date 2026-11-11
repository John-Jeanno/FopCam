import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('core', '0033_gamereward'),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name='GameChallenge',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('status', models.CharField(choices=[('pending', 'En attente'), ('accepted', 'Accepté'), ('declined', 'Refusé'), ('completed', 'Terminé')], default='pending', max_length=12)),
                ('challenger_score', models.PositiveIntegerField(blank=True, null=True)),
                ('challenged_score', models.PositiveIntegerField(blank=True, null=True)),
                ('challenged', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='received_game_challenges', to=settings.AUTH_USER_MODEL)),
                ('challenger', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='sent_game_challenges', to=settings.AUTH_USER_MODEL)),
                ('winner', models.ForeignKey(blank=True, null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='won_game_challenges', to=settings.AUTH_USER_MODEL)),
            ],
            options={
                'ordering': ('-created_at',),
            },
        ),
    ]
