from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0034_gamechallenge'),
    ]

    operations = [
        migrations.AlterField(
            model_name='groupevent',
            name='group',
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.CASCADE,
                related_name='events',
                to='core.group',
            ),
        ),
    ]
