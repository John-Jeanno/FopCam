from decimal import Decimal

from django.contrib.auth.models import User
from django.db import transaction

from .models import (
    UserProfile,
    Shop,
    Category,
    Product,
    Post,
    Notification,
    Story,
)

SAMPLE_USERS = [
    {
        'username': 'producer4',
        'first_name': 'Karim',
        'last_name': 'Sarr',
        'email': 'karim.sarr@fopcam.com',
        'password': 'Producer123!',
        'is_staff': False,
        'is_superuser': False,
        'role': 'producer',
        'phone': '+221 77 987 65 43',
        'address': 'Zone industrielle, Thiès',
        'city': 'Thiès',
        'country': 'Sénégal',
        'verified': True,
    },
    {
        'username': 'producer5',
        'first_name': 'Aïcha',
        'last_name': 'Fall',
        'email': 'aicha.fall@fopcam.com',
        'password': 'Producer123!',
        'is_staff': False,
        'is_superuser': False,
        'role': 'producer',
        'phone': '+221 76 543 21 09',
        'address': 'Pikine Nord, Dakar',
        'city': 'Dakar',
        'country': 'Sénégal',
        'verified': True,
    },
    {
        'username': 'vet1',
        'first_name': 'Dr.',
        'last_name': 'Vétérinaire',
        'email': 'dr.veto@fopcam.com',
        'password': 'VetSecure123!',
        'is_staff': False,
        'is_superuser': False,
        'role': 'producer',
        'phone': '+221 77 678 90 12',
        'address': 'Avenue Pasteur, Dakar',
        'city': 'Dakar',
        'country': 'Sénégal',
        'verified': True,
    },
    {
        'username': 'buyer2',
        'first_name': 'Sophie',
        'last_name': 'Ndiaye',
        'email': 'sophie.ndiaye@fopcam.com',
        'password': 'Buyer123!',
        'is_staff': False,
        'is_superuser': False,
        'role': 'buyer',
        'phone': '+221 78 123 45 67',
        'address': 'Mermoz, Dakar',
        'city': 'Dakar',
        'country': 'Sénégal',
        'verified': False,
    },
    {
        'username': 'buyer3',
        'first_name': 'Ousmane',
        'last_name': 'Keita',
        'email': 'ousmane.keita@fopcam.com',
        'password': 'Buyer123!',
        'is_staff': False,
        'is_superuser': False,
        'role': 'buyer',
        'phone': '+221 77 222 33 44',
        'address': 'Point E, Dakar',
        'city': 'Dakar',
        'country': 'Sénégal',
        'verified': False,
    },
    {
        'username': 'buyer4',
        'first_name': 'Aminata',
        'last_name': 'Diallo',
        'email': 'aminata.diallo@fopcam.com',
        'password': 'Buyer123!',
        'is_staff': False,
        'is_superuser': False,
        'role': 'buyer',
        'phone': '+221 77 333 44 55',
        'address': 'Almadies, Dakar',
        'city': 'Dakar',
        'country': 'Sénégal',
        'verified': False,
    },
]

SAMPLE_CATEGORIES = [
    {'name': 'Santé Avicole', 'slug': 'sante-avicole', 'sector': 'health', 'category_type': 'professional'},
    {'name': 'Vétérinaire', 'slug': 'veterinaire', 'sector': 'health', 'category_type': 'professional'},
    {'name': 'Vaccins & Sérums', 'slug': 'vaccins-serums', 'sector': 'health', 'category_type': 'product'},
    {'name': 'Soins et Médicaments', 'slug': 'soins-medicaments', 'sector': 'health', 'category_type': 'product'},
    {'name': 'Services de Nettoyage', 'slug': 'services-nettoyage', 'sector': 'services', 'category_type': 'professional'},
    {'name': 'Maintenance Électrique', 'slug': 'maintenance-electrique', 'sector': 'services', 'category_type': 'professional'},
    {'name': 'Coiffure & Beauté', 'slug': 'coiffure-beaute', 'sector': 'services', 'category_type': 'professional'},
    {'name': 'Transport & Livraison', 'slug': 'transport-livraison', 'sector': 'services', 'category_type': 'professional'},
    {'name': 'Éducation & Formation', 'slug': 'education-formation', 'sector': 'education', 'category_type': 'professional'},
    {'name': 'Commerce de Gros', 'slug': 'commerce-gros', 'sector': 'retail', 'category_type': 'product'},
    {'name': 'Sport', 'slug': 'sport', 'sector': 'entertainment', 'category_type': 'product'},
    {'name': 'Agriculture durable', 'slug': 'agriculture-durable', 'sector': 'agriculture', 'category_type': 'professional'},
    {'name': 'Éducation numérique', 'slug': 'education-numerique', 'sector': 'education', 'category_type': 'professional'},
    {'name': 'Innovation technologique', 'slug': 'innovation-technologique', 'sector': 'technology', 'category_type': 'professional'},
    {'name': 'Artisanat local', 'slug': 'artisanat-local', 'sector': 'manufacturing', 'category_type': 'professional'},
    {'name': 'Environnement', 'slug': 'environnement', 'sector': 'other', 'category_type': 'professional'},
]

SAMPLE_SHOPS = [
    {
        'owner': 'producer4',
        'name': 'Clinique Avicole du Lac',
        'description': 'Centre vétérinaire pour volailles, diagnostics et traitements sur mesure.',
        'location': 'Thiès, Sénégal',
        'active': True,
    },
    {
        'owner': 'producer5',
        'name': 'VétoVolaille',
        'description': 'Services vétérinaires spécialisés pour une agriculture durable et des productions modernes.',
        'location': 'Pikine, Dakar',
        'active': True,
    },
    {
        'owner': 'vet1',
        'name': 'AviCare Santé',
        'description': 'Boutique de matériel et médicaments vétérinaires pour vendeurs avicoles.',
        'location': 'Avenue Pasteur, Dakar',
        'active': True,
    },
]

SAMPLE_PRODUCTS_BY_CATEGORY = {
    'sante-avicole': [
        {
            'shop': 'Clinique Avicole du Lac',
            'title': 'Vaccin Aviaire Premium',
            'description': 'Vaccin à spectre large pour volailles, protection contre les maladies respiratoires.',
            'price': Decimal('32.50'),
            'quantity': 120,
        },
        {
            'shop': 'VétoVolaille',
            'title': 'Sérum réhydratant pour poules',
            'description': 'Solution de réhydratation pour volailles malades ou stressées.',
            'price': Decimal('18.00'),
            'quantity': 80,
        },
    ],
    'vaccins-serums': [
        {
            'shop': 'AviCare Santé',
            'title': 'Désinfectant pour cages',
            'description': 'Désinfectant concentré pour matériel et espaces avicoles.',
            'price': Decimal('14.90'),
            'quantity': 200,
        },
    ],
    'services-nettoyage': [
        {
            'shop': 'AviCare Santé',
            'title': 'Pack nettoyage de bureau',
            'description': 'Service de nettoyage professionnel pour entreprises et domiciles.',
            'price': Decimal('120.00'),
            'quantity': 50,
        },
    ],
    'maintenance-electrique': [
        {
            'shop': 'VétoVolaille',
            'title': 'Inspection électrique de site',
            'description': 'Contrôle et dépannage électrique pour bâtiments et ateliers.',
            'price': Decimal('95.00'),
            'quantity': 30,
        },
    ],
    'coiffure-beaute': [
        {
            'shop': 'Clinique Avicole du Lac',
            'title': 'Forfait soins esthétiques',
            'description': 'Service beauté premium avec soins capillaires et visage.',
            'price': Decimal('70.00'),
            'quantity': 25,
        },
    ],
    'transport-livraison': [
        {
            'shop': 'AviCare Santé',
            'title': 'Service de livraison express',
            'description': 'Livraison rapide de marchandises et documents en ville.',
            'price': Decimal('45.00'),
            'quantity': 60,
        },
    ],
}

SAMPLE_POSTS = [
    {
        'author': 'producer4',
        'content': 'Notre clinique avicole propose désormais un diagnostic gratuit pour toute nouvelle inscription.',
        'post_type': 'text',
        'category': 'sante-avicole',
        'hashtags': ['aviculture', 'santé'],
    },
    {
        'author': 'producer4',
        'content': 'Offre spéciale : service de nettoyage professionnel pour entreprises et maisons.',
        'post_type': 'image',
        'images': ['https://images.unsplash.com/photo-1581578731548-c64695cc6952?auto=format&fit=crop&w=900&q=80'],
        'category': 'services-nettoyage',
        'product': 'Pack nettoyage de bureau',
    },
    {
        'author': 'producer5',
        'content': 'Maintenance électrique rapide, fiable et disponible sur toute la région.',
        'post_type': 'image',
        'images': ['https://images.unsplash.com/photo-1518770660439-4636190af475?auto=format&fit=crop&w=900&q=80'],
        'category': 'maintenance-electrique',
        'product': 'Inspection électrique de site',
    },
    {
        'author': 'vet1',
        'content': 'Nouvelle offre beauté et coiffure pour les professionnels en ville.',
        'post_type': 'image',
        'images': ['https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=900&q=80'],
        'category': 'coiffure-beaute',
        'product': 'Forfait soins esthétiques',
    },
    {
        'author': 'buyer2',
        'content': 'Livraison express disponible aujourd’hui pour les petites et grandes commandes.',
        'post_type': 'image',
        'images': ['https://images.unsplash.com/photo-1517048676732-d65bc937f952?auto=format&fit=crop&w=900&q=80'],
        'category': 'transport-livraison',
        'product': 'Service de livraison express',
    },
    {
        'author': 'producer5',
        'content': 'Produit du jour : sérum réhydratant pour volailles. Livraison disponible sous 24h.',
        'post_type': 'image',
        'images': ['https://images.unsplash.com/photo-1517423440428-a5a00ad493e8?auto=format&fit=crop&w=900&q=80'],
        'category': 'vaccins-serums',
        'product': 'Sérum réhydratant pour poules',
    },
    {
        'author': 'vet1',
        'content': 'Visiteurs, découvrez nos conseils de prévention pour la grippe aviaire de cette saison.',
        'post_type': 'text',
        'category': 'sante-avicole',
        'hashtags': ['prévention', 'grippeaviaire'],
    },
    {
        'author': 'buyer2',
        'content': 'J’ai reçu mes produits rapidement, qualité exceptionnelle et service très pro!',
        'post_type': 'text',
        'category': 'sante-avicole',
    },
    {
        'author': 'buyer3',
        'content': 'Je recommande la boutique VétoVolaille pour leur service client et leurs conseils.',
        'post_type': 'text',
        'category': 'sante-avicole',
    },
    {
        'author': 'buyer4',
        'content': 'Merci à AviCare Santé pour leur disponibilité ce week-end.',
        'post_type': 'text',
        'category': 'sante-avicole',
    },
    {
        'author': 'producer4',
        'content': 'Nouveau service : consultation mobile sur site pour élevages de moins de 1000 poules.',
        'post_type': 'text',
        'category': 'sante-avicole',
    },
    {
        'author': 'producer5',
        'content': 'Nous livrons désormais dans 3 nouvelles zones autour de Dakar.',
        'post_type': 'text',
        'category': 'sante-avicole',
    },
    {
        'author': 'vet1',
        'content': 'Avez-vous déjà testé notre désinfectant pour cages? Il augmente la hygiène des élevages.',
        'post_type': 'text',
        'category': 'vaccins-serums',
    },
    {
        'author': 'buyer2',
        'content': 'Premier achat chez Clinique Avicole du Lac réussi, je recommande leur produit premium.',
        'post_type': 'text',
        'category': 'sante-avicole',
    },
    {
        'author': 'buyer3',
        'content': 'Les délais de livraison ont été respectés à la lettre.',
        'post_type': 'text',
        'category': 'sante-avicole',
    },
    {
        'author': 'buyer4',
        'content': 'Je cherche un fournisseur pour des vaccins de volaille en gros, contactez-moi.',
        'post_type': 'text',
        'category': 'sante-avicole',
    },
    {
        'author': 'producer4',
        'content': 'Exemple — en agriculture, la rotation des cultures et la protection des sols contribuent à préserver les récoltes.',
        'post_type': 'text',
        'category': 'agriculture-durable',
        'hashtags': ['exemple', 'agriculture', 'sols'],
    },
    {
        'author': 'producer5',
        'content': 'Exemple — atelier d’initiation au numérique : apprendre à rechercher une information et à protéger ses comptes en ligne.',
        'post_type': 'text',
        'category': 'education-numerique',
        'hashtags': ['exemple', 'education', 'numerique'],
    },
    {
        'author': 'buyer2',
        'content': 'Exemple — une idée de service numérique pour faciliter la prise de rendez-vous avec les artisans locaux.',
        'post_type': 'text',
        'category': 'innovation-technologique',
        'hashtags': ['exemple', 'innovation', 'services'],
    },
    {
        'author': 'buyer3',
        'content': 'Exemple — présentation d’un objet fabriqué localement et des étapes de son savoir-faire.',
        'post_type': 'image',
        'images': ['https://images.unsplash.com/photo-1452860606245-08befc0ff44b?auto=format&fit=crop&w=900&q=80'],
        'category': 'artisanat-local',
        'hashtags': ['exemple', 'artisanat', 'local'],
    },
    {
        'author': 'buyer4',
        'content': 'Exemple — des gestes simples comme le tri et la réduction des déchets participent à la protection de l’environnement.',
        'post_type': 'image',
        'images': ['https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=900&q=80'],
        'category': 'environnement',
        'hashtags': ['exemple', 'environnement'],
    },
    {
        'author': 'producer4',
        'content': 'Exemple vidéo — une courte séquence de fleurs pour illustrer un projet de jardinage et de biodiversité.',
        'post_type': 'video',
        'video': 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4',
        'category': 'environnement',
        'hashtags': ['exemple', 'jardinage', 'biodiversite'],
    },
]

SAMPLE_NOTIFICATIONS = [
    {
        'username': 'buyer2',
        'title': 'Nouvelle offre de santé avicole',
        'message': 'Découvrez les vaccins et traitements disponibles pour vos volailles.',
        'type': 'info',
        'data': {'category': 'vaccins-serums'},
    },
    {
        'username': 'producer4',
        'title': 'Demande de service',
        'message': 'Un buyer a demandé un traitement vétérinaire pour sa production.',
        'type': 'message',
        'data': {'room': 'vet-chat-buyer2'},
    },
    {
        'username': 'producer5',
        'title': 'Nouvelle commande en attente',
        'message': 'Un acheteur souhaite acheter un traitement vétérinaire.',
        'type': 'order',
        'data': {'status': 'pending'},
    },
]

SAMPLE_STORIES = [
    {
        'author': 'producer4',
        'story_type': 'image',
        'content': 'Diagnostic avicole gratuit aujourd’hui',
        'image': 'https://images.unsplash.com/photo-1518843875459-f738682238a6?auto=format&fit=crop&w=900&q=80',
        'background_color': '#1f3c88',
        'text_color': '#ffffff',
        'font_size': 24,
    },
    {
        'author': 'producer5',
        'story_type': 'text',
        'content': 'Offre spéciale sur les services de maintenance électrique',
        'background_color': '#f59e0b',
        'text_color': '#111827',
        'font_size': 26,
    },
    {
        'author': 'vet1',
        'story_type': 'image',
        'content': 'Visite vétérinaire sur site disponible ce soir',
        'image': 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=900&q=80',
        'background_color': '#0f766e',
        'text_color': '#ffffff',
        'font_size': 24,
    },
]


def _create_user(user_data):
    user, created = User.objects.get_or_create(
        username=user_data['username'],
        defaults={
            'first_name': user_data['first_name'],
            'last_name': user_data['last_name'],
            'email': user_data['email'],
            'is_staff': user_data['is_staff'],
            'is_superuser': user_data['is_superuser'],
            'is_active': True,
        },
    )
    if created:
        user.set_password(user_data['password'])
        user.save(update_fields=['password'])
    profile_defaults = {
        'role': user_data['role'],
        'phone': user_data['phone'],
        'address': user_data['address'],
        'city': user_data['city'],
        'country': user_data['country'],
        'verified': user_data['verified'],
    }
    UserProfile.objects.get_or_create(user=user, defaults=profile_defaults)
    return user, created


def _get_or_update(model, defaults=None, **filters):
    defaults = defaults or {}
    obj, created = model.objects.get_or_create(**filters, defaults=defaults)
    if not created:
        changed = False
        for key, value in defaults.items():
            if getattr(obj, key) != value:
                setattr(obj, key, value)
                changed = True
        if changed:
            obj.save()
    return obj, created


def load_sample_data():
    created = {
        'users': 0,
        'profiles': 0,
        'categories': 0,
        'shops': 0,
        'products': 0,
        'posts': 0,
        'stories': 0,
        'messages': 0,
        'notifications': 0,
    }

    with transaction.atomic():
        users = {}
        for user_data in SAMPLE_USERS:
            user, user_created = _create_user(user_data)
            users[user_data['username']] = user
            if user_created:
                created['users'] += 1

            profile = UserProfile.objects.filter(user=user).first()
            if profile and profile.created_at == profile.updated_at:
                created['profiles'] += int(user_created)

        categories = {}
        for category_data in SAMPLE_CATEGORIES:
            category, category_created = _get_or_update(
                Category,
                slug=category_data['slug'],
                defaults={
                    'name': category_data['name'],
                    'sector': category_data.get('sector', 'other'),
                    'category_type': category_data.get('category_type', 'product'),
                },
            )
            categories[category_data['slug']] = category
            if category_created:
                created['categories'] += 1

        shops = {}
        for shop_data in SAMPLE_SHOPS:
            owner = users[shop_data['owner']]
            shop, shop_created = _get_or_update(
                Shop,
                owner=owner,
                name=shop_data['name'],
                defaults={
                    'description': shop_data['description'],
                    'location': shop_data['location'],
                    'active': shop_data['active'],
                },
            )
            shops[shop_data['name']] = shop
            if shop_created:
                created['shops'] += 1

        products = {}
        for category_slug, products_data in SAMPLE_PRODUCTS_BY_CATEGORY.items():
            category = categories.get(category_slug)
            if not category:
                continue
            for product_data in products_data:
                shop = shops.get(product_data['shop'])
                if not shop:
                    continue
                product, product_created = _get_or_update(
                    Product,
                    shop=shop,
                    title=product_data['title'],
                    defaults={
                        'category': category,
                        'description': product_data['description'],
                        'price': product_data['price'],
                        'quantity': product_data['quantity'],
                        'is_active': True,
                    },
                )
                products[product_data['title']] = product
                if product_created:
                    created['products'] += 1

        for post_data in SAMPLE_POSTS:
            author = users.get(post_data['author'])
            if not author:
                continue
            category = categories.get(post_data.get('category')) if post_data.get('category') else None
            product = products.get(post_data.get('product')) if post_data.get('product') else None
            post, post_created = Post.objects.get_or_create(
                author=author,
                content=post_data['content'],
                defaults={
                    'post_type': post_data.get('post_type', 'text'),
                    'video': post_data.get('video'),
                    'category': category,
                    'privacy': 'public',
                    'location': post_data.get('location', ''),
                    'hashtags': post_data.get('hashtags', []),
                    'product': product,
                },
            )
            if post_created and post_data.get('images'):
                post.images = post_data['images']
                if len(post.images) == 1 and post.post_type == 'text':
                    post.post_type = 'image'
                elif len(post.images) > 1:
                    post.post_type = 'album'
                post.save(update_fields=['images', 'post_type'])
            if post_created:
                created.setdefault('posts', 0)
                created['posts'] += 1

        for story_data in SAMPLE_STORIES:
            author = users.get(story_data['author'])
            if not author:
                continue
            story, story_created = Story.objects.get_or_create(
                author=author,
                content=story_data['content'],
                defaults={
                    'story_type': story_data.get('story_type', 'text'),
                    'background_color': story_data.get('background_color', '#ffffff'),
                    'text_color': story_data.get('text_color', '#000000'),
                    'font_size': story_data.get('font_size', 24),
                    'is_active': True,
                },
            )
            if story_created:
                created['stories'] += 1

            if story_data.get('image'):
                story.image = story_data['image']
                story.save(update_fields=['image'])

        for notification_data in SAMPLE_NOTIFICATIONS:
            user = users[notification_data['username']]
            notification, notification_created = Notification.objects.get_or_create(
                user=user,
                title=notification_data['title'],
                message=notification_data['message'],
                defaults={
                    'type': notification_data['type'],
                    'is_read': False,
                    'data': notification_data['data'],
                },
            )
            if notification_created:
                created['notifications'] += 1

    return created


def create_sample_products_for_shop(shop):
    categories = {}
    for category_data in SAMPLE_CATEGORIES:
        category, _ = _get_or_update(
            Category,
            slug=category_data['slug'],
            defaults={'name': category_data['name']},
        )
        categories[category_data['slug']] = category

    created = 0
    for slug, products in SAMPLE_PRODUCTS_BY_CATEGORY.items():
        category = categories.get(slug)
        if not category:
            continue
        for product_data in products:
            title = product_data['title']
            product, product_created = _get_or_update(
                Product,
                shop=shop,
                title=title,
                defaults={
                    'category': category,
                    'description': product_data['description'],
                    'price': product_data['price'],
                    'quantity': product_data['quantity'],
                    'is_active': True,
                },
            )
            if product_created:
                created += 1

    return created
