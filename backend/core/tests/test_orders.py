from decimal import Decimal
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient

from core.models import (
    Notification,
    Order,
    OrderItem,
    Payment,
    Product,
    Shop,
    StockMovement,
)


class OrderCreationTests(TestCase):
    def setUp(self):
        self.buyer = User.objects.create_user(username='order-buyer')
        self.owner = User.objects.create_user(username='order-seller')
        self.shop = Shop.objects.create(
            owner=self.owner,
            name='Boutique test',
            active=True,
        )
        self.product = Product.objects.create(
            shop=self.shop,
            title='Produit test',
            purchase_price=Decimal('700.00'),
            price=Decimal('1250.00'),
            quantity=4,
            is_active=True,
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.buyer)

    def test_order_uses_server_price_and_saves_delivery_address(self):
        response = self.client.post(
            '/api/orders/',
            {
                'address': 'Dakar, Sénégal',
                'payment_method': 'cash_on_delivery',
                'items': [
                    {
                        'product': self.product.id,
                        'quantity': 2,
                        'price': '1.00',
                    }
                ],
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201, response.data)
        order = Order.objects.get(id=response.data['id'])
        item = OrderItem.objects.get(order=order)
        self.product.refresh_from_db()
        self.assertEqual(order.delivery_address, 'Dakar, Sénégal')
        self.assertEqual(order.total, Decimal('2500.00'))
        self.assertEqual(item.price, Decimal('1250.00'))
        self.assertEqual(item.purchase_price, Decimal('700.00'))
        self.assertEqual(self.product.quantity, 2)
        self.assertEqual(
            StockMovement.objects.get(order_item=item).quantity_change,
            -2,
        )
        self.assertTrue(
            Notification.objects.filter(
                user=self.owner,
                type='order',
                data__order_id=order.id,
            ).exists()
        )

    def test_order_saves_selected_product_color_and_size(self):
        self.product.color_options = ['Rouge', 'Gris']
        self.product.size_options = ['L', 'XL']
        self.product.save(update_fields=['color_options', 'size_options'])

        response = self.client.post(
            '/api/orders/',
            {
                'address': 'Dakar, Sénégal',
                'payment_method': 'cash_on_delivery',
                'items': [{
                    'product': self.product.id,
                    'quantity': 1,
                    'selected_color': 'Gris',
                    'selected_size': 'XL',
                }],
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201, response.data)
        item = OrderItem.objects.get(order_id=response.data['id'])
        self.assertEqual(item.selected_color, 'Gris')
        self.assertEqual(item.selected_size, 'XL')
        self.assertEqual(response.data['items'][0]['selected_color'], 'Gris')
        self.assertEqual(response.data['items'][0]['selected_size'], 'XL')

    def test_order_rejects_unavailable_product_variant(self):
        self.product.color_options = ['Rouge', 'Gris']
        self.product.size_options = ['L', 'XL']
        self.product.save(update_fields=['color_options', 'size_options'])

        response = self.client.post(
            '/api/orders/',
            {
                'address': 'Dakar, Sénégal',
                'payment_method': 'cash_on_delivery',
                'items': [{
                    'product': self.product.id,
                    'quantity': 1,
                    'selected_color': 'Bleu',
                    'selected_size': 'XL',
                }],
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn('items', response.data)

    def test_order_uses_promotion_price_instead_of_client_price(self):
        self.product.promo_price = Decimal('900.00')
        self.product.save(update_fields=['promo_price'])

        response = self.client.post(
            '/api/orders/',
            {
                'address': 'Dakar, Sénégal',
                'payment_method': 'cash_on_delivery',
                'items': [
                    {
                        'product': self.product.id,
                        'quantity': 2,
                        'price': '1.00',
                    }
                ],
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201, response.data)
        order = Order.objects.get(id=response.data['id'])
        item = OrderItem.objects.get(order=order)
        self.assertEqual(order.total, Decimal('1800.00'))
        self.assertEqual(item.price, Decimal('900.00'))

    @patch(
        'core.payments.WavePayment.create_payment',
        return_value={'payment_id': 'wave-test', 'payment_url': 'https://example.test/pay'},
    )
    def test_mobile_payment_uses_promotion_price_instead_of_client_price(self, _):
        self.product.promo_price = Decimal('900.00')
        self.product.save(update_fields=['promo_price'])

        response = self.client.post(
            '/api/payments/create_order_and_payment/',
            {
                'provider': 'wave',
                'items': [
                    {'product': self.product.id, 'quantity': 1, 'price': '1.00'}
                ],
            },
            format='json',
        )

        self.assertEqual(response.status_code, 200, response.data)
        order = Order.objects.get(id=response.data['order_id'])
        item = OrderItem.objects.get(order=order)
        payment = Payment.objects.get(id=response.data['payment_id'])
        self.assertEqual(order.total, Decimal('900.00'))
        self.assertEqual(item.price, Decimal('900.00'))
        self.assertEqual(payment.amount, Decimal('900.00'))

    def test_order_rejects_empty_items_or_missing_address(self):
        empty_items = self.client.post(
            '/api/orders/',
            {'address': 'Dakar', 'items': []},
            format='json',
        )
        missing_address = self.client.post(
            '/api/orders/',
            {
                'items': [{'product': self.product.id, 'quantity': 1}],
            },
            format='json',
        )

        self.assertEqual(empty_items.status_code, 400)
        self.assertEqual(missing_address.status_code, 400)
        self.assertEqual(Order.objects.count(), 0)

    def test_insufficient_stock_does_not_create_order_or_change_stock(self):
        response = self.client.post(
            '/api/orders/',
            {
                'address': 'Dakar',
                'items': [{'product': self.product.id, 'quantity': 5}],
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(Order.objects.count(), 0)
        self.product.refresh_from_db()
        self.assertEqual(self.product.quantity, 4)

    def test_seller_can_process_delivery_and_accept_a_partial_return(self):
        created = self.client.post(
            '/api/orders/',
            {
                'address': 'Dakar',
                'items': [{'product': self.product.id, 'quantity': 2}],
            },
            format='json',
        )
        order_id = created.data['id']
        item_id = OrderItem.objects.get(order_id=order_id).id

        self.client.force_authenticate(user=self.owner)
        sales = self.client.get('/api/orders/sales/')
        self.assertEqual(sales.status_code, 200)
        sale = sales.data['results'][0] if 'results' in sales.data else sales.data[0]
        self.assertEqual(sale['items'][0]['purchase_price'], '700.00')

        for next_status in ('preparing', 'in_delivery', 'delivered'):
            response = self.client.post(
                f'/api/orders/{order_id}/fulfillment/',
                {'item_id': item_id, 'status': next_status},
                format='json',
            )
            self.assertEqual(response.status_code, 200, response.data)

        returned = self.client.post(
            f'/api/orders/{order_id}/accept_return/',
            {'item_id': item_id, 'quantity': 1, 'note': 'Emballage intact'},
            format='json',
        )
        self.assertEqual(returned.status_code, 200, returned.data)
        item = OrderItem.objects.get(id=item_id)
        self.product.refresh_from_db()
        self.assertEqual(item.returned_quantity, 1)
        self.assertEqual(item.fulfillment_status, 'delivered')
        self.assertEqual(self.product.quantity, 3)
        self.assertEqual(
            StockMovement.objects.filter(
                order_item=item,
                movement_type='return',
            ).get().quantity_change,
            1,
        )
        self.assertTrue(
            Notification.objects.filter(
                user=self.buyer,
                title='Retour accepté',
            ).exists()
        )

    def test_seller_cancellation_restores_reserved_stock(self):
        created = self.client.post(
            '/api/orders/',
            {
                'address': 'Dakar',
                'items': [{'product': self.product.id, 'quantity': 2}],
            },
            format='json',
        )
        item_id = OrderItem.objects.get(order_id=created.data['id']).id
        self.client.force_authenticate(user=self.owner)

        response = self.client.post(
            f"/api/orders/{created.data['id']}/fulfillment/",
            {'item_id': item_id, 'status': 'cancelled'},
            format='json',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.product.refresh_from_db()
        self.assertEqual(self.product.quantity, 4)
        self.assertTrue(
            StockMovement.objects.filter(
                order_item_id=item_id,
                movement_type='cancellation',
                quantity_change=2,
            ).exists()
        )

    def test_seller_stock_actions_are_validated_and_tracked(self):
        self.client.force_authenticate(user=self.owner)
        insufficient = self.client.post(
            f'/api/products/{self.product.id}/stock/',
            {
                'movement_type': 'adjustment',
                'quantity': 5,
                'direction': 'decrease',
                'note': 'Casse',
            },
            format='json',
        )
        insufficient = self.client.post(
            f'/api/products/{self.product.id}/stock/',
            {
                'movement_type': 'adjustment',
                'quantity': 5,
                'direction': 'decrease',
                'note': 'Casse',
            },
            format='json',
        )
        self.assertEqual(insufficient.status_code, 400)

        restock = self.client.post(
            f'/api/products/{self.product.id}/stock/',
            {
                'movement_type': 'restock',
                'quantity': 6,
                'purchase_price': '800.00',
                'note': 'Approvisionnement fournisseur',
            },
            format='json',
        )

        self.assertEqual(restock.status_code, 201, restock.data)
        self.product.refresh_from_db()
        self.assertEqual(self.product.quantity, 10)
        self.assertEqual(self.product.purchase_price, Decimal('800.00'))
        self.assertTrue(
            StockMovement.objects.filter(
                product=self.product,
                movement_type='restock',
                quantity_change=6,
            ).exists()
        )

    def test_editing_product_quantity_records_stock_adjustment(self):
        self.client.force_authenticate(user=self.owner)

        response = self.client.patch(
            f'/api/products/{self.product.id}/',
            {'quantity': 7, 'category_name': 'Catégorie test'},
            format='json',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.product.refresh_from_db()
        self.assertEqual(self.product.quantity, 7)
        self.assertTrue(
            StockMovement.objects.filter(
                product=self.product,
                movement_type='adjustment',
                quantity_change=3,
                note='Ajustement lors de la modification du produit',
            ).exists()
        )

    def test_seller_can_set_and_clear_a_valid_promotion(self):
        self.client.force_authenticate(user=self.owner)

        response = self.client.patch(
            f'/api/products/{self.product.id}/',
            {'promo_price': '900.00', 'category_name': 'Catégorie test'},
            format='json',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['current_price'], Decimal('900.00'))
        self.assertTrue(response.data['is_on_promotion'])
        self.assertEqual(response.data['discount_percentage'], 28)
        self.client.force_authenticate(user=self.buyer)
        public_product = self.client.get(f'/api/products/{self.product.id}/')
        self.assertEqual(public_product.status_code, 200, public_product.data)
        self.assertEqual(public_product.data['current_price'], Decimal('900.00'))
        self.assertNotIn('purchase_price', public_product.data)
        self.client.force_authenticate(user=self.owner)

        invalid = self.client.patch(
            f'/api/products/{self.product.id}/',
            {'promo_price': '1250.00', 'category_name': 'Catégorie test'},
            format='json',
        )
        self.assertEqual(invalid.status_code, 400)
        self.assertIn('promo_price', invalid.data)

        cleared = self.client.patch(
            f'/api/products/{self.product.id}/',
            {'promo_price': None, 'category_name': 'Catégorie test'},
            format='json',
        )
        self.assertEqual(cleared.status_code, 200, cleared.data)
        self.assertEqual(cleared.data['current_price'], Decimal('1250.00'))
        self.assertFalse(cleared.data['is_on_promotion'])

    def test_seller_can_clear_promotion_with_multipart_form_data(self):
        self.client.force_authenticate(user=self.owner)
        self.product.promo_price = Decimal('900.00')
        self.product.save(update_fields=['promo_price'])

        response = self.client.patch(
            f'/api/products/{self.product.id}/',
            {'promo_price': '', 'category_name': 'Catégorie test'},
            format='multipart',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['current_price'], Decimal('1250.00'))
        self.assertFalse(response.data['is_on_promotion'])

    def test_seller_can_set_product_color_and_size_options_with_multipart(self):
        self.client.force_authenticate(user=self.owner)

        response = self.client.patch(
            f'/api/products/{self.product.id}/',
            {
                'color_options': '["Rouge","Gris"]',
                'size_options': '["L","XL","XXL"]',
                'category_name': 'Catégorie test',
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['color_options'], ['Rouge', 'Gris'])
        self.assertEqual(response.data['size_options'], ['L', 'XL', 'XXL'])

    def test_seller_cannot_see_other_shops_costs_on_a_shared_order(self):
        second_owner = User.objects.create_user(username='order-other-seller')
        second_shop = Shop.objects.create(
            owner=second_owner,
            name='Autre boutique',
            active=True,
        )
        other_product = Product.objects.create(
            shop=second_shop,
            title='Autre produit',
            purchase_price=Decimal('25.00'),
            price=Decimal('50.00'),
            quantity=2,
            is_active=True,
        )
        response = self.client.post(
            '/api/orders/',
            {
                'address': 'Dakar',
                'items': [
                    {'product': self.product.id, 'quantity': 1},
                    {'product': other_product.id, 'quantity': 1},
                ],
            },
            format='json',
        )
        self.client.force_authenticate(user=self.owner)

        sales = self.client.get('/api/orders/sales/')
        sale = sales.data['results'][0] if 'results' in sales.data else sales.data[0]

        self.assertEqual(response.status_code, 201)
        self.assertEqual(len(sale['items']), 1)
        self.assertEqual(sale['items'][0]['product'], self.product.id)

    def test_purchase_price_is_private_to_shop_owner(self):
        public_response = self.client.get(f'/api/products/{self.product.id}/')
        self.assertEqual(public_response.status_code, 200)
        self.assertNotIn('purchase_price', public_response.data)

        self.client.force_authenticate(user=self.owner)
        seller_response = self.client.get('/api/products/my/')
        seller_products = (
            seller_response.data.get('results', seller_response.data)
            if isinstance(seller_response.data, dict)
            else seller_response.data
        )
        self.assertEqual(seller_response.status_code, 200)
        self.assertEqual(seller_products[0]['purchase_price'], '700.00')

    def test_mobile_payment_requires_phone(self):
        response = self.client.post(
            '/api/orders/',
            {
                'address': 'Dakar',
                'payment_method': 'wave',
                'items': [{'product': self.product.id, 'quantity': 1}],
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(Order.objects.count(), 0)
