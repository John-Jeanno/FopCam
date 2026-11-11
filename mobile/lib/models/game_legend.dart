enum GameLegendTier {
  legend,
  legendPlus,
  legendPro,
  champion,
  championLeague,
  championLeaguePro,
}

class GameLegend {
  final int id;
  final int rank;
  final String displayName;
  final String username;
  final String? avatarUrl;
  final int score;
  final String title;
  final String duelMedal;
  final List<String> duelMedals;

  const GameLegend({
    required this.id,
    required this.rank,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    required this.score,
    required this.title,
    required this.duelMedal,
    required this.duelMedals,
  });

  String get duelMedalLabel => switch (duelMedal) {
    'bronze' => 'bronze',
    'silver' => 'argent',
    'gold' => 'or',
    'cup' => 'Coupe',
    'cup_pro' => 'Coupe Pro',
    _ => '',
  };

  String get displayLabel => '$displayName (@$username)';

  bool hasSameDuelTierAs(GameLegend other) => duelMedal == other.duelMedal;

  int get duelTierRank => switch (duelMedal) {
    'bronze' => 1,
    'silver' => 2,
    'gold' => 3,
    'cup' => 4,
    'cup_pro' => 5,
    _ => 0,
  };

  bool canChallenge(GameLegend other) => duelTierRank >= other.duelTierRank;

  bool appearsInTier(GameLegendTier requestedTier) {
    if (requestedTier == GameLegendTier.champion) {
      return duelMedals.contains('gold');
    }
    if (requestedTier == GameLegendTier.championLeague) {
      return duelMedals.contains('cup');
    }
    if (requestedTier == GameLegendTier.championLeaguePro) {
      return duelMedals.contains('cup_pro');
    }
    return tier == requestedTier;
  }

  List<String> medalsForTier(GameLegendTier requestedTier) {
    if (requestedTier == GameLegendTier.champion) {
      return duelMedals
          .where(const {'bronze', 'silver', 'gold'}.contains)
          .toList(growable: false);
    }
    if (requestedTier == GameLegendTier.championLeague) {
      return duelMedals.where(const {'cup'}.contains).toList(growable: false);
    }
    if (requestedTier == GameLegendTier.championLeaguePro) {
      return duelMedals
          .where(const {'cup_pro'}.contains)
          .toList(growable: false);
    }
    return duelMedals;
  }

  GameLegendTier get tier => switch (duelMedal) {
    'bronze' => GameLegendTier.legendPlus,
    'silver' => GameLegendTier.legendPro,
    'gold' => GameLegendTier.champion,
    'cup' => GameLegendTier.championLeague,
    'cup_pro' => GameLegendTier.championLeaguePro,
    _ => GameLegendTier.legend,
  };

  String get tierLabel => switch (tier) {
    GameLegendTier.legend => 'Légende',
    GameLegendTier.legendPlus => 'Légende+',
    GameLegendTier.legendPro => 'Légende Pro',
    GameLegendTier.champion => 'Champion FopCam',
    GameLegendTier.championLeague => 'Champion 1ère Ligue',
    GameLegendTier.championLeaguePro => 'Champion League Pro',
  };

  String get tierRequirement => switch (tier) {
    GameLegendTier.legend => 'Niveau 12',
    GameLegendTier.legendPlus => 'Niveau 12 · Médaille de bronze',
    GameLegendTier.legendPro => 'Niveau 12 · Médaille d’argent',
    GameLegendTier.champion => 'Niveau 12 · Médaille d’or',
    GameLegendTier.championLeague => 'Niveau 12 · 4 victoires distinctes',
    GameLegendTier.championLeaguePro =>
      'Niveau 12 · 5 victoires contre des adversaires distincts',
  };

  factory GameLegend.fromJson(Map<String, dynamic> json) {
    return GameLegend(
      id: json['id'] as int,
      rank: json['rank'] as int? ?? 0,
      displayName: json['display_name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      score: json['score'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      duelMedal: json['duel_medal'] as String? ?? 'none',
      duelMedals: [
        ...((json['duel_medals'] as List<dynamic>?)?.whereType<String>() ??
            const <String>[]),
        if (json['duel_medal'] is String &&
            json['duel_medal'] != 'none' &&
            !((json['duel_medals'] as List<dynamic>?)?.contains(
                  json['duel_medal'],
                ) ??
                false))
          json['duel_medal'] as String,
      ],
    );
  }
}
