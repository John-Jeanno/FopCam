import json
from types import SimpleNamespace
from unittest.mock import call, patch

from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient

from core.models import (
    Order,
    OrderItem,
    Product,
    ProductAnalyticsEvent,
    Shop,
    ShopAnalyticsEvent,
    ShopLike,
    ShopRating,
    ShopShare,
    ShopVote,
    Favorite,
)


class ShopInteractionTests(TestCase):
    def setUp(self):
        self.owner = User.objects.create_user(username='shop-owner')
        self.customer = User.objects.create_user(username='shop-customer')
        self.shop = Shop.objects.create(
            owner=self.owner,
            name='Boutique du quartier',
            active=True,
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.customer)

    def test_like_and_vote_toggle_and_are_serialized_for_user(self):
        like_response = self.client.post(f'/api/shops/{self.shop.id}/like/')
        vote_response = self.client.post(f'/api/shops/{self.shop.id}/vote/')

        self.assertEqual(like_response.status_code, 200)
        self.assertEqual(vote_response.status_code, 200)
        self.assertTrue(like_response.data['is_liked'])
        self.assertTrue(vote_response.data['is_voted'])
        self.assertEqual(like_response.data['like_count'], 1)
        self.assertEqual(vote_response.data['vote_count'], 1)

        shop_response = self.client.get(f'/api/shops/{self.shop.id}/')
        self.assertEqual(shop_response.status_code, 200)
        self.assertTrue(shop_response.data['is_liked'])
        self.assertTrue(shop_response.data['is_voted'])

        self.client.post(f'/api/shops/{self.shop.id}/like/')
        self.client.post(f'/api/shops/{self.shop.id}/vote/')
        self.assertEqual(ShopLike.objects.filter(shop=self.shop).count(), 0)
        self.assertEqual(ShopVote.objects.filter(shop=self.shop).count(), 0)

    def test_share_is_recorded_for_authenticated_user(self):
        response = self.client.post(f'/api/shops/{self.shop.id}/share/')

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['share_count'], 1)
        self.assertEqual(ShopShare.objects.filter(shop=self.shop).count(), 1)

    def test_shop_interactions_require_authentication(self):
        self.client.force_authenticate(user=None)

        response = self.client.post(f'/api/shops/{self.shop.id}/like/')

        self.assertEqual(response.status_code, 401)
        self.assertEqual(ShopLike.objects.filter(shop=self.shop).count(), 0)

    def test_rating_is_saved_and_updated_without_duplicate_reviews(self):
        first_response = self.client.post(
            f'/api/shops/{self.shop.id}/rate/',
            {'rating': 4},
            format='json',
        )
        update_response = self.client.post(
            f'/api/shops/{self.shop.id}/rate/',
            {'rating': 5},
            format='json',
        )

        self.assertEqual(first_response.status_code, 200)
        self.assertEqual(update_response.status_code, 200)
        self.assertEqual(update_response.data['average_rating'], 5.0)
        self.assertEqual(update_response.data['rating_count'], 1)
        self.assertEqual(update_response.data['user_rating'], 5)
        self.assertEqual(ShopRating.objects.filter(shop=self.shop).count(), 1)

        shop_response = self.client.get(f'/api/shops/{self.shop.id}/')
        self.assertEqual(shop_response.data['average_rating'], 5.0)
        self.assertEqual(shop_response.data['rating_count'], 1)

    def test_rating_rejects_values_outside_one_to_five(self):
        response = self.client.post(
            f'/api/shops/{self.shop.id}/rate/',
            {'rating': 6},
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(ShopRating.objects.filter(shop=self.shop).count(), 0)

    def test_shop_owner_cannot_rate_own_shop(self):
        self.client.force_authenticate(user=self.owner)

        response = self.client.post(
            f'/api/shops/{self.shop.id}/rate/',
            {'rating': 5},
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertEqual(ShopRating.objects.filter(shop=self.shop).count(), 0)

    def test_shop_views_and_search_appearances_are_recorded(self):
        detail_response = self.client.get(f'/api/shops/{self.shop.id}/')
        search_response = self.client.get(
            '/api/shops/',
            {'search': 'quartier'},
        )

        self.assertEqual(detail_response.status_code, 200)
        self.assertEqual(search_response.status_code, 200)
        self.assertEqual(
            ShopAnalyticsEvent.objects.filter(
                shop=self.shop,
                event_type='shop_view',
            ).count(),
            1,
        )
        self.assertEqual(
            ShopAnalyticsEvent.objects.filter(
                shop=self.shop,
                event_type='search_appearance',
            ).count(),
            1,
        )

    def test_shop_owner_views_do_not_count_as_customer_visits(self):
        self.client.force_authenticate(user=self.owner)

        response = self.client.get(f'/api/shops/{self.shop.id}/')

        self.assertEqual(response.status_code, 200)
        self.assertFalse(
            ShopAnalyticsEvent.objects.filter(
                shop=self.shop,
                event_type='shop_view',
            ).exists()
        )

    def test_shop_analytics_returns_real_sales_and_interactions_to_owner(self):
        ShopAnalyticsEvent.objects.create(shop=self.shop, event_type='shop_view')
        ShopAnalyticsEvent.objects.create(
            shop=self.shop,
            event_type='search_appearance',
        )
        ShopLike.objects.create(user=self.customer, shop=self.shop)
        ShopShare.objects.create(user=self.customer, shop=self.shop)
        ShopRating.objects.create(
            user=self.customer,
            shop=self.shop,
            rating=4,
        )
        product = Product.objects.create(
            shop=self.shop,
            title='Produit réel',
            price='1250.00',
            quantity=5,
        )
        order = Order.objects.create(
            buyer=self.customer,
            status='paid',
            total='2500.00',
        )
        OrderItem.objects.create(
            order=order,
            product=product,
            quantity=2,
            returned_quantity=1,
            price='1250.00',
        )
        ProductAnalyticsEvent.objects.create(
            product=product,
            event_type='product_view',
        )
        ProductAnalyticsEvent.objects.create(
            product=product,
            event_type='search_appearance',
        )
        Favorite.objects.create(user=self.customer, product=product)

        self.client.force_authenticate(user=self.owner)
        response = self.client.get(f'/api/shops/{self.shop.id}/analytics/')

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['shop_views_90d'], 1)
        self.assertEqual(response.data['shop_views_7d'], 1)
        self.assertEqual(response.data['search_appearances_7d'], 1)
        self.assertEqual(response.data['orders_7d'], 1)
        self.assertEqual(response.data['sales_revenue_7d'], '1250')
        self.assertEqual(response.data['sales_revenue_90d'], '1250')
        self.assertEqual(response.data['likes_total'], 1)
        self.assertEqual(response.data['shares_total'], 1)
        self.assertEqual(response.data['ratings_total'], 1)
        self.assertEqual(response.data['average_rating'], 4.0)
        self.assertEqual(len(response.data['daily_activity']), 7)
        self.assertEqual(len(response.data['product_metrics']), 1)
        product_metrics = response.data['product_metrics'][0]
        self.assertEqual(product_metrics['product_id'], product.id)
        self.assertEqual(product_metrics['views_total'], 1)
        self.assertEqual(product_metrics['search_appearances_7d'], 1)
        self.assertEqual(product_metrics['units_sold_90d'], 1)
        self.assertEqual(product_metrics['revenue_90d'], '1250')
        self.assertEqual(product_metrics['orders_90d'], 1)
        self.assertEqual(product_metrics['favorites_total'], 1)

    def test_shop_analytics_is_not_available_to_another_customer(self):
        response = self.client.get(f'/api/shops/{self.shop.id}/analytics/')

        self.assertEqual(response.status_code, 403)

    def test_owner_can_save_shop_appearance_and_multiple_phone_numbers(self):
        self.client.force_authenticate(user=self.owner)

        response = self.client.patch(
            f'/api/shops/{self.shop.id}/',
            {
                'phone_numbers': json.dumps([
                    '+221 77 111 22 33',
                    '+221 76 444 55 66',
                ]),
                'background_color': '#102030',
                'text_color': '#F0F0F0',
                'accent_color': '#AABBCC',
                'font_size': 20,
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(
            response.data['phone_numbers'],
            ['+221 77 111 22 33', '+221 76 444 55 66'],
        )
        self.assertEqual(response.data['phone'], '+221 77 111 22 33')
        self.assertEqual(response.data['background_color'], '#102030')
        self.assertEqual(response.data['text_color'], '#F0F0F0')
        self.assertEqual(response.data['accent_color'], '#AABBCC')
        self.assertEqual(response.data['font_size'], 20)

    def test_only_active_boutique_profile_can_create_a_shop(self):
        with patch('core.views.UserProfile.objects.filter') as profile_filter:
            profile_query = profile_filter.return_value.order_by.return_value
            profile_query.first.side_effect = [
                None,
                SimpleNamespace(role='particular'),
                SimpleNamespace(role='boutique'),
            ]
            no_profile_response = self.client.post(
                '/api/shops/',
                {'name': 'Boutique sans profil actif'},
                format='json',
            )
            other_role_response = self.client.post(
                '/api/shops/',
                {'name': 'Boutique avec autre rôle actif'},
                format='json',
            )
            allowed_response = self.client.post(
                '/api/shops/',
                {'name': 'Boutique autorisée'},
                format='json',
            )

        self.assertEqual(no_profile_response.status_code, 403)
        self.assertEqual(other_role_response.status_code, 403)
        self.assertFalse(
            Shop.objects.filter(
                name__in=[
                    'Boutique sans profil actif',
                    'Boutique avec autre rôle actif',
                ]
            ).exists()
        )
        self.assertEqual(allowed_response.status_code, 201, allowed_response.data)
        self.assertEqual(allowed_response.data['owner']['id'], self.customer.id)
        self.assertEqual(
            profile_filter.call_args_list,
            [
                call(user=self.customer, is_active=True),
                call(user=self.customer, is_active=True),
                call(user=self.customer, is_active=True),
            ],
        )

    def test_shop_appearance_rejects_invalid_values_and_non_owner_changes(self):
        self.client.force_authenticate(user=self.owner)
        invalid_response = self.client.patch(
            f'/api/shops/{self.shop.id}/',
            {'background_color': 'red', 'font_size': 40},
            format='json',
        )

        self.client.force_authenticate(user=self.customer)
        forbidden_response = self.client.patch(
            f'/api/shops/{self.shop.id}/',
            {'background_color': '#000000'},
            format='json',
        )

        self.assertEqual(invalid_response.status_code, 400)
        self.assertEqual(forbidden_response.status_code, 403)
        self.shop.refresh_from_db()
        self.assertEqual(self.shop.background_color, '#0F172A')
