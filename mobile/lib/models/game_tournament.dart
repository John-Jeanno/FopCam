class GameTournament {
  const GameTournament({
    required this.id,
    required this.capacity,
    required this.status,
    required this.organizerId,
    required this.organizerName,
    required this.trophyTitle,
    required this.winnerId,
    required this.entries,
    required this.matches,
    required this.standings,
    required this.supportCounts,
    required this.supporters,
    required this.mySupportedUserId,
    required this.isChampionPro,
    required this.isOrganizer,
    required this.canJoin,
    required this.canStart,
  });

  final int id;
  final int capacity;
  final String status;
  final int organizerId;
  final String organizerName;
  final String trophyTitle;
  final int? winnerId;
  final List<Map<String, dynamic>> entries;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> standings;
  final Map<String, int> supportCounts;
  final Map<String, List<String>> supporters;
  final int? mySupportedUserId;
  final bool isChampionPro;
  final bool isOrganizer;
  final bool canJoin;
  final bool canStart;

  factory GameTournament.fromJson(Map<String, dynamic> json) {
    final counts = json['support_counts'] is Map
        ? Map<String, dynamic>.from(json['support_counts'] as Map)
        : <String, dynamic>{};
    final supporters = json['supporters'] is Map
        ? Map<String, dynamic>.from(json['supporters'] as Map)
        : <String, dynamic>{};
    return GameTournament(
      id: json['id'] as int,
      capacity: json['capacity'] as int? ?? 6,
      status: json['status'] as String? ?? 'registration',
      organizerId: json['organizer_id'] as int? ?? 0,
      organizerName: json['organizer_name'] as String? ?? 'Champion',
      trophyTitle: json['trophy_title'] as String? ?? '',
      winnerId: json['winner_id'] as int?,
      entries: _mapList(json['entries']),
      matches: _mapList(json['matches']),
      standings: _mapList(json['standings']),
      supportCounts: counts.map(
        (key, value) => MapEntry(key, (value as num).toInt()),
      ),
      supporters: supporters.map(
        (key, value) => MapEntry(
          key,
          value is List ? value.whereType<String>().toList() : const <String>[],
        ),
      ),
      mySupportedUserId: json['my_supported_user_id'] as int?,
      isChampionPro: json['is_champion_pro'] as bool? ?? false,
      isOrganizer: json['is_organizer'] as bool? ?? false,
      canJoin: json['can_join'] as bool? ?? false,
      canStart: json['can_start'] as bool? ?? false,
    );
  }

  static List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
