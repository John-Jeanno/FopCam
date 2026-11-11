from typing import Any

from django.contrib.auth.models import User
from django.db import transaction

from .models import Category, Post, UserProfile


DEMO_CATEGORIES: tuple[dict[str, str], ...] = (
    {
        'name': 'Agriculture durable',
        'slug': 'agriculture-durable',
        'sector': 'agriculture',
    },
    {
        'name': 'Éducation numérique',
        'slug': 'education-numerique',
        'sector': 'education',
    },
    {
        'name': 'Innovation technologique',
        'slug': 'innovation-technologique',
        'sector': 'technology',
    },
    {
        'name': 'Artisanat local',
        'slug': 'artisanat-local',
        'sector': 'manufacturing',
    },
    {
        'name': 'Environnement',
        'slug': 'environnement',
        'sector': 'other',
    },
    {
        'name': 'Santé et bien-être',
        'slug': 'sante-bien-etre',
        'sector': 'health',
    },
    {
        'name': 'Restauration',
        'slug': 'restauration',
        'sector': 'hospitality',
    },
    {
        'name': 'Transport et logistique',
        'slug': 'transport-logistique',
        'sector': 'transport',
    },
    {
        'name': 'Commerce local',
        'slug': 'commerce-local',
        'sector': 'retail',
    },
    {
        'name': 'Bâtiment et énergie',
        'slug': 'batiment-energie',
        'sector': 'real_estate',
    },
    {
        'name': 'Finance et entrepreneuriat',
        'slug': 'finance-entrepreneuriat',
        'sector': 'finance',
    },
    {
        'name': 'Beauté et bien-être',
        'slug': 'beaute-bien-etre',
        'sector': 'services',
    },
    {
        'name': 'Arts et création',
        'slug': 'arts-creation',
        'sector': 'entertainment',
    },
    {
        'name': 'Pêche et aquaculture',
        'slug': 'peche-aquaculture',
        'sector': 'agriculture',
    },
    {
        'name': 'Horticulture',
        'slug': 'horticulture',
        'sector': 'agriculture',
    },
    {
        'name': 'Services numériques',
        'slug': 'services-numeriques',
        'sector': 'technology',
    },
    {
        'name': 'Tourisme local',
        'slug': 'tourisme-local',
        'sector': 'hospitality',
    },
)

DEMO_POSTS: tuple[dict[str, Any], ...] = (
    {
        'content': (
            'Exemple — en agriculture, la rotation des cultures et la '
            'protection des sols contribuent à préserver les récoltes.'
        ),
        'post_type': 'text',
        'category': 'agriculture-durable',
        'hashtags': ['exemple', 'agriculture', 'sols'],
    },
    {
        'content': (
            'Exemple — atelier d’initiation au numérique : apprendre à '
            'rechercher une information et à protéger ses comptes en ligne.'
        ),
        'post_type': 'text',
        'category': 'education-numerique',
        'hashtags': ['exemple', 'education', 'numerique'],
    },
    {
        'content': (
            'Exemple — une idée de service numérique pour faciliter la '
            'prise de rendez-vous avec les artisans locaux.'
        ),
        'post_type': 'text',
        'category': 'innovation-technologique',
        'hashtags': ['exemple', 'innovation', 'services'],
    },
    {
        'content': (
            'Exemple — présentation d’un objet fabriqué localement et des '
            'étapes de son savoir-faire.'
        ),
        'post_type': 'image',
        'category': 'artisanat-local',
        'images': [
            'https://images.unsplash.com/photo-1452860606245-08befc0ff44b?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['exemple', 'artisanat', 'local'],
    },
    {
        'content': (
            'Exemple — des gestes simples comme le tri et la réduction des '
            'déchets participent à la protection de l’environnement.'
        ),
        'post_type': 'image',
        'category': 'environnement',
        'images': [
            'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['exemple', 'environnement'],
    },
    {
        'content': (
            'Exemple vidéo — une courte séquence de fleurs pour illustrer '
            'un projet de jardinage et de biodiversité.'
        ),
        'post_type': 'video',
        'category': 'environnement',
        'video': (
            'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4'
        ),
        'hashtags': ['exemple', 'jardinage', 'biodiversite'],
    },
    {
        'content': (
            'Au champ, un sol couvert retient mieux l’humidité et protège les '
            'cultures pendant les journées chaudes.'
        ),
        'post_type': 'image',
        'category': 'agriculture-durable',
        'images': [
            'https://images.unsplash.com/photo-1500382017468-9049fed747ef?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['agriculture', 'sols', 'cultures'],
    },
    {
        'content': (
            'Atelier pratique : quelques outils numériques bien choisis '
            'peuvent rendre les cours plus interactifs.'
        ),
        'post_type': 'image',
        'category': 'education-numerique',
        'images': [
            'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['education', 'numerique', 'formation'],
    },
    {
        'content': (
            'Un bilan de santé régulier aide à détecter tôt les besoins et à '
            'choisir les bons gestes de prévention.'
        ),
        'post_type': 'image',
        'category': 'sante-bien-etre',
        'images': [
            'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['sante', 'prevention', 'bienetre'],
    },
    {
        'content': (
            'Une petite équipe teste une nouvelle interface avant son '
            'lancement : les retours des utilisateurs font la différence.'
        ),
        'post_type': 'image',
        'category': 'services-numeriques',
        'images': [
            'https://images.unsplash.com/photo-1519389950473-47ba0277781c?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['innovation', 'numerique', 'equipe'],
    },
    {
        'content': (
            'Le travail du bois demande de la précision à chaque étape, du '
            'choix de la matière aux finitions.'
        ),
        'post_type': 'image',
        'category': 'artisanat-local',
        'images': [
            'https://images.unsplash.com/photo-1504148455328-c376907d081c?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['artisanat', 'bois', 'savoirfaire'],
    },
    {
        'content': (
            'Un chantier bien préparé commence par des mesures précises et '
            'une coordination claire entre les métiers.'
        ),
        'post_type': 'image',
        'category': 'batiment-energie',
        'images': [
            'https://images.unsplash.com/photo-1511818966892-d7d671e672a2?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['construction', 'batiment', 'metiers'],
    },
    {
        'content': (
            'En cuisine, les produits de saison donnent de belles idées de '
            'menus simples et généreux.'
        ),
        'post_type': 'image',
        'category': 'restauration',
        'images': [
            'https://images.unsplash.com/photo-1556911220-e15b29be8c8f?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['cuisine', 'restauration', 'saison'],
    },
    {
        'content': (
            'Pour les livraisons en ville, regrouper les trajets permet de '
            'gagner du temps et de réduire les déplacements inutiles.'
        ),
        'post_type': 'image',
        'category': 'transport-logistique',
        'images': [
            'https://images.unsplash.com/photo-1526367790999-0150786686a2?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['transport', 'logistique', 'livraison'],
    },
    {
        'content': (
            'Une vitrine claire et des conseils utiles aident les clients à '
            'trouver rapidement ce qu’ils recherchent.'
        ),
        'post_type': 'image',
        'category': 'commerce-local',
        'images': [
            'https://images.unsplash.com/photo-1441986300917-64674bd600d8?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['commerce', 'vitrine', 'proximite'],
    },
    {
        'content': (
            'L’énergie solaire peut compléter les besoins d’un atelier ou '
            'd’une petite exploitation, selon son installation.'
        ),
        'post_type': 'image',
        'category': 'environnement',
        'images': [
            'https://images.unsplash.com/photo-1509391366360-2e959784a276?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['energie', 'solaire', 'environnement'],
    },
    {
        'content': (
            'Un budget simple, mis à jour régulièrement, aide à suivre les '
            'dépenses et à préparer les prochains investissements.'
        ),
        'post_type': 'image',
        'category': 'finance-entrepreneuriat',
        'images': [
            'https://images.unsplash.com/photo-1554224155-6726b3ff858f?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['entrepreneuriat', 'gestion', 'budget'],
    },
    {
        'content': (
            'Une routine de soin adaptée commence par des gestes réguliers '
            'et des produits choisis selon ses besoins.'
        ),
        'post_type': 'image',
        'category': 'beaute-bien-etre',
        'images': [
            'https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['beaute', 'bienetre', 'conseils'],
    },
    {
        'content': (
            'Dans un atelier créatif, les idées prennent forme en combinant '
            'matières, couleurs et savoir-faire.'
        ),
        'post_type': 'image',
        'category': 'arts-creation',
        'images': [
            'https://images.unsplash.com/photo-1460661419201-fd4cecdf8a8b?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['creation', 'artisanat', 'culture'],
    },
    {
        'content': (
            'La lumière naturelle et un cadrage soigné peuvent raconter une '
            'histoire sans matériel compliqué.'
        ),
        'post_type': 'image',
        'category': 'arts-creation',
        'images': [
            'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['photographie', 'creation', 'image'],
    },
    {
        'content': (
            'La fraîcheur et le respect de la chaîne du froid sont essentiels '
            'pour valoriser les produits de la pêche.'
        ),
        'post_type': 'image',
        'category': 'peche-aquaculture',
        'images': [
            'https://images.unsplash.com/photo-1510130387422-82bed34b37e9?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['peche', 'aquaculture', 'qualite'],
    },
    {
        'content': (
            'Un bon café, un accueil chaleureux et un espace agréable : les '
            'petites attentions comptent dans un commerce de quartier.'
        ),
        'post_type': 'image',
        'category': 'restauration',
        'images': [
            'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['cafe', 'restauration', 'commerce'],
    },
    {
        'content': (
            'Un jardin bien entretenu commence par le choix des plantes et '
            'un arrosage adapté à la météo.'
        ),
        'post_type': 'image',
        'category': 'horticulture',
        'images': [
            'https://images.unsplash.com/photo-1416879595882-3373a0480b5b?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['jardin', 'horticulture', 'biodiversite'],
    },
    {
        'content': (
            'Une page web rapide, lisible sur mobile et facile à parcourir '
            'améliore l’expérience de vos clients.'
        ),
        'post_type': 'image',
        'category': 'services-numeriques',
        'images': [
            'https://images.unsplash.com/photo-1516321318423-f06f85e504b3?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['web', 'numerique', 'entreprise'],
    },
    {
        'content': (
            'Un suivi clair des colis et des stocks simplifie le travail '
            'des équipes de livraison.'
        ),
        'post_type': 'image',
        'category': 'transport-logistique',
        'images': [
            'https://images.unsplash.com/photo-1586528116311-ad8dd3c8310d?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['logistique', 'livraison', 'organisation'],
    },
    {
        'content': (
            'Échanger entre professionnels permet de partager des pratiques '
            'et de faire émerger de nouvelles collaborations.'
        ),
        'post_type': 'image',
        'category': 'finance-entrepreneuriat',
        'images': [
            'https://images.unsplash.com/photo-1521737711867-e3b97375f902?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['reseau', 'entrepreneuriat', 'collaboration'],
    },
    {
        'content': (
            'Apprendre ensemble encourage la curiosité et donne confiance '
            'pour essayer de nouvelles méthodes.'
        ),
        'post_type': 'image',
        'category': 'education-numerique',
        'images': [
            'https://images.unsplash.com/photo-1517486808906-6ca8b3f04846?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['apprentissage', 'education', 'partage'],
    },
    {
        'content': (
            'Les fruits et légumes locaux inspirent des recettes colorées '
            'et mettent en valeur les récoltes de saison.'
        ),
        'post_type': 'image',
        'category': 'agriculture-durable',
        'images': [
            'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['marche', 'produitslocaux', 'saison'],
    },
    {
        'content': (
            'Avant une réparation, un diagnostic précis aide à identifier '
            'la pièce nécessaire et à éviter les remplacements inutiles.'
        ),
        'post_type': 'image',
        'category': 'artisanat-local',
        'images': [
            'https://images.unsplash.com/photo-1486262715619-67b85e0b08d3?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['reparation', 'mecanique', 'savoirfaire'],
    },
    {
        'content': (
            'Les solutions renouvelables se développent : bien dimensionner '
            'son installation reste la première étape.'
        ),
        'post_type': 'image',
        'category': 'environnement',
        'images': [
            'https://images.unsplash.com/photo-1473341304170-971dccb5ac1e?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['energie', 'transition', 'durable'],
    },
    {
        'content': (
            'À découvrir : les itinéraires de proximité permettent de mieux '
            'connaître le patrimoine et les initiatives locales.'
        ),
        'post_type': 'text',
        'category': 'tourisme-local',
        'hashtags': ['tourisme', 'decouverte', 'local'],
    },
    {
        'content': (
            'Pensez à sauvegarder vos documents importants et à activer une '
            'méthode de récupération pour vos comptes professionnels.'
        ),
        'post_type': 'text',
        'category': 'services-numeriques',
        'hashtags': ['securite', 'numerique', 'conseils'],
    },
    {
        'content': (
            'La qualité d’un service se construit aussi avec l’écoute, des '
            'délais annoncés clairement et un suivi après intervention.'
        ),
        'post_type': 'text',
        'category': 'sante-bien-etre',
        'hashtags': ['service', 'confiance', 'professionnels'],
    },
    {
        'content': (
            'Pour mieux préserver les ressources, commencez par mesurer '
            'votre consommation et repérez les économies possibles.'
        ),
        'post_type': 'text',
        'category': 'batiment-energie',
        'hashtags': ['energie', 'conseils', 'durable'],
    },
    {
        'content': (
            'Une rencontre professionnelle est l’occasion de présenter son '
            'activité et de créer de nouveaux partenariats.'
        ),
        'post_type': 'image',
        'category': 'finance-entrepreneuriat',
        'images': [
            'https://images.unsplash.com/photo-1531058020387-3be344556be6?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['rencontre', 'reseau', 'professionnels'],
    },
    {
        'content': (
            'Un espace accueillant et une carte lisible donnent envie de '
            'prendre le temps de découvrir les spécialités du lieu.'
        ),
        'post_type': 'image',
        'category': 'restauration',
        'images': [
            'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=900&q=80',
        ],
        'hashtags': ['restauration', 'accueil', 'commerce'],
    },
)


@transaction.atomic
def load_demo_feed() -> dict[str, int | bool]:
    author, author_created = User.objects.get_or_create(
        username='fopcam-demo',
        defaults={
            'first_name': 'FopCam',
            'last_name': 'Exemples',
            'is_active': False,
        },
    )
    if author_created:
        author.set_unusable_password()
        author.save(update_fields=['password'])

    UserProfile.objects.get_or_create(
        user=author,
        defaults={
            'role': 'particular',
            'is_active': False,
            'bio': 'Compte désactivé pour les publications de démonstration.',
        },
    )

    categories: dict[str, Category] = {}
    categories_created = 0
    for category_data in DEMO_CATEGORIES:
        category, created = Category.objects.get_or_create(
            slug=category_data['slug'],
            defaults={
                'name': category_data['name'],
                'sector': category_data['sector'],
                'category_type': 'professional',
            },
        )
        categories[category_data['slug']] = category
        categories_created += int(created)

    posts_created = 0
    for post_data in DEMO_POSTS:
        defaults: dict[str, Any] = {
            'post_type': post_data['post_type'],
            'category': categories[post_data['category']],
            'privacy': 'public',
            'hashtags': post_data['hashtags'],
            'is_active': True,
        }
        if 'images' in post_data:
            defaults['images'] = post_data['images']
        if 'video' in post_data:
            defaults['video'] = post_data['video']

        _, created = Post.objects.get_or_create(
            author=author,
            content=post_data['content'],
            defaults=defaults,
        )
        posts_created += int(created)

    return {
        'author_created': author_created,
        'categories_created': categories_created,
        'posts_created': posts_created,
    }
