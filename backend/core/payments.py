from decimal import Decimal

from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from .models import Payment, Order, Notification, OrderItem, Product
from django.shortcuts import get_object_or_404
from django.conf import settings
from django.db import transaction
# requests/json not required for mock implementations


class WavePayment:
    def __init__(self):
        self.api_key = getattr(settings, 'WAVE_API_KEY', 'test_key')
        self.base_url = 'https://api.wave.com/v1'  # Mock URL

    def create_payment(self, amount, order_id, callback_url):
        # Simulate Wave API call
        payload = {
            'amount': str(amount),
            'currency': 'XOF',
            'description': f'Order {order_id}',
            'callback_url': callback_url
        }
        # In real: response = requests.post(f'{self.base_url}/payments', json=payload, headers={'Authorization': f'Bearer {self.api_key}'})
        # Mock response
        return {'payment_id': f'wave_{order_id}', 'payment_url': f'https://wave.com/pay/{order_id}'}


class OrangeMoneyPayment:
    def __init__(self):
        self.client_id = getattr(settings, 'ORANGE_CLIENT_ID', 'test_client')
        self.client_secret = getattr(settings, 'ORANGE_CLIENT_SECRET', 'test_secret')
        self.base_url = 'https://api.orange.com'  # Mock URL

    def create_payment(self, amount, order_id, callback_url):
        # Simulate Orange Money API call
        payload = {
            'amount': amount,
            'currency': 'XOF',
            'order_id': order_id,
            'callback_url': callback_url
        }
        # In real: get token first, then post payment
        return {'payment_id': f'orange_{order_id}', 'payment_url': f'https://orange.com/pay/{order_id}'}


class PaymentViewSet(viewsets.ViewSet):
    permission_classes = [permissions.IsAuthenticated]

    @action(detail=False, methods=['post'])
    def create_payment(self, request):
        order_id = request.data.get('order')
        provider = request.data.get('provider', 'wave')  # wave or orange
        order = get_object_or_404(Order, id=order_id, buyer=request.user)

        if provider == 'wave':
            payment_handler = WavePayment()
        elif provider == 'orange':
            payment_handler = OrangeMoneyPayment()
        else:
            return Response({'error': 'Provider not supported'}, status=400)

        callback_url = f"{settings.BASE_URL}/api/payments/callback/{order_id}/"
        result = payment_handler.create_payment(order.total, order_id, callback_url)

        payment = Payment.objects.create(
            order=order,
            provider=provider,
            amount=order.total,
            status='pending',
            external_id=result['payment_id']
        )

        # Create notification for buyer
        Notification.objects.create(
            user=request.user,
            title='Paiement initié',
            message=f'Votre paiement pour la commande {order_id} a été initié.',
            type='payment',
            data={'order_id': order_id, 'payment_id': payment.id}
        )

        return Response({
            'payment_id': payment.id,
            'payment_url': result['payment_url'],
            'provider': provider
        })

    @action(detail=False, methods=['post'])
    def create_order_and_payment(self, request):
        """Accepts cart items + provider, creates Order + OrderItems, then initiates payment and returns payment_url."""
        provider = request.data.get('provider', 'wave')
        items = request.data.get('items', [])
        payment_phone = request.data.get('payment_phone')

        if not items or not isinstance(items, list):
            return Response({'error': 'items must be a non-empty list'}, status=400)

        # Map provider to payment method choices
        payment_method = 'wave' if provider == 'wave' else 'orange_money' if provider == 'orange' else provider

        with transaction.atomic():
            order = Order.objects.create(buyer=request.user, payment_method=payment_method, payment_phone=payment_phone)
            total = Decimal('0.00')
            for it in items:
                prod_id = it.get('product')
                quantity = int(it.get('quantity', 1))
                try:
                    product = Product.objects.select_for_update().get(id=prod_id)
                except Product.DoesNotExist:
                    transaction.set_rollback(True)
                    return Response({'error': f'Product {prod_id} not found'}, status=400)

                selected_color = str(it.get('selected_color') or '').strip()
                selected_size = str(it.get('selected_size') or '').strip()
                if quantity < 1:
                    transaction.set_rollback(True)
                    return Response({'error': 'La quantité doit être positive.'}, status=400)
                if (
                    (product.color_options and selected_color not in product.color_options)
                    or (not product.color_options and selected_color)
                    or (product.size_options and selected_size not in product.size_options)
                    or (not product.size_options and selected_size)
                ):
                    transaction.set_rollback(True)
                    return Response(
                        {'error': f'Choix de couleur ou taille invalide pour {product.title}.'},
                        status=400,
                    )

                OrderItem.objects.create(
                    order=order,
                    product=product,
                    quantity=quantity,
                    price=product.current_price,
                    selected_color=selected_color,
                    selected_size=selected_size,
                    purchase_price=product.purchase_price,
                )
                total += product.current_price * quantity

                # reduce stock if available
                if product.quantity >= quantity:
                    product.quantity -= quantity
                    product.save()

            order.total = total
            order.save()

            # Initiate payment
            if provider == 'wave':
                payment_handler = WavePayment()
            elif provider == 'orange':
                payment_handler = OrangeMoneyPayment()
            else:
                return Response({'error': 'Provider not supported'}, status=400)

            callback_url = f"{settings.BASE_URL}/api/payments/callback/{order.id}/"
            result = payment_handler.create_payment(order.total, order.id, callback_url)

            payment = Payment.objects.create(
                order=order,
                provider=provider,
                amount=order.total,
                status='pending',
                external_id=result.get('payment_id')
            )

            Notification.objects.create(
                user=request.user,
                title='Paiement initié',
                message=f'Votre paiement pour la commande {order.id} a été initié.',
                type='payment',
                data={'order_id': order.id, 'payment_id': payment.id}
            )

            return Response({'order_id': order.id, 'payment_id': payment.id, 'payment_url': result.get('payment_url')})

    @action(detail=False, methods=['post'], permission_classes=[permissions.AllowAny])
    def callback(self, request):
        # Webhook for payment confirmation
        secret = request.headers.get('X-WEBHOOK-SECRET') or request.data.get('webhook_secret')
        if secret != settings.PAYMENT_WEBHOOK_SECRET:
            return Response({'error': 'Invalid webhook secret'}, status=status.HTTP_403_FORBIDDEN)

        order_id = request.data.get('order_id')
        provider = request.data.get('provider')
        status_in = request.data.get('status')
        external_id = request.data.get('payment_id')

        if not order_id:
            return Response({'error': 'order_id is required'}, status=status.HTTP_400_BAD_REQUEST)

        payment = get_object_or_404(Payment, external_id=external_id, order_id=order_id)
        if status_in == 'success':
            payment.status = 'success'
            payment.save()
            payment.order.status = 'paid'
            payment.order.save()

            # Notify buyer and producer
            Notification.objects.create(
                user=payment.order.buyer,
                title='Paiement confirmé',
                message=f'Votre paiement pour la commande {order_id} a été confirmé.',
                type='payment',
                data={'order_id': order_id}
            )
            Notification.objects.create(
                user=payment.order.buyer,  # Assuming producer is order.buyer for now; adjust if needed
                title='Nouvelle commande payée',
                message=f'Une commande a été payée.',
                type='order',
                data={'order_id': order_id}
            )

        return Response({'ok': True})
