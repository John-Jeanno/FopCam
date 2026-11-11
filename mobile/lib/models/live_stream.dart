import 'package:mobile/models/user.dart';

class LiveStream {
  final String id;
  final String title;
  final User host;
  final int viewers;
  final bool isLive;
  final DateTime startedAt;
  final String category;

  LiveStream({
    required this.id,
    required this.title,
    required this.host,
    required this.viewers,
    this.isLive = true,
    required this.startedAt,
    this.category = 'Commerce',
  });

  factory LiveStream.fromJson(Map<String, dynamic> json) {
    return LiveStream(
      id: (json['room_name'] ?? json['id'] ?? '').toString(),
      title: json['title'] ?? 'Diffusion',
      host: User.fromJson(Map<String, dynamic>.from(json['host'] ?? {})),
      viewers: json['viewers'] ?? 0,
      isLive: json['is_live'] ?? true,
      startedAt:
          DateTime.tryParse(json['started_at']?.toString() ?? '') ??
          DateTime.now(),
      category: json['category']?.toString() ?? 'Commerce',
    );
  }
}
