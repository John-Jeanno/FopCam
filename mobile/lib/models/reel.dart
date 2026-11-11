import 'package:mobile/models/user.dart';

class Reel {
  final int id;
  final String title;
  final String description;
  final String? video;
  final String? thumbnail;
  final String? duration;
  final int viewsCount;
  final int likesCount;
  final int commentsCount;
  final int sharesCount;
  final String? audioTitle;
  final String? audioArtist;
  final bool isLiked;
  final bool isViewed;
  final DateTime createdAt;
  final User author;
  final String theme;
  final String effect;
  final String? sticker;

  Reel({
    required this.id,
    required this.title,
    required this.description,
    this.video,
    this.thumbnail,
    this.duration,
    this.viewsCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.audioTitle,
    this.audioArtist,
    this.isLiked = false,
    this.isViewed = false,
    required this.createdAt,
    required this.author,
    this.theme = 'Produits',
    this.effect = 'none',
    this.sticker,
  });

  factory Reel.fromJson(Map<String, dynamic> json) {
    return Reel(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['description'] ?? 'Clip',
      description: json['description'] ?? '',
      video: json['video']?.toString(),
      thumbnail: json['thumbnail']?.toString(),
      duration: json['duration']?.toString(),
      viewsCount: json['views_count'] ?? 0,
      likesCount: json['likes_count'] ?? 0,
      commentsCount: json['comments_count'] ?? 0,
      sharesCount: json['shares_count'] ?? 0,
      audioTitle: json['audio_title']?.toString(),
      audioArtist: json['audio_artist']?.toString(),
      isLiked: json['is_liked'] ?? false,
      isViewed: json['is_viewed'] ?? false,
      createdAt:
          DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
      author: User.fromJson(Map<String, dynamic>.from(json['author'] ?? {})),
      theme: json['theme']?.toString() ?? 'Produits',
      effect: json['effect']?.toString() ?? 'none',
      sticker: json['sticker']?.toString(),
    );
  }

  static List<Reel> mockReels() {
    return [
      Reel(
        id: 1,
        title: 'Découverte de produits locaux',
        description: 'Une visite rapide des meilleurs produits du marché.',
        thumbnail: null,
        duration: '15s',
        viewsCount: 124,
        likesCount: 32,
        commentsCount: 8,
        sharesCount: 3,
        audioTitle: 'Breeze',
        audioArtist: 'FopCam Beats',
        isLiked: false,
        isViewed: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        author: User(
          id: 1,
          username: 'market_local',
          email: 'market_local@example.com',
          role: 'producer',
        ),
        theme: 'Produits',
      ),
      Reel(
        id: 2,
        title: 'Recette rapide maison',
        description: 'Une recette locale de saison en moins de 30 secondes.',
        thumbnail: null,
        duration: '20s',
        viewsCount: 214,
        likesCount: 56,
        commentsCount: 17,
        sharesCount: 5,
        audioTitle: 'Fresh Bite',
        audioArtist: 'ChefLocal',
        isLiked: true,
        isViewed: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        author: User(
          id: 2,
          username: 'chef_fopcam',
          email: 'chef_fopcam@example.com',
          role: 'producer',
        ),
        theme: 'Recettes',
      ),
      Reel(
        id: 3,
        title: 'Tendance street food',
        description: 'Street food locale que tout le monde adore.',
        thumbnail: null,
        duration: '12s',
        viewsCount: 89,
        likesCount: 21,
        commentsCount: 4,
        sharesCount: 1,
        audioTitle: 'Street Beat',
        audioArtist: 'Food Traveler',
        isLiked: false,
        isViewed: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 7)),
        author: User(
          id: 3,
          username: 'food_traveler',
          email: 'food_traveler@example.com',
          role: 'buyer',
        ),
        theme: 'Tendances',
      ),
    ];
  }
}
