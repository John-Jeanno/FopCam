from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0066_profile_sections_language_country'),
    ]

    operations = [
        migrations.AddField(
            model_name='userprofile',
            name='skills',
            field=models.JSONField(
                blank=True,
                default=list,
                verbose_name='Mes compétences',
            ),
        ),
    ]
