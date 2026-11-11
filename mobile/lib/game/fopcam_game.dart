import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:mobile/game/game_level.dart';

const double maxGameFrameDelta = 1 / 30;
const double gameSimulationStep = 1 / 60;
const Color gameHudBackgroundColor = Color(0xF20C1622);
const List<int> challengeRoundDurationsSeconds = [50, 45, 40];
const double baseFlyingBirdIntervalSeconds = 12;
const double flyingBirdIntervalReductionPerLevel = 0.5;

double challengeRoundObstacleSpeedMultiplier(int roundNumber) =>
    switch (roundNumber) {
      1 => 1,
      2 => 1.35,
      3 => 1.7,
      _ => throw RangeError.range(roundNumber, 1, 3, 'roundNumber'),
    };

double challengeRoundSpawnIntervalMultiplier(int roundNumber) =>
    switch (roundNumber) {
      1 => 1,
      2 => 0.85,
      3 => 0.7,
      _ => throw RangeError.range(roundNumber, 1, 3, 'roundNumber'),
    };

double flyingBirdIntervalForLevel(int level) {
  if (level < 1 || level > GameLevel.all.length) {
    throw RangeError.range(level, 1, GameLevel.all.length, 'level');
  }
  return baseFlyingBirdIntervalSeconds -
      (level - 1) * flyingBirdIntervalReductionPerLevel;
}

class GameFixedStepClock {
  double _remainder = 0;

  int consume(double elapsed) {
    _remainder += boundedGameFrameDelta(elapsed);
    final steps = ((_remainder + 1e-10) / gameSimulationStep).floor();
    _remainder = max(0, _remainder - steps * gameSimulationStep);
    return steps;
  }
}

Vector2 advanceFallingObjectPosition(Vector2 current, double speed, double dt) {
  if (!speed.isFinite || !dt.isFinite || speed <= 0 || dt <= 0) {
    return current.clone();
  }
  return current + Vector2(0, speed * dt);
}

Path buildPlayerBirdPath(Size size) {
  final path = Path()
    ..moveTo(size.width * 0.04, size.height * 0.59)
    ..lineTo(size.width * 0.27, size.height * 0.49)
    ..cubicTo(
      size.width * 0.25,
      size.height * 0.32,
      size.width * 0.43,
      size.height * 0.12,
      size.width * 0.63,
      size.height * 0.17,
    )
    ..cubicTo(
      size.width * 0.76,
      size.height * 0.18,
      size.width * 0.83,
      size.height * 0.27,
      size.width * 0.85,
      size.height * 0.33,
    )
    ..lineTo(size.width * 0.99, size.height * 0.39)
    ..lineTo(size.width * 0.84, size.height * 0.45)
    ..cubicTo(
      size.width * 0.86,
      size.height * 0.61,
      size.width * 0.75,
      size.height * 0.76,
      size.width * 0.58,
      size.height * 0.79,
    )
    ..cubicTo(
      size.width * 0.39,
      size.height * 0.82,
      size.width * 0.24,
      size.height * 0.73,
      size.width * 0.22,
      size.height * 0.61,
    )
    ..close();
  return path;
}

double boundedGameFrameDelta(double dt) {
  if (!dt.isFinite || dt <= 0) return 0;
  return min(dt, maxGameFrameDelta);
}

double gameSceneScrollOffset(double elapsed, int level, double width) {
  if (!elapsed.isFinite || elapsed < 0 || !width.isFinite || width <= 0) {
    return 0;
  }
  if (level < 1 || level > GameLevel.all.length) {
    throw RangeError.range(level, 1, GameLevel.all.length, 'level');
  }
  return (elapsed * (18 + level * 1.8)) % width;
}

int gameSnowParticleCountForLevel(int level) {
  if (level < 1 || level > GameLevel.all.length) {
    throw RangeError.range(level, 1, GameLevel.all.length, 'level');
  }
  return 18 + level * 2 + (level == 9 || level == 12 ? 18 : 0);
}

Vector2 clampGamePlayerTarget(Vector2 target, Vector2 gameSize) {
  const halfPlayer = Player.sizeS / 2;
  const topLimit = 112.0;
  final maxX = max(halfPlayer, gameSize.x - halfPlayer);
  final maxY = max(topLimit, gameSize.y - halfPlayer);
  return Vector2(
    target.x.clamp(halfPlayer, maxX).toDouble(),
    target.y.clamp(topLimit, maxY).toDouble(),
  );
}

Vector2 restoredGamePlayerPosition(
  Vector2 gameSize, {
  int? xMillionths,
  int? yMillionths,
}) {
  final x = xMillionths == null
      ? gameSize.x / 2
      : gameSize.x * (xMillionths.clamp(0, 1000000) / 1000000);
  final y = yMillionths == null
      ? gameSize.y - 80
      : gameSize.y * (yMillionths.clamp(0, 1000000) / 1000000);
  return clampGamePlayerTarget(Vector2(x, y), gameSize);
}

Vector2 advancePlayerPosition(
  Vector2 current,
  Vector2 target,
  double maxDistance,
) {
  if (!maxDistance.isFinite || maxDistance <= 0) return current.clone();
  final delta = target - current;
  final distance = delta.length;
  if (distance <= maxDistance || distance == 0) return target.clone();
  return current + delta * (maxDistance / distance);
}

class GamePositionPlayback {
  Vector2? _from;
  Vector2? _target;
  double _elapsed = 0;
  double _duration = 0;

  void retarget(Vector2 current, Vector2 target, double durationSeconds) {
    _from = current.clone();
    _target = target.clone();
    _elapsed = 0;
    _duration = durationSeconds.isFinite && durationSeconds > 0
        ? durationSeconds
        : 0;
    if (_duration == 0) {
      current.setFrom(target);
      _from = null;
      _target = null;
    }
  }

  void update(Vector2 position, double dt) {
    final from = _from;
    final target = _target;
    if (from == null || target == null) return;
    _elapsed = min(_elapsed + boundedGameFrameDelta(dt), _duration);
    final progress = (_elapsed / _duration).clamp(0.0, 1.0);
    position.setFrom(from + (target - from) * progress);
    if (_elapsed >= _duration) {
      _from = null;
      _target = null;
    }
  }
}

double clampGameAudioVolume(double volume) {
  if (!volume.isFinite) {
    throw ArgumentError.value(volume, 'volume', 'Must be a finite number.');
  }
  return volume.clamp(0.0, 1.0);
}

double effectiveGameAudioVolume(double volume, {required bool muted}) =>
    muted ? 0 : clampGameAudioVolume(volume);

bool shouldAutoValidateFinalGameLevel({
  required GameProgression progression,
  required int score,
  required double remainingSeconds,
}) =>
    progression.level == GameLevel.all.length &&
    progression.canCompleteWithinTimer(score, remainingSeconds);

enum GameSoundEffect {
  collision,
  shieldPickup,
  shieldBlock,
  bonus,
  score,
  demotion,
}

String gameMusicAssetForLevel(int level) {
  if (level < 1 || level > GameLevel.all.length) {
    throw RangeError.range(level, 1, GameLevel.all.length, 'level');
  }
  return GameLevel.all[level - 1].musicAsset;
}

GameLevel legendChallengeLandscapeForRound(int roundNumber) {
  if (roundNumber < 1 || roundNumber > GameLevel.challengeLandscapes.length) {
    throw RangeError.range(
      roundNumber,
      1,
      GameLevel.challengeLandscapes.length,
      'roundNumber',
    );
  }
  return GameLevel.challengeLandscapes[roundNumber - 1];
}

String legendChallengeMusicAssetForRound(int roundNumber) {
  if (roundNumber < 1 || roundNumber > challengeRoundDurationsSeconds.length) {
    throw RangeError.range(
      roundNumber,
      1,
      challengeRoundDurationsSeconds.length,
      'roundNumber',
    );
  }
  return 'sounds/legend_round_0$roundNumber.wav';
}

String legendChallengeVoiceAssetForRound(int roundNumber) {
  if (roundNumber < 1 || roundNumber > challengeRoundDurationsSeconds.length) {
    throw RangeError.range(
      roundNumber,
      1,
      challengeRoundDurationsSeconds.length,
      'roundNumber',
    );
  }
  return 'sounds/legend_round_0${roundNumber}_voice.wav';
}

String gameSoundEffectAsset(GameSoundEffect effect) => switch (effect) {
  GameSoundEffect.collision => 'sounds/collision.wav',
  GameSoundEffect.shieldPickup => 'sounds/shield_pickup.wav',
  GameSoundEffect.shieldBlock => 'sounds/shield_block.wav',
  GameSoundEffect.bonus => 'sounds/bonus.wav',
  GameSoundEffect.score => 'sounds/score.wav',
  GameSoundEffect.demotion => 'sounds/whistle.wav',
};

class NextGiftScoreBonus {
  bool _isArmed = false;

  bool get isArmed => _isArmed;

  void activate() {
    _isArmed = true;
  }

  int applyTo(int points) {
    if (!_isArmed) return points;
    _isArmed = false;
    return points * FopcamGame.scoreMultiplierValue;
  }

  void restoreFromMultiplier(double multiplier) {
    _isArmed = multiplier >= FopcamGame.scoreMultiplierValue;
  }
}

class FopcamGame extends FlameGame {
  static const int collisionPenalty = 1;
  static const int timeoutPenalty = 3;
  static const int shieldBonus = 3;
  static const int birdRewardPoints = 5;
  static const int birdTrapPenalty = 3;
  static const int successfulDodgePoints = 1;
  static const double shieldDurationSeconds = 6;
  static const int scoreMultiplierValue = 2;
  static Future<void> _musicQueue = Future<void>.value();
  static String? _activeMusicAsset;
  static const String _audioVolumeKey = 'game_audio_volume';
  static const String _audioEffectsVolumeKey = 'game_audio_effects_volume';
  static const String _audioMutedKey = 'game_audio_muted';
  static const double defaultGameVolume = 0.7;
  static const double defaultGameEffectsVolume = 0.7;
  static double _gameVolume = defaultGameVolume;
  static double _gameEffectsVolume = defaultGameEffectsVolume;
  static bool _gameMuted = false;
  static Future<void>? _audioSettingsLoadFuture;
  static bool _audioSettingsLoaded = false;
  static final Map<String, Future<AudioPool>> _soundPools = {};

  static double get gameVolume => _gameVolume;
  static double get gameEffectsVolume => _gameEffectsVolume;
  static bool get gameMuted => _gameMuted;
  static double get effectiveGameVolume =>
      effectiveGameAudioVolume(_gameVolume, muted: _gameMuted);
  static double get effectiveGameEffectsVolume =>
      effectiveGameAudioVolume(_gameEffectsVolume, muted: _gameMuted);

  static Future<void> loadAudioSettings() async {
    if (_audioSettingsLoaded) return;
    final pending = _audioSettingsLoadFuture;
    if (pending != null) return pending;

    final load = _loadAudioSettings();
    _audioSettingsLoadFuture = load;
    try {
      await load;
      _audioSettingsLoaded = true;
    } finally {
      if (identical(_audioSettingsLoadFuture, load)) {
        _audioSettingsLoadFuture = null;
      }
    }
  }

  static Future<void> _loadAudioSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final volume = prefs.getDouble(_audioVolumeKey);
    final effectsVolume = prefs.getDouble(_audioEffectsVolumeKey);
    _gameVolume = clampGameAudioVolume(volume ?? defaultGameVolume);
    _gameEffectsVolume = clampGameAudioVolume(
      effectsVolume ?? defaultGameEffectsVolume,
    );
    _gameMuted = prefs.getBool(_audioMutedKey) ?? false;
  }

  static Future<AudioPool> _soundPoolFor(String asset) async {
    final existing = _soundPools[asset];
    if (existing != null) return existing;

    FlameAudio.updatePrefix('assets/');
    final pending = FlameAudio.createPool(asset, maxPlayers: 3);
    _soundPools[asset] = pending;
    try {
      return await pending;
    } on Object {
      if (identical(_soundPools[asset], pending)) _soundPools.remove(asset);
      rethrow;
    }
  }

  static Future<void> prepareAudioForUserGesture({
    required int level,
    int? challengeRound,
  }) async {
    final asset = challengeRound == null
        ? gameMusicAssetForLevel(level)
        : legendChallengeMusicAssetForRound(challengeRound);
    await loadAudioSettings();
    await _queueMusicOperation(() async {
      FlameAudio.updatePrefix('assets/');
      await FlameAudio.bgm.initialize();
      await FlameAudio.bgm.audioPlayer.setReleaseMode(ReleaseMode.loop);
      await FlameAudio.bgm.audioPlayer.setVolume(effectiveGameVolume);
      await FlameAudio.bgm.audioPlayer.setSource(AssetSource(asset));
    });
  }

  static Future<void> resumeAudioFromUserGesture() async {
    await FlameAudio.bgm.audioPlayer.resume();
  }

  static Future<void> _queueMusicOperation(Future<void> Function() operation) {
    final next = _musicQueue.then((_) => operation());
    _musicQueue = next.catchError((Object error, StackTrace stackTrace) {
      debugPrint('Game music operation failed: $error\n$stackTrace');
    });
    return next;
  }

  static Future<void> _playLegendRoundAnnouncement(int roundNumber) async {
    try {
      final pool = await _soundPoolFor(
        legendChallengeVoiceAssetForRound(roundNumber),
      );
      await pool.start(volume: effectiveGameVolume);
    } on Object catch (error, stackTrace) {
      debugPrint(
        'Legend challenge round $roundNumber announcement failed: '
        '$error\n$stackTrace',
      );
    }
  }

  static Future<void> setGameVolume(double volume) async {
    await loadAudioSettings();
    _gameVolume = clampGameAudioVolume(volume);
    await _queueMusicOperation(
      () => FlameAudio.bgm.audioPlayer.setVolume(effectiveGameVolume),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_audioVolumeKey, _gameVolume);
  }

  static Future<void> setGameEffectsVolume(double volume) async {
    await loadAudioSettings();
    _gameEffectsVolume = clampGameAudioVolume(volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_audioEffectsVolumeKey, _gameEffectsVolume);
  }

  static Future<void> setGameMuted(bool muted) async {
    await loadAudioSettings();
    _gameMuted = muted;
    await _queueMusicOperation(
      () => FlameAudio.bgm.audioPlayer.setVolume(effectiveGameVolume),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_audioMutedKey, muted);
  }

  static Future<void> startGameMusic({
    required int level,
    int? challengeRound,
  }) async {
    final asset = challengeRound == null
        ? gameMusicAssetForLevel(level)
        : legendChallengeMusicAssetForRound(challengeRound);
    var startedNewTrack = false;
    await _queueMusicOperation(() async {
      try {
        if (_activeMusicAsset == asset && FlameAudio.bgm.isPlaying) return;
        FlameAudio.updatePrefix('assets/');
        await FlameAudio.bgm.initialize();
        await loadAudioSettings();
        await FlameAudio.bgm.play(asset, volume: effectiveGameVolume);
        _activeMusicAsset = asset;
        startedNewTrack = true;
      } on Object catch (error, stackTrace) {
        debugPrint('Game music failed to start ($asset): $error\n$stackTrace');
      }
    });
    if (challengeRound != null && startedNewTrack) {
      unawaited(_playLegendRoundAnnouncement(challengeRound));
    }
  }

  static Future<void> pauseGameMusic() => _queueMusicOperation(() async {
    try {
      if (FlameAudio.bgm.isPlaying) await FlameAudio.bgm.pause();
    } on Object catch (error, stackTrace) {
      debugPrint('Game music failed to pause: $error\n$stackTrace');
    }
  });

  static Future<void> resumeGameMusic({
    required int level,
    int? challengeRound,
  }) async {
    final asset = challengeRound == null
        ? gameMusicAssetForLevel(level)
        : legendChallengeMusicAssetForRound(challengeRound);
    await _queueMusicOperation(() async {
      try {
        await FlameAudio.bgm.initialize();
        await loadAudioSettings();
        if (_activeMusicAsset != asset) {
          FlameAudio.updatePrefix('assets/');
          await FlameAudio.bgm.play(asset, volume: effectiveGameVolume);
          _activeMusicAsset = asset;
        } else if (!FlameAudio.bgm.isPlaying) {
          await FlameAudio.bgm.resume();
        }
      } on Object catch (error, stackTrace) {
        debugPrint('Game music failed to resume ($asset): $error\n$stackTrace');
      }
    });
  }

  FopcamGame({
    this.playerName = 'Joueur',
    this.onRewardEarned,
    this.onRewardFailed,
    this.onChallengeEliminated,
    this.onChallengeRoundCompleted,
    this.isChallengeMode = false,
    this.challengeRoundNumber = 1,
    this.challengeRoundDurationSeconds = 50,
    this.challengeRoundStartedAt,
    this.isSpectatorMode = false,
    this.initialSpectatorState,
    this.initialChallengeRoundComplete = false,
    this.initialScore = 0,
    int initialLevel = 1,
    this.initialRemainingMilliseconds,
    this.initialPlayerXMillionths,
    this.initialPlayerYMillionths,
    this.initialDemotionReplay = false,
  }) : score = initialScore,
       _progression = GameProgression(
         level: isChallengeMode ? GameLevel.all.length : initialLevel,
       );

  static const String _pausedGameKey = 'paused_game_progress';
  static const String _pendingLevelTwelveRewardKey =
      'pending_level_twelve_reward_score';
  final String playerName;
  final Future<void> Function(String playerName, int score)? onRewardEarned;
  final Future<void> Function(Object error)? onRewardFailed;
  final Future<void> Function(int score)? onChallengeEliminated;
  final Future<void> Function(int roundNumber, int score)?
  onChallengeRoundCompleted;
  final bool isChallengeMode;
  final int challengeRoundNumber;
  final int challengeRoundDurationSeconds;
  final DateTime? challengeRoundStartedAt;
  final bool isSpectatorMode;
  final Map<String, dynamic>? initialSpectatorState;
  final bool initialChallengeRoundComplete;
  final int initialScore;
  final int? initialRemainingMilliseconds;
  final int? initialPlayerXMillionths;
  final int? initialPlayerYMillionths;
  final bool initialDemotionReplay;
  late Player _player;
  late TextComponent _scoreText;
  late TextComponent _bestText;
  late TextComponent _levelText;
  late TextComponent _progressText;
  late TextComponent _streakText;
  late TextComponent _powerupText;
  int score;
  int bestScore = 0;
  late SharedPreferences _prefs;
  double spawnTimer = 0.0;
  double spawnInterval = GameLevel.all.first.spawnInterval;
  final GameFixedStepClock _simulationClock = GameFixedStepClock();
  final Random _rand = Random();
  ui.Picture? _backdropPicture;
  Size? _backdropPictureSize;
  GameBackdrop? _backdropPictureTheme;
  double _sceneElapsed = 0;
  int _nextLiveObjectId = 1;
  int _nextLiveEventId = 1;
  final Map<int, PositionComponent> _spectatorObjects = {};
  final List<Map<String, dynamic>> _liveEvents = [];
  int _lastSpectatorEventId = 0;
  bool _hasSpectatorSnapshot = false;
  bool _spectatorReady = false;
  Map<String, dynamic>? _pendingSpectatorState;
  ui.Picture? _farmlandHillPicture;
  ui.Picture? _hillPicture;
  ui.Picture? _landmarkPicture;

  double powerupTimer = 0.0;
  final double powerupInterval = 8.0;
  double flyingBirdTimer = 0.0;
  bool shieldActive = false;
  double shieldRemaining = 0.0;
  final NextGiftScoreBonus _nextGiftScoreBonus = NextGiftScoreBonus();
  final GameProgression _progression;
  int get level => _progression.level;
  double get scoreMultiplier =>
      _nextGiftScoreBonus.isArmed ? scoreMultiplierValue.toDouble() : 1.0;
  bool _rewardClaimed = false;
  bool _rewardDispatched = false;
  bool _challengeEliminated = false;
  bool _challengeRoundFinished = false;
  double _challengeRemaining = 50;
  TextComponent? _challengeTimerText;
  int _activeChallengeRound = 1;
  DateTime? _activeChallengeRoundStartedAt;
  int get currentChallengeRound => _activeChallengeRound;
  double get challengeRemainingSeconds => _challengeRemaining;
  bool get hasSpectatorSnapshot => _hasSpectatorSnapshot;
  bool get isPlayerVisible => !isSpectatorMode;
  late double _levelRemainingSeconds;
  TextComponent? _levelTimerText;
  int _streak = 0;
  int? _recoverableLevel;
  bool _demotionReplay = false;

  GameLevel get currentLevel => GameLevel.all[level - 1];
  bool get challengeLost => _challengeEliminated;
  int? get recoverableLevel => _recoverableLevel;
  int get recoveryCost => _recoverableLevel == null
      ? 0
      : GameProgression.recoveryCostFor(_recoverableLevel!);
  bool get canRecoverLostLevel {
    final targetLevel = _recoverableLevel;
    return targetLevel != null &&
        GameProgression.scoreAfterRecovery(score, targetLevel) != null;
  }

  static Future<Map<String, int>?> loadPausedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pausedGameKey);
    if (raw == null) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Format de sauvegarde invalide.');
      }
      final score = decoded['score'];
      final level = decoded['level'];
      final remainingMilliseconds = decoded['remainingMilliseconds'];
      final remainingSeconds = decoded['remainingSeconds'];
      final playerXMillionths = decoded['playerXMillionths'];
      final playerYMillionths = decoded['playerYMillionths'];
      final demotionReplay = decoded['demotionReplay'];
      if (score is! int ||
          score < 0 ||
          level is! int ||
          level < 1 ||
          level > GameLevel.all.length ||
          (remainingMilliseconds != null &&
              (remainingMilliseconds is! int || remainingMilliseconds < 1)) ||
          (remainingSeconds != null &&
              (remainingSeconds is! int || remainingSeconds < 1)) ||
          (playerXMillionths != null &&
              (playerXMillionths is! int ||
                  playerXMillionths < 0 ||
                  playerXMillionths > 1000000)) ||
          (playerYMillionths != null &&
              (playerYMillionths is! int ||
                  playerYMillionths < 0 ||
                  playerYMillionths > 1000000)) ||
          (demotionReplay != null && demotionReplay is! bool)) {
        throw const FormatException('Progression sauvegardée invalide.');
      }
      final progress = <String, int>{
        'score': score,
        'level': level,
        'remainingMilliseconds':
            remainingMilliseconds as int? ??
            (remainingSeconds as int? ??
                    GameLevel.durationSecondsFor(
                      level,
                      replayAfterDemotion: demotionReplay == true,
                    )) *
                1000,
      };
      if (playerXMillionths != null) {
        progress['playerXMillionths'] = playerXMillionths as int;
      }
      if (playerYMillionths != null) {
        progress['playerYMillionths'] = playerYMillionths as int;
      }
      if (demotionReplay == true) progress['demotionReplay'] = 1;
      return progress;
    } on FormatException catch (error) {
      debugPrint('Game save is invalid and will be discarded: $error');
      await prefs.remove(_pausedGameKey);
      return null;
    }
  }

  static Future<void> clearPausedProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pausedGameKey);
  }

  static Future<int?> loadPendingLevelTwelveReward() async {
    final prefs = await SharedPreferences.getInstance();
    final score = prefs.getInt(_pendingLevelTwelveRewardKey);
    if (score == null) return null;
    if (score <
        GameProgression(level: GameLevel.all.length).validationThreshold) {
      debugPrint('Invalid pending level 12 reward score; discarding it.');
      await prefs.remove(_pendingLevelTwelveRewardKey);
      return null;
    }
    return score;
  }

  static Future<void> savePendingLevelTwelveReward(int score) async {
    final minimumScore = GameProgression(
      level: GameLevel.all.length,
    ).validationThreshold;
    if (score < minimumScore) {
      throw RangeError.range(score, minimumScore, null, 'score');
    }
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setInt(_pendingLevelTwelveRewardKey, score);
    if (!saved) {
      throw StateError(
        'La récompense n’a pas pu être conservée sur cet appareil.',
      );
    }
  }

  static Future<void> clearPendingLevelTwelveReward() async {
    final prefs = await SharedPreferences.getInstance();
    final removed = await prefs.remove(_pendingLevelTwelveRewardKey);
    if (!removed) {
      throw StateError(
        'La récompense synchronisée n’a pas pu être retirée de cet appareil.',
      );
    }
  }

  Future<void> savePausedProgress() async {
    if (isChallengeMode || _progression.isCompleted) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _pausedGameKey,
      jsonEncode({
        'score': score,
        'level': level,
        'remainingMilliseconds': max(
          1,
          (_levelRemainingSeconds * 1000).round(),
        ),
        'playerXMillionths': size.x <= 0
            ? 500000
            : (_player.position.x / size.x * 1000000).round().clamp(0, 1000000),
        'playerYMillionths': size.y <= 0
            ? 900000
            : (_player.position.y / size.y * 1000000).round().clamp(0, 1000000),
        'demotionReplay': _demotionReplay,
      }),
    );
  }

  void pauseForLater() {
    if (overlays.isActive('gamePaused') ||
        overlays.isActive('levelValidation') ||
        overlays.isActive('challengeComplete') ||
        _progression.isCompleted) {
      return;
    }
    pauseEngine();
    unawaited(pauseGameMusic());
    overlays.add('gamePaused');
    unawaited(savePausedProgress());
  }

  void resumeFromPause() {
    overlays.remove('gamePaused');
    resumeEngine();
    _resumeCurrentMusic();
  }

  void _resumeCurrentMusic() {
    unawaited(
      resumeGameMusic(
        level: level,
        challengeRound: isChallengeMode ? _activeChallengeRound : null,
      ),
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _prefs = await SharedPreferences.getInstance();
    bestScore = _prefs.getInt('best_score') ?? 0;
    _levelRemainingSeconds =
        (initialRemainingMilliseconds ??
            GameLevel.durationSecondsFor(
                  level,
                  replayAfterDemotion: initialDemotionReplay,
                ) *
                1000) /
        1000;
    _demotionReplay = initialDemotionReplay;
    _activeChallengeRound = challengeRoundNumber;
    _activeChallengeRoundStartedAt = challengeRoundStartedAt;
    _challengeRoundFinished = initialChallengeRoundComplete;
    _challengeRemaining = challengeRoundDurationSeconds.toDouble();
    if (isChallengeMode) {
      final startedAt = _activeChallengeRoundStartedAt;
      if (startedAt != null) {
        final elapsed = max(
          0.0,
          DateTime.now().difference(startedAt).inMilliseconds / 1000,
        );
        _challengeRemaining = max(
          0.0,
          challengeRoundDurationSeconds.toDouble() - elapsed,
        );
      }
    }
    _player = Player()
      ..position = restoredGamePlayerPosition(
        size,
        xMillionths: initialPlayerXMillionths,
        yMillionths: initialPlayerYMillionths,
      )
      ..anchor = Anchor.center;
    if (isPlayerVisible) add(_player);

    score = initialScore;
    _scoreText = TextComponent(
      text: 'Score: $score',
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.white, fontSize: 18),
      ),
    )..position = Vector2(8, 8);
    add(_scoreText);
    _bestText = TextComponent(
      text: 'Best: $bestScore',
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.amber, fontSize: 14),
      ),
    )..position = Vector2(8, 30);
    add(_bestText);

    _levelText = TextComponent(
      text: _levelLabel,
      textRenderer: TextPaint(
        style: TextStyle(
          color: currentLevel.accentColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    )..position = Vector2(size.x - 174, 8);
    add(_levelText);
    _progressText = TextComponent(
      text: '',
      textRenderer: TextPaint(
        style: TextStyle(
          color: currentLevel.accentColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    )..position = Vector2(size.x - 174, 27);
    add(_progressText);
    _updateLevelDisplay();
    if (!isChallengeMode) {
      _levelTimerText = TextComponent(
        text: _levelTimerLabel,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      )..position = Vector2(size.x - 174, 45);
      add(_levelTimerText!);
    }
    _streakText = TextComponent(
      text: '',
      textRenderer: TextPaint(
        style: const TextStyle(
          color: Colors.amberAccent,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    )..position = Vector2(8, 52);
    add(_streakText);
    _powerupText = TextComponent(
      text: '',
      textRenderer: TextPaint(
        style: const TextStyle(color: Colors.cyanAccent, fontSize: 14),
      ),
    )..position = Vector2(8, 74);
    add(_powerupText);
    if (isChallengeMode) {
      _challengeTimerText = TextComponent(
        text: _challengeRoundLabel,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      )..position = Vector2(size.x - 168, 52);
      add(_challengeTimerText!);
      if (!isSpectatorMode) {
        if (initialChallengeRoundComplete) {
          pauseEngine();
          overlays.add('challengeRoundComplete');
        } else if (_challengeRemaining <= 0) {
          _finishChallengeRound();
        }
      }
    }
    _spectatorReady = true;
    final initialState = _pendingSpectatorState ?? initialSpectatorState;
    _pendingSpectatorState = null;
    if (isSpectatorMode && initialState != null) {
      applySpectatorState(initialState);
    }
    unawaited(
      startGameMusic(
        level: level,
        challengeRound: isChallengeMode ? _activeChallengeRound : null,
      ),
    );
  }

  void _spawnScoreParticle(Vector2 pos) {
    final p = ScoreParticle(position: pos.clone());
    add(p);
  }

  void _spawnExplosion(Vector2 pos) {
    final p = ExplosionParticle(position: pos.clone());
    add(p);
  }

  void _spawnFloatingFeedback(Vector2 pos, String text, Color color) {
    add(FloatingFeedback(position: pos.clone(), text: text, color: color));
  }

  void _spawnPowerUp() {
    final types = ['shield', 'double'];
    final type = types[_rand.nextInt(types.length)];
    final x = _rand.nextDouble() * (size.x - 40) + 20;
    final p = PowerUp(liveObjectId: _nextLiveObjectId++, type: type)
      ..position = Vector2(x, -20)
      ..anchor = Anchor.center;
    add(p);
  }

  void _spawnFlyingBird() {
    final dropsReward = _rand.nextBool();
    final direction = _rand.nextBool() ? 1.0 : -1.0;
    final bird =
        FlyingBird(
            liveObjectId: _nextLiveObjectId++,
            dropsReward: dropsReward,
            direction: direction,
          )
          ..position = Vector2(
            direction > 0 ? -32 : size.x + 32,
            116 + _rand.nextDouble() * min(144, size.y * 0.24),
          )
          ..anchor = Anchor.center;
    add(bird);
  }

  void _spawnBirdDrop(Vector2 position, {required bool reward}) {
    final powerUp =
        PowerUp(
            liveObjectId: _nextLiveObjectId++,
            type: reward ? 'reward' : 'trap',
          )
          ..position = position.clone()
          ..anchor = Anchor.center;
    add(powerUp);
  }

  void _applyPowerUp(String type) {
    if (type == 'shield') {
      _recordLiveEvent('shield_pickup', _player.position);
      shieldActive = true;
      shieldRemaining = shieldDurationSeconds;
      final giftPoints = _nextGiftScoreBonus.applyTo(shieldBonus);
      increaseScore(giftPoints);
      _spawnFloatingFeedback(
        _player.position,
        '🎁 +$giftPoints points',
        Colors.lightGreenAccent,
      );
      _updatePowerupLabel();
      playSoundEffect(gameSoundEffectAsset(GameSoundEffect.shieldPickup));
    } else if (type == 'double') {
      _recordLiveEvent('bonus_pickup', _player.position);
      _nextGiftScoreBonus.activate();
      _updatePowerupLabel();
      playSoundEffect(gameSoundEffectAsset(GameSoundEffect.bonus));
    } else if (type == 'reward') {
      _recordLiveEvent('reward_pickup', _player.position);
      final giftPoints = _nextGiftScoreBonus.applyTo(birdRewardPoints);
      increaseScore(giftPoints);
      _spawnFloatingFeedback(
        _player.position,
        '+$giftPoints points',
        Colors.lightGreenAccent,
      );
      _updatePowerupLabel();
      playSoundEffect(gameSoundEffectAsset(GameSoundEffect.bonus));
    } else if (type == 'trap') {
      _recordLiveEvent('trap_pickup', _player.position);
      loseScore(birdTrapPenalty, demote: false);
      _spawnFloatingFeedback(
        _player.position,
        '-$birdTrapPenalty points',
        Colors.redAccent,
      );
      playSoundEffect(gameSoundEffectAsset(GameSoundEffect.collision));
    } else {
      throw ArgumentError.value(type, 'type', 'Unknown game power-up.');
    }
  }

  void _updatePowerupLabel() {
    if (shieldActive) {
      _powerupText.text = 'Shield: ${shieldRemaining.toStringAsFixed(0)}s';
    } else if (_nextGiftScoreBonus.isArmed) {
      _powerupText.text = 'Prochain cadeau x$scoreMultiplierValue';
    } else {
      _powerupText.text = '';
    }
  }

  void playSoundEffect(String asset) {
    unawaited(_playSoundEffect(asset));
  }

  Future<void> _playSoundEffect(String asset) async {
    try {
      final volume = effectiveGameEffectsVolume;
      if (volume == 0) return;
      final pool = await _soundPoolFor(asset);
      await pool.start(volume: volume);
    } on Object catch (error, stackTrace) {
      debugPrint('Game sound effect failed ($asset): $error\n$stackTrace');
    }
  }

  String get _levelLabel => 'Niv. $level · ${currentLevel.name}';
  String get _challengeRoundLabel =>
      _activeChallengeRoundStartedAt != null &&
          DateTime.now().isBefore(_activeChallengeRoundStartedAt!)
      ? 'Manche $_activeChallengeRound/3 · départ ${max(0, _activeChallengeRoundStartedAt!.difference(DateTime.now()).inSeconds + 1)} s'
      : 'Manche $_activeChallengeRound/3 · ${_challengeRemaining.ceil()} s';

  void _updateLevelDisplay() {
    final stage = currentLevel;
    spawnInterval =
        stage.spawnInterval *
        (isChallengeMode
            ? challengeRoundSpawnIntervalMultiplier(_activeChallengeRound)
            : 1);
    _levelText
      ..text = _levelLabel
      ..textRenderer = TextPaint(
        style: TextStyle(
          color: stage.accentColor,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
    _updateProgressDisplay();
  }

  void _updateProgressDisplay() {
    final threshold = _progression.validationThreshold;
    final progress = min(score, threshold);
    _progressText
      ..text = 'À valider : $progress / $threshold'
      ..textRenderer = TextPaint(
        style: TextStyle(
          color: currentLevel.accentColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
  }

  String get _levelTimerLabel => 'Temps : ${_levelRemainingSeconds.ceil()} s';

  void _resetLevelTimer() {
    _levelRemainingSeconds = GameLevel.durationSecondsFor(
      level,
      replayAfterDemotion: _demotionReplay,
    ).toDouble();
    _levelTimerText?.text = _levelTimerLabel;
  }

  void _handleLevelTimeout() {
    if (_progression.canCompleteWithinTimer(score, _levelRemainingSeconds)) {
      if (shouldAutoValidateFinalGameLevel(
        progression: _progression,
        score: score,
        remainingSeconds: _levelRemainingSeconds,
      )) {
        pauseEngine();
        validateCurrentLevel();
        return;
      }
      pauseEngine();
      unawaited(pauseGameMusic());
      overlays.add('levelValidation');
      return;
    }

    final failedLevel = level;
    _progression.resetCollisionCount();
    loseScore(timeoutPenalty);
    for (final obstacle in children.whereType<Obstacle>().toList()) {
      obstacle.removeFromParent();
    }
    for (final powerUp in children.whereType<PowerUp>().toList()) {
      powerUp.removeFromParent();
    }
    pauseEngine();
    unawaited(pauseGameMusic());
    overlays.add('levelTimeExpired');
    _levelTimerText?.text = 'Temps écoulé';
    _timedOutLevel = failedLevel;
  }

  int _timedOutLevel = 1;

  void retryAfterTimeout() {
    _recoverableLevel = null;
    _resetLevelTimer();
    overlays.remove('levelTimeExpired');
    resumeEngine();
    _resumeCurrentMusic();
  }

  bool recoverLostLevel() {
    final targetLevel = _recoverableLevel;
    if (targetLevel == null) return false;
    final recoveredScore = GameProgression.scoreAfterRecovery(
      score,
      targetLevel,
    );
    if (recoveredScore == null) return false;
    if (targetLevel != level + 1 || !_progression.recoverOneLevel()) {
      throw StateError('La récupération du niveau n’est plus disponible.');
    }

    score = recoveredScore;
    _scoreText.text = 'Score: $score';
    _recoverableLevel = null;
    _demotionReplay = false;
    _resetLevelTimer();
    _updateLevelDisplay();
    overlays.remove('levelDemoted');
    overlays.remove('levelTimeExpired');
    resumeEngine();
    _resumeCurrentMusic();
    return true;
  }

  void continueAfterDemotion() {
    _recoverableLevel = null;
    overlays.remove('levelDemoted');
    resumeEngine();
    _resumeCurrentMusic();
  }

  void validateCurrentLevel() {
    if (!_progression.validate(score)) return;
    _recoverableLevel = null;
    _demotionReplay = false;
    overlays.remove('levelValidation');
    _resetLevelTimer();
    _updateLevelDisplay();

    if (_progression.isCompleted) {
      unawaited(pauseGameMusic());
      unawaited(_dispatchLevelTwelveReward());
      return;
    }
    resumeEngine();
    _resumeCurrentMusic();
  }

  void recordSuccessfulDodge([Vector2? position]) {
    if (position != null) _recordLiveEvent('dodge', position);
    _streak++;
    _streakText.text = _streak >= 3 ? 'Série x$_streak !' : '';
    increaseScore(successfulDodgePoints);
  }

  Future<void> retryLevelTwelveReward() => _dispatchLevelTwelveReward();

  Future<void> _dispatchLevelTwelveReward() async {
    if (_rewardClaimed || _rewardDispatched) return;
    _rewardDispatched = true;
    final name = playerName.trim().isEmpty ? 'Joueur' : playerName.trim();
    try {
      var pendingRewardSaved = false;
      try {
        await savePendingLevelTwelveReward(score);
        pendingRewardSaved = true;
      } on Object catch (error, stackTrace) {
        debugPrint(
          'Unable to save pending game reward locally: $error\n$stackTrace',
        );
      }

      if (pendingRewardSaved) {
        try {
          await clearPausedProgress();
        } on Object catch (error, stackTrace) {
          debugPrint(
            'Unable to clear completed game progress: $error\n$stackTrace',
          );
        }
      }

      final claimReward = onRewardEarned;
      if (claimReward == null) {
        throw StateError(
          'Le service de synchronisation des récompenses est indisponible.',
        );
      }
      await claimReward(name, score);
      _rewardClaimed = true;
      try {
        await clearPausedProgress();
      } on Object catch (error, stackTrace) {
        debugPrint(
          'Unable to clear completed game progress: $error\n$stackTrace',
        );
      }
    } catch (error, stackTrace) {
      _rewardDispatched = false;
      debugPrint('Game reward sync failed: $error\n$stackTrace');
      final reportFailure = onRewardFailed;
      if (reportFailure != null) {
        await reportFailure(error);
      } else {
        rethrow;
      }
    }
  }

  int get timedOutLevel => _timedOutLevel;

  @override
  void update(double dt) {
    final elapsed = boundedGameFrameDelta(dt);
    if (elapsed == 0) return;
    _sceneElapsed += elapsed;
    if (isSpectatorMode) {
      final roundStartsAt = _activeChallengeRoundStartedAt;
      if (roundStartsAt == null || !DateTime.now().isBefore(roundStartsAt)) {
        _challengeRemaining = max(0, _challengeRemaining - elapsed);
      }
      _challengeTimerText?.text = _challengeRoundLabel;
      super.update(elapsed);
      return;
    }
    if (!_advanceTimers(elapsed)) return;
    final steps = _simulationClock.consume(elapsed);
    for (var step = 0; step < steps; step++) {
      super.update(gameSimulationStep);
      _advanceSimulation(gameSimulationStep);
    }
  }

  bool _advanceTimers(double dt) {
    if (isChallengeMode) {
      final roundStartsAt = _activeChallengeRoundStartedAt;
      if (roundStartsAt != null && DateTime.now().isBefore(roundStartsAt)) {
        _challengeTimerText?.text = _challengeRoundLabel;
        return false;
      }
      if (_challengeRemaining > 0) {
        _challengeRemaining = max(0, _challengeRemaining - dt);
        _challengeTimerText?.text = _challengeRoundLabel;
        if (_challengeRemaining == 0) {
          _finishChallengeRound();
          return false;
        }
      }
    }
    if (!isChallengeMode && _levelRemainingSeconds > 0) {
      _levelRemainingSeconds = max(0, _levelRemainingSeconds - dt);
      _levelTimerText?.text = _levelTimerLabel;
      if (_levelRemainingSeconds == 0) {
        _handleLevelTimeout();
        return false;
      }
    }
    if (shieldActive) {
      shieldRemaining -= dt;
      if (shieldRemaining <= 0) {
        shieldActive = false;
        _updatePowerupLabel();
      } else {
        _powerupText.text = 'Shield: ${shieldRemaining.toStringAsFixed(0)}s';
      }
    }
    return true;
  }

  void _advanceSimulation(double dt) {
    spawnTimer += dt;
    powerupTimer += dt;
    flyingBirdTimer += dt;

    while (spawnTimer >= spawnInterval) {
      spawnTimer -= spawnInterval;
      _spawnObstacle();
    }

    while (powerupTimer >= powerupInterval) {
      powerupTimer -= powerupInterval;
      if (_rand.nextDouble() < currentLevel.powerUpChance) {
        _spawnPowerUp();
      }
    }

    final birdInterval = flyingBirdIntervalForLevel(level);
    while (flyingBirdTimer >= birdInterval) {
      flyingBirdTimer -= birdInterval;
      _spawnFlyingBird();
    }
  }

  void _spawnObstacle() {
    final x = _rand.nextDouble() * (size.x - 40) + 20;
    final stage = currentLevel;
    final speed =
        stage.minObstacleSpeed +
        _rand.nextDouble() * (stage.maxObstacleSpeed - stage.minObstacleSpeed);
    final challengeSpeed = isChallengeMode
        ? speed * challengeRoundObstacleSpeedMultiplier(_activeChallengeRound)
        : speed;
    final obs =
        Obstacle(
            liveObjectId: _nextLiveObjectId++,
            speed: challengeSpeed,
            stage: stage,
          )
          ..position = Vector2(x, -20)
          ..anchor = Anchor.center;
    add(obs);
  }

  Color get levelColor => currentLevel.color;
  Color get levelAccentColor => currentLevel.accentColor;

  @override
  Color backgroundColor() => const Color(0xFF111820);

  @override
  void onRemove() {
    _backdropPicture?.dispose();
    _backdropPicture = null;
    _farmlandHillPicture?.dispose();
    _farmlandHillPicture = null;
    _hillPicture?.dispose();
    _hillPicture = null;
    _landmarkPicture?.dispose();
    _landmarkPicture = null;
    super.onRemove();
  }

  @override
  void render(Canvas canvas) {
    final stage = isChallengeMode
        ? legendChallengeLandscapeForRound(_activeChallengeRound)
        : currentLevel;
    _renderBackdrop(canvas, Size(size.x, size.y), stage);
    _renderHudBacking(canvas, Size(size.x, size.y), stage);
    super.render(canvas);
  }

  void _renderHudBacking(Canvas canvas, Size bounds, GameLevel stage) {
    final panel = Rect.fromLTWH(0, 0, bounds.width, 104);
    canvas.drawRect(panel, Paint()..color = gameHudBackgroundColor);
    canvas.drawLine(
      Offset(0, panel.bottom),
      Offset(bounds.width, panel.bottom),
      Paint()
        ..color = stage.accentColor.withValues(alpha: 0.68)
        ..strokeWidth = 2,
    );
  }

  void _renderBackdrop(Canvas canvas, Size bounds, GameLevel stage) {
    if (bounds.width <= 0 || bounds.height <= 0) return;
    if (_backdropPicture == null ||
        _backdropPictureSize != bounds ||
        _backdropPictureTheme != stage.backdrop) {
      _backdropPicture?.dispose();
      _farmlandHillPicture?.dispose();
      _hillPicture?.dispose();
      _landmarkPicture?.dispose();
      final recorder = ui.PictureRecorder();
      _paintBackdropBase(Canvas(recorder), bounds, stage);
      _backdropPicture = recorder.endRecording();
      final palette = _BackdropPalette.forTheme(stage.backdrop);
      _farmlandHillPicture = _recordLandscapeHill(
        bounds,
        bounds.height * 0.57 + bounds.height * 0.035,
        palette.farmland.withValues(alpha: 0.55),
        0.21,
      );
      _hillPicture = _recordLandscapeHill(
        bounds,
        bounds.height * 0.57 + bounds.height * 0.09,
        palette.hills,
        0.62,
      );
      final landmarkRecorder = ui.PictureRecorder();
      _drawThemeLandmarks(
        Canvas(landmarkRecorder),
        bounds,
        stage.backdrop,
        palette,
        bounds.height * 0.57,
      );
      _landmarkPicture = landmarkRecorder.endRecording();
      _backdropPictureSize = bounds;
      _backdropPictureTheme = stage.backdrop;
    }
    canvas.drawPicture(_backdropPicture!);
    _paintBackdrop(canvas, bounds, stage, _sceneElapsed);
  }

  ui.Picture _recordLandscapeHill(
    Size bounds,
    double baseline,
    Color color,
    double amplitude,
  ) {
    final recorder = ui.PictureRecorder();
    final path = Path()..moveTo(-bounds.width, bounds.height);
    const segments = 64;
    final period = bounds.width * 0.75;
    for (var step = 0; step <= segments; step++) {
      final x = -bounds.width + bounds.width * 3 * step / segments;
      final phase = x * 2 * pi / period;
      final y = baseline - sin(phase) * bounds.height * amplitude * 0.22;
      path.lineTo(x, y);
    }
    path
      ..lineTo(bounds.width * 2, bounds.height)
      ..close();
    Canvas(recorder).drawPath(path, Paint()..color = color);
    return recorder.endRecording();
  }

  void _paintBackdropBase(Canvas canvas, Size bounds, GameLevel stage) {
    final palette = _BackdropPalette.forTheme(stage.backdrop);
    final fullRect = Offset.zero & bounds;
    canvas.drawRect(
      fullRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [palette.skyTop, palette.skyBottom],
        ).createShader(fullRect),
    );
    canvas.drawCircle(
      Offset(bounds.width * 0.78, bounds.height * 0.22),
      min(bounds.width, bounds.height) * 0.065,
      Paint()..color = palette.sun.withValues(alpha: 0.82),
    );
  }

  void _paintBackdrop(
    Canvas canvas,
    Size bounds,
    GameLevel stage,
    double elapsed,
  ) {
    final palette = _BackdropPalette.forTheme(stage.backdrop);
    final horizon = bounds.height * 0.57;
    final levelScroll = gameSceneScrollOffset(
      elapsed,
      stage.number,
      bounds.width,
    );
    canvas
      ..save()
      ..translate(-levelScroll * 0.35, 0)
      ..drawPicture(_farmlandHillPicture!)
      ..restore()
      ..save()
      ..translate(-levelScroll, 0)
      ..drawPicture(_hillPicture!)
      ..restore();
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        horizon + bounds.height * 0.08,
        bounds.width,
        bounds.height,
      ),
      Paint()..color = palette.ground,
    );
    final landmarkScroll = (levelScroll * 1.6) % bounds.width;
    canvas.save();
    canvas.translate(-landmarkScroll, 0);
    canvas.drawPicture(_landmarkPicture!);
    canvas.translate(bounds.width, 0);
    canvas.drawPicture(_landmarkPicture!);
    canvas.restore();
    _drawWeather(canvas, bounds, stage, elapsed);
  }

  void _drawWeather(
    Canvas canvas,
    Size bounds,
    GameLevel stage,
    double elapsed,
  ) {
    final snowPaint = Paint()..color = const Color(0xDDF8FCFF);
    final particleHeight = bounds.height + 16;
    final particleWidth = bounds.width + 16;
    for (
      var index = 0;
      index < gameSnowParticleCountForLevel(stage.number);
      index++
    ) {
      final seedX = (index * 37 % 101) / 101;
      final seedY = (index * 61 % 97) / 97;
      final rawX = seedX * particleWidth - elapsed * (18 + index % 5 * 5);
      final rawY = seedY * particleHeight + elapsed * (25 + index % 7 * 8);
      final x = ((rawX % particleWidth) + particleWidth) % particleWidth - 8;
      final y = ((rawY % particleHeight) + particleHeight) % particleHeight - 8;
      final radius = 1.1 + (index % 4) * 0.55;
      canvas.drawCircle(Offset(x, y), radius, snowPaint);
    }

    final count = 8 + stage.number;
    switch (stage.backdrop) {
      case GameBackdrop.rainySeason:
        final rainPaint = Paint()
          ..color = const Color(0x99C7E7FF)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        for (var index = 0; index < count; index++) {
          final seedX = (index * 43 % 97) / 97;
          final seedY = (index * 29 % 89) / 89;
          final rawY = seedY * particleHeight + elapsed * 230;
          final y = ((rawY % particleHeight) + particleHeight) % particleHeight;
          final rawX = seedX * particleWidth - elapsed * 28;
          final x = ((rawX % particleWidth) + particleWidth) % particleWidth;
          canvas.drawLine(Offset(x, y), Offset(x - 4, y + 12), rainPaint);
        }
      case GameBackdrop.orchard:
      case GameBackdrop.harvest:
      case GameBackdrop.goldenLands:
        final leafPaint = Paint()..color = const Color(0xB8F59E0B);
        for (var index = 0; index < count; index++) {
          final seedX = (index * 31 % 101) / 101;
          final seedY = (index * 47 % 103) / 103;
          final rawY = seedY * particleHeight + elapsed * (35 + index % 4 * 9);
          final y = ((rawY % particleHeight) + particleHeight) % particleHeight;
          final rawX = seedX * particleWidth - elapsed * (22 + index % 3 * 8);
          final x = ((rawX % particleWidth) + particleWidth) % particleWidth;
          canvas.drawOval(
            Rect.fromCenter(center: Offset(x, y), width: 5, height: 9),
            leafPaint,
          );
        }
      case GameBackdrop.redLands:
      case GameBackdrop.savannah:
        final dustPaint = Paint()..color = const Color(0x88FCD34D);
        for (var index = 0; index < count; index++) {
          final seedX = (index * 31 % 101) / 101;
          final seedY = (index * 47 % 103) / 103;
          final rawY = seedY * particleHeight - elapsed * (12 + index % 4 * 5);
          final y = ((rawY % particleHeight) + particleHeight) % particleHeight;
          final rawX = seedX * particleWidth - elapsed * 16;
          final x = ((rawX % particleWidth) + particleWidth) % particleWidth;
          canvas.drawCircle(Offset(x, y), 1.5 + index % 3, dustPaint);
        }
      case GameBackdrop.nursery:
      case GameBackdrop.sprouts:
      case GameBackdrop.garden:
        final pollenPaint = Paint()..color = const Color(0xB8FDE68A);
        for (var index = 0; index < count; index++) {
          final seedX = (index * 31 % 101) / 101;
          final seedY = (index * 47 % 103) / 103;
          final rawY = seedY * particleHeight + elapsed * (12 + index % 3 * 5);
          final y = ((rawY % particleHeight) + particleHeight) % particleHeight;
          final rawX = seedX * particleWidth - elapsed * 10;
          final x = ((rawX % particleWidth) + particleWidth) % particleWidth;
          canvas.drawCircle(Offset(x, y), 1.7, pollenPaint);
        }
      case GameBackdrop.highlands:
      case GameBackdrop.market:
      case GameBackdrop.legend:
      case GameBackdrop.duelCoast:
      case GameBackdrop.duelBaobabValley:
      case GameBackdrop.duelRiverOasis:
        break;
    }
  }

  void _drawThemeLandmarks(
    Canvas canvas,
    Size bounds,
    GameBackdrop theme,
    _BackdropPalette palette,
    double horizon,
  ) {
    final foreground = Paint()..color = palette.foreground;
    final detail = Paint()
      ..color = palette.detail
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    switch (theme) {
      case GameBackdrop.nursery:
      case GameBackdrop.sprouts:
      case GameBackdrop.garden:
      case GameBackdrop.harvest:
      case GameBackdrop.goldenLands:
        for (var index = 0; index < 7; index++) {
          final x = bounds.width * (0.08 + index * 0.14);
          final height = bounds.height * (0.075 + (index % 3) * 0.018);
          final base = horizon + bounds.height * 0.36;
          canvas.drawLine(Offset(x, base), Offset(x, base - height), detail);
          canvas.drawLine(
            Offset(x, base - height * 0.45),
            Offset(x - bounds.width * 0.035, base - height * 0.67),
            detail,
          );
          canvas.drawLine(
            Offset(x, base - height * 0.62),
            Offset(x + bounds.width * 0.035, base - height * 0.8),
            detail,
          );
          if (theme == GameBackdrop.garden ||
              theme == GameBackdrop.harvest ||
              theme == GameBackdrop.goldenLands) {
            canvas.drawCircle(
              Offset(x, base - height),
              bounds.width * 0.009,
              foreground,
            );
          }
        }
        for (var row = 0; row < 4; row++) {
          final y = horizon + bounds.height * (0.15 + row * 0.075);
          canvas.drawLine(
            Offset(0, y),
            Offset(bounds.width, y),
            Paint()
              ..color = palette.detail.withValues(alpha: 0.28)
              ..strokeWidth = 1,
          );
        }
      case GameBackdrop.duelCoast:
        final water = Paint()
          ..color = palette.detail.withValues(alpha: 0.58)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        for (var wave = 0; wave < 7; wave++) {
          final y = horizon + bounds.height * (0.12 + wave * 0.034);
          final path = Path()..moveTo(0, y);
          for (var step = 0; step <= 12; step++) {
            final x = bounds.width * step / 12;
            path.lineTo(
              x,
              y + sin(step * pi / 2 + wave) * bounds.height * 0.008,
            );
          }
          canvas.drawPath(path, water);
        }
        final shoreline = Path()
          ..moveTo(0, horizon + bounds.height * 0.29)
          ..cubicTo(
            bounds.width * 0.22,
            horizon + bounds.height * 0.21,
            bounds.width * 0.48,
            horizon + bounds.height * 0.34,
            bounds.width * 0.68,
            horizon + bounds.height * 0.27,
          )
          ..cubicTo(
            bounds.width * 0.82,
            horizon + bounds.height * 0.23,
            bounds.width * 0.9,
            horizon + bounds.height * 0.28,
            bounds.width,
            horizon + bounds.height * 0.22,
          )
          ..lineTo(bounds.width, bounds.height)
          ..lineTo(0, bounds.height)
          ..close();
        canvas.drawPath(
          shoreline,
          Paint()..color = palette.farmland.withValues(alpha: 0.88),
        );
        final foam = Paint()
          ..color = const Color(0xBFF4FFF6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        for (var wave = 0; wave < 5; wave++) {
          final y = horizon + bounds.height * (0.25 + wave * 0.045);
          final path = Path()
            ..moveTo(bounds.width * 0.04, y)
            ..cubicTo(
              bounds.width * 0.28,
              y - bounds.height * 0.012,
              bounds.width * 0.52,
              y + bounds.height * 0.012,
              bounds.width * 0.78,
              y,
            );
          canvas.drawPath(path, foam);
        }
        for (final xRatio in [0.14, 0.82]) {
          final x = bounds.width * xRatio;
          final cliff = Path()
            ..moveTo(x - bounds.width * 0.15, horizon + bounds.height * 0.23)
            ..lineTo(x - bounds.width * 0.07, horizon - bounds.height * 0.08)
            ..lineTo(x + bounds.width * 0.035, horizon - bounds.height * 0.025)
            ..lineTo(x + bounds.width * 0.14, horizon + bounds.height * 0.23)
            ..close();
          canvas.drawPath(cliff, foreground);
          final shadowFace = Path()
            ..moveTo(x, horizon - bounds.height * 0.08)
            ..lineTo(x + bounds.width * 0.035, horizon - bounds.height * 0.025)
            ..lineTo(x + bounds.width * 0.14, horizon + bounds.height * 0.23)
            ..lineTo(x + bounds.width * 0.045, horizon + bounds.height * 0.23)
            ..close();
          canvas.drawPath(
            shadowFace,
            Paint()..color = palette.hills.withValues(alpha: 0.72),
          );
          canvas.drawLine(
            Offset(x - bounds.width * 0.065, horizon - bounds.height * 0.065),
            Offset(x + bounds.width * 0.03, horizon - bounds.height * 0.008),
            detail,
          );
        }
        for (var bird = 0; bird < 4; bird++) {
          final x = bounds.width * (0.31 + bird * 0.095);
          final y = horizon - bounds.height * (0.2 + (bird % 2) * 0.06);
          final path = Path()
            ..moveTo(x - bounds.width * 0.018, y)
            ..quadraticBezierTo(
              x,
              y - bounds.height * 0.016,
              x + bounds.width * 0.018,
              y,
            );
          canvas.drawPath(path, detail);
        }
      case GameBackdrop.duelBaobabValley:
        final distantTree = Paint()
          ..color = palette.hills.withValues(alpha: 0.82);
        for (final xRatio in [0.35, 0.52, 0.64]) {
          final x = bounds.width * xRatio;
          final canopy = Path()
            ..moveTo(x - bounds.width * 0.08, horizon + bounds.height * 0.015)
            ..quadraticBezierTo(
              x,
              horizon - bounds.height * 0.055,
              x + bounds.width * 0.08,
              horizon + bounds.height * 0.015,
            )
            ..close();
          canvas.drawPath(canopy, distantTree);
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(x, horizon + bounds.height * 0.065),
              width: bounds.width * 0.018,
              height: bounds.height * 0.1,
            ),
            distantTree,
          );
        }
        for (final xRatio in [0.16, 0.72, 0.91]) {
          final x = bounds.width * xRatio;
          final base = horizon + bounds.height * 0.31;
          final trunk = Path()
            ..moveTo(x - bounds.width * 0.035, base)
            ..lineTo(x - bounds.width * 0.023, horizon - bounds.height * 0.03)
            ..lineTo(x + bounds.width * 0.024, horizon - bounds.height * 0.03)
            ..lineTo(x + bounds.width * 0.042, base)
            ..close();
          canvas.drawPath(trunk, foreground);
          final canopy = Path()
            ..moveTo(x - bounds.width * 0.17, horizon - bounds.height * 0.025)
            ..quadraticBezierTo(
              x - bounds.width * 0.14,
              horizon - bounds.height * 0.11,
              x - bounds.width * 0.07,
              horizon - bounds.height * 0.075,
            )
            ..quadraticBezierTo(
              x,
              horizon - bounds.height * 0.15,
              x + bounds.width * 0.07,
              horizon - bounds.height * 0.075,
            )
            ..quadraticBezierTo(
              x + bounds.width * 0.14,
              horizon - bounds.height * 0.11,
              x + bounds.width * 0.17,
              horizon - bounds.height * 0.025,
            )
            ..close();
          canvas.drawPath(canopy, foreground);
          for (var root = -2; root <= 2; root++) {
            canvas.drawLine(
              Offset(
                x + root * bounds.width * 0.012,
                base - bounds.height * 0.025,
              ),
              Offset(x + root * bounds.width * 0.03, base),
              detail,
            );
          }
        }
        for (var grass = 0; grass < 24; grass++) {
          final x = bounds.width * ((grass * 41 % 97) / 97);
          final base = horizon + bounds.height * (0.18 + (grass % 3) * 0.025);
          canvas.drawLine(
            Offset(x, base),
            Offset(x + bounds.width * 0.008, base - bounds.height * 0.035),
            detail,
          );
        }
        final rockPaint = Paint()
          ..color = palette.detail.withValues(alpha: 0.65);
        for (var rock = 0; rock < 8; rock++) {
          final x = bounds.width * ((rock * 29 % 89) / 89);
          final y = horizon + bounds.height * (0.28 + (rock % 3) * 0.12);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x, y),
              width: bounds.width * (0.018 + rock % 2 * 0.008),
              height: bounds.height * 0.012,
            ),
            rockPaint,
          );
        }
      case GameBackdrop.duelRiverOasis:
        final river = Path()
          ..moveTo(bounds.width * 0.24, horizon)
          ..cubicTo(
            bounds.width * 0.72,
            horizon + bounds.height * 0.08,
            bounds.width * 0.2,
            horizon + bounds.height * 0.24,
            bounds.width * 0.58,
            horizon + bounds.height * 0.43,
          )
          ..lineTo(bounds.width * 0.94, bounds.height)
          ..lineTo(bounds.width * 0.2, bounds.height)
          ..cubicTo(
            bounds.width * 0.08,
            horizon + bounds.height * 0.24,
            bounds.width * 0.62,
            horizon + bounds.height * 0.13,
            bounds.width * 0.24,
            horizon,
          )
          ..close();
        canvas.drawPath(river, Paint()..color = palette.detail);
        for (var reflection = 0; reflection < 12; reflection++) {
          final x = bounds.width * (0.34 + (reflection % 4) * 0.09);
          final y = horizon + bounds.height * (0.1 + reflection * 0.034);
          canvas.drawLine(
            Offset(x, y),
            Offset(x + bounds.width * (0.025 + reflection % 3 * 0.01), y),
            Paint()
              ..color = palette.sun.withValues(alpha: 0.45)
              ..strokeWidth = 2,
          );
        }
        for (final xRatio in [0.1, 0.82]) {
          final x = bounds.width * xRatio;
          final base = horizon + bounds.height * 0.3;
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(x, horizon + bounds.height * 0.13),
              width: bounds.width * 0.018,
              height: bounds.height * 0.28,
            ),
            foreground,
          );
          for (var frond = 0; frond < 7; frond++) {
            final angle = -pi + frond * pi / 6;
            final tip = Offset(
              x + cos(angle) * bounds.width * 0.1,
              horizon + sin(angle) * bounds.height * 0.085,
            );
            canvas.drawLine(Offset(x, horizon), tip, detail);
          }
          canvas.drawLine(
            Offset(x - bounds.width * 0.035, base),
            Offset(x + bounds.width * 0.035, base),
            detail,
          );
        }
        final reedPaint = Paint()
          ..color = palette.foreground.withValues(alpha: 0.78)
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        for (var cluster = 0; cluster < 7; cluster++) {
          final x = bounds.width * (0.06 + cluster * 0.14);
          final y = horizon + bounds.height * (0.31 + cluster % 2 * 0.06);
          for (var stem = -1; stem <= 1; stem++) {
            final top = Offset(
              x + stem * bounds.width * 0.012,
              y - bounds.height * (0.035 + (stem + 1) * 0.006),
            );
            canvas.drawLine(Offset(x, y), top, reedPaint);
            canvas.drawOval(
              Rect.fromCenter(
                center: top,
                width: bounds.width * 0.012,
                height: bounds.height * 0.006,
              ),
              Paint()..color = palette.detail,
            );
          }
        }
      case GameBackdrop.rainySeason:
        for (var cloud = 0; cloud < 3; cloud++) {
          final x = bounds.width * (0.2 + cloud * 0.3);
          final y = bounds.height * (0.16 + (cloud % 2) * 0.07);
          final cloudPaint = Paint()
            ..color = palette.sun.withValues(alpha: 0.52);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x, y),
              width: bounds.width * 0.15,
              height: bounds.height * 0.045,
            ),
            cloudPaint,
          );
          for (var drop = -1; drop <= 1; drop++) {
            canvas.drawLine(
              Offset(x + drop * bounds.width * 0.04, y + bounds.height * 0.03),
              Offset(
                x + drop * bounds.width * 0.045,
                y + bounds.height * 0.075,
              ),
              detail,
            );
          }
        }
        for (var crop = 0; crop < 5; crop++) {
          final x = bounds.width * (0.12 + crop * 0.18);
          final base = horizon + bounds.height * 0.34;
          canvas.drawLine(
            Offset(x, base),
            Offset(x, base - bounds.height * 0.085),
            detail,
          );
          canvas.drawLine(
            Offset(x, base - bounds.height * 0.04),
            Offset(x - bounds.width * 0.035, base - bounds.height * 0.065),
            detail,
          );
          canvas.drawLine(
            Offset(x, base - bounds.height * 0.055),
            Offset(x + bounds.width * 0.035, base - bounds.height * 0.08),
            detail,
          );
        }
      case GameBackdrop.orchard:
        for (var index = 0; index < 5; index++) {
          final x = bounds.width * (0.1 + index * 0.2);
          final base = horizon + bounds.height * (0.28 + (index % 2) * 0.04);
          final trunkWidth = bounds.width * 0.018;
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(x, base - bounds.height * 0.09),
              width: trunkWidth,
              height: bounds.height * 0.2,
            ),
            foreground,
          );
          for (var leaf = -1; leaf <= 1; leaf++) {
            canvas.drawCircle(
              Offset(
                x + leaf * bounds.width * 0.035,
                base - bounds.height * (0.2 + (leaf == 0 ? 0.035 : 0)),
              ),
              bounds.width * 0.045,
              Paint()..color = palette.detail,
            );
          }
          canvas.drawCircle(
            Offset(x, base - bounds.height * 0.19),
            bounds.width * 0.012,
            Paint()..color = palette.sun,
          );
        }
      case GameBackdrop.redLands:
      case GameBackdrop.savannah:
        for (final xRatio in [0.18, 0.79]) {
          final x = bounds.width * xRatio;
          final base = horizon + bounds.height * 0.27;
          final trunk = Path()
            ..moveTo(x - bounds.width * 0.016, base)
            ..lineTo(x - bounds.width * 0.009, horizon)
            ..lineTo(x + bounds.width * 0.014, horizon)
            ..lineTo(x + bounds.width * 0.022, base)
            ..close();
          canvas.drawPath(trunk, foreground);
          canvas.drawLine(
            Offset(x, horizon + bounds.height * 0.035),
            Offset(x - bounds.width * 0.055, horizon - bounds.height * 0.04),
            detail,
          );
          canvas.drawLine(
            Offset(x, horizon + bounds.height * 0.035),
            Offset(x + bounds.width * 0.06, horizon - bounds.height * 0.045),
            detail,
          );
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x, horizon - bounds.height * 0.045),
              width: bounds.width * 0.19,
              height: bounds.height * 0.045,
            ),
            foreground,
          );
          for (var blade = -2; blade <= 2; blade++) {
            canvas.drawLine(
              Offset(x + blade * bounds.width * 0.028, base),
              Offset(
                x + blade * bounds.width * 0.036,
                base - bounds.height * 0.045,
              ),
              detail,
            );
          }
        }
      case GameBackdrop.highlands:
        for (var index = 0; index < 4; index++) {
          final left = bounds.width * (index * 0.28 - 0.04);
          final peak = Offset(
            left + bounds.width * 0.16,
            horizon - bounds.height * (0.12 + (index % 2) * 0.1),
          );
          final path = Path()
            ..moveTo(left, horizon + bounds.height * 0.1)
            ..lineTo(peak.dx, peak.dy)
            ..lineTo(left + bounds.width * 0.33, horizon + bounds.height * 0.1)
            ..close();
          canvas.drawPath(path, foreground);
          final snow = Path()
            ..moveTo(
              peak.dx - bounds.width * 0.045,
              peak.dy + bounds.height * 0.05,
            )
            ..lineTo(peak.dx, peak.dy)
            ..lineTo(
              peak.dx + bounds.width * 0.05,
              peak.dy + bounds.height * 0.05,
            )
            ..lineTo(
              peak.dx + bounds.width * 0.018,
              peak.dy + bounds.height * 0.04,
            )
            ..lineTo(peak.dx, peak.dy + bounds.height * 0.065)
            ..lineTo(
              peak.dx - bounds.width * 0.02,
              peak.dy + bounds.height * 0.04,
            )
            ..close();
          canvas.drawPath(snow, Paint()..color = palette.sun);
        }
      case GameBackdrop.market:
        for (var index = 0; index < 3; index++) {
          final x = bounds.width * (0.12 + index * 0.32);
          final top = horizon + bounds.height * 0.14;
          final width = bounds.width * 0.22;
          final booth = Rect.fromLTWH(x, top, width, bounds.height * 0.23);
          canvas.drawRect(booth, foreground);
          canvas.drawRect(
            Rect.fromLTWH(
              x - width * 0.08,
              top,
              width * 1.16,
              bounds.height * 0.055,
            ),
            Paint()..color = palette.detail,
          );
          for (var stripe = 0; stripe < 4; stripe++) {
            canvas.drawRect(
              Rect.fromLTWH(
                x + stripe * width * 0.25,
                top,
                width * 0.125,
                bounds.height * 0.055,
              ),
              Paint()..color = palette.sun.withValues(alpha: 0.8),
            );
          }
        }
      case GameBackdrop.legend:
        final center = Offset(
          bounds.width * 0.5,
          horizon - bounds.height * 0.04,
        );
        for (var ring = 0; ring < 4; ring++) {
          canvas.drawCircle(
            center,
            bounds.width * (0.12 + ring * 0.06),
            Paint()
              ..color = palette.detail.withValues(alpha: 0.45 - ring * 0.08)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
        for (var ray = 0; ray < 12; ray++) {
          final angle = ray * pi / 6;
          canvas.drawLine(
            center,
            Offset(
              center.dx + cos(angle) * bounds.width * 0.4,
              center.dy + sin(angle) * bounds.width * 0.4,
            ),
            Paint()
              ..color = palette.sun.withValues(alpha: 0.38)
              ..strokeWidth = 2,
          );
        }
    }
  }

  void recordCollision(Vector2 position) {
    _recordLiveEvent('collision', position);
    final previousLevel = level;
    final shouldDemote = _progression.registerCollision();
    loseScore(collisionPenalty, demote: shouldDemote);
    if (level < previousLevel) {
      if (isChallengeMode) {
        _finishChallengeAfterDemotion();
        return;
      }
      _spawnFloatingFeedback(
        position,
        'Niveau rétrogradé',
        Colors.orangeAccent,
      );
      pauseEngine();
      unawaited(pauseGameMusic());
      overlays.add('levelDemoted');
    }
  }

  void increaseScore(int delta) {
    score += delta;
    _scoreText.text = 'Score: $score';
    _updateProgressDisplay();
    if (score > bestScore) {
      bestScore = score;
      _bestText.text = 'Best: $bestScore';
      _prefs.setInt('best_score', bestScore);
    }
  }

  void loseScore(int penalty, {bool demote = true}) {
    final previousLevel = level;
    _streak = 0;
    _streakText.text = '';
    score = demote
        ? _progression.fail(score, penalty)
        : max(0, score - penalty);
    _scoreText.text = 'Score: $score';
    if (level != previousLevel) {
      if (!isChallengeMode) {
        _recoverableLevel = previousLevel;
        _demotionReplay = true;
        _resetLevelTimer();
      }
      playSoundEffect(gameSoundEffectAsset(GameSoundEffect.demotion));
      _updateLevelDisplay();
    }
  }

  void _finishChallengeAfterDemotion() {
    if (_challengeEliminated) return;
    _challengeEliminated = true;
    pauseEngine();
    unawaited(pauseGameMusic());
    overlays.add('challengeComplete');
    final callback = onChallengeEliminated;
    if (callback != null) unawaited(callback(score));
  }

  void _finishChallengeRound() {
    if (_challengeRoundFinished || _challengeEliminated) return;
    _challengeRoundFinished = true;
    pauseEngine();
    unawaited(pauseGameMusic());
    overlays.add('challengeRoundComplete');
    final callback = onChallengeRoundCompleted;
    if (callback != null) {
      unawaited(callback(_activeChallengeRound, score));
    }
  }

  void startChallengeRound({
    required int roundNumber,
    required int durationSeconds,
    required DateTime startedAt,
  }) {
    if (roundNumber < 1 ||
        roundNumber > challengeRoundDurationsSeconds.length) {
      throw RangeError.range(
        roundNumber,
        1,
        challengeRoundDurationsSeconds.length,
        'roundNumber',
      );
    }
    if (durationSeconds != challengeRoundDurationsSeconds[roundNumber - 1]) {
      throw ArgumentError.value(
        durationSeconds,
        'durationSeconds',
        'Round duration does not match the configured challenge round.',
      );
    }
    _activeChallengeRound = roundNumber;
    _challengeRoundFinished = false;
    _activeChallengeRoundStartedAt = startedAt;
    _progression.resetCollisionCount();
    final elapsed = max(
      0.0,
      DateTime.now().difference(startedAt).inMilliseconds / 1000,
    );
    _challengeRemaining = max(0.0, durationSeconds.toDouble() - elapsed);
    spawnTimer = 0;
    _updateLevelDisplay();
    _challengeTimerText?.text = _challengeRoundLabel;
    overlays.remove('challengeRoundComplete');
    if (_challengeRemaining <= 0) {
      _finishChallengeRound();
    } else {
      unawaited(startGameMusic(level: level, challengeRound: roundNumber));
      resumeEngine();
    }
  }

  void completeChallengeFromServer() {
    overlays.remove('challengeRoundComplete');
    if (overlays.isActive('challengeComplete')) return;
    pauseEngine();
    unawaited(pauseGameMusic());
    overlays.add('challengeComplete');
  }

  void movePlayerTo(double x, [double? y]) {
    if (isSpectatorMode) return;
    _player.moveTo(x, y);
  }

  Map<String, dynamic> spectatorState() {
    final gameWidth = size.x;
    final gameHeight = size.y;
    double normalized(double value, double extent) =>
        extent <= 0 ? 0 : (value / extent).clamp(0, 1).toDouble();

    final objects = <Map<String, dynamic>>[
      for (final obstacle in children.whereType<Obstacle>())
        {
          'id': obstacle.liveObjectId,
          'x': normalized(obstacle.position.x, gameWidth),
          'y': normalized(obstacle.position.y, gameHeight),
          'type': 'obstacle',
        },
      for (final powerUp in children.whereType<PowerUp>())
        {
          'id': powerUp.liveObjectId,
          'x': normalized(powerUp.position.x, gameWidth),
          'y': normalized(powerUp.position.y, gameHeight),
          'type': powerUp.type == 'double' ? 'bonus' : powerUp.type,
        },
      for (final bird in children.whereType<FlyingBird>())
        {
          'id': bird.liveObjectId,
          'x': normalized(bird.position.x, gameWidth),
          'y': normalized(bird.position.y, gameHeight),
          'type': bird.dropsReward ? 'reward_bird' : 'trap_bird',
          'direction': bird.direction,
        },
    ];
    return {
      'round_number': _activeChallengeRound,
      'score': score,
      'remaining_seconds': _challengeRemaining.clamp(0, 50).toDouble(),
      'player_x': normalized(_player.position.x, gameWidth),
      'player_y': normalized(_player.position.y, gameHeight),
      'player_target_x': normalized(_player.intendedPosition.x, gameWidth),
      'player_target_y': normalized(_player.intendedPosition.y, gameHeight),
      'shield_active': shieldActive,
      'score_multiplier': scoreMultiplier,
      'objects': objects.take(60).toList(),
      'events': _liveEvents
          .map((event) => Map<String, dynamic>.from(event))
          .toList(),
    };
  }

  void _recordLiveEvent(String type, Vector2 position) {
    if (isSpectatorMode || size.x <= 0 || size.y <= 0) return;
    double normalized(double value, double extent) =>
        (value / extent).clamp(0, 1).toDouble();
    _liveEvents.add({
      'id': _nextLiveEventId++,
      'type': type,
      'x': normalized(position.x, size.x),
      'y': normalized(position.y, size.y),
    });
    if (_liveEvents.length > 8) _liveEvents.removeAt(0);
  }

  void applySpectatorState(Map<String, dynamic> state) {
    if (!isSpectatorMode) {
      throw StateError('Les snapshots sont réservés au mode spectateur.');
    }
    if (!_spectatorReady) {
      _pendingSpectatorState = Map<String, dynamic>.from(state);
      return;
    }
    final roundNumber = state['round_number'];
    final liveScore = state['score'];
    final remainingSeconds = state['remaining_seconds'];
    final playerX = state['player_x'];
    final playerY = state['player_y'];
    final rawObjects = state['objects'];
    if (roundNumber is! int ||
        roundNumber < 1 ||
        roundNumber > challengeRoundDurationsSeconds.length ||
        liveScore is! int ||
        remainingSeconds is! num ||
        playerX is! num ||
        playerY is! num ||
        rawObjects is! List) {
      throw const FormatException('Snapshot de duel invalide.');
    }
    _activeChallengeRound = roundNumber;
    score = liveScore;
    _scoreText.text = 'Score: $score';
    _challengeRemaining = remainingSeconds
        .toDouble()
        .clamp(0, challengeRoundDurationsSeconds[roundNumber - 1])
        .toDouble();
    _challengeTimerText?.text = _challengeRoundLabel;
    shieldActive = state['shield_active'] == true;
    final multiplier = state['score_multiplier'];
    _nextGiftScoreBonus.restoreFromMultiplier(
      multiplier is num && multiplier.isFinite
          ? multiplier.toDouble().clamp(1, 2).toDouble()
          : 1,
    );
    _updatePowerupLabel();

    final presentIds = <int>{};
    for (var index = 0; index < rawObjects.length; index++) {
      final rawObject = rawObjects[index];
      if (rawObject is! Map) continue;
      final objectType = rawObject['type'];
      final x = rawObject['x'];
      final y = rawObject['y'];
      if (objectType is! String || x is! num || y is! num) continue;
      final rawId = rawObject['id'];
      final id = rawId is int ? rawId : index;
      if (id < 0) continue;
      presentIds.add(id);
      final objectPosition = Vector2(
        size.x * x.toDouble().clamp(0, 1),
        size.y * y.toDouble().clamp(0, 1),
      );
      final existing = _spectatorObjects[id];
      if (objectType == 'obstacle') {
        if (existing is! Obstacle) {
          existing?.removeFromParent();
          final obstacle =
              Obstacle(
                  liveObjectId: id,
                  speed: currentLevel.maxObstacleSpeed,
                  stage: legendChallengeLandscapeForRound(roundNumber),
                )
                ..position = objectPosition
                ..anchor = Anchor.center;
          _spectatorObjects[id] = obstacle;
          add(obstacle);
        } else {
          existing.playTo(objectPosition, const Duration(milliseconds: 500));
        }
      } else if (objectType == 'shield' ||
          objectType == 'bonus' ||
          objectType == 'reward' ||
          objectType == 'trap') {
        if (existing is! PowerUp) {
          existing?.removeFromParent();
          final powerUp =
              PowerUp(
                  liveObjectId: id,
                  type: objectType == 'bonus' ? 'double' : objectType,
                )
                ..position = objectPosition
                ..anchor = Anchor.center;
          _spectatorObjects[id] = powerUp;
          add(powerUp);
        } else {
          existing.playTo(objectPosition, const Duration(milliseconds: 500));
        }
      } else if (objectType == 'reward_bird' || objectType == 'trap_bird') {
        final rawDirection = rawObject['direction'];
        final direction = rawDirection is num && rawDirection < 0 ? -1.0 : 1.0;
        if (existing is! FlyingBird) {
          existing?.removeFromParent();
          final bird =
              FlyingBird(
                  liveObjectId: id,
                  dropsReward: objectType == 'reward_bird',
                  direction: direction,
                  spectatorOnly: true,
                )
                ..position = objectPosition
                ..anchor = Anchor.center;
          _spectatorObjects[id] = bird;
          add(bird);
        } else {
          existing.playTo(objectPosition, const Duration(milliseconds: 500));
        }
      }
    }
    for (final entry in _spectatorObjects.entries.toList()) {
      if (!presentIds.contains(entry.key)) {
        entry.value.removeFromParent();
        _spectatorObjects.remove(entry.key);
      }
    }
    _hasSpectatorSnapshot = true;
    final events = state['events'];
    if (events is List) {
      for (final rawEvent in events) {
        if (rawEvent is! Map) continue;
        final id = rawEvent['id'];
        final type = rawEvent['type'];
        final x = rawEvent['x'];
        final y = rawEvent['y'];
        if (id is! int ||
            id <= _lastSpectatorEventId ||
            type is! String ||
            x is! num ||
            y is! num) {
          continue;
        }
        _lastSpectatorEventId = id;
        final eventPosition = Vector2(
          size.x * x.toDouble().clamp(0, 1),
          size.y * y.toDouble().clamp(0, 1),
        );
        switch (type) {
          case 'collision':
            _spawnExplosion(eventPosition);
            _spawnFloatingFeedback(eventPosition, 'Impact', Colors.redAccent);
            playSoundEffect(gameSoundEffectAsset(GameSoundEffect.collision));
          case 'dodge':
            _spawnScoreParticle(eventPosition);
            playSoundEffect(gameSoundEffectAsset(GameSoundEffect.score));
          case 'shield_pickup':
            _spawnFloatingFeedback(
              eventPosition,
              'Bouclier activé',
              Colors.lightGreenAccent,
            );
            playSoundEffect(gameSoundEffectAsset(GameSoundEffect.shieldPickup));
          case 'bonus_pickup':
            _spawnFloatingFeedback(
              eventPosition,
              'Bonus récupéré',
              Colors.amberAccent,
            );
            playSoundEffect(gameSoundEffectAsset(GameSoundEffect.bonus));
          case 'reward_pickup':
            _spawnFloatingFeedback(
              eventPosition,
              '+$birdRewardPoints points',
              Colors.lightGreenAccent,
            );
            playSoundEffect(gameSoundEffectAsset(GameSoundEffect.bonus));
          case 'trap_pickup':
            _spawnFloatingFeedback(
              eventPosition,
              '-$birdTrapPenalty points',
              Colors.redAccent,
            );
            playSoundEffect(gameSoundEffectAsset(GameSoundEffect.collision));
        }
      }
    }
  }
}

class _BackdropPalette {
  const _BackdropPalette({
    required this.skyTop,
    required this.skyBottom,
    required this.sun,
    required this.farmland,
    required this.hills,
    required this.ground,
    required this.foreground,
    required this.detail,
  });

  final Color skyTop;
  final Color skyBottom;
  final Color sun;
  final Color farmland;
  final Color hills;
  final Color ground;
  final Color foreground;
  final Color detail;

  static _BackdropPalette forTheme(GameBackdrop theme) => switch (theme) {
    GameBackdrop.nursery => const _BackdropPalette(
      skyTop: Color(0xFF8CCFE2),
      skyBottom: Color(0xFFE4F3D0),
      sun: Color(0xFFFFF0A3),
      farmland: Color(0xFF9DCF8C),
      hills: Color(0xFF72A96A),
      ground: Color(0xFF527D45),
      foreground: Color(0xFF355F39),
      detail: Color(0xFFB5E477),
    ),
    GameBackdrop.sprouts => const _BackdropPalette(
      skyTop: Color(0xFF68B8B0),
      skyBottom: Color(0xFFD8EAC1),
      sun: Color(0xFFFFE495),
      farmland: Color(0xFF94BE65),
      hills: Color(0xFF5E9A69),
      ground: Color(0xFF4D804B),
      foreground: Color(0xFF2D6548),
      detail: Color(0xFFA5D85F),
    ),
    GameBackdrop.garden => const _BackdropPalette(
      skyTop: Color(0xFF63A8D2),
      skyBottom: Color(0xFFD7E8C3),
      sun: Color(0xFFFFE48A),
      farmland: Color(0xFF9ABD63),
      hills: Color(0xFF628F54),
      ground: Color(0xFF536F3D),
      foreground: Color(0xFF315C36),
      detail: Color(0xFFBEDC62),
    ),
    GameBackdrop.orchard => const _BackdropPalette(
      skyTop: Color(0xFF76C2E0),
      skyBottom: Color(0xFFD9EFC5),
      sun: Color(0xFFFFD966),
      farmland: Color(0xFF8CB967),
      hills: Color(0xFF568A55),
      ground: Color(0xFF476F42),
      foreground: Color(0xFF61482F),
      detail: Color(0xFF4F983C),
    ),
    GameBackdrop.harvest => const _BackdropPalette(
      skyTop: Color(0xFF4F98B8),
      skyBottom: Color(0xFFF5D38A),
      sun: Color(0xFFFFB84D),
      farmland: Color(0xFFD6A143),
      hills: Color(0xFF9C783A),
      ground: Color(0xFF76562E),
      foreground: Color(0xFF614323),
      detail: Color(0xFFFFD260),
    ),
    GameBackdrop.rainySeason => const _BackdropPalette(
      skyTop: Color(0xFF526D87),
      skyBottom: Color(0xFFB6C6C8),
      sun: Color(0xFFE5E1C1),
      farmland: Color(0xFF799B79),
      hills: Color(0xFF54745C),
      ground: Color(0xFF3F654B),
      foreground: Color(0xFF34583F),
      detail: Color(0xFF80BDA2),
    ),
    GameBackdrop.redLands => const _BackdropPalette(
      skyTop: Color(0xFF75A7B7),
      skyBottom: Color(0xFFE7B27B),
      sun: Color(0xFFFFD176),
      farmland: Color(0xFFC8764F),
      hills: Color(0xFF9F513C),
      ground: Color(0xFF87412F),
      foreground: Color(0xFF65382A),
      detail: Color(0xFFB66A3E),
    ),
    GameBackdrop.savannah => const _BackdropPalette(
      skyTop: Color(0xFF56A7CC),
      skyBottom: Color(0xFFFFD77E),
      sun: Color(0xFFFFE58A),
      farmland: Color(0xFFD6B85F),
      hills: Color(0xFFA58B46),
      ground: Color(0xFF8C7138),
      foreground: Color(0xFF4A4328),
      detail: Color(0xFFB68C3F),
    ),
    GameBackdrop.highlands => const _BackdropPalette(
      skyTop: Color(0xFF628BB5),
      skyBottom: Color(0xFFD4E5E7),
      sun: Color(0xFFF5F4E8),
      farmland: Color(0xFF9EB5B1),
      hills: Color(0xFF718A91),
      ground: Color(0xFF556D70),
      foreground: Color(0xFF415A62),
      detail: Color(0xFFE7F0E8),
    ),
    GameBackdrop.market => const _BackdropPalette(
      skyTop: Color(0xFF73B6C4),
      skyBottom: Color(0xFFFFD39B),
      sun: Color(0xFFFFE69B),
      farmland: Color(0xFFD7A25C),
      hills: Color(0xFFA9754C),
      ground: Color(0xFF825A3C),
      foreground: Color(0xFF62452F),
      detail: Color(0xFFCB6546),
    ),
    GameBackdrop.goldenLands => const _BackdropPalette(
      skyTop: Color(0xFF4F91B4),
      skyBottom: Color(0xFFFFC963),
      sun: Color(0xFFFFE58C),
      farmland: Color(0xFFE6B644),
      hills: Color(0xFFB78432),
      ground: Color(0xFF93652C),
      foreground: Color(0xFF765125),
      detail: Color(0xFFFFD34F),
    ),
    GameBackdrop.legend => const _BackdropPalette(
      skyTop: Color(0xFF372A70),
      skyBottom: Color(0xFF9C4F7E),
      sun: Color(0xFFFFD66E),
      farmland: Color(0xFF8F6274),
      hills: Color(0xFF624365),
      ground: Color(0xFF403151),
      foreground: Color(0xFF2F253F),
      detail: Color(0xFFFFC95B),
    ),
    GameBackdrop.duelCoast => const _BackdropPalette(
      skyTop: Color(0xFF2185A5),
      skyBottom: Color(0xFFFFD39B),
      sun: Color(0xFFFFF0BE),
      farmland: Color(0xFF79B997),
      hills: Color(0xFF328D91),
      ground: Color(0xFF176B78),
      foreground: Color(0xFF735D4B),
      detail: Color(0xFFB8F0E7),
    ),
    GameBackdrop.duelBaobabValley => const _BackdropPalette(
      skyTop: Color(0xFFB94838),
      skyBottom: Color(0xFFFFC36D),
      sun: Color(0xFFFFE3A1),
      farmland: Color(0xFFC99042),
      hills: Color(0xFF9A5E36),
      ground: Color(0xFF74442E),
      foreground: Color(0xFF382D27),
      detail: Color(0xFFE5AD58),
    ),
    GameBackdrop.duelRiverOasis => const _BackdropPalette(
      skyTop: Color(0xFF79C8C0),
      skyBottom: Color(0xFFD9EDB6),
      sun: Color(0xFFFFE99A),
      farmland: Color(0xFF84BD72),
      hills: Color(0xFF528A61),
      ground: Color(0xFF356B4C),
      foreground: Color(0xFF31523C),
      detail: Color(0xFF72C9CE),
    ),
  };
}

class Player extends PositionComponent with HasGameReference<FopcamGame> {
  static const double sizeS = 40.0;
  Vector2 target = Vector2.zero();
  double speed = 460.0;
  bool _hasTarget = false;
  final GamePositionPlayback _playback = GamePositionPlayback();
  late final Path _birdPath;
  late final Path _wingPath;
  final Paint _shadowPaint = Paint()
    ..color = Colors.black.withValues(alpha: 0.36)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
  final Paint _ringPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _birdPaint = Paint();
  final Paint _wingPaint = Paint();
  final Paint _eyePaint = Paint()..color = const Color(0xFF17202A);
  Color? _paintedAccent;
  Color? _paintedLevelColor;

  Player() : super(size: Vector2.all(sizeS)) {
    const birdSize = Size(sizeS * 0.84, sizeS * 0.84);
    _birdPath = buildPlayerBirdPath(birdSize);
    _wingPath = Path()
      ..moveTo(birdSize.width * 0.28, birdSize.height * 0.52)
      ..cubicTo(
        birdSize.width * 0.38,
        birdSize.height * 0.32,
        birdSize.width * 0.58,
        birdSize.height * 0.28,
        birdSize.width * 0.77,
        birdSize.height * 0.36,
      )
      ..cubicTo(
        birdSize.width * 0.63,
        birdSize.height * 0.52,
        birdSize.width * 0.46,
        birdSize.height * 0.62,
        birdSize.width * 0.3,
        birdSize.height * 0.62,
      )
      ..close();
  }

  @override
  Future<void> onLoad() async {
    anchor = Anchor.center;
  }

  void moveTo(double x, [double? y]) {
    target = clampGamePlayerTarget(Vector2(x, y ?? position.y), game.size);
    _hasTarget = true;
  }

  Vector2 get intendedPosition => _hasTarget ? target : position;

  void playTo(Vector2 nextPosition, Duration duration) {
    _playback.retarget(position, nextPosition, duration.inMilliseconds / 1000);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (game.isSpectatorMode) {
      _playback.update(position, dt);
      return;
    }
    if (_hasTarget) {
      position.setFrom(advancePlayerPosition(position, target, speed * dt));
    }
    // clamp to screen
    position.setFrom(clampGamePlayerTarget(position, game.size));
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (game.isSpectatorMode) return;
    final accent = game.levelAccentColor;
    final levelColor = game.levelColor;
    if (_paintedAccent != accent || _paintedLevelColor != levelColor) {
      _paintedAccent = accent;
      _paintedLevelColor = levelColor;
      _ringPaint.color = accent;
      _birdPaint.color = accent;
      _wingPaint.color = levelColor;
    }
    final center = Offset(size.x / 2, size.y / 2);
    final radius = size.x / 2;
    canvas.drawCircle(center, radius, _shadowPaint);
    if (game.shieldActive) {
      canvas.drawCircle(
        center,
        radius * 1.16,
        Paint()
          ..color = Colors.lightBlueAccent.withValues(alpha: 0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    canvas.drawCircle(center, radius * 0.88, _ringPaint);
    final birdBounds = Rect.fromLTWH(
      size.x * 0.08,
      size.y * 0.08,
      size.x * 0.84,
      size.y * 0.84,
    );
    final birdSize = Size(birdBounds.width, birdBounds.height);
    canvas.save();
    canvas.translate(birdBounds.left, birdBounds.top);
    canvas.drawPath(_birdPath, _birdPaint);
    canvas.drawPath(_wingPath, _wingPaint);
    canvas.drawCircle(
      Offset(birdSize.width * 0.78, birdSize.height * 0.3),
      birdSize.width * 0.035,
      _eyePaint,
    );
    canvas.restore();
  }

  // input handled by the parent game via `movePlayerTo` to avoid
  // direct Flame input API differences across versions.
}

class FlyingBird extends PositionComponent with HasGameReference<FopcamGame> {
  final int liveObjectId;
  final bool dropsReward;
  final double direction;
  final bool spectatorOnly;
  final GamePositionPlayback _playback = GamePositionPlayback();
  final Paint _bodyPaint;
  final Paint _wingPaint;
  final Paint _beakPaint = Paint()..color = const Color(0xFFFFB74D);
  final Paint _eyePaint = Paint()..color = const Color(0xFF17212B);
  double _wingPhase = 0;
  bool _hasDropped = false;

  FlyingBird({
    required this.liveObjectId,
    required this.dropsReward,
    required this.direction,
    this.spectatorOnly = false,
  }) : _bodyPaint = Paint()
         ..color = dropsReward
             ? const Color(0xFF37B879)
             : const Color(0xFF67506F),
       _wingPaint = Paint()
         ..color = dropsReward
             ? const Color(0xFFB8F2C8)
             : const Color(0xFFE78A91),
       super(size: Vector2(56, 38));

  @override
  void update(double dt) {
    _wingPhase += dt * 12;
    if (game.isSpectatorMode) {
      _playback.update(position, dt);
      return;
    }
    if (spectatorOnly) return;
    super.update(dt);
    position.x += direction * (132 + game.level * 4) * dt;
    final visibleDropPoint = direction > 0
        ? game.size.x * 0.28
        : game.size.x * 0.72;
    if (!_hasDropped &&
        (direction > 0
            ? position.x >= visibleDropPoint
            : position.x <= visibleDropPoint)) {
      _hasDropped = true;
      game._spawnBirdDrop(
        Vector2(position.x, position.y + size.y * 0.35),
        reward: dropsReward,
      );
    }
    if ((direction > 0 && position.x > game.size.x + size.x) ||
        (direction < 0 && position.x < -size.x)) {
      removeFromParent();
    }
  }

  void playTo(Vector2 nextPosition, Duration duration) {
    _playback.retarget(position, nextPosition, duration.inMilliseconds / 1000);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    canvas.save();
    if (direction < 0) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }
    final center = Offset(size.x * 0.48, size.y * 0.55);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(sin(_wingPhase) * 0.48);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-size.x * 0.04, -size.y * 0.1),
        width: size.x * 0.54,
        height: size.y * 0.3,
      ),
      _wingPaint,
    );
    canvas.restore();
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: size.x * 0.62,
        height: size.y * 0.44,
      ),
      _bodyPaint,
    );
    canvas.drawCircle(
      Offset(size.x * 0.72, size.y * 0.34),
      size.y * 0.18,
      _bodyPaint,
    );
    final beak = Path()
      ..moveTo(size.x * 0.86, size.y * 0.31)
      ..lineTo(size.x * 0.99, size.y * 0.37)
      ..lineTo(size.x * 0.86, size.y * 0.43)
      ..close();
    canvas.drawPath(beak, _beakPaint);
    canvas.drawCircle(
      Offset(size.x * 0.75, size.y * 0.32),
      size.y * 0.035,
      _eyePaint,
    );
    canvas.restore();
  }
}

class Obstacle extends PositionComponent with HasGameReference<FopcamGame> {
  final int liveObjectId;
  double speed;
  GameLevel stage;
  static const double sizeS = 28.0;
  bool _resolved = false;
  final GamePositionPlayback _playback = GamePositionPlayback();
  final Paint _fillPaint;
  final Paint _outlinePaint;

  Obstacle({
    required this.liveObjectId,
    required this.speed,
    required this.stage,
  }) : _fillPaint = Paint()..color = stage.color,
       _outlinePaint = Paint()
         ..color = stage.accentColor.withValues(alpha: 0.72)
         ..style = PaintingStyle.stroke
         ..strokeWidth = 2,
       super(size: Vector2.all(sizeS));

  @override
  void update(double dt) {
    if (game.isSpectatorMode) {
      _playback.update(position, dt);
      return;
    }
    if (_resolved) return;
    super.update(dt);
    position.setFrom(advanceFallingObjectPosition(position, speed, dt));
    if (position.y > game.size.y + 50) {
      _resolved = true;
      game._spawnScoreParticle(position);
      game.playSoundEffect(gameSoundEffectAsset(GameSoundEffect.score));
      removeFromParent();
      game.recordSuccessfulDodge(position);
      return;
    }
    final player = game._player;
    if ((player.position - position).length <
        (player.size.x / 2 + size.x / 2)) {
      _resolved = true;
      if (game.shieldActive) {
        game._spawnScoreParticle(position);
        game.playSoundEffect(gameSoundEffectAsset(GameSoundEffect.shieldBlock));
        removeFromParent();
        game.recordSuccessfulDodge(position);
      } else {
        game._spawnExplosion(position);
        game._spawnFloatingFeedback(position, '-1 point', Colors.redAccent);
        game.playSoundEffect(gameSoundEffectAsset(GameSoundEffect.collision));
        removeFromParent();
        game.recordCollision(position);
      }
      return;
    }
  }

  void playTo(Vector2 nextPosition, Duration duration) {
    _playback.retarget(position, nextPosition, duration.inMilliseconds / 1000);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(7)),
      _fillPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(5)),
      _outlinePaint,
    );
  }
}

class PowerUp extends PositionComponent with HasGameReference<FopcamGame> {
  final int liveObjectId;
  final String type;
  final double speed = 80.0;
  bool _consumed = false;
  final GamePositionPlayback _playback = GamePositionPlayback();
  final Paint _giftPaint = Paint()..color = const Color(0xFFE83E62);
  final Paint _ribbonPaint = Paint()..color = const Color(0xFFFFD166);
  final Paint _doublePaint = Paint()..color = const Color(0xFFFFCA28);
  final Paint _rewardPaint = Paint()..color = const Color(0xFF2EAA70);
  final Paint _trapPaint = Paint()..color = const Color(0xFF8F3046);
  final TextPainter _doubleLabel = TextPainter(
    text: const TextSpan(
      text: 'x2',
      style: TextStyle(
        color: Color(0xFF4B3510),
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final TextPainter _rewardLabel = TextPainter(
    text: const TextSpan(
      text: '+5',
      style: TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final TextPainter _trapLabel = TextPainter(
    text: const TextSpan(
      text: '-3',
      style: TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.w900,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  PowerUp({required this.liveObjectId, required this.type})
    : super(size: Vector2.all(30));

  @override
  void update(double dt) {
    if (game.isSpectatorMode) {
      _playback.update(position, dt);
      return;
    }
    if (_consumed) return;
    super.update(dt);
    position.setFrom(advanceFallingObjectPosition(position, speed, dt));
    if (position.y > game.size.y + 50) {
      _consumed = true;
      removeFromParent();
      return;
    }
    final player = game._player;
    if ((player.position - position).length <
        (player.size.x / 2 + size.x / 2)) {
      _consumed = true;
      game._applyPowerUp(type);
      removeFromParent();
    }
  }

  void playTo(Vector2 nextPosition, Duration duration) {
    _playback.retarget(position, nextPosition, duration.inMilliseconds / 1000);
  }

  @override
  void render(Canvas canvas) {
    final bounds = Rect.fromLTWH(0, 0, size.x, size.y);
    if (type == 'shield') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds.deflate(2), const Radius.circular(5)),
        _giftPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(size.x * 0.42, 2, size.x * 0.16, size.y - 4),
        _ribbonPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(2, size.y * 0.42, size.x - 4, size.y * 0.16),
        _ribbonPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.x * 0.38, size.y * 0.16),
          width: size.x * 0.3,
          height: size.y * 0.2,
        ),
        _ribbonPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.x * 0.62, size.y * 0.16),
          width: size.x * 0.3,
          height: size.y * 0.2,
        ),
        _ribbonPaint,
      );
    } else if (type == 'reward') {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds.deflate(2), const Radius.circular(5)),
        _rewardPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(size.x * 0.43, 2, size.x * 0.14, size.y - 4),
        _ribbonPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(2, size.y * 0.43, size.x - 4, size.y * 0.14),
        _ribbonPaint,
      );
      _rewardLabel.paint(
        canvas,
        Offset(
          (size.x - _rewardLabel.width) / 2,
          (size.y - _rewardLabel.height) / 2,
        ),
      );
    } else if (type == 'trap') {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        size.x * 0.47,
        _trapPaint,
      );
      _trapLabel.paint(
        canvas,
        Offset(
          (size.x - _trapLabel.width) / 2,
          (size.y - _trapLabel.height) / 2,
        ),
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds.deflate(2), const Radius.circular(6)),
        _doublePaint,
      );
      _doubleLabel.paint(
        canvas,
        Offset(
          (size.x - _doubleLabel.width) / 2,
          (size.y - _doubleLabel.height) / 2,
        ),
      );
    }
  }
}

class ScoreParticle extends PositionComponent {
  double life = 0.6;
  Paint paint = Paint()..color = Colors.amber;

  ScoreParticle({required Vector2 position})
    : super(position: position, size: Vector2.all(20)) {
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    life -= dt;
    position += Vector2(0, -60) * dt;
    if (life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final alpha = (life.clamp(0, 1) * 255).toInt();
    paint.color = Colors.amber.withAlpha(alpha);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), 8, paint);
  }
}

class ExplosionParticle extends PositionComponent {
  double life = 0.8;

  ExplosionParticle({required Vector2 position})
    : super(position: position, size: Vector2.all(40)) {
    anchor = Anchor.center;
  }

  @override
  void update(double dt) {
    super.update(dt);
    life -= dt;
    if (life <= 0) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final prog = (life.clamp(0, 1)).toDouble();
    final paint = Paint()..color = Colors.redAccent.withValues(alpha: prog);
    canvas.drawCircle(Offset(size.x / 2, size.y / 2), 20 * prog, paint);
  }
}

class FloatingFeedback extends TextComponent {
  FloatingFeedback({
    required Vector2 position,
    required String text,
    required Color color,
  }) : _color = color,
       super(
         text: text,
         position: position,
         anchor: Anchor.center,
         textRenderer: TextPaint(
           style: TextStyle(
             color: color,
             fontSize: 20,
             fontWeight: FontWeight.bold,
             shadows: const [
               Shadow(
                 color: Colors.black87,
                 blurRadius: 4,
                 offset: Offset(1, 2),
               ),
             ],
           ),
         ),
       );

  final Color _color;
  double _remaining = 1.2;

  @override
  void update(double dt) {
    super.update(dt);
    _remaining -= dt;
    position.y -= 48 * dt;
    final opacity = (_remaining / 1.2).clamp(0.0, 1.0);
    textRenderer = TextPaint(
      style: TextStyle(
        color: _color.withValues(alpha: opacity),
        fontSize: 20,
        fontWeight: FontWeight.bold,
        shadows: const [
          Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(1, 2)),
        ],
      ),
    );
    if (_remaining <= 0) removeFromParent();
  }
}
