from rest_framework import serializers
from django.db import transaction
from rest_framework.exceptions import ValidationError

from .models import Notification, Order, OrderItem, Product, StockMovement


class OrderItemSerializer(serializers.ModelSerializer):
    product_title = serializers.CharField(source='product.title', read_only=True)
    product_image = serializers.ImageField(source='product.image', read_only=True)
    shop_name = serializers.CharField(source='product.shop.name', read_only=True)

    class Meta:
        model = OrderItem
        fields = ('id', 'product', 'product_title', 'product_image', 'shop_name', 'quantity', 'selected_color', 'selected_size', 'price')


class SellerOrderItemSerializer(serializers.ModelSerializer):
    product_title = serializers.CharField(source='product.title', read_only=True)
    shop_name = serializers.CharField(source='product.shop.name', read_only=True)
    line_profit = serializers.SerializerMethodField()

    class Meta:
        model = OrderItem
        fields = (
            'id',
            'product',
            'product_title',
            'shop_name',
            'quantity',
            'selected_color',
            'selected_size',
            'returned_quantity',
            'price',
            'purchase_price',
            'fulfillment_status',
            'line_profit',
        )

    def get_line_profit(self, obj):
        if obj.fulfillment_status != 'delivered' or obj.purchase_price is None:
            return None
        sold_quantity = obj.quantity - obj.returned_quantity
        return f'{(obj.price - obj.purchase_price) * sold_quantity:.2f}'


class OrderSerializer(serializers.ModelSerializer):
    items = OrderItemSerializer(many=True, read_only=True)
    buyer_username = serializers.CharField(source='buyer.username', read_only=True)
    address = serializers.CharField(source='delivery_address', read_only=True)
    created_at_formatted = serializers.SerializerMethodField()
    status_display = serializers.SerializerMethodField()
    payment_method_display = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = ('id', 'buyer', 'buyer_username', 'status', 'status_display', 'payment_method', 'payment_method_display', 'payment_phone', 'address', 'total', 'items', 'created_at', 'created_at_formatted', 'updated_at')

    def get_created_at_formatted(self, obj):
        return obj.created_at.strftime('%d/%m/%Y %H:%M')

    def get_status_display(self, obj):
        status_map = {
            'pending': 'En attente',
            'paid': 'Payé',
            'shipped': 'Expédié',
            'completed': 'Terminé',
            'cancelled': 'Annulé',
        }
        return status_map.get(obj.status, obj.status)

    def get_payment_method_display(self, obj):
        return obj.get_payment_method_display()


class SellerOrderSerializer(OrderSerializer):
    items = serializers.SerializerMethodField()
    total = serializers.SerializerMethodField()

    def _seller_items(self, obj):
        request = self.context.get('request')
        if request is None:
            return obj.items.none()
        if request.user.is_staff:
            return obj.items.all()
        return obj.items.filter(product__shop__owner=request.user)

    def get_items(self, obj):
        return SellerOrderItemSerializer(
            self._seller_items(obj),
            many=True,
            context=self.context,
        ).data

    def get_total(self, obj):
        return sum(
            (
                item.price * (item.quantity - item.returned_quantity)
                for item in self._seller_items(obj)
            ),
            start=0,
        )


class OrderItemCreateSerializer(serializers.ModelSerializer):
    product = serializers.PrimaryKeyRelatedField(
        queryset=Product.objects.filter(is_active=True),
    )
    quantity = serializers.IntegerField(min_value=1)
    price = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        read_only=True,
    )
    selected_color = serializers.CharField(required=False, allow_blank=True, max_length=80)
    selected_size = serializers.CharField(required=False, allow_blank=True, max_length=80)

    class Meta:
        model = OrderItem
        fields = ('product', 'quantity', 'selected_color', 'selected_size', 'price')

    def validate(self, attrs):
        product = attrs['product']
        for field, option_field in (
            ('selected_color', 'color_options'),
            ('selected_size', 'size_options'),
        ):
            value = attrs.get(field, '')
            options = getattr(product, option_field)
            if options and value not in options:
                raise serializers.ValidationError(
                    {field: 'Veuillez choisir une option disponible pour ce produit.'}
                )
            if not options and value:
                raise serializers.ValidationError(
                    {field: 'Cette option n’est pas proposée pour ce produit.'}
                )
        return attrs


class OrderCreateSerializer(serializers.ModelSerializer):
    items = OrderItemCreateSerializer(many=True)
    address = serializers.CharField(
        source='delivery_address',
        write_only=True,
        trim_whitespace=True,
        allow_blank=False,
    )
    buyer = serializers.PrimaryKeyRelatedField(read_only=True)
    status = serializers.CharField(read_only=True)
    total = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        read_only=True,
    )
    payment_phone = serializers.CharField(
        required=False,
        allow_null=True,
        allow_blank=True,
    )

    class Meta:
        model = Order
        fields = ('id', 'buyer', 'status', 'payment_method', 'payment_phone', 'address', 'total', 'items')

    def validate_items(self, items):
        if not items:
            raise serializers.ValidationError('La commande doit contenir au moins un produit.')

        variants = [
            (
                item['product'].id,
                item.get('selected_color', ''),
                item.get('selected_size', ''),
            )
            for item in items
        ]
        if len(variants) != len(set(variants)):
            raise serializers.ValidationError(
                'Une même variante ne peut apparaître qu’une fois dans la commande.'
            )
        return items

    def validate(self, attrs):
        if not attrs.get('delivery_address', '').strip():
            raise serializers.ValidationError(
                {'address': 'Une adresse de livraison est requise.'}
            )
        payment_method = attrs.get('payment_method', 'cash_on_delivery')
        if payment_method != 'cash_on_delivery' and not (
            attrs.get('payment_phone') or ''
        ).strip():
            raise serializers.ValidationError(
                {'payment_phone': 'Un numéro est requis pour le paiement mobile.'}
            )
        return attrs

    @transaction.atomic
    def create(self, validated_data):
        items_data = validated_data.pop('items')
        product_ids = sorted(item['product'].id for item in items_data)
        locked_products = {
            product.id: product
            for product in Product.objects.select_for_update().filter(
                id__in=product_ids,
                is_active=True,
            )
        }

        order_lines = []
        total = 0
        for item in items_data:
            product = locked_products.get(item['product'].id)
            quantity = item['quantity']
            if product is None:
                raise ValidationError(
                    {'items': 'Un produit de la commande n’est plus disponible.'}
                )
            if quantity > product.quantity:
                raise ValidationError(
                    {
                        'items': (
                            f'Stock insuffisant pour « {product.title} » '
                            f'(disponible : {product.quantity}).'
                        )
                    }
                )
            selected_color = item.get('selected_color', '')
            selected_size = item.get('selected_size', '')
            if (
                (product.color_options and selected_color not in product.color_options)
                or (not product.color_options and selected_color)
                or (product.size_options and selected_size not in product.size_options)
                or (not product.size_options and selected_size)
            ):
                raise ValidationError(
                    {
                        'items': (
                            f'Les options choisies ne sont plus disponibles pour '
                            f'« {product.title} ».'
                        )
                    }
                )
            order_lines.append((
                product,
                quantity,
                product.current_price,
                product.purchase_price,
                selected_color,
                selected_size,
            ))
            total += product.current_price * quantity

        order = Order.objects.create(total=total, **validated_data)
        notified_owners = set()
        for product, quantity, price, purchase_price, selected_color, selected_size in order_lines:
            order_item = OrderItem.objects.create(
                order=order,
                product=product,
                quantity=quantity,
                price=price,
                selected_color=selected_color,
                selected_size=selected_size,
                purchase_price=purchase_price,
            )
            StockMovement.objects.create(
                product=product,
                user=order.buyer,
                movement_type='sale',
                quantity_change=-quantity,
                unit_cost=purchase_price,
                note=f'Commande #{order.id}',
                order_item=order_item,
            )
            if product.shop.owner_id not in notified_owners:
                Notification.objects.create(
                    user=product.shop.owner,
                    title='Nouvelle commande reçue',
                    message=f'Une nouvelle commande contient {product.title}.',
                    type='order',
                    data={'order_id': order.id, 'audience': 'seller'},
                )
                notified_owners.add(product.shop.owner_id)
            previous_quantity = product.quantity
            product.quantity -= quantity
            product.save(update_fields=['quantity'])
            if previous_quantity > 5 >= product.quantity:
                Notification.objects.create(
                    user=product.shop.owner,
                    title='Stock faible',
                    message=(
                        f'Le stock de {product.title} est maintenant de '
                        f'{product.quantity}.'
                    ),
                    type='stock',
                    data={'product_id': product.id, 'audience': 'seller'},
                )
        return order
