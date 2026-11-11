import 'package:mobile/models/user.dart';
import 'package:mobile/utils/media_url_helper.dart';

class Post {
  final int id;
  String content;
  final String? image;
  final List<String>? images; // Multiple images for albums
  final String? video; // Video URL
  final String postType; // 'text', 'image', 'video', 'album', 'reel'
  final String? backgroundColor;
  final Map<String, dynamic>? trophyData;
  final User author;
  final String privacy; // 'public', 'friends', 'private'
  final String? location;
  bool isLiked;
  int likesCount;
  int commentsCount;
  int sharesCount;
  final DateTime createdAt;
  final List<String>? hashtags;
  bool isShared; // If this is a share/repost
  Post? sharedPost; // Original post if this is a share

  Post({
    required this.id,
    required this.content,
    this.image,
    this.images,
    this.video,
    this.postType = 'text',
    this.backgroundColor,
    this.trophyData,
    required this.author,
    this.privacy = 'public',
    this.location,
    this.isLiked = false,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    required this.createdAt,
    this.hashtags,
    this.isShared = false,
    this.sharedPost,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final authorData =
        json['author'] ?? json['user'] ?? json['owner'] ?? json['created_by'];
    final author = authorData is Map<String, dynamic>
        ? User.fromJson(authorData)
        : User.fromJson({'id': 0, 'username': 'unknown', 'email': ''});

    List<String>? images;
    if (json['images'] is List) {
      images = List<String>.from(json['images'] as List);
    }

    List<String>? hashtags;
    if (json['hashtags'] is List) {
      hashtags = List<String>.from(json['hashtags'] as List);
    }

    final normalizedImages = images
        ?.map((image) => normalizeMediaUrl(image) ?? image)
        .toList();

    return Post(
      id: json['id'] ?? 0,
      content: json['content'] ?? json['text'] ?? '',
      image: normalizeMediaUrl(
        json['image']?.toString() ?? json['media']?.toString(),
      ),
      images: normalizedImages,
      video: json['video'],
      postType: json['post_type'] ?? 'text',
      backgroundColor: json['background_color']?.toString(),
      trophyData: json['trophy_data'] is Map
          ? Map<String, dynamic>.from(json['trophy_data'] as Map)
          : null,
      author: author,
      privacy: json['privacy'] ?? 'public',
      location: json['location'],
      isLiked:
          json['is_liked'] == true ||
          (json['liked_by'] != null &&
              json['liked_by'] is bool &&
              json['liked_by']),
      likesCount: json['likes_count'] ?? json['likes'] ?? 0,
      commentsCount: json['comments_count'] ?? json['comments'] ?? 0,
      sharesCount: json['shares_count'] ?? json['shares'] ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at'] ?? json['created']) ??
          DateTime.now(),
      hashtags: hashtags,
      isShared: json['repost_of'] != null,
      sharedPost: json['repost_of'] != null
          ? Post.fromJson(json['repost_of'] as Map<String, dynamic>)
          : null,
    );
  }

  // Get time ago string
  String getTimeAgo() {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'il y a ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'il y a ${difference.inDays}j';
    } else {
      return createdAt.toString().split(' ')[0];
    }
  }

  static List<Post> mockPosts() {
    final producer = User(
      id: 21,
      username: 'mariame_ferme',
      email: 'mariame@example.com',
      firstName: 'Mariame',
      lastName: 'Diop',
      profileImage:
          'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=200&q=80',
      role: 'producer',
    );

    final buyer = User(
      id: 22,
      username: 'kader_local',
      email: 'kader@example.com',
      firstName: 'Kader',
      lastName: 'Sarr',
      profileImage:
          'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=200&q=80',
      role: 'buyer',
    );

    return [
      Post(
        id: 101,
        content:
            '🌿 Nouveau panier de légumes frais récoltés ce matin dans la région. Venez découvrir les saveurs du terroir !',
        image:
            'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=900&q=80',
        postType: 'image',
        author: producer,
        privacy: 'public',
        location: 'Dakar, Sénégal',
        likesCount: 124,
        commentsCount: 18,
        sharesCount: 7,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        hashtags: ['#fopcam', '#local', '#legumes'],
      ),
      Post(
        id: 102,
        content:
            '🧺 Deuxième lancement de la semaine : produits artisanaux et produits du marché à petit prix. À partager autour de vous.',
        images: [
          'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=900&q=80',
          'https://images.unsplash.com/photo-1502741338009-cac2772e18bc?auto=format&fit=crop&w=900&q=80',
        ],
        postType: 'album',
        author: buyer,
        privacy: 'public',
        location: 'Grand-Yoff',
        likesCount: 86,
        commentsCount: 11,
        sharesCount: 3,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        hashtags: ['#produits', '#artisanat', '#fopcam'],
      ),
      Post(
        id: 103,
        content:
            '✨ Le marché du quartier s’anime ce soir avec des saveurs locales, des produits frais et une vraie ambiance de partage.',
        image:
            'https://images.unsplash.com/photo-1482049016688-2d3e1b311543?auto=format&fit=crop&w=900&q=80',
        postType: 'image',
        author: producer,
        privacy: 'public',
        location: 'Mermoz',
        likesCount: 153,
        commentsCount: 24,
        sharesCount: 9,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        hashtags: ['#marché', '#fopcam', '#sénégal'],
      ),
      Post(
        id: 104,
        content:
            '💛 Offrez un peu de goût et de proximité grâce aux produits du terroir sélectionnés avec soin pour votre foyer.',
        image:
            'https://images.unsplash.com/photo-1498837167922-ddd27525d352?auto=format&fit=crop&w=900&q=80',
        postType: 'image',
        author: buyer,
        privacy: 'public',
        location: 'Yoff',
        likesCount: 97,
        commentsCount: 14,
        sharesCount: 5,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        hashtags: ['#offre', '#local', '#community'],
      ),
    ];
  }
}
