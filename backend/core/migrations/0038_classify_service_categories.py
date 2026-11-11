from django.db import migrations


SERVICE_CATEGORY_SLUGS = (
    'sante-avicole',
    'veterinaire',
    'services-nettoyage',
    'maintenance-electrique',
    'coiffure-beaute',
    'transport-livraison',
    'education-formation',
)


def classify_service_categories(apps, schema_editor):
    Category = apps.get_model('core', 'Category')
    Category.objects.filter(slug__in=SERVICE_CATEGORY_SLUGS).update(
        category_type='professional',
    )


def restore_service_categories(apps, schema_editor):
    Category = apps.get_model('core', 'Category')
    Category.objects.filter(slug__in=SERVICE_CATEGORY_SLUGS).update(
        category_type='product',
    )


class Migration(migrations.Migration):
    dependencies = [
        ('core', '0037_shopshare_shoplike_shopvote'),
    ]

    operations = [
        migrations.RunPython(
            classify_service_categories,
            restore_service_categories,
        ),
    ]