import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/game_challenge.dart';
import 'package:mobile/models/game_legend.dart';
import 'package:mobile/models/game_live_duel.dart';

void main() {
  test('parses public legend data for the leaderboard', () {
    final legend = GameLegend.fromJson({
      'id': 4,
      'rank': 1,
      'display_name': 'Awa Diop',
      'username': 'awa',
      'avatar_url': 'https://example.test/awa.png',
      'score': 246,
      'title': 'Trophée Awa · Légende FopCam',
      'duel_medal': 'silver',
      'duel_medals': ['bronze', 'silver'],
    });

    expect(legend.id, 4);
    expect(legend.rank, 1);
    expect(legend.displayName, 'Awa Diop');
    expect(legend.displayLabel, 'Awa Diop (@awa)');
    expect(legend.score, 246);
    expect(legend.avatarUrl, 'https://example.test/awa.png');
    expect(legend.duelMedalLabel, 'argent');
    expect(legend.duelMedals, ['bronze', 'silver']);
  });

  test('maps level-twelve legends to medal sections', () {
    GameLegend legendFor(String medal) => GameLegend.fromJson({
      'id': 4,
      'display_name': 'Awa',
      'username': 'awa',
      'score': 100,
      'duel_medal': medal,
    });

    expect(legendFor('none').tierLabel, 'Légende');
    expect(legendFor('none').tierRequirement, 'Niveau 12');
    expect(legendFor('bronze').tierLabel, 'Légende+');
    expect(
      legendFor('bronze').tierRequirement,
      'Niveau 12 · Médaille de bronze',
    );
    expect(legendFor('silver').tierLabel, 'Légende Pro');
    expect(
      legendFor('silver').tierRequirement,
      'Niveau 12 · Médaille d’argent',
    );
    expect(legendFor('gold').tierLabel, 'Champion FopCam');
    expect(legendFor('gold').tierRequirement, 'Niveau 12 · Médaille d’or');
    expect(legendFor('cup').duelMedalLabel, 'Coupe');
    expect(legendFor('cup').tierLabel, 'Champion 1ère Ligue');
    expect(
      legendFor('cup').tierRequirement,
      'Niveau 12 · 4 victoires distinctes',
    );
    expect(legendFor('cup_pro').tierLabel, 'Champion League Pro');
    expect(
      legendFor('cup_pro').tierRequirement,
      'Niveau 12 · 5 victoires contre des adversaires distincts',
    );
  });

  test('separates champion medals from the first-league cup', () {
    final legend = GameLegend.fromJson({
      'id': 1,
      'display_name': 'Jeanno SENE',
      'username': 'admin-jeanno',
      'score': 500,
      'duel_medal': 'cup',
      'duel_medals': ['bronze', 'silver', 'gold', 'cup'],
    });

    expect(legend.appearsInTier(GameLegendTier.champion), isTrue);
    expect(legend.appearsInTier(GameLegendTier.championLeague), isTrue);
    expect(legend.medalsForTier(GameLegendTier.champion), [
      'bronze',
      'silver',
      'gold',
    ]);
    expect(legend.medalsForTier(GameLegendTier.championLeague), ['cup']);
    expect(legend.appearsInTier(GameLegendTier.legendPlus), isFalse);
    expect(legend.appearsInTier(GameLegendTier.legendPro), isFalse);
  });

  test('lists the Pro League Cup as a separate trophy tier', () {
    final legend = GameLegend.fromJson({
      'id': 2,
      'display_name': 'Awa Diop',
      'username': 'awa',
      'score': 500,
      'duel_medal': 'cup_pro',
      'duel_medals': ['bronze', 'silver', 'gold', 'cup', 'cup_pro'],
    });

    expect(legend.appearsInTier(GameLegendTier.championLeague), isTrue);
    expect(legend.appearsInTier(GameLegendTier.championLeaguePro), isTrue);
    expect(legend.medalsForTier(GameLegendTier.championLeaguePro), ['cup_pro']);
  });

  test('allows challenges only between legends at the same tier', () {
    GameLegend legendFor(String medal) => GameLegend.fromJson({
      'id': 4,
      'display_name': 'Awa',
      'username': 'awa',
      'duel_medal': medal,
    });

    expect(legendFor('bronze').hasSameDuelTierAs(legendFor('bronze')), isTrue);
    expect(legendFor('silver').hasSameDuelTierAs(legendFor('silver')), isTrue);
    expect(legendFor('cup').hasSameDuelTierAs(legendFor('cup')), isTrue);
    expect(legendFor('bronze').hasSameDuelTierAs(legendFor('silver')), isFalse);
    expect(legendFor('gold').hasSameDuelTierAs(legendFor('cup')), isFalse);
    expect(
      legendFor('cup_pro').hasSameDuelTierAs(legendFor('cup_pro')),
      isTrue,
    );
    expect(legendFor('cup').hasSameDuelTierAs(legendFor('cup_pro')), isFalse);
  });

  test('higher-tier legends may challenge legends at lower tiers', () {
    GameLegend legendFor(String medal) => GameLegend.fromJson({
      'id': medal.hashCode,
      'display_name': 'Legend $medal',
      'username': medal,
      'score': 100,
      'duel_medal': medal,
    });

    final baseLegend = legendFor('none');
    final bronzeLegend = legendFor('bronze');
    final champion = legendFor('gold');
    final proChampion = legendFor('cup_pro');

    expect(champion.canChallenge(bronzeLegend), isTrue);
    expect(champion.canChallenge(baseLegend), isTrue);
    expect(bronzeLegend.canChallenge(baseLegend), isTrue);
    expect(bronzeLegend.canChallenge(champion), isFalse);
    expect(baseLegend.canChallenge(proChampion), isFalse);
    expect(proChampion.canChallenge(champion), isTrue);
  });

  test('parses public live duel details', () {
    final duel = GameLiveDuel.fromJson({
      'id': 10,
      'challenger_name': 'Awa',
      'challenged_name': 'Moussa',
      'challenger_score': 24,
      'challenged_score': 18,
      'round_number': 2,
      'active_player_name': 'Awa',
      'state': {
        'round_number': 2,
        'score': 24,
        'remaining_seconds': 20.0,
        'player_x': 0.5,
        'player_y': 0.6,
        'objects': [],
      },
    });

    expect(duel.id, 10);
    expect(duel.activePlayerName, 'Awa');
    expect(duel.challengerScore, 24);
    expect(duel.state?['score'], 24);
    expect(duel.hasLiveState, isTrue);
  });

  test('parses incoming challenge and exposes whether it can be played', () {
    final challenge = GameChallenge.fromJson({
      'id': 8,
      'status': 'accepted',
      'opponent': {
        'id': 4,
        'display_name': 'Awa',
        'username': 'awa',
        'score': 246,
        'title': 'Légende FopCam',
      },
      'my_score': null,
      'opponent_score': null,
      'winner_id': null,
      'winner_name': null,
      'is_incoming': true,
      'expires_at': '2026-11-01T04:03:00Z',
    });

    expect(challenge.opponent?.displayName, 'Awa');
    expect(challenge.isIncoming, isTrue);
    expect(challenge.canPlay, isTrue);
    expect(challenge.expiresAt, DateTime.utc(2026, 11, 1, 4, 3));
  });

  test('parses shared challenge cancellation and deletion permissions', () {
    final incoming = GameChallenge.fromJson({
      'id': 8,
      'status': 'pending',
      'is_incoming': true,
      'can_cancel': true,
    });
    final declined = GameChallenge.fromJson({
      'id': 9,
      'status': 'declined',
      'can_delete': true,
    });

    expect(incoming.canCancel, isTrue);
    expect(declined.canDelete, isTrue);
  });

  test('classifies completed duels as my victories or defeats', () {
    final victory = GameChallenge.fromJson({
      'id': 30,
      'status': 'completed',
      'my_won': true,
    });
    final defeat = GameChallenge.fromJson({
      'id': 31,
      'status': 'completed',
      'my_won': false,
    });
    final draw = GameChallenge.fromJson({
      'id': 32,
      'status': 'completed',
      'my_won': null,
    });
    final active = GameChallenge.fromJson({
      'id': 33,
      'status': 'playing',
      'my_won': true,
    });
    final completedRematchVictory = GameChallenge.fromJson({
      'id': 34,
      'status': 'completed',
      'my_won': true,
      'is_rematch': true,
    });
    final pendingRematch = GameChallenge.fromJson({
      'id': 35,
      'status': 'pending',
      'is_rematch': true,
    });

    expect(victory.isMyVictory, isTrue);
    expect(victory.isMyDefeat, isFalse);
    expect(defeat.isMyVictory, isFalse);
    expect(defeat.isMyDefeat, isTrue);
    expect(draw.isMyVictory, isFalse);
    expect(draw.isMyDefeat, isFalse);
    expect(active.isMyVictory, isFalse);
    expect(active.isMyDefeat, isFalse);
    expect(completedRematchVictory.isMyVictory, isFalse);
    expect(completedRematchVictory.isMyDefeat, isFalse);
    expect(pendingRematch.isMyVictory, isFalse);
    expect(pendingRematch.isMyDefeat, isFalse);
  });

  test('a submitted challenge score cannot be played again', () {
    final challenge = GameChallenge.fromJson({
      'id': 8,
      'status': 'accepted',
      'my_score': 30,
      'is_incoming': false,
    });

    expect(challenge.canPlay, isFalse);
  });

  test('a defeated player can see the remaining rematch allowance', () {
    final challenge = GameChallenge.fromJson({
      'id': 11,
      'status': 'completed',
      'can_request_rematch': true,
      'rematches_used': 2,
      'my_won': false,
    });

    expect(challenge.canRequestRematch, isTrue);
    expect(challenge.rematchesUsed, 2);
  });

  test('parses a unique rematch victory reward', () {
    final challenge = GameChallenge.fromJson({
      'id': 13,
      'status': 'completed',
      'my_won': true,
      'duel_reward': {
        'title': 'Flamme de revanche n°1',
        'description': 'Récompense personnalisée pour Awa.',
        'type': 'flame',
        'color': '#EF4444',
        'sequence': 1,
      },
    });

    expect(challenge.duelReward?['title'], 'Flamme de revanche n°1');
    expect(challenge.duelReward?['sequence'], 1);
  });

  test('parses synchronized live duel readiness and start delay', () {
    final challenge = GameChallenge.fromJson({
      'id': 9,
      'status': 'playing',
      'my_ready': true,
      'opponent_ready': true,
      'started_at': '2026-10-24T13:30:08Z',
      'starts_in_milliseconds': 5000,
      'my_medal': 'bronze',
      'winner_by_score': true,
      'is_my_turn': false,
      'turn_player_name': 'Awa',
      'opponent_live_state': {
        'round_number': 1,
        'score': 10,
        'remaining_seconds': 40.0,
        'player_x': 0.5,
        'player_y': 0.7,
        'objects': [],
      },
    });

    expect(challenge.canPlay, isTrue);
    expect(challenge.myReady, isTrue);
    expect(challenge.opponentReady, isTrue);
    expect(challenge.startsInMilliseconds, 5000);
    expect(challenge.myMedalLabel, 'bronze');
    expect(challenge.winnerByScore, isTrue);
    expect(challenge.isMyTurn, isFalse);
    expect(challenge.turnPlayerName, 'Awa');
    expect(challenge.opponentLiveState?['score'], 10);
  });

  test('parses the cup reward label for a completed duel', () {
    final challenge = GameChallenge.fromJson({
      'id': 14,
      'status': 'completed',
      'my_medal': 'cup',
      'my_title': 'Champion 1ère Ligue',
      'my_won': true,
    });

    expect(challenge.myMedalLabel, 'Coupe');
    expect(challenge.myTitle, 'Champion 1ère Ligue');
  });
}
