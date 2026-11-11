import 'package:mobile/models/user.dart';
import 'package:mobile/utils/media_url_helper.dart';

class Story {
  final int id;
  final String storyType;
  final String? content;
  final String? image;
  final String? video;
  final String? backgroundColor;
  final String? textColor;
  final double fontSize;
  final DateTime? expiresAt;
  final bool isViewed;
  final bool isExpired;
  final bool isDemo;
  final bool isPending;
  final bool isLiked;
  final int viewsCount;
  final int likesCount;
  final DateTime createdAt;
  final User author;

  Story({
    required this.id,
    required this.storyType,
    this.content,
    this.image,
    this.video,
    this.backgroundColor,
    this.textColor,
    required this.fontSize,
    this.expiresAt,
    required this.isViewed,
    required this.isExpired,
    this.isDemo = false,
    this.isPending = false,
    this.isLiked = false,
    this.viewsCount = 0,
    this.likesCount = 0,
    required this.createdAt,
    required this.author,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    final expiresAt = DateTime.tryParse(json['expires_at']?.toString() ?? '');
    return Story(
      id: json['id'] ?? 0,
      storyType: json['story_type'] ?? 'text',
      content: json['content']?.toString(),
      image: normalizeMediaUrl(json['image']?.toString()),
      video: normalizeMediaUrl(json['video']?.toString()),
      backgroundColor: json['background_color']?.toString(),
      textColor: json['text_color']?.toString(),
      fontSize: (json['font_size'] is num)
          ? (json['font_size'] as num).toDouble()
          : double.tryParse(json['font_size']?.toString() ?? '') ?? 14.0,
      expiresAt: expiresAt,
      isViewed: json['is_viewed'] ?? false,
      isExpired:
          json['is_expired'] == true ||
          (expiresAt != null && !expiresAt.isAfter(DateTime.now())),
      isDemo: json['is_demo'] == true,
      isPending: json['is_pending'] == true,
      isLiked: json['is_liked'] ?? false,
      viewsCount: json['views_count'] ?? 0,
      likesCount: json['likes_count'] ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      author: User.fromJson(Map<String, dynamic>.from(json['author'] ?? {})),
    );
  }

  static List<Story> mockStories() => exampleStories();

  static List<Story> exampleStories() {
    const examples = [
      (
        'Fruits et légumes',
        'Exemple à adapter : mangues, tomates et légumes frais disponibles. Contactez le vendeur pour le prix.',
        '#14532D',
      ),
      (
        'Céréales et légumineuses',
        'Exemple à adapter : mil, riz, maïs et niébé en stock. Formats et prix à préciser.',
        '#854D0E',
      ),
      (
        'Volaille et œufs',
        'Exemple à adapter : poulets élevés localement et œufs frais. Disponibilité à confirmer.',
        '#9A3412',
      ),
      (
        'Poissons et fruits de mer',
        'Exemple à adapter : arrivage du jour, poissons frais et produits de mer.',
        '#075985',
      ),
      (
        'Lait et produits laitiers',
        'Exemple à adapter : lait, yaourts et fromages locaux. Conditions de conservation à préciser.',
        '#1E40AF',
      ),
      (
        'Viande',
        'Exemple à adapter : viande disponible sur commande. Découpe, origine et prix à préciser.',
        '#991B1B',
      ),
      (
        'Produits transformés',
        'Exemple à adapter : jus, confitures, céréales transformées et spécialités locales.',
        '#7E22CE',
      ),
      (
        'Vêtements',
        'Exemple à adapter : vêtements pour adultes et enfants. Tailles et prix à préciser.',
        '#9D174D',
      ),
      (
        'Chaussures et accessoires',
        'Exemple à adapter : chaussures, sacs et accessoires disponibles. Modèles à préciser.',
        '#3730A3',
      ),
      (
        'Beauté et hygiène',
        'Exemple à adapter : produits de beauté et d’hygiène. Marques et composition à préciser.',
        '#BE185D',
      ),
      (
        'Téléphones et électronique',
        'Exemple à adapter : téléphones et accessoires. État, garantie et prix à préciser.',
        '#1D4ED8',
      ),
      (
        'Maison et mobilier',
        'Exemple à adapter : mobilier, décoration et articles pour la maison.',
        '#57534E',
      ),
      (
        'Artisanat local',
        'Exemple à adapter : objets artisanaux fabriqués localement. Commandes personnalisées possibles.',
        '#9A3412',
      ),
      (
        'Matériel agricole',
        'Exemple à adapter : semences, outils et équipements agricoles. Disponibilité à préciser.',
        '#3F6212',
      ),
      (
        'Animaux et élevage',
        'Exemple à adapter : animaux d’élevage disponibles. Race, âge et conditions à préciser.',
        '#713F12',
      ),
      (
        'Coiffure et beauté',
        'Exemple à adapter : rendez-vous coiffure et soins esthétiques disponibles. Prestations, horaires et tarifs à préciser.',
        '#BE185D',
      ),
      (
        'Réparation et maintenance',
        'Exemple à adapter : dépannage et entretien à domicile ou en atelier. Équipements concernés et zone à préciser.',
        '#334155',
      ),
      (
        'Transport et livraison',
        'Exemple à adapter : courses et livraisons disponibles. Zone desservie, horaires et tarifs à préciser.',
        '#075985',
      ),
      (
        'Éducation et formation',
        'Exemple à adapter : cours particuliers et formations professionnelles. Matières, niveaux et modalités à préciser.',
        '#1D4ED8',
      ),
      (
        'Santé et bien-être',
        'Exemple à adapter : présentation d’un service de santé ou de bien-être. Spécialité, horaires et contact à préciser.',
        '#0F766E',
      ),
      (
        'Immobilier',
        'Exemple à adapter : annonce de location ou de vente. Localisation, caractéristiques et prix à préciser.',
        '#7C2D12',
      ),
      (
        'Hôtellerie et tourisme',
        'Exemple à adapter : hébergement ou activité touristique. Disponibilités, services et réservation à préciser.',
        '#0369A1',
      ),
      (
        'Construction et bâtiment',
        'Exemple à adapter : travaux de construction et de rénovation. Spécialités, zone d’intervention et devis à préciser.',
        '#854D0E',
      ),
      (
        'Services numériques',
        'Exemple à adapter : création de sites, assistance informatique ou conseil numérique. Prestations et contact à préciser.',
        '#4338CA',
      ),
      (
        'Événementiel',
        'Exemple à adapter : organisation ou location de matériel pour vos événements. Services, dates et tarifs à préciser.',
        '#7E22CE',
      ),
      (
        'Nettoyage et entretien',
        'Exemple à adapter : entretien de locaux, maisons ou bureaux. Fréquence, zone et devis à préciser.',
        '#047857',
      ),
      (
        'Services professionnels',
        'Exemple à adapter : conseil, comptabilité ou accompagnement professionnel. Domaine, modalités et contact à préciser.',
        '#1E3A8A',
      ),
      (
        'Commerce et distribution',
        'Exemple à adapter : arrivage ou offre commerciale de votre boutique. Produits, conditions et prix à préciser.',
        '#9A3412',
      ),
      (
        'Art et loisirs',
        'Exemple à adapter : cours, activités de loisirs ou prestations artistiques. Programme, lieu et réservation à préciser.',
        '#6B21A8',
      ),
    ];

    return [
      for (var index = 0; index < examples.length; index++)
        Story(
          id: -1000 - index,
          storyType: 'text',
          content: examples[index].$2,
          backgroundColor: examples[index].$3,
          textColor: '#FFFFFF',
          fontSize: 16,
          isViewed: false,
          isExpired: false,
          isDemo: true,
          createdAt: DateTime.now(),
          author: User(
            id: 0,
            username: 'Exemple • ${examples[index].$1}',
            email: '',
            role: 'producer',
          ),
        ),
    ];
  }
}
