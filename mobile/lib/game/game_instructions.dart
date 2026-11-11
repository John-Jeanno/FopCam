import 'package:flutter/material.dart';
import 'package:mobile/game/fopcam_game.dart';
import 'package:mobile/game/game_level.dart';

class GameInstruction {
  const GameInstruction({required this.icon, required this.text});

  final IconData icon;
  final String text;
}

class GameInstructions {
  static List<GameInstruction> soloRules() => [
    const GameInstruction(
      icon: Icons.touch_app,
      text:
          'Glisse ton doigt dans toutes les directions pour déplacer ton '
          'personnage horizontalement et verticalement.',
    ),
    GameInstruction(
      icon: Icons.bolt,
      text:
          'Chaque obstacle esquivé rapporte ${FopcamGame.successfulDodgePoints} '
          'point et augmente ta série. Leur vitesse augmente à chaque niveau.',
    ),
    GameInstruction(
      icon: Icons.timer,
      text:
          'Temps par niveau : ${_levelDurationsDescription()}. Atteins le score '
          'requis avant la fin ; sinon, tu perds ${FopcamGame.timeoutPenalty} '
          'points et recules d’un niveau (sauf au niveau 1). Après une '
          'rétrogradation, la reprise dure '
          '${GameLevel.durationSecondsFor(1, replayAfterDemotion: true)} secondes.',
    ),
    GameInstruction(
      icon: Icons.trending_down,
      text:
          'Une collision coûte ${FopcamGame.collisionPenalty} point. '
          '${GameProgression.collisionsBeforeDemotion} collisions font reculer '
          'd’un niveau ; le compteur repart après validation ou recul. Après '
          'un recul, tu peux récupérer le niveau pour '
          '${_recoveryCostsDescription()}.',
    ),
    ..._pickupRules(),
  ];

  static List<GameInstruction> challengeRules() {
    final roundCount = challengeRoundDurationsSeconds.length;
    final durations = challengeRoundDurationsSeconds
        .asMap()
        .entries
        .map((entry) => 'manche ${entry.key + 1} : ${entry.value} s')
        .join(', ');
    final speedMultipliers = List.generate(
      challengeRoundDurationsSeconds.length,
      (index) => 'x${challengeRoundObstacleSpeedMultiplier(index + 1)}',
    ).join(', ');

    return [
      const GameInstruction(
        icon: Icons.touch_app,
        text:
            'Glisse ton doigt dans toutes les directions pour déplacer ton '
            'personnage horizontalement et verticalement.',
      ),
      const GameInstruction(
        icon: Icons.sports_esports,
        text:
            'Joue à tour de rôle avec ton adversaire. Pendant son tour, tu peux '
            'suivre sa partie en direct sans contrôler son personnage.',
      ),
      GameInstruction(
        icon: Icons.timer,
        text:
            'Les $roundCount manches durent : $durations. La vitesse des obstacles '
            'augmente à chaque manche ($speedMultipliers). Chaque manche a son '
            'paysage, sa musique et son annonce vocale.',
      ),
      GameInstruction(
        icon: Icons.bolt,
        text:
            'Chaque obstacle esquivé rapporte ${FopcamGame.successfulDodgePoints} '
            'point. Une collision coûte ${FopcamGame.collisionPenalty} point ; '
            '${GameProgression.collisionsBeforeDemotion} collisions font reculer '
            'd’un niveau et mettent fin au duel.',
      ),
      ..._pickupRules(),
      GameInstruction(
        icon: Icons.emoji_events,
        text:
            'Si vous terminez les $roundCount manches, le score cumulé le plus '
            'élevé gagne ; seuls des scores égaux donnent un nul.',
      ),
    ];
  }

  static List<GameInstruction> _pickupRules() => [
    GameInstruction(
      icon: Icons.card_giftcard,
      text:
          'Le paquet cadeau ajoute ${FopcamGame.shieldBonus} points et protège '
          'des collisions pendant ${FopcamGame.shieldDurationSeconds.toInt()} '
          'secondes. Le bonus jaune x${FopcamGame.scoreMultiplierValue} double '
          'les points du prochain cadeau ramassé.',
    ),
    GameInstruction(
      icon: Icons.flight,
      text:
          'Un oiseau passe environ toutes les '
          '${baseFlyingBirdIntervalSeconds.toInt()} secondes, puis plus souvent '
          'à chaque niveau (jusqu’à ${flyingBirdIntervalForLevel(GameLevel.all.length)} '
          'secondes au niveau ${GameLevel.all.length}). Sa boîte peut rapporter '
          '${FopcamGame.birdRewardPoints} points ou en faire perdre '
          '${FopcamGame.birdTrapPenalty}, sans rétrogradation.',
    ),
  ];

  static String _levelDurationsDescription() {
    final groups = <({int seconds, int firstLevel, int lastLevel})>[];
    for (final level in GameLevel.all) {
      final seconds = GameLevel.durationSecondsFor(level.number);
      if (groups.isNotEmpty && groups.last.seconds == seconds) {
        final previous = groups.removeLast();
        groups.add((
          seconds: seconds,
          firstLevel: previous.firstLevel,
          lastLevel: level.number,
        ));
      } else {
        groups.add((
          seconds: seconds,
          firstLevel: level.number,
          lastLevel: level.number,
        ));
      }
    }

    return groups
        .map((group) {
          final levels = group.firstLevel == group.lastLevel
              ? 'niveau ${group.firstLevel}'
              : 'niveaux ${group.firstLevel} à ${group.lastLevel}';
          return '${group.seconds} s ($levels)';
        })
        .join(', ');
  }

  static String _recoveryCostsDescription() {
    final costs = GameLevel.all
        .map((level) => GameProgression.recoveryCostFor(level.number))
        .toList();
    final firstChange = costs.indexWhere((cost) => cost != costs.first);
    if (firstChange < 0) return '${costs.first} points';
    return '${costs.first} points, puis ${costs[firstChange]} à partir du '
        'niveau ${firstChange + 1}';
  }

  static int requiredScoreFor(GameLevel level) =>
      GameProgression(level: level.number).validationThreshold;
}
