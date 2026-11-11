from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient

from core.models import Category, Product, ProductAnalyticsEvent, Shop


class ProductExplorerFilterTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        owner = User.objects.create_user(
            username='explorer-vendor',
            first_name='Mariam',
            last_name='Diop',
        )
        self.shop = Shop.objects.create(
            owner=owner,
            name='Marché du quartier',
            description='Produits locaux',
            active=True,
        )
        self.product_category = Category.objects.create(
            name='Fruits',
            slug='explorer-fruits',
            sector='agriculture',
            category_type='product',
        )
        self.service_category = Category.objects.create(
            name='Livraison',
            slug='explorer-livraison',
            sector='services',
            category_type='professional',
        )
        self.product = Product.objects.create(
            shop=self.shop,
            category=self.product_category,
            title='Mangues fraîches',
            description='Récolte du jour',
            price='2500',
            quantity=12,
            is_active=True,
        )
        self.service = Product.objects.create(
            shop=self.shop,
            category=self.service_category,
            title='Livraison locale',
            description='Livraison rapide',
            price='1000',
            quantity=8,
            is_active=True,
        )
        self.out_of_stock = Product.objects.create(
            shop=self.shop,
            category=self.product_category,
            title='Mangues épuisées',
            description='Produit temporairement indisponible',
            price='4000',
            quantity=0,
            is_active=True,
        )

    def _product_ids(self, response):
        return self._result_ids(response)

    def _result_ids(self, response):
        self.assertEqual(response.status_code, 200)
        data = response.data
        results = data.get('results', []) if isinstance(data, dict) else data
        return {item['id'] for item in results}

    def test_search_finds_products_and_shop_names(self):
        self.assertEqual(
            self._product_ids(self.client.get('/api/products/?search=mangues')),
            {self.product.id, self.out_of_stock.id},
        )
        self.assertEqual(
            self._product_ids(self.client.get('/api/products/?search=quartier')),
            {self.product.id, self.service.id, self.out_of_stock.id},
        )

    def test_search_records_product_appearances(self):
        response = self.client.get('/api/products/?search=mangues')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            set(
                ProductAnalyticsEvent.objects.filter(
                    event_type='search_appearance',
                ).values_list('product_id', flat=True)
            ),
            {self.product.id, self.out_of_stock.id},
        )

    def test_product_detail_records_public_views_but_not_owner_views(self):
        self.client.force_authenticate(user=None)
        response = self.client.get(f'/api/products/{self.product.id}/')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            ProductAnalyticsEvent.objects.filter(
                product=self.product,
                event_type='product_view',
            ).count(),
            1,
        )

        self.client.force_authenticate(user=self.shop.owner)
        owner_response = self.client.get(f'/api/products/{self.product.id}/')

        self.assertEqual(owner_response.status_code, 200)
        self.assertEqual(
            ProductAnalyticsEvent.objects.filter(
                product=self.product,
                event_type='product_view',
            ).count(),
            1,
        )

    def test_category_and_category_type_filters_work(self):
        self.assertEqual(
            self._product_ids(
                self.client.get(f'/api/products/?category={self.product_category.id}')
            ),
            {self.product.id, self.out_of_stock.id},
        )
        self.assertEqual(
            self._product_ids(
                self.client.get('/api/products/?category_type=professional')
            ),
            {self.service.id},
        )

    def test_shop_and_category_search_filters_work(self):
        shops_response = self.client.get('/api/shops/?search=quartier')
        self.assertEqual(self._result_ids(shops_response), {self.shop.id})

        owner_response = self.client.get('/api/shops/?search=mariam')
        self.assertEqual(self._result_ids(owner_response), {self.shop.id})

        categories_response = self.client.get('/api/categories/?search=fruits')
        self.assertEqual(
            self._result_ids(categories_response),
            {self.product_category.id},
        )

    def test_category_type_filter_returns_only_alphabetical_product_categories(self):
        another_product_category = Category.objects.create(
            name='abricots',
            slug='explorer-abricots',
            category_type='product',
        )

        response = self.client.get('/api/categories/?category_type=product')

        self.assertEqual(response.status_code, 200)
        results = (
            response.data.get('results', [])
            if isinstance(response.data, dict)
            else response.data
        )
        self.assertEqual(
            [item['id'] for item in results],
            [
                another_product_category.id,
                self.product_category.id,
                Category.objects.get(slug='sport').id,
            ],
        )
        self.assertNotIn(self.service_category.id, [item['id'] for item in results])

    def test_sport_category_is_available_for_products(self):
        response = self.client.get('/api/categories/?category_type=product')

        self.assertEqual(response.status_code, 200)
        results = (
            response.data.get('results', [])
            if isinstance(response.data, dict)
            else response.data
        )
        sport = next(item for item in results if item['slug'] == 'sport')

        self.assertEqual(sport['name'], 'Sport')
        self.assertEqual(sport['translated_name'], 'Sport')

    def test_invalid_category_type_is_rejected(self):
        response = self.client.get('/api/products/?category_type=services')

        self.assertEqual(response.status_code, 400)

    def test_price_and_stock_filters_can_be_combined(self):
        response = self.client.get(
            '/api/products/?price_min=2000&price_max=3000&in_stock=true'
        )

        self.assertEqual(self._product_ids(response), {self.product.id})

    def test_price_sorting_orders_matching_products(self):
        response = self.client.get('/api/products/?ordering=price_asc')

        self.assertEqual(response.status_code, 200)
        results = (
            response.data.get('results', [])
            if isinstance(response.data, dict)
            else response.data
        )
        self.assertEqual(
            [item['id'] for item in results],
            [self.service.id, self.product.id, self.out_of_stock.id],
        )

    def test_invalid_price_range_is_rejected(self):
        response = self.client.get('/api/products/?price_min=3000&price_max=1000')

        self.assertEqual(response.status_code, 400)
