import 'package:mobile/utils/media_url_helper.dart';

class User {
  final int id;
  final String username;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? profileImage;
  final String? coverImage;
  final String? bio;
  final String? phone;
  final String phoneVisibility;
  final String profileVisibility;
  final String? city;
  final String? country;
  final String countryCode;
  final String preferredLanguage;
  final Map<String, String> notificationSounds;
  final List<Map<String, dynamic>> experienceAndJourney;
  final List<Map<String, dynamic>> educationAndTraining;
  final List<Map<String, dynamic>> skills;
  final List<Map<String, dynamic>> services;
  final String role;
  final bool isOnline;
  final String? connectionStatus;
  final int? friendRequestId;
  final String? friendRequestDirection;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.firstName,
    this.lastName,
    this.profileImage,
    this.coverImage,
    this.bio,
    this.phone,
    this.phoneVisibility = 'private',
    this.profileVisibility = 'public',
    this.city,
    this.country,
    this.countryCode = '',
    this.preferredLanguage = '',
    this.notificationSounds = const {},
    this.experienceAndJourney = const [],
    this.educationAndTraining = const [],
    this.skills = const [],
    this.services = const [],
    required this.role,
    this.isOnline = false,
    this.connectionStatus,
    this.friendRequestId,
    this.friendRequestDirection,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final userData = json['user'] is Map
        ? Map<String, dynamic>.from(json['user'] as Map)
        : json;
    final requestId = json['friend_request_id'];
    List<Map<String, dynamic>> parseItems(Object? value) {
      if (value is! List) return const [];
      return value
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    return User(
      id: userData['id'] ?? 0,
      username: userData['username'] ?? '',
      email: userData['email'] ?? '',
      firstName: userData['first_name'],
      lastName: userData['last_name'],
      profileImage: normalizeMediaUrl(json['profile_image']?.toString()),
      coverImage: normalizeMediaUrl(json['cover_image']?.toString()),
      bio: json['bio'],
      phone: json['phone'],
      phoneVisibility: json['phone_visibility']?.toString() ?? 'private',
      profileVisibility: json['profile_visibility']?.toString() ?? 'public',
      city: json['city'],
      country: json['country']?.toString(),
      countryCode: json['country_code']?.toString() ?? '',
      preferredLanguage: json['preferred_language']?.toString() ?? '',
      notificationSounds: json['notification_sounds'] is Map
          ? (json['notification_sounds'] as Map).map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const {},
      experienceAndJourney: parseItems(json['experience_and_journey']),
      educationAndTraining: parseItems(json['education_and_training']),
      skills: parseItems(json['skills']),
      services: parseItems(json['services']),
      role: json['role'] ?? 'buyer',
      isOnline: json['is_online'] == true,
      connectionStatus: json['connection_status']?.toString(),
      friendRequestId: requestId is int
          ? requestId
          : int.tryParse(requestId?.toString() ?? ''),
      friendRequestDirection: json['friend_request_direction']?.toString(),
    );
  }
}
