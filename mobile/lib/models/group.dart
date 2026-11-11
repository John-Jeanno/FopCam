import 'package:mobile/models/user.dart';
import 'package:mobile/utils/media_url_helper.dart';

class Group {
  final int id;
  final String name;
  final String description;
  final String slug;
  final String groupType;
  final String? coverImage;
  final String? avatar;
  final int memberCount;
  final bool isMember;
  final String? memberStatus;
  final bool isActive;
  final String? rules;
  final User creator;

  Group({
    required this.id,
    required this.name,
    required this.description,
    required this.slug,
    required this.groupType,
    this.coverImage,
    this.avatar,
    required this.memberCount,
    required this.isMember,
    this.memberStatus,
    required this.isActive,
    this.rules,
    required this.creator,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      slug: json['slug'] ?? '',
      groupType: json['group_type'] ?? '',
      coverImage: normalizeMediaUrl(json['cover_image']?.toString()),
      avatar: normalizeMediaUrl(json['avatar']?.toString()),
      memberCount: json['member_count'] ?? 0,
      isMember: json['is_member'] ?? false,
      memberStatus: json['member_status']?.toString(),
      isActive: json['is_active'] ?? true,
      rules: json['rules']?.toString(),
      creator: User.fromJson(Map<String, dynamic>.from(json['creator'] ?? {})),
    );
  }

  Group copyWith({
    int? id,
    String? name,
    String? description,
    String? slug,
    String? groupType,
    String? coverImage,
    String? avatar,
    int? memberCount,
    bool? isMember,
    String? memberStatus,
    bool? isActive,
    String? rules,
    User? creator,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      slug: slug ?? this.slug,
      groupType: groupType ?? this.groupType,
      coverImage: coverImage ?? this.coverImage,
      avatar: avatar ?? this.avatar,
      memberCount: memberCount ?? this.memberCount,
      isMember: isMember ?? this.isMember,
      memberStatus: memberStatus ?? this.memberStatus,
      isActive: isActive ?? this.isActive,
      rules: rules ?? this.rules,
      creator: creator ?? this.creator,
    );
  }
}
