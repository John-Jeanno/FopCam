import 'dart:ui' show Canvas, PictureRecorder, Size;

import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/game/game_level.dart';
import 'package:mobile/game/fopcam_game.dart';

void main() {
  test('legend duels use three faster, shorter rounds', () {
    expect(challengeRoundDurationsSeconds, [50, 45, 40]);
    final speedMultipliers = [
      for (var round = 1; round <= 3; round++)
        challengeRoundObstacleSpeedMultiplier(round),
    ];
    final spawnMultipliers = [
      for (var round = 1; round <= 3; round++)
        challengeRoundSpawnIntervalMultiplier(round),
    ];

    expect(speedMultipliers, orderedEquals([1, 1.35, 1.7]));
    expect(spawnMultipliers, orderedEquals([1, 0.85, 0.7]));
    expect(
      challengeRoundObstacleSpeedMultiplier(3),
      greaterThan(challengeRoundObstacleSpeedMultiplier(2)),
    );
    expect(
      challengeRoundSpawnIntervalMultiplier(3),
      lessThan(challengeRoundSpawnIntervalMultiplier(2)),
    );
    expect(() => challengeRoundObstacleSpeedMultiplier(4), throwsRangeError);
    expect(() => challengeRoundSpawnIntervalMultiplier(0), throwsRangeError);
  });

  test('bounds horizontal and vertical player targets to the play area', () {
    expect(
      clampGamePlayerTarget(Vector2(-30, 10), Vector2(320, 700)),
      Vector2(20, 112),
    );
    expect(
      clampGamePlayerTarget(Vector2(500, 900), Vector2(320, 700)),
      Vector2(300, 680),
    );
  });

  test('limits large and invalid frame deltas before simulating', () {
    expect(maxGameFrameDelta, closeTo(1 / 30, 0.000001));
    expect(boundedGameFrameDelta(1), maxGameFrameDelta);
    expect(boundedGameFrameDelta(1 / 60), closeTo(1 / 60, 0.000001));
    expect(boundedGameFrameDelta(double.nan), 0);
    expect(boundedGameFrameDelta(-1), 0);
  });

  test(
    'the first two collisions demote a level-12 challenger exactly once',
    () {
      final progression = GameProgression(level: GameLevel.all.length);

      expect(progression.registerCollision(), isFalse);
      expect(progression.level, 12);
      expect(progression.registerCollision(), isTrue);
      expect(progression.fail(200, 10), 190);
      expect(progression.level, 11);
    },
  );

  test(
    'fixed-step obstacle movement is independent of 30 or 60 FPS frames',
    () {
      final at30Fps = GameFixedStepClock();
      final at60Fps = GameFixedStepClock();
      var stepsAt30Fps = 0;
      var stepsAt60Fps = 0;
      for (var frame = 0; frame < 30; frame++) {
        stepsAt30Fps += at30Fps.consume(1 / 30);
      }
      for (var frame = 0; frame < 60; frame++) {
        stepsAt60Fps += at60Fps.consume(1 / 60);
      }

      expect(stepsAt30Fps, 60);
      expect(stepsAt60Fps, 60);
      final initialPosition = Vector2(120, 0);
      expect(
        advanceFallingObjectPosition(
          initialPosition,
          156,
          gameSimulationStep * stepsAt30Fps,
        ),
        advanceFallingObjectPosition(
          initialPosition,
          156,
          gameSimulationStep * stepsAt60Fps,
        ),
      );
      for (final level in GameLevel.all) {
        final displacement = advanceFallingObjectPosition(
          initialPosition,
          level.maxObstacleSpeed,
          gameSimulationStep,
        ).y;
        expect(displacement, greaterThan(0));
        expect(displacement, lessThan(5));
      }
    },
  );

  test('player movement never overshoots or oscillates around its target', () {
    var position = Vector2.zero();
    final target = Vector2(10, 0);

    position = advancePlayerPosition(position, target, 5.5);
    expect(position, Vector2(5.5, 0));
    position = advancePlayerPosition(position, target, 5.5);
    expect(position, target);
    position = advancePlayerPosition(position, target, 5.5);
    expect(position, target);
  });

  test('spectator playback interpolates snapshots without overshooting', () {
    final playback = GamePositionPlayback();
    final position = Vector2(0, 0);
    playback.retarget(position, Vector2(100, 50), 1);

    for (var frame = 0; frame < 30; frame++) {
      playback.update(position, 1 / 60);
    }
    expect(position.x, closeTo(50, 0.01));
    expect(position.y, closeTo(25, 0.01));

    for (var frame = 0; frame < 30; frame++) {
      playback.update(position, 1 / 60);
    }
    expect(position, Vector2(100, 50));
    playback.update(position, 1 / 60);
    expect(position, Vector2(100, 50));
  });

  test('spectator snapshots arriving before game load are queued safely', () {
    final game = FopcamGame(isChallengeMode: true, isSpectatorMode: true);

    expect(
      () => game.applySpectatorState({
        'round_number': 1,
        'score': 3,
        'remaining_seconds': 48.0,
        'player_x': 0.5,
        'player_y': 0.7,
        'objects': const [],
      }),
      returnsNormally,
    );
    expect(game.hasSpectatorSnapshot, isFalse);
  });

  test('spectator games show falling objects without rendering the player', () {
    final spectator = FopcamGame(
      isChallengeMode: true,
      isSpectatorMode: true,
    );
    final player = FopcamGame(isChallengeMode: true);

    expect(spectator.isPlayerVisible, isFalse);
    expect(player.isPlayerVisible, isTrue);
  });

  test('restores the player at its saved position when resuming a game', () {
    expect(
      restoredGamePlayerPosition(
        Vector2(400, 800),
        xMillionths: 250000,
        yMillionths: 700000,
      ),
      Vector2(100, 560),
    );
    expect(restoredGamePlayerPosition(Vector2(400, 800)), Vector2(200, 720));
    expect(
      restoredGamePlayerPosition(
        Vector2(400, 800),
        xMillionths: 2000000,
        yMillionths: -1,
      ),
      Vector2(380, 112),
    );
  });

  test('audio volume stays in range and mute silences music and effects', () {
    expect(clampGameAudioVolume(-0.5), 0);
    expect(clampGameAudioVolume(1.5), 1);
    expect(effectiveGameAudioVolume(0.6, muted: true), 0);
    expect(effectiveGameAudioVolume(0.6, muted: false), 0.6);
    expect(effectiveGameAudioVolume(0.25, muted: false), 0.25);
    expect(effectiveGameAudioVolume(0.25, muted: true), 0);
    expect(() => clampGameAudioVolume(double.nan), throwsArgumentError);
  });

  test(
    'every level has a distinct track with a progressively faster tempo',
    () {
      final tracks = [
        for (var level = 1; level <= GameLevel.all.length; level++)
          gameMusicAssetForLevel(level),
      ];
      final tempos = GameLevel.all.map((level) => level.musicTempo).toList();

      expect(
        GameLevel.all.map((level) => level.number),
        orderedEquals(List<int>.generate(12, (index) => index + 1)),
      );
      expect(tracks.toSet(), hasLength(GameLevel.all.length));
      expect(tempos, orderedEquals([...tempos]..sort()));
      expect(gameMusicAssetForLevel(1), 'sounds/level_01.wav');
      expect(gameMusicAssetForLevel(12), 'sounds/level_12.wav');
      expect(() => gameMusicAssetForLevel(0), throwsRangeError);
      expect(() => gameMusicAssetForLevel(13), throwsRangeError);
    },
  );

  test(
    'legend duel rounds get distinct landscapes, tracks and voice lines',
    () {
      final landscapes = [
        for (var round = 1; round <= 3; round++)
          legendChallengeLandscapeForRound(round).backdrop,
      ];
      final tracks = [
        for (var round = 1; round <= 3; round++)
          legendChallengeMusicAssetForRound(round),
      ];
      final voiceLines = [
        for (var round = 1; round <= 3; round++)
          legendChallengeVoiceAssetForRound(round),
      ];

      expect(landscapes.toSet(), hasLength(3));
      expect(landscapes, [
        GameBackdrop.duelCoast,
        GameBackdrop.duelBaobabValley,
        GameBackdrop.duelRiverOasis,
      ]);
      expect(
        landscapes.toSet().intersection(
          GameLevel.all.map((level) => level.backdrop).toSet(),
        ),
        isEmpty,
      );
      expect(tracks.toSet(), hasLength(3));
      expect(voiceLines.toSet(), hasLength(3));
      expect(() => legendChallengeLandscapeForRound(0), throwsRangeError);
      expect(() => legendChallengeMusicAssetForRound(4), throwsRangeError);
      expect(() => legendChallengeVoiceAssetForRound(4), throwsRangeError);
    },
  );

  test(
    'collision, shield pickup, shield block and bonus use unique effects',
    () {
      final effects = GameSoundEffect.values.map(gameSoundEffectAsset).toList();

      expect(effects.toSet(), hasLength(GameSoundEffect.values.length));
      expect(
        gameSoundEffectAsset(GameSoundEffect.collision),
        'sounds/collision.wav',
      );
      expect(
        gameSoundEffectAsset(GameSoundEffect.shieldPickup),
        'sounds/shield_pickup.wav',
      );
      expect(
        gameSoundEffectAsset(GameSoundEffect.shieldBlock),
        'sounds/shield_block.wav',
      );
      expect(gameSoundEffectAsset(GameSoundEffect.bonus), 'sounds/bonus.wav');
    },
  );

  test('player bird artwork stays within its component bounds', () {
    final bounds = buildPlayerBirdPath(const Size(40, 40)).getBounds();

    expect(bounds.left, greaterThanOrEqualTo(0));
    expect(bounds.top, greaterThanOrEqualTo(0));
    expect(bounds.right, lessThanOrEqualTo(40));
    expect(bounds.bottom, lessThanOrEqualTo(40));
    expect(bounds.width, greaterThan(35));
    expect(bounds.height, greaterThan(20));
  });

  test('renders and releases the cached backdrop for every level', () {
    for (final level in GameLevel.all) {
      final game = FopcamGame(initialLevel: level.number)
        ..onGameResize(Vector2(390, 844));
      final recorder = PictureRecorder();

      game.render(Canvas(recorder));
      recorder.endRecording().dispose();
      game.onRemove();
    }
    for (var round = 1; round <= 3; round++) {
      final game = FopcamGame(
        isChallengeMode: true,
        challengeRoundNumber: round,
      )..onGameResize(Vector2(390, 844));
      final recorder = PictureRecorder();

      game.render(Canvas(recorder));
      recorder.endRecording().dispose();
      game.onRemove();
    }
  });

  test('HUD backing remains opaque over every themed background', () {
    expect(gameHudBackgroundColor.toARGB32() >> 24, greaterThanOrEqualTo(240));
  });

  test('every level scrolls its scenery at an increasing safe speed', () {
    final offsets = [
      for (final level in GameLevel.all)
        gameSceneScrollOffset(2, level.number, 320),
    ];

    for (var index = 1; index < offsets.length; index++) {
      expect(offsets[index], greaterThan(offsets[index - 1]));
    }
    expect(gameSceneScrollOffset(20, 12, 320), greaterThanOrEqualTo(0));
    expect(gameSceneScrollOffset(20, 12, 320), lessThan(320));
    expect(gameSceneScrollOffset(double.nan, 12, 320), 0);
    expect(gameSceneScrollOffset(2, 12, 0), 0);
  });

  test(
    'snowfall appears throughout the game and is heavier in cold levels',
    () {
      final counts = [
        for (final level in GameLevel.all)
          gameSnowParticleCountForLevel(level.number),
      ];

      expect(counts, everyElement(greaterThanOrEqualTo(20)));
      expect(counts[8], greaterThan(counts[7]));
      expect(counts[11], greaterThan(counts[10]));
    },
  );
}
