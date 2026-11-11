from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0035_make_group_event_public'),
    ]

    operations = [
        migrations.AddField(
            model_name='post',
            name='background_color',
            field=models.CharField(blank=True, default='', max_length=7),
        ),
    ]
