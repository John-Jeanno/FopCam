from django.db import models
from django.contrib.auth.models import User
from django.core.validators import MaxValueValidator, MinValueValidator
from django.utils import timezone
from datetime import timedelta
from django.utils.translation import gettext_lazy as _

def game_challenge_expiry():
    return timezone.now() + timedelta(minutes=30)


class TimestampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class UserProfile(TimestampedModel):
    LANGUAGE_CHOICES = (
        ('fr', 'Français'),
        ('en', 'English'),
        ('zh-Hans', '简体中文'),
        ('de', 'Deutsch'),
        ('pt', 'Português'),
        ('es', 'Español'),
        ('ar', 'العربية'),
        ('ru', 'Русский'),
        ('hi', 'हिन्दी'),
        ('bn', 'বাংলা'),
        ('id', 'Bahasa Indonesia'),
        ('ur', 'اردو'),
        ('ja', '日本語'),
        ('sw', 'Kiswahili'),
        ('it', 'Italiano'),
        ('nl', 'Nederlands'),
        ('tr', 'Türkçe'),
        ('ko', '한국어'),
        ('fa', 'فارسی'),
        ('th', 'ไทย'),
        ('pl', 'Polski'),
        ('vi', 'Tiếng Việt'),
        ('uk', 'Українська'),
        ('ro', 'Română'),
        ('el', 'Ελληνικά'),
    )
    ROLE_CHOICES = (
        ('particular', _('Particulier')),
        ('producer', _('Producteur')),
        ('boutique', _('Boutique')),
        ('prestataire', _('Prestataire')),
        ('enterprise', _('Entreprise')),
        ('influencer', _('Influenceur')),
        ('community_lead', _('Responsable Communautaire')),
        ('driver', _('Livreur')),
        ('admin', _('Administrateur')),
    )
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='profiles', verbose_name=_('Utilisateur'))
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='particular', verbose_name=_('Rôle'))
    is_active = models.BooleanField(default=False, verbose_name=_('Profil actif'))
    phone = models.CharField(max_length=30, blank=True, null=True, verbose_name=_('Téléphone'))
    phone_visibility = models.CharField(
        max_length=10,
        choices=(('public', _('Public')), ('private', _('Privé'))),
        default='private',
        verbose_name=_('Visibilité du téléphone'),
    )
    profile_visibility = models.CharField(
        max_length=10,
        choices=(('public', _('Public')), ('private', _('Privé'))),
        default='public',
        verbose_name=_('Visibilité du profil'),
    )
    motorcycle_plate = models.CharField(max_length=50, blank=True, null=True, verbose_name=_('Matricule de la moto'))
    address = models.CharField(max_length=255, blank=True, null=True, verbose_name=_('Adresse'))
    city = models.CharField(max_length=100, blank=True, null=True, verbose_name=_('Ville'))
    country = models.CharField(max_length=100, blank=True, null=True, verbose_name=_('Pays'))
    country_code = models.CharField(max_length=2, blank=True, default='', verbose_name=_('Code pays'))
    preferred_language = models.CharField(
        max_length=10,
        choices=LANGUAGE_CHOICES,
        blank=True,
        default='',
        verbose_name=_('Langue préférée'),
    )
    notification_sounds = models.JSONField(
        default=dict,
        blank=True,
        verbose_name=_('Sonneries des notifications'),
    )
    latitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True, verbose_name=_('Latitude'))
    longitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True, verbose_name=_('Longitude'))
    verified = models.BooleanField(default=False, verbose_name=_('Vérifié'))
    last_seen_at = models.DateTimeField(blank=True, null=True, verbose_name=_('Dernière activité'))
    verification_document = models.FileField(upload_to='verifications/', blank=True, null=True, verbose_name=_('Document de vérification'))
    profile_image = models.ImageField(upload_to='profiles/', blank=True, null=True, verbose_name=_('Image de profil'))
    cover_image = models.ImageField(upload_to='covers/', blank=True, null=True, verbose_name=_('Image de couverture'))
    bio = models.TextField(blank=True, null=True, max_length=500, verbose_name=_('Biographie'))
    website = models.URLField(blank=True, null=True, verbose_name=_('Site web'))
    experience_and_journey = models.JSONField(default=list, blank=True, verbose_name=_('Expériences et parcours'))
    education_and_training = models.JSONField(default=list, blank=True, verbose_name=_('Profil et formations'))
    skills = models.JSONField(default=list, blank=True, verbose_name=_('Mes compétences'))
    services = models.JSONField(default=list, blank=True, verbose_name=_('Mes services'))
    # Champs spécifiques au profil
    company_name = models.CharField(max_length=255, blank=True, null=True, verbose_name=_('Nom de l\'entreprise'))
    company_registration = models.CharField(max_length=100, blank=True, null=True, verbose_name=_('Numéro d\'immatriculation'))
    tax_id = models.CharField(max_length=100, blank=True, null=True, verbose_name=_('Numéro de TVA/Impôt'))
    business_license = models.FileField(upload_to='business_licenses/', blank=True, null=True, verbose_name=_('Licence professionnelle'))
    followers_count = models.PositiveIntegerField(default=0, verbose_name=_('Nombre d\'abonnés'))

    class Meta:
        verbose_name = _('Profil utilisateur')
        verbose_name_plural = _('Profils utilisateurs')

    def __str__(self):
        return f"{self.user.username} ({self.role})"


PROFILE_ROLE_CHANGE_CHOICES = tuple(
    choice for choice in UserProfile.ROLE_CHOICES if choice[0] != 'admin'
)


class ProfileRoleChange(TimestampedModel):
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='profile_role_changes',
    )
    old_role = models.CharField(max_length=20, choices=UserProfile.ROLE_CHOICES)
    new_role = models.CharField(max_length=20, choices=UserProfile.ROLE_CHOICES)

    class Meta:
        ordering = ('-created_at',)
        indexes = [
            models.Index(
                fields=('user', 'created_at'),
                name='core_role_user_created_idx',
            ),
        ]


class Shop(TimestampedModel):
    owner = models.ForeignKey(User, on_delete=models.CASCADE, related_name='shops', verbose_name=_('Propriétaire'))
    name = models.CharField(max_length=255, verbose_name=_('Nom'))
    slug = models.SlugField(blank=True, verbose_name=_('Slug'))
    description = models.TextField(blank=True, verbose_name=_('Description'))
    location = models.CharField(max_length=255, blank=True, verbose_name=_('Emplacement'))
    latitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True, verbose_name=_('Latitude'))
    longitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True, verbose_name=_('Longitude'))
    phone = models.CharField(max_length=30, blank=True, null=True, verbose_name=_('Téléphone'))
    phone_numbers = models.JSONField(default=list, blank=True, verbose_name=_('Numéros de téléphone'))
    email = models.EmailField(blank=True, null=True, verbose_name=_('Email'))
    website = models.URLField(blank=True, null=True, verbose_name=_('Site web'))
    logo = models.ImageField(upload_to='shops/', blank=True, null=True, verbose_name=_('Logo'))
    banner = models.ImageField(upload_to='shops/', blank=True, null=True, verbose_name=_('Bannière'))
    background_color = models.CharField(max_length=7, default='#0F172A', verbose_name=_('Couleur de fond'))
    text_color = models.CharField(max_length=7, default='#F8FAFC', verbose_name=_('Couleur du texte'))
    accent_color = models.CharField(max_length=7, default='#7C3AED', verbose_name=_('Couleur d’accentuation'))
    font_size = models.PositiveSmallIntegerField(default=16, verbose_name=_('Taille de police'))
    active = models.BooleanField(default=True, verbose_name=_('Actif'))
    delivery_zones = models.JSONField(blank=True, null=True, verbose_name=_('Zones de livraison'))  # Liste des zones de livraison
    opening_hours = models.JSONField(blank=True, null=True, verbose_name=_('Horaires d\'ouverture'))  # Horaires d'ouverture

    class Meta:
        verbose_name = _('Boutique')
        verbose_name_plural = _('Boutiques')

    def save(self, *args, **kwargs):
        if not self.slug:
            from django.utils.text import slugify
            self.slug = slugify(self.name)
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name


class ShopAnalyticsEvent(TimestampedModel):
    EVENT_TYPES = (
        ('shop_view', 'Consultation de la boutique'),
        ('search_appearance', 'Apparition dans les recherches'),
    )

    shop = models.ForeignKey(
        Shop,
        on_delete=models.CASCADE,
        related_name='analytics_events',
    )
    event_type = models.CharField(max_length=32, choices=EVENT_TYPES)

    class Meta:
        indexes = [
            models.Index(fields=('shop', 'event_type', 'created_at')),
        ]


class ShopLike(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='shop_likes')
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='likes')

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=('user', 'shop'), name='unique_user_shop_like'),
        ]


class ShopVote(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='shop_votes')
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='votes')

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=('user', 'shop'), name='unique_user_shop_vote'),
        ]


class ShopShare(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='shop_shares')
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='shares')


class ShopRating(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='shop_ratings')
    shop = models.ForeignKey(Shop, on_delete=models.CASCADE, related_name='ratings')
    rating = models.PositiveSmallIntegerField(
        validators=[MinValueValidator(1), MaxValueValidator(5)],
        verbose_name=_('Note'),
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=('user', 'shop'), name='unique_user_shop_rating'),
        ]


class Category(models.Model):
    SECTOR_CHOICES = (
        ('agriculture', _('Agriculture')),
        ('technology', _('Technologie')),
        ('health', _('Santé')),
        ('education', _('Éducation')),
        ('government', _('Gouvernement')),
        ('services', _('Services')),
        ('retail', _('Commerce de détail')),
        ('manufacturing', _('Fabrication')),
        ('finance', _('Finance')),
        ('real_estate', _('Immobilier')),
        ('transport', _('Transport')),
        ('hospitality', _('Hôtellerie')),
        ('entertainment', _('Divertissement')),
        ('other', _('Autre')),
    )
    
    CATEGORY_TYPE_CHOICES = (
        ('product', _('Produit (Boutique)')),
        ('professional', _('Professionnel (Publications)')),
    )
    
    name = models.CharField(max_length=100, verbose_name=_('Nom'))
    slug = models.SlugField(unique=True, verbose_name=_('Slug'))
    sector = models.CharField(max_length=20, choices=SECTOR_CHOICES, default='other', verbose_name=_('Secteur'))
    category_type = models.CharField(max_length=20, choices=CATEGORY_TYPE_CHOICES, default='product', verbose_name=_('Type de catégorie'))
    parent = models.ForeignKey('self', on_delete=models.CASCADE, null=True, blank=True, related_name='subcategories', verbose_name=_('Parent'))

    class Meta:
        verbose_name = _('Catégorie')
        verbose_name_plural = _('Catégories')

    def __str__(self):
        return self.name


class ProductQuerySet(models.QuerySet):
    def delete(self):
        raise models.ProtectedError(
            'Les produits ne peuvent être supprimés que par une action manuelle explicite.',
            self,
        )

    def manual_delete(self, deleted_by=None):
        queryset = self.filter(is_deleted=False)
        now = timezone.now()
        updates = {
            'is_deleted': True,
            'deleted_at': now,
            'deleted_by': deleted_by,
            'updated_at': now,
        }
        count = queryset.update(**updates)
        return count, {self.model._meta.label: count}

    def restore(self):
        queryset = self.filter(is_deleted=True)
        count = queryset.update(
            is_deleted=False,
            deleted_at=None,
            deleted_by=None,
            updated_at=timezone.now(),
        )
        return count


class ProductManager(models.Manager.from_queryset(ProductQuerySet)):
    def get_queryset(self):
        return super().get_queryset().filter(is_deleted=False)


class Product(TimestampedModel):
    objects = ProductManager()
    all_objects = ProductQuerySet.as_manager()

    shop = models.ForeignKey(Shop, on_delete=models.PROTECT, related_name='products', verbose_name=_('Boutique'))
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True, verbose_name=_('Catégorie'))
    title = models.CharField(max_length=255, verbose_name=_('Titre'))
    description = models.TextField(blank=True, verbose_name=_('Description'))
    purchase_price = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True, default=None, validators=[MinValueValidator(0)], verbose_name=_('Prix d’achat unitaire'))
    price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name=_('Prix'))
    promo_price = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True, validators=[MinValueValidator(0)], verbose_name=_('Prix promotionnel'))
    color_options = models.JSONField(default=list, blank=True, verbose_name=_('Couleurs disponibles'))
    size_options = models.JSONField(default=list, blank=True, verbose_name=_('Tailles disponibles'))
    quantity = models.PositiveIntegerField(default=0, verbose_name=_('Quantité'))
    image = models.ImageField(upload_to='products/', blank=True, null=True, verbose_name=_('Image'))
    video = models.FileField(upload_to='products/videos/', blank=True, null=True, verbose_name=_('Vidéo'))
    is_active = models.BooleanField(default=True, verbose_name=_('Actif'))
    is_deleted = models.BooleanField(default=False, db_index=True, verbose_name=_('Supprimé manuellement'))
    deleted_at = models.DateTimeField(blank=True, null=True, verbose_name=_('Date de suppression'))
    deleted_by = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='manually_deleted_products',
        verbose_name=_('Supprimé par'),
    )

    class Meta:
        verbose_name = _('Produit')
        verbose_name_plural = _('Produits')

    def __str__(self):
        return self.title

    def delete(self, using=None, keep_parents=False):
        raise models.ProtectedError(
            'Les produits ne peuvent être supprimés que par une action manuelle explicite.',
            [self],
        )

    def manual_delete(self, deleted_by=None):
        return type(self).objects.filter(pk=self.pk).manual_delete(
            deleted_by=deleted_by,
        )

    @property
    def current_price(self):
        if self.promo_price is not None and 0 < self.promo_price < self.price:
            return self.promo_price
        return self.price

    @property
    def is_on_promotion(self):
        return self.current_price != self.price


class ProductAnalyticsEvent(TimestampedModel):
    EVENT_TYPES = (
        ('product_view', 'Consultation du produit'),
        ('search_appearance', 'Apparition dans les recherches'),
    )

    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='analytics_events',
    )
    event_type = models.CharField(max_length=32, choices=EVENT_TYPES)

    class Meta:
        indexes = [
            models.Index(fields=('product', 'event_type', 'created_at')),
        ]


class ProductImage(TimestampedModel):
    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE,
        related_name='images',
        verbose_name=_('Produit'),
    )
    image = models.ImageField(
        upload_to='products/images/',
        verbose_name=_('Image'),
    )
    order = models.PositiveIntegerField(
        default=0,
        verbose_name=_('Ordre'),
    )

    class Meta:
        ordering = ['order', 'id']
        verbose_name = _('Image produit')
        verbose_name_plural = _('Images produit')

    def __str__(self):
        return f"{self.product.title} image {self.id}"


PAYMENT_METHODS = (
    ('wave', _('Wave')),
    ('orange_money', _('Orange Money')),
    ('cash_on_delivery', _('Espèces à la livraison')),
)


class Order(TimestampedModel):
    STATUS = (
        ('pending', _('En attente')),
        ('paid', _('Payé')),
        ('shipped', _('Expédié')),
        ('completed', _('Terminé')),
        ('cancelled', _('Annulé')),
    )
    buyer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='orders', verbose_name=_('Acheteur'))
    status = models.CharField(max_length=20, choices=STATUS, default='pending', verbose_name=_('Statut'))
    payment_method = models.CharField(max_length=50, choices=PAYMENT_METHODS, default='cash_on_delivery', verbose_name=_('Méthode de paiement'))
    payment_phone = models.CharField(max_length=30, blank=True, null=True, verbose_name=_('Téléphone de paiement'))
    delivery_address = models.TextField(blank=True, default='', verbose_name=_('Adresse de livraison'))
    total = models.DecimalField(max_digits=10, decimal_places=2, default=0, verbose_name=_('Total'))

    class Meta:
        verbose_name = _('Commande')
        verbose_name_plural = _('Commandes')


class OrderItem(models.Model):
    FULFILLMENT_STATUSES = (
        ('pending', _('À traiter')),
        ('preparing', _('En préparation')),
        ('in_delivery', _('En cours de livraison')),
        ('delivered', _('Livrée')),
        ('cancelled', _('Annulée')),
        ('returned', _('Retournée')),
    )

    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='items', verbose_name=_('Commande'))
    product = models.ForeignKey(Product, on_delete=models.SET_NULL, null=True, verbose_name=_('Produit'))
    quantity = models.PositiveIntegerField(default=1, verbose_name=_('Quantité'))
    price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name=_('Prix'))
    selected_color = models.CharField(max_length=80, blank=True, verbose_name=_('Couleur choisie'))
    selected_size = models.CharField(max_length=80, blank=True, verbose_name=_('Taille choisie'))
    purchase_price = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True, default=None, verbose_name=_('Prix d’achat au moment de la vente'))
    fulfillment_status = models.CharField(max_length=20, choices=FULFILLMENT_STATUSES, default='pending', verbose_name=_('État de livraison'))
    returned_quantity = models.PositiveIntegerField(default=0, verbose_name=_('Quantité retournée'))

    class Meta:
        verbose_name = _('Article de commande')
        verbose_name_plural = _('Articles de commande')


class StockMovement(TimestampedModel):
    MOVEMENT_TYPES = (
        ('restock', _('Approvisionnement')),
        ('adjustment', _('Ajustement de stock')),
        ('sale', _('Vente')),
        ('return', _('Retour accepté')),
        ('cancellation', _('Annulation de commande')),
    )

    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='stock_movements', verbose_name=_('Produit'))
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, related_name='stock_movements', verbose_name=_('Utilisateur'))
    movement_type = models.CharField(max_length=20, choices=MOVEMENT_TYPES, verbose_name=_('Type de mouvement'))
    quantity_change = models.IntegerField(verbose_name=_('Variation de quantité'))
    unit_cost = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True, default=None, verbose_name=_('Coût unitaire'))
    note = models.CharField(max_length=255, blank=True, verbose_name=_('Note'))
    order_item = models.ForeignKey(OrderItem, on_delete=models.SET_NULL, null=True, blank=True, related_name='stock_movements', verbose_name=_('Article de commande'))

    class Meta:
        ordering = ('-created_at', '-id')
        verbose_name = _('Mouvement de stock')
        verbose_name_plural = _('Mouvements de stock')


class Transaction(TimestampedModel):
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='transaction', verbose_name=_('Commande'))
    amount = models.DecimalField(max_digits=10, decimal_places=2, verbose_name=_('Montant'))
    provider = models.CharField(max_length=100, blank=True, verbose_name=_('Fournisseur'))
    success = models.BooleanField(default=False, verbose_name=_('Succès'))

    class Meta:
        verbose_name = _('Transaction')
        verbose_name_plural = _('Transactions')


class Payment(TimestampedModel):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name='payments', verbose_name=_('Commande'))
    provider = models.CharField(max_length=100, verbose_name=_('Fournisseur'))
    amount = models.DecimalField(max_digits=10, decimal_places=2, verbose_name=_('Montant'))
    status = models.CharField(max_length=50, default='pending', verbose_name=_('Statut'))
    external_id = models.CharField(max_length=255, blank=True, null=True, verbose_name=_('ID externe'))

    class Meta:
        verbose_name = _('Paiement')
        verbose_name_plural = _('Paiements')


class Invoice(TimestampedModel):
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='invoice', verbose_name=_('Commande'))
    issued = models.BooleanField(default=False, verbose_name=_('Émis'))
    pdf = models.FileField(upload_to='invoices/', blank=True, null=True, verbose_name=_('PDF'))

    class Meta:
        verbose_name = _('Facture')
        verbose_name_plural = _('Factures')


class Delivery(TimestampedModel):
    order = models.OneToOneField(Order, on_delete=models.CASCADE, related_name='delivery', verbose_name=_('Commande'))
    tracking_number = models.CharField(max_length=255, blank=True, null=True, verbose_name=_('Numéro de suivi'))
    carrier = models.CharField(max_length=255, blank=True, null=True, verbose_name=_('Transporteur'))
    delivered = models.BooleanField(default=False, verbose_name=_('Livré'))

    class Meta:
        verbose_name = _('Livraison')
        verbose_name_plural = _('Livraisons')


class Review(TimestampedModel):
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='reviews', verbose_name=_('Produit'))
    user = models.ForeignKey(User, on_delete=models.CASCADE, verbose_name=_('Utilisateur'))
    rating = models.PositiveSmallIntegerField(default=5, verbose_name=_('Note'))
    comment = models.TextField(blank=True, verbose_name=_('Commentaire'))

    class Meta:
        verbose_name = _('Avis')
        verbose_name_plural = _('Avis')

    def __str__(self):
        return f"{self.product.title} - {self.user.username} ({self.rating})"


class ProducerReview(TimestampedModel):
    producer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='producer_reviews', verbose_name=_('Vendeur'))
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='producer_ratings', verbose_name=_('Utilisateur'))
    rating = models.PositiveSmallIntegerField(
        default=5,
        validators=[MinValueValidator(1), MaxValueValidator(10)],
        verbose_name=_('Note')
    )
    comment = models.TextField(blank=True, verbose_name=_('Commentaire'))

    class Meta:
        verbose_name = _('Avis vendeur')
        verbose_name_plural = _('Avis vendeurs')
        unique_together = ('producer', 'user')

    def __str__(self):
        return f"{self.producer.username} - {self.user.username} ({self.rating})"


class Message(TimestampedModel):
    MESSAGE_TYPES = (
        ('text', _('Texte')),
        ('audio', _('Audio')),
        ('image', _('Image')),
        ('video', _('Vidéo')),
        ('document', _('Document')),
    )
    room = models.CharField(max_length=255, verbose_name=_('Salle'))
    reply_to = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        related_name='replies',
        null=True,
        blank=True,
        verbose_name=_('Réponse à'),
    )
    user = models.ForeignKey('auth.User', on_delete=models.CASCADE, verbose_name=_('Utilisateur'))
    recipient = models.ForeignKey('auth.User', on_delete=models.CASCADE, related_name='received_messages', null=True, blank=True, verbose_name=_('Destinataire'))
    content = models.TextField(blank=True, verbose_name=_('Contenu'))  # Pour les messages texte
    message_type = models.CharField(max_length=15, choices=MESSAGE_TYPES, default='text', verbose_name=_('Type de message'))
    audio_file = models.FileField(upload_to='messages/audio/', blank=True, null=True, verbose_name=_('Fichier audio'))  # Pour les fichiers audio
    attachment_file = models.FileField(upload_to='messages/attachments/', blank=True, null=True, verbose_name=_('Fichier joint'))
    attachment_type = models.CharField(max_length=15, blank=True, null=True, verbose_name=_('Type de pièce jointe'))
    audio_duration = models.PositiveIntegerField(blank=True, null=True, verbose_name=_('Durée audio'))  # Durée en secondes
    is_read = models.BooleanField(default=False, verbose_name=_('Lu'))

    class Meta:
        verbose_name = _('Message')
        verbose_name_plural = _('Messages')


class Notification(TimestampedModel):
    user = models.ForeignKey('auth.User', on_delete=models.CASCADE, related_name='notifications', verbose_name=_('Utilisateur'))
    title = models.CharField(max_length=255, verbose_name=_('Titre'))
    message = models.TextField(verbose_name=_('Message'))
    type = models.CharField(max_length=50, default='info', verbose_name=_('Type'))  # order, payment, message
    is_read = models.BooleanField(default=False, verbose_name=_('Lu'))
    data = models.JSONField(blank=True, null=True, verbose_name=_('Données'))  # extra data like order_id

    class Meta:
        verbose_name = _('Notification')
        verbose_name_plural = _('Notifications')


# Modèles pour le réseau social
class Follow(TimestampedModel):
    follower = models.ForeignKey(User, on_delete=models.CASCADE, related_name='following', verbose_name=_('Abonné'))
    followed = models.ForeignKey(User, on_delete=models.CASCADE, related_name='followers', verbose_name=_('Suivi'))

    class Meta:
        verbose_name = _('Abonnement')
        verbose_name_plural = _('Abonnements')
        unique_together = ('follower', 'followed')

    def __str__(self):
        return f"{self.follower.username} follows {self.followed.username}"


class Friend(TimestampedModel):
    STATUS_CHOICES = (
        ('pending', _('En attente')),
        ('accepted', _('Accepté')),
        ('declined', _('Refusé')),
    )
    requester = models.ForeignKey(User, on_delete=models.CASCADE, related_name='friend_requests_sent', verbose_name=_('Demandeur'))
    receiver = models.ForeignKey(User, on_delete=models.CASCADE, related_name='friend_requests_received', verbose_name=_('Receveur'))
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending', verbose_name=_('Statut'))

    class Meta:
        verbose_name = _('Ami')
        verbose_name_plural = _('Amis')
        unique_together = ('requester', 'receiver')

    def __str__(self):
        return f"{self.requester.username} -> {self.receiver.username} ({self.status})"


class Favorite(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='favorites', verbose_name=_('Utilisateur'))
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='favorited_by', verbose_name=_('Produit'))

    class Meta:
        verbose_name = _('Favori')
        verbose_name_plural = _('Favoris')
        unique_together = ('user', 'product')

    def __str__(self):
        return f"{self.user.username} favorited {self.product.title}"


class ProductView(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='product_views')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='views')
    viewed_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'product')

    def __str__(self):
        return f"{self.user.username} viewed {self.product.title}"


class Recommendation(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='recommendations')
    product = models.ForeignKey(Product, on_delete=models.CASCADE, related_name='recommended_to')
    score = models.FloatField(default=0.0)  # Recommendation score


# Modèles pour le réseau social étendu
class Post(TimestampedModel):
    POST_TYPES = (
        ('text', 'Texte'),
        ('image', 'Image'),
        ('video', 'Vidéo'),
        ('album', 'Album'),
        ('trophy', 'Trophée'),
        ('reel', 'Reel'),
        ('job', 'Offre d\'emploi'),
        ('government', 'Information gouvernementale'),
        ('education', 'Information éducative'),
        ('health', 'Information santé'),
        ('service', 'Service public/privé'),
        ('marketplace', 'Article marketplace'),
    )

    PRIVACY_CHOICES = (
        ('public', 'Public'),
        ('friends', 'Amis'),
        ('private', 'Privé'),
        ('custom', 'Personnalisé'),
    )

    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='posts')
    content = models.TextField(blank=True)
    post_type = models.CharField(max_length=20, choices=POST_TYPES, default='text')
    background_color = models.CharField(max_length=7, blank=True, default='')

    # Media fields
    image = models.ImageField(upload_to='posts/', blank=True, null=True)
    video = models.FileField(upload_to='posts/videos/', blank=True, null=True)

    # Album support (multiple images)
    images = models.JSONField(blank=True, null=True, help_text="List of image URLs for albums")

    # Marketplace integration
    product = models.ForeignKey('Product', on_delete=models.SET_NULL, null=True, blank=True, related_name='posts')

    # Social features
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True)
    privacy = models.CharField(max_length=20, choices=PRIVACY_CHOICES, default='public')
    location = models.CharField(max_length=255, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)

    # Engagement metrics
    is_active = models.BooleanField(default=True)
    likes_count = models.PositiveIntegerField(default=0)
    comments_count = models.PositiveIntegerField(default=0)
    shares_count = models.PositiveIntegerField(default=0)

    # Repost functionality
    repost_of = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='reposts')

    # Tags and mentions
    tagged_users = models.ManyToManyField(User, blank=True, related_name='tagged_in_posts')
    hashtags = models.JSONField(blank=True, null=True, help_text="List of hashtags")
    trophy_challenge = models.ForeignKey(
        'GameChallenge',
        on_delete=models.SET_NULL,
        blank=True,
        null=True,
        related_name='trophy_posts',
    )
    trophy_data = models.JSONField(blank=True, null=True)

    def __str__(self):
        return f"{self.author.username}: {self.content[:50] if self.content else self.post_type}"


class ProfileAnalyticsEvent(TimestampedModel):
    EVENT_TYPES = (
        ('profile_view', 'Consultation du profil'),
        ('post_impression', 'Impression d’une publication'),
        ('search_appearance', 'Apparition dans les recherches'),
    )

    owner = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='profile_analytics_events',
    )
    event_type = models.CharField(max_length=32, choices=EVENT_TYPES)
    post = models.ForeignKey(
        Post,
        on_delete=models.CASCADE,
        related_name='analytics_events',
        blank=True,
        null=True,
    )

    class Meta:
        indexes = [
            models.Index(fields=('owner', 'event_type', 'created_at')),
        ]


class Like(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='likes')
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='likes')

    class Meta:
        unique_together = ('user', 'post')

    def __str__(self):
        return f"{self.user.username} liked {self.post.id}"


class Comment(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='comments')
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='comments')
    content = models.TextField()
    parent = models.ForeignKey('self', on_delete=models.CASCADE, null=True, blank=True, related_name='replies')

    def __str__(self):
        return f"{self.user.username}: {self.content[:50]}"


class Share(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='shares')
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='shares')
    content = models.TextField(blank=True)  # Optional comment when sharing

    def __str__(self):
        return f"{self.user.username} shared {self.post.id}"


class JobPosting(TimestampedModel):
    employer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='job_postings')
    title = models.CharField(max_length=255)
    description = models.TextField()
    company = models.CharField(max_length=255, blank=True)
    location = models.CharField(max_length=255, blank=True)
    salary_min = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    salary_max = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    job_type = models.CharField(max_length=50, choices=[
        ('full_time', 'Temps plein'),
        ('part_time', 'Temps partiel'),
        ('contract', 'Contrat'),
        ('freelance', 'Freelance'),
    ], default='full_time')
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True)
    is_active = models.BooleanField(default=True)
    applications_count = models.PositiveIntegerField(default=0)

    def __str__(self):
        return self.title


class JobSeekerPost(TimestampedModel):
    author = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='job_seeker_posts',
    )
    title = models.CharField(max_length=255)
    description = models.TextField()
    location = models.CharField(max_length=255, blank=True)
    job_type = models.CharField(
        max_length=50,
        choices=JobPosting._meta.get_field('job_type').choices,
        blank=True,
    )
    resume = models.FileField(upload_to='resumes/', blank=True, null=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ('-created_at',)

    def __str__(self):
        return self.title


class JobApplication(TimestampedModel):
    applicant = models.ForeignKey(User, on_delete=models.CASCADE, related_name='job_applications')
    job = models.ForeignKey(JobPosting, on_delete=models.CASCADE, related_name='applications')
    cover_letter = models.TextField(blank=True)
    resume = models.FileField(upload_to='resumes/', blank=True, null=True)
    status = models.CharField(max_length=20, choices=[
        ('pending', 'En attente'),
        ('reviewed', 'Examiné'),
        ('accepted', 'Accepté'),
        ('rejected', 'Rejeté'),
    ], default='pending')

    class Meta:
        unique_together = ('applicant', 'job')

    def __str__(self):
        return f"{self.applicant.username} applied for {self.job.title}"

    def __str__(self):
        return f"Recommendation for {self.user.username}: {self.product.title} ({self.score})"


class Like(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='likes')
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='likes')

    class Meta:
        unique_together = ('user', 'post')

    def __str__(self):
        return f"{self.user.username} liked {self.post.author.username}'s post"


class Comment(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='comments')
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='comments')
    content = models.TextField()

    def __str__(self):
        return f"{self.user.username} commented on {self.post.author.username}'s post"


# Modèles pour les coupons et fidélité
class Coupon(TimestampedModel):
    code = models.CharField(max_length=50, unique=True)
    discount_type = models.CharField(max_length=20, choices=[('percentage', 'Pourcentage'), ('fixed', 'Montant fixe')])
    discount_value = models.DecimalField(max_digits=10, decimal_places=2)
    min_order_value = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    max_discount = models.DecimalField(max_digits=10, decimal_places=2, blank=True, null=True)
    usage_limit = models.PositiveIntegerField(default=1)
    used_count = models.PositiveIntegerField(default=0)
    valid_from = models.DateTimeField()
    valid_until = models.DateTimeField()
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.code} - {self.discount_value}{' %' if self.discount_type == 'percentage' else ' FCFA'}"


class LoyaltyProgram(TimestampedModel):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='loyalty')
    points = models.PositiveIntegerField(default=0)

    def __str__(self):
        return f"{self.user.username} - {self.points} points"


class Referral(TimestampedModel):
    referrer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='referrals_made')
    referred = models.ForeignKey(User, on_delete=models.CASCADE, related_name='referred_by')
    bonus_points = models.PositiveIntegerField(default=100)

    def __str__(self):
        return f"{self.referrer.username} referred {self.referred.username}"


# Group/Community Models
class Group(TimestampedModel):
    GROUP_TYPES = (
        ('public', 'Public'),
        ('private', 'Privé'),
        ('secret', 'Secret'),
    )

    name = models.CharField(max_length=255)
    slug = models.SlugField(unique=True, blank=True)
    description = models.TextField(blank=True)
    cover_image = models.ImageField(upload_to='groups/', blank=True, null=True)
    avatar = models.ImageField(upload_to='groups/avatars/', blank=True, null=True)
    group_type = models.CharField(max_length=20, choices=GROUP_TYPES, default='public')
    creator = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_groups')
    category = models.ForeignKey(Category, on_delete=models.SET_NULL, null=True, blank=True)
    rules = models.TextField(blank=True)
    member_count = models.PositiveIntegerField(default=0)
    post_count = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    def save(self, *args, **kwargs):
        from django.utils.text import slugify

        if not self.slug:
            base_slug = slugify(self.name)
            slug = base_slug
            count = 1
            while Group.objects.filter(slug=slug).exclude(pk=self.pk).exists():
                count += 1
                slug = f"{base_slug}-{count}"
            self.slug = slug
        super().save(*args, **kwargs)

    def __str__(self):
        return self.name


class GroupMember(TimestampedModel):
    MEMBER_ROLES = (
        ('member', 'Membre'),
        ('moderator', 'Modérateur'),
        ('admin', 'Administrateur'),
    )

    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name='members')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='group_memberships')
    role = models.CharField(max_length=20, choices=MEMBER_ROLES, default='member')
    joined_at = models.DateTimeField(auto_now_add=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        unique_together = ('group', 'user')

    def __str__(self):
        return f"{self.user.username} in {self.group.name}"


class GroupEvent(TimestampedModel):
    group = models.ForeignKey(
        Group,
        on_delete=models.CASCADE,
        related_name='events',
        blank=True,
        null=True,
    )
    creator = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_group_events')
    title = models.CharField(max_length=255)
    description = models.TextField(blank=True)
    location = models.CharField(max_length=255, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)
    start_date = models.DateTimeField()
    end_date = models.DateTimeField()
    max_attendees = models.PositiveIntegerField(blank=True, null=True)
    attendee_count = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.title} - {self.group.name if self.group else 'Événement public'}"


class GroupEventAttendee(TimestampedModel):
    event = models.ForeignKey(GroupEvent, on_delete=models.CASCADE, related_name='attendees')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='group_event_attendances')
    status = models.CharField(max_length=20, choices=[
        ('going', 'Participe'),
        ('maybe', 'Peut-être'),
        ('not_going', 'Ne participe pas')
    ], default='going')

    class Meta:
        unique_together = ('event', 'user')

    def __str__(self):
        return f"{self.user.username} - {self.event.title}"


class GroupPost(TimestampedModel):
    POST_TYPES = (
        ('text', 'Texte'),
        ('image', 'Image'),
        ('video', 'Vidéo'),
        ('album', 'Album'),
        ('event', 'Événement'),
        ('poll', 'Sondage'),
    )

    PRIVACY_CHOICES = (
        ('public', 'Public'),
        ('friends', 'Amis'),
    )

    group = models.ForeignKey(Group, on_delete=models.CASCADE, related_name='posts')
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='group_posts')
    content = models.TextField(blank=True)
    post_type = models.CharField(max_length=20, choices=POST_TYPES, default='text')
    privacy = models.CharField(max_length=20, choices=PRIVACY_CHOICES, default='public')

    # Media fields
    image = models.ImageField(upload_to='group_posts/', blank=True, null=True)
    video = models.FileField(upload_to='group_posts/', blank=True, null=True)
    images = models.JSONField(blank=True, null=True, help_text="List of image URLs for albums")

    # Event integration
    event = models.ForeignKey(GroupEvent, on_delete=models.SET_NULL, null=True, blank=True, related_name='posts')

    # Poll functionality
    poll_question = models.CharField(max_length=255, blank=True)
    poll_options = models.JSONField(blank=True, null=True, help_text="List of poll options")
    poll_results = models.JSONField(blank=True, null=True, help_text="Poll voting results")

    # Engagement metrics
    likes_count = models.PositiveIntegerField(default=0)
    comments_count = models.PositiveIntegerField(default=0)
    shares_count = models.PositiveIntegerField(default=0)
    repost_of = models.ForeignKey('self', on_delete=models.SET_NULL, null=True, blank=True, related_name='reposts')

    # Group-specific features
    is_pinned = models.BooleanField(default=False)
    is_announcement = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)

    # Tags and mentions
    tagged_users = models.ManyToManyField(User, blank=True, related_name='tagged_in_group_posts')
    hashtags = models.JSONField(blank=True, null=True, help_text="List of hashtags")

    def __str__(self):
        return f"Post by {self.author.username} in {self.group.name}"


class GroupPostLike(TimestampedModel):
    post = models.ForeignKey(GroupPost, on_delete=models.CASCADE, related_name='likes')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='group_post_likes')

    class Meta:
        unique_together = ('post', 'user')

    def __str__(self):
        return f"{self.user.username} liked post in {self.post.group.name}"


class GroupPostComment(TimestampedModel):
    post = models.ForeignKey(GroupPost, on_delete=models.CASCADE, related_name='comments')
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='group_post_comments')
    content = models.TextField()
    # parent = models.ForeignKey('GroupPostComment', on_delete=models.CASCADE, null=True, blank=True, related_name='replies')
    likes_count = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"Comment by {self.author.username} on post in {self.post.group.name}"


# Stories (Instagram-style)
class Story(TimestampedModel):
    STORY_TYPES = (
        ('image', 'Image'),
        ('video', 'Vidéo'),
        ('text', 'Texte'),
    )

    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='stories')
    story_type = models.CharField(max_length=10, choices=STORY_TYPES, default='image')
    content = models.TextField(blank=True)  # For text stories
    image = models.ImageField(upload_to='stories/', blank=True, null=True)
    video = models.FileField(upload_to='stories/', blank=True, null=True)
    background_color = models.CharField(max_length=7, default='#ffffff')  # Hex color for text stories
    text_color = models.CharField(max_length=7, default='#000000')
    font_size = models.IntegerField(default=24)
    expires_at = models.DateTimeField()
    is_active = models.BooleanField(default=True)
    views_count = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Story by {self.author.username}"

    def save(self, *args, **kwargs):
        if not self.expires_at:
            self.expires_at = timezone.now() + timedelta(hours=24)
        super().save(*args, **kwargs)

    @property
    def is_expired(self):
        return timezone.now() >= self.expires_at


class StoryView(TimestampedModel):
    story = models.ForeignKey(Story, on_delete=models.CASCADE, related_name='views')
    viewer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='story_views')

    class Meta:
        unique_together = ('story', 'viewer')

    def __str__(self):
        return f"{self.viewer.username} viewed story by {self.story.author.username}"


class StoryLike(TimestampedModel):
    story = models.ForeignKey(Story, on_delete=models.CASCADE, related_name='likes')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='story_likes')

    class Meta:
        unique_together = ('story', 'user')

    def __str__(self):
        return f"{self.user.username} liked story by {self.story.author.username}"


# Reels (Instagram-style short videos)
class Reel(TimestampedModel):
    THEME_CHOICES = (
        ('Produits', 'Produits'),
        ('Recettes', 'Recettes'),
        ('Vie locale', 'Vie locale'),
        ('Tendances', 'Tendances'),
    )
    EFFECT_CHOICES = (
        ('none', 'Aucun'),
        ('light', 'Lumière'),
        ('stickers', 'Autocollants'),
        ('before_after', 'Avant / après'),
        ('face', 'Visage'),
    )
    STICKER_CHOICES = (
        ('sparkle', 'Étincelles'),
        ('heart', 'Cœur'),
        ('star', 'Étoile'),
        ('cool', 'Lunettes'),
    )

    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reels')
    title = models.CharField(max_length=255, blank=True)
    description = models.TextField(blank=True)
    theme = models.CharField(max_length=32, choices=THEME_CHOICES, default='Produits')
    effect = models.CharField(max_length=20, choices=EFFECT_CHOICES, default='none')
    sticker = models.CharField(max_length=16, choices=STICKER_CHOICES, blank=True, default='')
    video = models.FileField(upload_to='reels/')
    thumbnail = models.ImageField(upload_to='reels/thumbnails/', blank=True, null=True)
    duration = models.DurationField(blank=True, null=True)
    views_count = models.PositiveIntegerField(default=0)
    likes_count = models.PositiveIntegerField(default=0)
    comments_count = models.PositiveIntegerField(default=0)
    shares_count = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    # Audio information
    audio_title = models.CharField(max_length=255, blank=True)
    audio_artist = models.CharField(max_length=255, blank=True)

    def __str__(self):
        return f"Reel by {self.author.username}: {self.title or 'Untitled'}"


class ReelLike(TimestampedModel):
    reel = models.ForeignKey(Reel, on_delete=models.CASCADE, related_name='likes')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reel_likes')

    class Meta:
        unique_together = ('reel', 'user')

    def __str__(self):
        return f"{self.user.username} liked reel by {self.reel.author.username}"


class ReelComment(TimestampedModel):
    reel = models.ForeignKey(Reel, on_delete=models.CASCADE, related_name='comments')
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reel_comments')
    content = models.TextField()
    parent = models.ForeignKey('self', on_delete=models.CASCADE, null=True, blank=True, related_name='replies')
    likes_count = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"Comment by {self.author.username} on reel"


class ReelView(TimestampedModel):
    reel = models.ForeignKey(Reel, on_delete=models.CASCADE, related_name='views')
    viewer = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reel_views')

    class Meta:
        unique_together = ('reel', 'viewer')

    def __str__(self):
        return f"{self.viewer.username} viewed reel by {self.reel.author.username}"


# Enhanced reactions (Facebook-style)
class Reaction(TimestampedModel):
    REACTION_TYPES = (
        ('like', 'J\'aime'),
        ('love', 'J\'adore'),
        ('laugh', 'Haha'),
        ('wow', 'Wow'),
        ('sad', 'Triste'),
        ('angry', 'En colère'),
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='reactions')
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='reactions', null=True, blank=True)
    group_post = models.ForeignKey(GroupPost, on_delete=models.CASCADE, related_name='reactions', null=True, blank=True)
    reel = models.ForeignKey(Reel, on_delete=models.CASCADE, related_name='reactions', null=True, blank=True)
    reaction_type = models.CharField(max_length=10, choices=REACTION_TYPES, default='like')

    class Meta:
        unique_together = ('user', 'post', 'group_post', 'reel')

    def __str__(self):
        target = self.post or self.group_post or self.reel
        return f"{self.user.username} reacted {self.reaction_type} to {target}"


# Marketplace enhancements
class MarketplaceListing(TimestampedModel):
    CONDITION_CHOICES = (
        ('new', 'Neuf'),
        ('used_like_new', 'Comme neuf'),
        ('used_good', 'Bon état'),
        ('used_fair', 'État correct'),
        ('used_poor', 'Mauvais état'),
    )

    seller = models.ForeignKey(User, on_delete=models.CASCADE, related_name='marketplace_listings')
    product = models.OneToOneField(Product, on_delete=models.CASCADE, related_name='marketplace_listing')
    title = models.CharField(max_length=255)
    description = models.TextField()
    price = models.DecimalField(max_digits=10, decimal_places=2)
    condition = models.CharField(max_length=20, choices=CONDITION_CHOICES, default='new')
    location = models.CharField(max_length=255, blank=True)
    latitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, blank=True, null=True)
    is_active = models.BooleanField(default=True)
    views_count = models.PositiveIntegerField(default=0)
    favorites_count = models.PositiveIntegerField(default=0)

    def __str__(self):
        return f"{self.title} - {self.price}€"


class MarketplaceFavorite(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='marketplace_favorites')
    listing = models.ForeignKey(MarketplaceListing, on_delete=models.CASCADE, related_name='favorites')

    class Meta:
        unique_together = ('user', 'listing')

    def __str__(self):
        return f"{self.user.username} favorited {self.listing.title}"


# Hashtags system
class Hashtag(TimestampedModel):
    name = models.CharField(max_length=100, unique=True)
    usage_count = models.PositiveIntegerField(default=0)

    def __str__(self):
        return f"#{self.name}"

    def save(self, *args, **kwargs):
        self.name = self.name.lower().replace('#', '')
        super().save(*args, **kwargs)


# Mentions system
class Mention(TimestampedModel):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='mentions')
    mentioned_by = models.ForeignKey(User, on_delete=models.CASCADE, related_name='created_mentions')
    post = models.ForeignKey(Post, on_delete=models.CASCADE, related_name='mentions', null=True, blank=True)
    group_post = models.ForeignKey(GroupPost, on_delete=models.CASCADE, related_name='mentions', null=True, blank=True)
    comment = models.ForeignKey(Comment, on_delete=models.CASCADE, related_name='mentions', null=True, blank=True)
    group_comment = models.ForeignKey(GroupPostComment, on_delete=models.CASCADE, related_name='mentions', null=True, blank=True)

    def __str__(self):
        return f"{self.mentioned_by.username} mentioned {self.user.username}"


# Shopping Cart
class Cart(TimestampedModel):
    user = models.OneToOneField(User, on_delete=models.CASCADE, related_name='cart', verbose_name=_('Utilisateur'))
    total = models.DecimalField(max_digits=10, decimal_places=2, default=0, verbose_name=_('Total'))

    class Meta:
        verbose_name = _('Panier')
        verbose_name_plural = _('Paniers')

    def __str__(self):
        return f"Panier de {self.user.username}"

    def calculate_total(self):
        """Recalcule le total du panier"""
        total = sum(
            item.product.current_price * item.quantity
            for item in self.items.select_related('product')
        )
        self.total = total
        self.save()
        return total

    @property
    def item_count(self):
        return sum(item.quantity for item in self.items.all())


class CartItem(TimestampedModel):
    cart = models.ForeignKey(Cart, on_delete=models.CASCADE, related_name='items', verbose_name=_('Panier'))
    product = models.ForeignKey(Product, on_delete=models.CASCADE, verbose_name=_('Produit'))
    quantity = models.PositiveIntegerField(default=1, verbose_name=_('Quantité'))
    price = models.DecimalField(max_digits=10, decimal_places=2, verbose_name=_('Prix unitaire'))
    selected_color = models.CharField(max_length=80, blank=True, verbose_name=_('Couleur choisie'))
    selected_size = models.CharField(max_length=80, blank=True, verbose_name=_('Taille choisie'))

    class Meta:
        verbose_name = _('Article du panier')
        verbose_name_plural = _('Articles du panier')
        constraints = [
            models.UniqueConstraint(
                fields=('cart', 'product', 'selected_color', 'selected_size'),
                name='unique_cart_product_variant',
            ),
        ]

    def __str__(self):
        return f"{self.product.title} (x{self.quantity})"

    @property
    def subtotal(self):
        return self.quantity * self.price

    def save(self, *args, **kwargs):
        if not self.price:
            self.price = self.product.current_price
        super().save(*args, **kwargs)
        self.cart.calculate_total()


class GameReward(TimestampedModel):
    DUEL_MEDAL_CHOICES = (
        ('none', _('Aucune')),
        ('bronze', _('Bronze')),
        ('silver', _('Argent')),
        ('gold', _('Or')),
        ('cup', _('Coupe')),
        ('cup_pro', _('Coupe Pro')),
    )

    user = models.OneToOneField(
        User,
        on_delete=models.CASCADE,
        related_name='fopcam_game_reward',
        verbose_name=_('Utilisateur'),
    )
    level = models.PositiveSmallIntegerField(default=12)
    score = models.PositiveIntegerField()
    points = models.PositiveIntegerField(default=500)
    title = models.CharField(max_length=255)
    duel_medal = models.CharField(
        max_length=10,
        choices=DUEL_MEDAL_CHOICES,
        default='none',
    )
    earned_duel_medals = models.JSONField(default=list, blank=True)

    class Meta:
        verbose_name = _('Récompense de jeu')
        verbose_name_plural = _('Récompenses de jeu')

    def __str__(self):
        return f"{self.title} ({self.user.username})"


class GameChallenge(TimestampedModel):
    PENDING = 'pending'
    ACCEPTED = 'accepted'
    PLAYING = 'playing'
    DECLINED = 'declined'
    CANCELLED = 'cancelled'
    COMPLETED = 'completed'
    EXPIRED = 'expired'
    STATUS_CHOICES = (
        (PENDING, _('En attente')),
        (ACCEPTED, _('Accepté')),
        (PLAYING, _('En cours')),
        (DECLINED, _('Refusé')),
        (CANCELLED, _('Annulé')),
        (COMPLETED, _('Terminé')),
        (EXPIRED, _('Expiré')),
    )

    challenger = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='sent_game_challenges',
    )
    challenged = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='received_game_challenges',
    )
    status = models.CharField(max_length=12, choices=STATUS_CHOICES, default=PENDING)
    expires_at = models.DateTimeField(default=game_challenge_expiry, db_index=True)
    challenger_ready_at = models.DateTimeField(blank=True, null=True)
    challenged_ready_at = models.DateTimeField(blank=True, null=True)
    started_at = models.DateTimeField(blank=True, null=True)
    round_number = models.PositiveSmallIntegerField(default=1)
    challenger_round_complete = models.BooleanField(default=False)
    challenged_round_complete = models.BooleanField(default=False)
    challenger_turn = models.BooleanField(default=True)
    challenger_score = models.PositiveIntegerField(blank=True, null=True)
    challenged_score = models.PositiveIntegerField(blank=True, null=True)
    challenger_live_state = models.JSONField(blank=True, null=True)
    challenged_live_state = models.JSONField(blank=True, null=True)
    challenger_live_at = models.DateTimeField(blank=True, null=True)
    challenged_live_at = models.DateTimeField(blank=True, null=True)
    winner = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        related_name='won_game_challenges',
        blank=True,
        null=True,
    )
    winner_by_score = models.BooleanField(default=False)
    rematch_of = models.ForeignKey(
        'self',
        on_delete=models.SET_NULL,
        related_name='rematches',
        blank=True,
        null=True,
    )
    rematch_requester = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        related_name='requested_game_rematches',
        blank=True,
        null=True,
    )
    tournament_match = models.ForeignKey(
        'GameTournamentMatch',
        on_delete=models.SET_NULL,
        related_name='game_challenges',
        blank=True,
        null=True,
    )

    class Meta:
        ordering = ('-created_at',)

    def __str__(self):
        return f"Défi {self.challenger.username} vs {self.challenged.username} ({self.status})"


class GameDuelReward(TimestampedModel):
    challenge = models.OneToOneField(
        GameChallenge,
        on_delete=models.CASCADE,
        related_name='duel_reward',
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='game_duel_rewards',
    )
    sequence = models.PositiveIntegerField()
    title = models.CharField(max_length=120)
    description = models.CharField(max_length=255)
    reward_type = models.CharField(max_length=32)
    color = models.CharField(max_length=7)

    class Meta:
        ordering = ('-created_at',)
        constraints = [
            models.UniqueConstraint(
                fields=('user', 'sequence'),
                name='unique_user_game_duel_reward_sequence',
            ),
        ]

    def __str__(self):
        return f"{self.title} ({self.user.username})"


class GameTournament(TimestampedModel):
    REGISTRATION = 'registration'
    GROUPS = 'groups'
    QUARTERFINALS = 'quarterfinals'
    SEMIFINALS = 'semifinals'
    FINAL = 'final'
    COMPLETED = 'completed'
    STATUS_CHOICES = (
        (REGISTRATION, _('Inscriptions')),
        (GROUPS, _('Phase de poules')),
        (QUARTERFINALS, _('Quarts de finale')),
        (SEMIFINALS, _('Demi-finales')),
        (FINAL, _('Finale')),
        (COMPLETED, _('Terminé')),
    )

    organizer = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='organized_game_tournaments',
    )
    capacity = models.PositiveSmallIntegerField(
        choices=((6, '6'), (12, '12')),
    )
    status = models.CharField(
        max_length=16,
        choices=STATUS_CHOICES,
        default=REGISTRATION,
        db_index=True,
    )
    winner = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        related_name='won_game_tournaments',
        blank=True,
        null=True,
    )
    trophy_title = models.CharField(max_length=80, blank=True)
    started_at = models.DateTimeField(blank=True, null=True)
    completed_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        ordering = ('-created_at',)

    def __str__(self):
        return f"Championnat à {self.capacity} participants ({self.status})"


class GameTournamentEntry(TimestampedModel):
    INVITED = 'invited'
    CONFIRMED = 'confirmed'
    STATUS_CHOICES = (
        (INVITED, _('Invité')),
        (CONFIRMED, _('Inscrit')),
    )

    tournament = models.ForeignKey(
        GameTournament,
        on_delete=models.CASCADE,
        related_name='entries',
    )
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='game_tournament_entries',
    )
    status = models.CharField(
        max_length=12,
        choices=STATUS_CHOICES,
        default=CONFIRMED,
    )
    group_number = models.PositiveSmallIntegerField(blank=True, null=True)
    joined_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        ordering = ('created_at', 'id')
        constraints = [
            models.UniqueConstraint(
                fields=('tournament', 'user'),
                name='unique_game_tournament_entry',
            ),
        ]

    def __str__(self):
        return f"{self.user.username} · championnat {self.tournament_id}"


class GameTournamentMatch(TimestampedModel):
    GROUP = 'group'
    QUARTERFINAL = 'quarterfinal'
    SEMIFINAL = 'semifinal'
    FINAL = 'final'
    ROUND_CHOICES = (
        (GROUP, _('Phase de poules')),
        (QUARTERFINAL, _('Quart de finale')),
        (SEMIFINAL, _('Demi-finale')),
        (FINAL, _('Finale')),
    )
    SCHEDULED = 'scheduled'
    PLAYING = 'playing'
    COMPLETED = 'completed'
    STATUS_CHOICES = (
        (SCHEDULED, _('À jouer')),
        (PLAYING, _('En cours')),
        (COMPLETED, _('Terminé')),
    )

    tournament = models.ForeignKey(
        GameTournament,
        on_delete=models.CASCADE,
        related_name='matches',
    )
    round_type = models.CharField(max_length=16, choices=ROUND_CHOICES)
    group_number = models.PositiveSmallIntegerField(blank=True, null=True)
    match_number = models.PositiveSmallIntegerField()
    player_a = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='game_tournament_matches_as_a',
    )
    player_b = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='game_tournament_matches_as_b',
    )
    challenge = models.OneToOneField(
        GameChallenge,
        on_delete=models.SET_NULL,
        related_name='tournament_fixture',
        blank=True,
        null=True,
    )
    winner = models.ForeignKey(
        User,
        on_delete=models.SET_NULL,
        related_name='won_game_tournament_matches',
        blank=True,
        null=True,
    )
    status = models.CharField(
        max_length=12,
        choices=STATUS_CHOICES,
        default=SCHEDULED,
        db_index=True,
    )

    class Meta:
        ordering = ('round_type', 'group_number', 'match_number', 'id')

    def __str__(self):
        return f"Match {self.tournament_id} · {self.round_type} · {self.match_number}"


class GameTournamentSupport(TimestampedModel):
    tournament = models.ForeignKey(
        GameTournament,
        on_delete=models.CASCADE,
        related_name='support_votes',
    )
    supporter = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='game_tournament_supports',
    )
    participant = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='game_tournament_supporters',
    )

    class Meta:
        constraints = [
            models.UniqueConstraint(
                fields=('tournament', 'supporter'),
                name='unique_game_tournament_supporter',
            ),
        ]

    def __str__(self):
        return f"{self.supporter.username} soutient {self.participant.username}"


class PasswordResetCode(TimestampedModel):
    EMAIL = 'email'
    WHATSAPP = 'whatsapp'
    CHANNEL_CHOICES = (
        (EMAIL, _('Email')),
        (WHATSAPP, _('WhatsApp')),
    )

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='password_reset_codes',
    )
    channel = models.CharField(max_length=10, choices=CHANNEL_CHOICES)
    code_hash = models.CharField(max_length=128)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    consumed_at = models.DateTimeField(blank=True, null=True)

    class Meta:
        indexes = [
            models.Index(fields=('user', 'created_at')),
        ]

    def __str__(self):
        return f"Code de réinitialisation {self.user.username} ({self.channel})"