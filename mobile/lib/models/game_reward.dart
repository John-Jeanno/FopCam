class GameReward {
  final int level;
  final int score;
  final int points;
  final String title;
  final DateTime earnedAt;
  final bool alreadyClaimed;

  const GameReward({
    required this.level,
    required this.score,
    required this.points,
    required this.title,
    required this.earnedAt,
    required this.alreadyClaimed,
  });

  factory GameReward.fromJson(Map<String, dynamic> json) {
    return GameReward(
      level: json['level'] as int,
      score: json['score'] as int,
      points: json['points'] as int,
      title: json['title'] as String,
      earnedAt: DateTime.parse(json['earned_at'] as String),
      alreadyClaimed: json['already_claimed'] as bool,
    );
  }
}
