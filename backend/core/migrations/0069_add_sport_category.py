from django.db import migrations


def add_sport_category(apps, schema_editor):
    Category = apps.get_model('core', 'Category')
    Category.objects.get_or_create(
        slug='sport',
        defaults={
            'name': 'Sport',
            'sector': 'entertainment',
            'category_type': 'product',
        },
    )


class Migration(migrations.Migration):

    dependencies = [
        ('core', '0068_reel_video_effects'),
    ]

    operations = [
        migrations.RunPython(add_sport_category, migrations.RunPython.noop),
    ]
