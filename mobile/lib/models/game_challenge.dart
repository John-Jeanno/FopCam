import 'game_legend.dart';

class GameChallenge {
  final int id;
  final String status;
  final int roundNumber;
  final int roundDurationSeconds;
  final bool myRoundComplete;
  final bool opponentRoundComplete;
  final bool isMyTurn;
  final bool isDraw;
  final String? turnPlayerName;
  final Map<String, dynamic>? opponentLiveState;
  final GameLegend? opponent;
  final int? myScore;
  final int? opponentScore;
  final int? challengerScore;
  final int? challengedScore;
  final int? winnerId;
  final String? winnerName;
  final bool winnerByScore;
  final bool? myWon;
  final bool canRequestRematch;
  final bool canCancel;
  final bool canDelete;
  final int rematchesUsed;
  final bool isIncoming;
  final bool isRematch;
  final bool myReady;
  final bool opponentReady;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final int? startsInMilliseconds;
  final int? secondsUntilExpiry;
  final String? myTitle;
  final String? myMedal;
  final String? opponentTitle;
  final String? opponentMedal;
  final Map<String, dynamic>? duelReward;

  const GameChallenge({
    required this.id,
    required this.status,
    required this.roundNumber,
    required this.roundDurationSeconds,
    required this.myRoundComplete,
    required this.opponentRoundComplete,
    required this.isMyTurn,
    required this.isDraw,
    required this.turnPlayerName,
    required this.opponentLiveState,
    required this.opponent,
    required this.myScore,
    required this.opponentScore,
    required this.challengerScore,
    required this.challengedScore,
    required this.winnerId,
    required this.winnerName,
    required this.winnerByScore,
    required this.myWon,
    required this.canRequestRematch,
    required this.canCancel,
    required this.canDelete,
    required this.rematchesUsed,
    required this.isIncoming,
    required this.isRematch,
    required this.myReady,
    required this.opponentReady,
    required this.startedAt,
    this.expiresAt,
    required this.startsInMilliseconds,
    required this.secondsUntilExpiry,
    required this.myTitle,
    required this.myMedal,
    required this.opponentTitle,
    required this.opponentMedal,
    required this.duelReward,
  });

  bool get canPlay =>
      status == 'playing' || (status == 'accepted' && myScore == null);

  bool get isMyVictory => status == 'completed' && !isRematch && myWon == true;
  bool get isMyDefeat => status == 'completed' && !isRematch && myWon == false;
  bool get isOutgoingPending => status == 'pending' && !isIncoming;

  String? get myMedalLabel => switch (myMedal) {
    'bronze' => 'bronze',
    'silver' => 'argent',
    'gold' => 'or',
    'cup' => 'Coupe',
    'cup_pro' => 'Coupe Pro',
    _ => null,
  };

  factory GameChallenge.fromJson(Map<String, dynamic> json) {
    final opponentData = json['opponent'];
    final opponent = opponentData is Map
        ? GameLegend.fromJson(Map<String, dynamic>.from(opponentData))
        : null;
    return GameChallenge(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'pending',
      roundNumber: json['round_number'] as int? ?? 1,
      roundDurationSeconds: json['round_duration_seconds'] as int? ?? 50,
      myRoundComplete: json['my_round_complete'] as bool? ?? false,
      opponentRoundComplete: json['opponent_round_complete'] as bool? ?? false,
      isMyTurn: json['is_my_turn'] as bool? ?? false,
      isDraw: json['is_draw'] as bool? ?? false,
      turnPlayerName: json['turn_player_name'] as String?,
      opponentLiveState: json['opponent_live_state'] is Map
          ? Map<String, dynamic>.from(json['opponent_live_state'] as Map)
          : null,
      opponent: opponent,
      myScore: json['my_score'] as int?,
      opponentScore: json['opponent_score'] as int?,
      challengerScore: json['challenger_score'] as int?,
      challengedScore: json['challenged_score'] as int?,
      winnerId: json['winner_id'] as int?,
      winnerName: json['winner_name'] as String?,
      winnerByScore: json['winner_by_score'] as bool? ?? false,
      myWon: json['my_won'] as bool?,
      canRequestRematch: json['can_request_rematch'] as bool? ?? false,
      canCancel: json['can_cancel'] as bool? ?? false,
      canDelete: json['can_delete'] as bool? ?? false,
      rematchesUsed: json['rematches_used'] as int? ?? 0,
      isIncoming: json['is_incoming'] as bool? ?? false,
      isRematch: json['is_rematch'] as bool? ?? false,
      myReady: json['my_ready'] as bool? ?? false,
      opponentReady: json['opponent_ready'] as bool? ?? false,
      startedAt: json['started_at'] is String
          ? DateTime.tryParse(json['started_at'] as String)
          : null,
      expiresAt: json['expires_at'] is String
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      startsInMilliseconds: json['starts_in_milliseconds'] as int?,
      secondsUntilExpiry: json['seconds_until_expiry'] as int?,
      myTitle: json['my_title'] as String?,
      myMedal: json['my_medal'] as String?,
      opponentTitle: json['opponent_title'] as String?,
      opponentMedal: json['opponent_medal'] as String?,
      duelReward: json['duel_reward'] is Map
          ? Map<String, dynamic>.from(json['duel_reward'] as Map)
          : null,
    );
  }
}
