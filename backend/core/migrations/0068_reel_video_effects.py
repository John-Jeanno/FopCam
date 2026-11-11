from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0067_userprofile_skills'),
    ]

    operations = [
        migrations.AddField(
            model_name='reel',
            name='theme',
            field=models.CharField(
                choices=[
                    ('Produits', 'Produits'),
                    ('Recettes', 'Recettes'),
                    ('Vie locale', 'Vie locale'),
                    ('Tendances', 'Tendances'),
                ],
                default='Produits',
                max_length=32,
            ),
        ),
        migrations.AddField(
            model_name='reel',
            name='effect',
            field=models.CharField(
                choices=[
                    ('none', 'Aucun'),
                    ('light', 'Lumière'),
                    ('stickers', 'Autocollants'),
                    ('before_after', 'Avant / après'),
                    ('face', 'Visage'),
                ],
                default='none',
                max_length=20,
            ),
        ),
        migrations.AddField(
            model_name='reel',
            name='sticker',
            field=models.CharField(
                blank=True,
                choices=[
                    ('sparkle', 'Étincelles'),
                    ('heart', 'Cœur'),
                    ('star', 'Étoile'),
                    ('cool', 'Lunettes'),
                ],
                default='',
                max_length=16,
            ),
        ),
    ]
