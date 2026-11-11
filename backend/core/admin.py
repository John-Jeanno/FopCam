from django.contrib import admin
from django.contrib.auth.models import User, Group
from django.contrib.auth import logout as auth_logout
from django.http import HttpResponseRedirect
from django.urls import reverse
from functools import wraps
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit
from .models import UserProfile, Shop, Product, ProductImage, Category, Order, OrderItem, Transaction, Delivery, Review, ProducerReview, Payment, Message, Notification, Invoice
import django

# Personnaliser l'interface admin
admin.site.site_header = "FopCam Admin"
admin.site.site_title = "FopCam - Marketplace Agricole"
admin.site.index_title = "Tableau de bord"

# Base admin commune pour la sélection multiple et pagination
class FopCamModelAdmin(admin.ModelAdmin):
    change_list_template = 'admin/change_list_custom.html'
    actions_on_top = True
    actions_on_bottom = True
    list_per_page = 25

# Désenregistrer le User par défaut pour le personnaliser
admin.site.unregister(User)

@admin.register(User)
class UserAdmin(FopCamModelAdmin):
	list_display = ('username', 'email', 'first_name', 'last_name', 'is_staff', 'is_active', 'date_joined')
	list_filter = ('is_staff', 'is_active', 'date_joined')
	search_fields = ('username', 'email', 'first_name', 'last_name')
	ordering = ('-date_joined',)

# Personnaliser Group aussi
class GroupAdmin(FopCamModelAdmin):
	pass

# Configurer les templates personnalisés
# admin.site.index_template = 'admin/index.html'  # Maintenant géré par FopCamAdminSite
# admin.site.login_template = 'admin/login.html'  # Maintenant géré par FopCamAdminSite


@admin.register(UserProfile)
class UserProfileAdmin(FopCamModelAdmin):
	list_display = ('user', 'role', 'phone', 'city', 'verified', 'created_at')
	list_filter = ('role', 'verified', 'created_at')
	search_fields = ('user__username', 'user__email', 'phone', 'city', 'country')
	readonly_fields = ('created_at', 'updated_at')
	ordering = ('-created_at',)


@admin.register(Shop)
class ShopAdmin(FopCamModelAdmin):
	list_display = ('name', 'owner', 'location', 'active', 'created_at')
	list_filter = ('active', 'created_at')
	search_fields = ('name', 'owner__username', 'location')
	readonly_fields = ('created_at', 'updated_at')
	ordering = ('-created_at',)


@admin.register(Product)
class ProductAdmin(FopCamModelAdmin):
	list_display = ('title', 'shop', 'category', 'price', 'quantity', 'is_active', 'is_deleted', 'created_at')
	list_filter = ('is_active', 'is_deleted', 'category', 'shop', 'created_at')
	search_fields = ('title', 'description', 'shop__name')
	readonly_fields = ('created_at', 'updated_at', 'deleted_at', 'deleted_by')
	ordering = ('-created_at',)

	def get_queryset(self, request):
		return Product.all_objects.all()

	@admin.action(description='Restaurer les produits sélectionnés')
	def restore_products(self, request, queryset):
		queryset.restore()

	actions = ('restore_products', 'delete_selected')

	def delete_model(self, request, obj):
		obj.manual_delete(deleted_by=request.user)

	def delete_queryset(self, request, queryset):
		queryset.manual_delete(deleted_by=request.user)


@admin.register(ProductImage)
class ProductImageAdmin(FopCamModelAdmin):
	list_display = ('product', 'order', 'image')
	list_filter = ('product',)
	search_fields = ('product__title',)
	ordering = ('product', 'order')


@admin.register(Category)
class CategoryAdmin(FopCamModelAdmin):
	list_display = ('name', 'slug')
	search_fields = ('name', 'slug')
	prepopulated_fields = {'slug': ('name',)}
	ordering = ('name',)


@admin.register(Order)
class OrderAdmin(FopCamModelAdmin):
	list_display = ('id', 'buyer', 'status', 'total', 'created_at')
	list_filter = ('status', 'created_at')
	search_fields = ('buyer__username', 'id')
	readonly_fields = ('created_at', 'updated_at')
	ordering = ('-created_at',)


@admin.register(OrderItem)
class OrderItemAdmin(FopCamModelAdmin):
	list_display = ('order', 'product', 'quantity', 'price')
	list_filter = ('order', 'product')
	search_fields = ('order__id', 'product__title')
	ordering = ('-id',)


@admin.register(Transaction)
class TransactionAdmin(FopCamModelAdmin):
	list_display = ('order', 'amount', 'provider', 'success', 'created_at')
	list_filter = ('success', 'provider', 'created_at')
	search_fields = ('order__id', 'provider')
	readonly_fields = ('created_at', 'updated_at')
	ordering = ('-created_at',)


@admin.register(Delivery)
class DeliveryAdmin(FopCamModelAdmin):
	list_display = ('order', 'carrier', 'tracking_number', 'delivered', 'created_at')
	list_filter = ('delivered', 'created_at')
	search_fields = ('order__id', 'carrier', 'tracking_number')
	readonly_fields = ('created_at', 'updated_at')
	ordering = ('-created_at',)


@admin.register(Review)
class ReviewAdmin(FopCamModelAdmin):
	list_display = ('product', 'user', 'rating', 'created_at')
	list_filter = ('rating', 'created_at')
	search_fields = ('product__title', 'user__username', 'comment')
	readonly_fields = ('created_at', 'updated_at')
	ordering = ('-created_at',)


@admin.register(ProducerReview)
class ProducerReviewAdmin(FopCamModelAdmin):
	list_display = ('producer', 'user', 'rating', 'created_at')
	list_filter = ('rating', 'created_at')
	search_fields = ('producer__username', 'user__username', 'comment')
	readonly_fields = ('created_at', 'updated_at')
	ordering = ('-created_at',)


@admin.register(Payment)
class PaymentAdmin(FopCamModelAdmin):
	list_display = ('order', 'provider', 'amount', 'status', 'created_at')
	list_filter = ('status', 'provider', 'created_at')
	search_fields = ('order__id', 'provider', 'external_id')
	readonly_fields = ('created_at', 'updated_at')
	ordering = ('-created_at',)


@admin.register(Message)
class MessageAdmin(FopCamModelAdmin):
	list_display = ('room', 'user', 'content', 'is_read', 'created_at')
	list_filter = ('room', 'is_read', 'created_at')
	search_fields = ('room', 'user__username', 'content')
	readonly_fields = ('created_at', 'updated_at')
	ordering = ('-created_at',)


@admin.register(Notification)
class NotificationAdmin(FopCamModelAdmin):
	list_display = ('user', 'title', 'type', 'is_read', 'created_at')
	list_filter = ('type', 'is_read', 'created_at')
	search_fields = ('title', 'message', 'user__username')
	readonly_fields = ('created_at', 'updated_at')
	ordering = ('-created_at',)


@admin.register(Invoice)
class InvoiceAdmin(FopCamModelAdmin):
	list_display = ('order', 'issued', 'pdf', 'created_at')
	list_filter = ('issued', 'created_at')
	search_fields = ('order__id',)
	readonly_fields = ('created_at', 'updated_at')
	ordering = ('-created_at',)


# Customize AdminSite to show stats on index
class FopCamAdminSite(admin.AdminSite):
    site_header = "FopCam Admin"
    site_title = "FopCam - Marketplace Agricole"
    index_title = "Tableau de bord"
    index_template = 'admin/index.html'
    login_template = 'admin/login.html'

    def admin_view(self, view, cacheable=False):
        admin_view = super().admin_view(view, cacheable=cacheable)

        @wraps(admin_view)
        def prefixed_admin_view(request, *args, **kwargs):
            response = admin_view(request, *args, **kwargs)
            login_url = reverse("admin:login", current_app=self.name)
            location = response.get("Location", "")
            if response.status_code == 302 and location.startswith(login_url):
                script_prefix = login_url.rsplit("/admin/login/", 1)[0]
                if script_prefix:
                    parsed_location = urlsplit(location)
                    query = parse_qsl(
                        parsed_location.query,
                        keep_blank_values=True,
                    )
                    query = [
                        (
                            key,
                            f"{script_prefix}{value}"
                            if key == "next"
                            and value.startswith("/")
                            and not value.startswith(f"{script_prefix}/")
                            else value,
                        )
                        for key, value in query
                    ]
                    response["Location"] = urlunsplit(
                        parsed_location._replace(query=urlencode(query)),
                    )
            return response

        return prefixed_admin_view

    def index(self, request, extra_context=None):
        extra_context = extra_context or {}
        # Statistiques utilisateurs
        extra_context['total_users'] = User.objects.count()
        extra_context['total_groups'] = Group.objects.count()
        extra_context['total_profiles'] = UserProfile.objects.count()

        # Statistiques catalogue
        extra_context['total_products'] = Product.objects.count()
        extra_context['total_categories'] = Category.objects.count()
        extra_context['total_shops'] = Shop.objects.count()
        extra_context['total_reviews'] = Review.objects.count()

        # Statistiques commerce
        extra_context['total_orders'] = Order.objects.count()
        extra_context['total_order_items'] = OrderItem.objects.count()

        # Statistiques finances
        extra_context['total_transactions'] = Transaction.objects.count()
        extra_context['total_payments'] = Payment.objects.count()
        extra_context['total_invoices'] = Invoice.objects.count()

        # Statistiques logistique
        extra_context['total_deliveries'] = Delivery.objects.count()

        # Statistiques communication
        extra_context['total_messages'] = Message.objects.count()
        extra_context['total_notifications'] = Notification.objects.count()

        # Informations système
        extra_context['django_version'] = django.get_version()
        return super().index(request, extra_context)

    def logout(self, request):
        """
        Gère la déconnexion pour GET et POST.
        Affiche une page de confirmation après la déconnexion.
        """
        auth_logout(request)
        from django.shortcuts import render
        return render(request, 'admin/logout.html', {
            'site_header': self.site_header,
        })


# Optionnel: remplacer le site admin par défaut
admin_site = FopCamAdminSite(name='fopcam_admin')

# Enregistrer tous les modèles sur le nouveau site admin
admin_site.register(User, UserAdmin)
admin_site.register(Group, GroupAdmin)
admin_site.register(UserProfile, UserProfileAdmin)
admin_site.register(Shop, ShopAdmin)
admin_site.register(Product, ProductAdmin)
admin_site.register(Category, CategoryAdmin)
admin_site.register(Order, OrderAdmin)
admin_site.register(OrderItem, OrderItemAdmin)
admin_site.register(Transaction, TransactionAdmin)
admin_site.register(Delivery, DeliveryAdmin)
admin_site.register(Review, ReviewAdmin)
admin_site.register(ProducerReview, ProducerReviewAdmin)
admin_site.register(Payment, PaymentAdmin)
admin_site.register(Message, MessageAdmin)
admin_site.register(Notification, NotificationAdmin)
admin_site.register(Invoice, InvoiceAdmin)

admin.site = admin_site
