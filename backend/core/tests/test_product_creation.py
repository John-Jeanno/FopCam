import base64
from decimal import Decimal
from tempfile import TemporaryDirectory
from zlib import crc32

from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from core.models import Category, Product, ProductImage, Shop, StockMovement


def large_png_with_text_chunk():
    image_bytes = base64.b64decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
        '/x8AAwMCAO+jwS8AAAAASUVORK5CYII='
    )
    text = b'Comment\x00' + b'x' * 700_000
    chunk_type = b'tEXt'
    chunk = (
        len(text).to_bytes(4, 'big')
        + chunk_type
        + text
        + crc32(chunk_type + text).to_bytes(4, 'big')
    )
    return image_bytes[:33] + chunk + image_bytes[33:]


class ProductCreationTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(username='product-create-owner')
        self.shop = Shop.objects.create(
            owner=self.owner,
            name='Boutique test création produit',
            active=True,
        )
        self.category = Category.objects.create(
            name='Accessoires',
            slug='accessoires-product-create-test',
            category_type='product',
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.owner)

    def test_seller_creates_multipart_product_with_variants_and_images(self):
        image_bytes = base64.b64decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8'
            '/x8AAwMCAO+jwS8AAAAASUVORK5CYII='
        )
        with TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                response = self.client.post(
                    '/api/products/',
                    {
                        'title': 'Short de sport',
                        'description': 'Tailles et couleurs disponibles',
                        'purchase_price': '',
                        'price': '1250',
                        'promo_price': '',
                        'color_options': '["bleu","Noir","Gris"]',
                        'size_options': '["S","M","XL"]',
                        'quantity': '10',
                        'shop_id': str(self.shop.pk),
                        'category_id': str(self.category.pk),
                        'images': [
                            SimpleUploadedFile(
                                f'photo-{index}.png',
                                image_bytes,
                                content_type='image/png',
                            )
                            for index in range(4)
                        ],
                    },
                    format='multipart',
                    HTTP_HOST='testserver',
                )

        self.assertEqual(response.status_code, 201, response.data)
        product = Product.objects.get(pk=response.data['id'])
        self.assertEqual(product.price, Decimal('1250'))
        self.assertEqual(product.color_options, ['bleu', 'Noir', 'Gris'])
        self.assertEqual(product.size_options, ['S', 'M', 'XL'])
        self.assertEqual(product.quantity, 10)
        self.assertEqual(ProductImage.objects.filter(product=product).count(), 4)
        self.assertTrue(
            StockMovement.objects.filter(
                product=product,
                movement_type='restock',
                quantity_change=10,
            ).exists()
        )
        self.assertEqual(response.data['shop']['id'], self.shop.pk)

    def test_seller_creates_product_when_images_exceed_memory_upload_limit(self):
        image_bytes = large_png_with_text_chunk()

        with TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                response = self.client.post(
                    '/api/products/',
                    {
                        'title': 'Produit avec images volumineuses',
                        'description': 'Test des fichiers temporaires',
                        'purchase_price': '',
                        'price': '1250',
                        'promo_price': '',
                        'color_options': '["bleu","Noir","Gris"]',
                        'size_options': '["S","M","XL"]',
                        'quantity': '10',
                        'shop_id': str(self.shop.pk),
                        'category_id': str(self.category.pk),
                        'images': [
                            SimpleUploadedFile(
                                f'large-{index}.png',
                                image_bytes,
                                content_type='image/png',
                            )
                            for index in range(4)
                        ],
                    },
                    format='multipart',
                    HTTP_HOST='testserver',
                )

        self.assertEqual(response.status_code, 201, response.data)
        product = Product.objects.get(pk=response.data['id'])
        self.assertEqual(ProductImage.objects.filter(product=product).count(), 4)

    def test_seller_updates_product_with_images_exceeding_memory_upload_limit(self):
        image_bytes = large_png_with_text_chunk()
        product = Product.objects.create(
            shop=self.shop,
            category=self.category,
            title='Produit à modifier',
            price=Decimal('1250'),
            quantity=10,
        )

        with TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                response = self.client.patch(
                    f'/api/products/{product.pk}/',
                    {
                        'images': [
                            SimpleUploadedFile(
                                f'large-update-{index}.png',
                                image_bytes,
                                content_type='image/png',
                            )
                            for index in range(4)
                        ],
                    },
                    format='multipart',
                    HTTP_HOST='testserver',
                )

        self.assertEqual(response.status_code, 200, response.data)
        product.refresh_from_db()
        self.assertEqual(ProductImage.objects.filter(product=product).count(), 4)
        self.assertEqual(
            product.image.name,
            product.images.order_by('order', 'id').first().image.name,
        )
