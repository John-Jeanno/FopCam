import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/game/fopcam_game.dart';
import 'package:mobile/game/game_instructions.dart';
import 'package:mobile/game/game_level.dart';

void main() {
  test('solo instructions reflect current progression and pickup rules', () {
    final rules = GameInstructions.soloRules()
        .map((rule) => rule.text)
        .join(' ');

    expect(rules, contains('${GameLevel.all.length}'));
    for (final level in GameLevel.all) {
      expect(
        GameInstructions.requiredScoreFor(level),
        GameProgression(level: level.number).validationThreshold,
      );
    }

    expect(rules, contains('${FopcamGame.successfulDodgePoints}'));
    expect(rules, contains('${FopcamGame.timeoutPenalty}'));
    expect(rules, contains('${FopcamGame.collisionPenalty}'));
    expect(rules, contains('${GameProgression.collisionsBeforeDemotion}'));
    expect(rules, contains('${FopcamGame.shieldBonus}'));
    expect(rules, contains('${FopcamGame.shieldDurationSeconds.toInt()}'));
    expect(rules, contains('x${FopcamGame.scoreMultiplierValue}'));
    expect(rules, contains('double les points du prochain cadeau ramassé'));
    expect(rules, contains('${FopcamGame.birdRewardPoints}'));
    expect(rules, contains('${FopcamGame.birdTrapPenalty}'));
    expect(
      rules,
      contains(
        '${GameLevel.durationSecondsFor(1, replayAfterDemotion: true)} secondes',
      ),
    );
  });

  test('challenge instructions reflect configured rounds and mechanics', () {
    final rules = GameInstructions.challengeRules()
        .map((rule) => rule.text)
        .join(' ');

    expect(rules, contains('${challengeRoundDurationsSeconds.length} manches'));
    for (final duration in challengeRoundDurationsSeconds) {
      expect(rules, contains('$duration s'));
    }
    for (
      var round = 1;
      round <= challengeRoundDurationsSeconds.length;
      round++
    ) {
      expect(
        rules,
        contains('x${challengeRoundObstacleSpeedMultiplier(round)}'),
      );
    }
    expect(rules, contains('${GameProgression.collisionsBeforeDemotion}'));
    expect(rules, contains('${FopcamGame.shieldDurationSeconds.toInt()}'));
    expect(rules, contains('${FopcamGame.birdTrapPenalty}'));
  });

  test('all twelve levels have guide targets from progression rules', () {
    expect(GameLevel.all, hasLength(12));
    for (final level in GameLevel.all) {
      expect(
        GameInstructions.requiredScoreFor(level),
        GameProgression(level: level.number).validationThreshold,
      );
    }
  });
}
