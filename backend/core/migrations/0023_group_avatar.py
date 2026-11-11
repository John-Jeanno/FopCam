from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0022_grouppost_privacy_grouppost_repost_of'),
    ]

    operations = [
        migrations.AddField(
            model_name='group',
            name='avatar',
            field=models.ImageField(upload_to='groups/avatars/', blank=True, null=True),
        ),
    ]
