class GameLiveDuel {
  const GameLiveDuel({
    required this.id,
    required this.challengerName,
    required this.challengedName,
    required this.challengerScore,
    required this.challengedScore,
    required this.roundNumber,
    required this.hasLiveState,
    this.activePlayerName,
    this.state,
  });

  final int id;
  final String challengerName;
  final String challengedName;
  final int challengerScore;
  final int challengedScore;
  final int roundNumber;
  final bool hasLiveState;
  final String? activePlayerName;
  final Map<String, dynamic>? state;

  factory GameLiveDuel.fromJson(Map<String, dynamic> json) => GameLiveDuel(
    id: json['id'] as int,
    challengerName: json['challenger_name'] as String? ?? '',
    challengedName: json['challenged_name'] as String? ?? '',
    challengerScore: json['challenger_score'] as int? ?? 0,
    challengedScore: json['challenged_score'] as int? ?? 0,
    roundNumber: json['round_number'] as int? ?? 1,
    hasLiveState: json['has_live_state'] as bool? ?? json['state'] != null,
    activePlayerName: json['active_player_name'] as String?,
    state: json['state'] is Map
        ? Map<String, dynamic>.from(json['state'] as Map)
        : null,
  );
}
