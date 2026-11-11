from django.contrib.auth.models import User
from django.db.models import ProtectedError
from django.test import TestCase
from rest_framework.test import APIClient

from core.models import Product, Shop


class ProductPersistenceTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(username='persistent-vendor')
        self.shop = Shop.objects.create(
            owner=self.owner,
            name='Boutique persistante',
        )
        self.product = Product.objects.create(
            shop=self.shop,
            title='Produit conservé',
            price='1200.00',
            quantity=5,
            is_active=True,
        )

    def test_instance_delete_is_blocked_without_manual_action(self):
        with self.assertRaises(ProtectedError):
            self.product.delete()

        self.assertTrue(Product.all_objects.filter(pk=self.product.pk).exists())
        self.assertFalse(self.product.is_deleted)

    def test_queryset_delete_is_blocked_without_manual_action(self):
        with self.assertRaises(ProtectedError):
            Product.objects.filter(pk=self.product.pk).delete()

        self.assertTrue(Product.all_objects.filter(pk=self.product.pk).exists())
        self.assertFalse(self.product.is_deleted)

    def test_manual_api_delete_hides_but_preserves_product(self):
        client = APIClient()
        client.force_authenticate(user=self.owner)

        response = client.delete(f'/api/products/{self.product.pk}/')

        self.assertEqual(response.status_code, 204)
        self.product.refresh_from_db()
        self.assertTrue(self.product.is_deleted)
        self.assertEqual(self.product.deleted_by, self.owner)
        self.assertEqual(self.product.title, 'Produit conservé')
        self.assertEqual(
            client.get('/api/products/my/').data,
            [],
        )
        self.assertEqual(
            APIClient().get(f'/api/products/{self.product.pk}/').status_code,
            404,
        )

    def test_deleted_product_can_be_restored(self):
        self.product.manual_delete(deleted_by=self.owner)

        Product.all_objects.filter(pk=self.product.pk).restore()

        self.product.refresh_from_db()
        self.assertFalse(self.product.is_deleted)
        self.assertIsNone(self.product.deleted_at)
        self.assertIsNone(self.product.deleted_by)

    def test_shop_cannot_be_deleted_while_products_are_preserved(self):
        client = APIClient()
        client.force_authenticate(user=self.owner)

        response = client.delete(f'/api/shops/{self.shop.pk}/')

        self.assertEqual(response.status_code, 400)
        self.assertTrue(Product.all_objects.filter(pk=self.product.pk).exists())
        self.assertTrue(Shop.objects.filter(pk=self.shop.pk).exists())
