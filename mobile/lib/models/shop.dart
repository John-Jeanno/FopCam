import 'package:mobile/models/user.dart';

class Shop {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? phone;
  final List<String> phoneNumbers;
  final String? email;
  final String? website;
  final String? logo;
  final String? banner;
  final String backgroundColor;
  final String textColor;
  final String accentColor;
  final double fontSize;
  final bool active;
  final User? owner;
  final int likeCount;
  final int voteCount;
  final int shareCount;
  final bool isLiked;
  final bool isVoted;
  final double averageRating;
  final int ratingCount;
  final int? userRating;

  Shop({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.location,
    this.latitude,
    this.longitude,
    this.phone,
    this.phoneNumbers = const [],
    this.email,
    this.website,
    this.logo,
    this.banner,
    this.backgroundColor = '#0F172A',
    this.textColor = '#F8FAFC',
    this.accentColor = '#7C3AED',
    this.fontSize = 16,
    required this.active,
    this.owner,
    this.likeCount = 0,
    this.voteCount = 0,
    this.shareCount = 0,
    this.isLiked = false,
    this.isVoted = false,
    this.averageRating = 0,
    this.ratingCount = 0,
    this.userRating,
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    final ownerJson = json['owner'];
    return Shop(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description']?.toString(),
      location: json['location']?.toString(),
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      phone: json['phone']?.toString(),
      phoneNumbers: [
        if (json['phone_numbers'] is List)
          ...(json['phone_numbers'] as List)
              .whereType<String>()
              .map((number) => number.trim())
              .where((number) => number.isNotEmpty),
        if ((json['phone_numbers'] is! List ||
                (json['phone_numbers'] as List).isEmpty) &&
            json['phone'] is String &&
            (json['phone'] as String).trim().isNotEmpty)
          (json['phone'] as String).trim(),
      ],
      email: json['email']?.toString(),
      website: json['website']?.toString(),
      logo: json['logo']?.toString(),
      banner: json['banner']?.toString(),
      backgroundColor: json['background_color'] as String? ?? '#0F172A',
      textColor: json['text_color'] as String? ?? '#F8FAFC',
      accentColor: json['accent_color'] as String? ?? '#7C3AED',
      fontSize: double.tryParse(json['font_size']?.toString() ?? '') ?? 16,
      active: json['active'] ?? false,
      owner: ownerJson != null
          ? User.fromJson(Map<String, dynamic>.from(ownerJson))
          : null,
      likeCount: _parseCount(json['like_count']),
      voteCount: _parseCount(json['vote_count']),
      shareCount: _parseCount(json['share_count']),
      isLiked: json['is_liked'] == true,
      isVoted: json['is_voted'] == true,
      averageRating:
          double.tryParse(json['average_rating']?.toString() ?? '') ?? 0,
      ratingCount: _parseCount(json['rating_count']),
      userRating: json['user_rating'] == null
          ? null
          : _parseCount(json['user_rating']),
    );
  }

  static int _parseCount(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
