import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/game/game_level.dart';
import 'package:mobile/game/fopcam_game.dart';

void main() {
  test('flying bird drops become more frequent at higher levels', () {
    final intervals = [
      for (var level = 1; level <= GameLevel.all.length; level++)
        flyingBirdIntervalForLevel(level),
    ];

    expect(intervals.first, 12);
    expect(intervals.last, 6.5);
    for (var index = 1; index < intervals.length; index++) {
      expect(intervals[index], lessThan(intervals[index - 1]));
    }
    expect(() => flyingBirdIntervalForLevel(0), throwsRangeError);
    expect(() => flyingBirdIntervalForLevel(13), throwsRangeError);
    expect(FopcamGame.birdRewardPoints, 5);
    expect(FopcamGame.birdTrapPenalty, 3);
  });

  test('defines 12 distinct, progressively harder levels', () {
    expect(GameLevel.all, hasLength(12));
    expect(
      GameLevel.all.map((level) => level.backdrop).toSet(),
      hasLength(GameLevel.all.length),
    );
    expect(
      GameLevel.all.map((level) => level.musicAsset).toSet(),
      hasLength(GameLevel.all.length),
    );

    for (var index = 1; index < GameLevel.all.length; index++) {
      final previous = GameLevel.all[index - 1];
      final current = GameLevel.all[index];

      expect(current.number, previous.number + 1);
      expect(current.musicTempo, greaterThan(previous.musicTempo));
      expect(current.musicAsset, isNot(previous.musicAsset));
      expect(current.scoreThreshold, greaterThan(previous.scoreThreshold));
      expect(current.spawnInterval, lessThan(previous.spawnInterval));
      expect(current.minObstacleSpeed, greaterThan(previous.minObstacleSpeed));
      expect(current.maxObstacleSpeed, greaterThan(previous.maxObstacleSpeed));
      expect(current.color, isNot(previous.color));
    }
  });

  test('ramps obstacle speed smoothly and slightly more at each level', () {
    final minSpeedSteps = <double>[];
    final maxSpeedSteps = <double>[];

    for (var index = 1; index < GameLevel.all.length; index++) {
      final previous = GameLevel.all[index - 1];
      final current = GameLevel.all[index];
      minSpeedSteps.add(current.minObstacleSpeed - previous.minObstacleSpeed);
      maxSpeedSteps.add(current.maxObstacleSpeed - previous.maxObstacleSpeed);
      expect(
        previous.spawnInterval - current.spawnInterval,
        closeTo(0.03, 0.001),
      );
      expect(
        previous.powerUpChance - current.powerUpChance,
        closeTo(0.01, 0.001),
      );
    }

    expect(minSpeedSteps, [4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]);
    expect(maxSpeedSteps, [5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);
    expect(GameLevel.all.last.maxObstacleSpeed, 255);
  });

  test('every level uses a safe, strictly increasing obstacle speed range', () {
    for (var index = 0; index < GameLevel.all.length; index++) {
      final level = GameLevel.all[index];
      expect(level.minObstacleSpeed, greaterThan(0));
      expect(level.maxObstacleSpeed, greaterThan(level.minObstacleSpeed));
      expect(level.spawnInterval, greaterThan(0));
      if (index > 0) {
        final previous = GameLevel.all[index - 1];
        expect(level.minObstacleSpeed, greaterThan(previous.minObstacleSpeed));
        expect(level.maxObstacleSpeed, greaterThan(previous.maxObstacleSpeed));
      }
    }
  });

  test('maps scores to the correct level, capped at level 12', () {
    expect(GameLevel.forScore(0).number, 1);
    expect(GameLevel.forScore(5).number, 1);
    expect(GameLevel.forScore(6).number, 2);
    expect(GameLevel.forScore(153).number, 11);
    expect(GameLevel.forScore(154).number, 12);
    expect(GameLevel.forScore(1000).number, 12);
  });

  test('shortens the score targets for every level', () {
    expect(GameLevel.all.map((level) => level.scoreThreshold).toList(), [
      0,
      6,
      13,
      22,
      32,
      44,
      58,
      74,
      91,
      110,
      131,
      154,
    ]);
  });

  test('shortens regular timers and fixes levels 6 through 12 at 55s', () {
    expect(
      List.generate(
        GameLevel.all.length,
        (index) => GameLevel.durationSecondsFor(index + 1),
      ),
      [30, 45, 60, 75, 90, 55, 55, 55, 55, 55, 55, 55],
    );
    expect(
      List.generate(
        GameLevel.all.length,
        (index) =>
            GameLevel.durationSecondsFor(index + 1, replayAfterDemotion: true),
      ),
      List<int>.filled(GameLevel.all.length, 30),
    );
    expect(() => GameLevel.durationSecondsFor(0), throwsRangeError);
    expect(() => GameLevel.durationSecondsFor(13), throwsRangeError);
    expect(
      () => GameLevel.durationSecondsFor(0, replayAfterDemotion: true),
      throwsRangeError,
    );
  });

  test('requires explicit validation before each next level is unlocked', () {
    final progression = GameProgression();

    expect(progression.canValidate(5), isFalse);
    expect(progression.canValidate(6), isTrue);
    expect(progression.validate(1000), isTrue);
    expect(progression.level, 2);

    for (var completedLevel = 2; completedLevel < 12; completedLevel++) {
      expect(progression.level, completedLevel);
      expect(progression.validate(1000), isTrue);
      expect(progression.level, completedLevel + 1);
    }

    expect(progression.isCompleted, isFalse);
    expect(progression.canValidate(176), isFalse);
    expect(progression.validate(177), isTrue);
    expect(progression.level, 12);
    expect(progression.isCompleted, isTrue);
    expect(progression.validate(1000), isFalse);
  });

  test('completes level 12 once and cannot advance beyond it', () {
    final progression = GameProgression(level: GameLevel.all.length);
    final finalLevelThreshold = progression.validationThreshold;

    expect(progression.validate(finalLevelThreshold - 1), isFalse);
    expect(progression.validate(finalLevelThreshold), isTrue);
    expect(progression.isCompleted, isTrue);
    expect(progression.level, GameLevel.all.length);
    expect(progression.validate(finalLevelThreshold + 100), isFalse);
    expect(progression.level, GameLevel.all.length);
  });

  test('does not allow a level to finish before its timer reaches zero', () {
    final progression = GameProgression();

    expect(progression.canCompleteWithinTimer(6, 12), isFalse);
    expect(progression.canCompleteWithinTimer(5, 0), isFalse);
    expect(progression.canCompleteWithinTimer(6, 0), isTrue);
    expect(progression.level, 1);
  });

  test('automatically validates a completed level 12 at timeout', () {
    final progression = GameProgression(level: GameLevel.all.length);

    expect(
      shouldAutoValidateFinalGameLevel(
        progression: progression,
        score: progression.validationThreshold,
        remainingSeconds: 0,
      ),
      isTrue,
    );
    expect(
      shouldAutoValidateFinalGameLevel(
        progression: progression,
        score: progression.validationThreshold - 1,
        remainingSeconds: 0,
      ),
      isFalse,
    );
    expect(
      shouldAutoValidateFinalGameLevel(
        progression: progression,
        score: progression.validationThreshold,
        remainingSeconds: 1,
      ),
      isFalse,
    );
  });

  test('a failure demotes one level and applies only its penalty', () {
    final progression = GameProgression();

    progression.validate(8);
    progression.validate(18);
    expect(progression.level, 3);

    final scoreAfterFailure = progression.fail(21, 3);

    expect(progression.level, 2);
    expect(scoreAfterFailure, 18);
    expect(progression.canCompleteWithinTimer(scoreAfterFailure, 1), isFalse);
    expect(progression.canCompleteWithinTimer(scoreAfterFailure, 0), isTrue);
    expect(progression.canValidate(scoreAfterFailure), isTrue);
    expect(progression.canValidate(18), isTrue);
  });

  test('a collision costs one point before applying level demotion', () {
    final progression = GameProgression();
    progression.validate(6);

    final scoreAfterCollision = progression.fail(
      12,
      FopcamGame.collisionPenalty,
    );

    expect(progression.level, 1);
    expect(scoreAfterCollision, 11);
    expect(FopcamGame.shieldBonus, 3);
  });

  test('requires two collisions before demoting and resets on validation', () {
    final progression = GameProgression();
    expect(progression.validate(6), isTrue);
    expect(progression.level, 2);

    var score = 12;
    final firstCollisionDemotes = progression.registerCollision();
    score = progression.fail(
      score,
      FopcamGame.collisionPenalty,
      demote: firstCollisionDemotes,
    );
    expect(score, 11);
    expect(progression.level, 2);

    final secondCollisionDemotes = progression.registerCollision();
    score = progression.fail(
      score,
      FopcamGame.collisionPenalty,
      demote: secondCollisionDemotes,
    );
    expect(score, 10);
    expect(progression.level, 1);

    expect(progression.registerCollision(), isFalse);
    expect(progression.validate(12), isTrue);
    expect(progression.registerCollision(), isFalse);
    expect(progression.level, 2);
  });

  test('prices level recovery at 50 points below level 6 and 100 from 6', () {
    expect(GameProgression.recoveryCostFor(2), 50);
    expect(GameProgression.recoveryCostFor(5), 50);
    expect(GameProgression.recoveryCostFor(6), 100);
    expect(GameProgression.recoveryCostFor(12), 100);
    expect(() => GameProgression.recoveryCostFor(0), throwsRangeError);
    expect(() => GameProgression.recoveryCostFor(13), throwsRangeError);
    expect(GameProgression.scoreAfterRecovery(49, 5), isNull);
    expect(GameProgression.scoreAfterRecovery(50, 5), 0);
    expect(GameProgression.scoreAfterRecovery(120, 6), 20);
    expect(GameProgression.scoreAfterRecovery(99, 6), isNull);
    expect(() => GameProgression.scoreAfterRecovery(-1, 6), throwsRangeError);
  });

  test('recovers exactly one demoted level and resets pending collisions', () {
    final progression = GameProgression(level: 5);
    expect(progression.registerCollision(), isFalse);
    expect(progression.registerCollision(), isTrue);
    expect(progression.fail(90, 1), 89);
    expect(progression.level, 4);

    expect(progression.recoverOneLevel(), isTrue);
    expect(progression.level, 5);
    expect(progression.registerCollision(), isFalse);
    expect(progression.recoverOneLevel(), isTrue);
    expect(progression.level, 6);
    expect(progression.recoverOneLevel(), isTrue);
    expect(progression.level, 7);

    final levelOne = GameProgression();
    expect(levelOne.recoverOneLevel(), isFalse);
  });

  test('a failure on level one keeps the player on level one', () {
    final progression = GameProgression();

    expect(progression.fail(7, 3), 4);
    expect(progression.level, 1);
    expect(progression.canValidate(4), isFalse);
  });
}
