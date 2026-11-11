import 'dart:math';

import 'package:flutter/material.dart';

enum GameBackdrop {
  nursery,
  sprouts,
  garden,
  orchard,
  harvest,
  rainySeason,
  redLands,
  savannah,
  highlands,
  market,
  goldenLands,
  legend,
  duelCoast,
  duelBaobabValley,
  duelRiverOasis,
}

class GameLevel {
  final int number;
  final String name;
  final GameBackdrop backdrop;
  final int scoreThreshold;
  final Color color;
  final Color accentColor;
  final String musicAsset;
  final int musicTempo;
  final double spawnInterval;
  final double minObstacleSpeed;
  final double maxObstacleSpeed;
  final double powerUpChance;

  const GameLevel({
    required this.number,
    required this.name,
    required this.backdrop,
    required this.scoreThreshold,
    required this.color,
    required this.accentColor,
    required this.musicAsset,
    required this.musicTempo,
    required this.spawnInterval,
    required this.minObstacleSpeed,
    required this.maxObstacleSpeed,
    required this.powerUpChance,
  });

  static const List<GameLevel> all = [
    GameLevel(
      number: 1,
      name: 'Les semis',
      backdrop: GameBackdrop.nursery,
      scoreThreshold: 0,
      color: Color(0xFF4CAF50),
      accentColor: Color(0xFFA5D66D),
      musicAsset: 'sounds/level_01.wav',
      musicTempo: 112,
      spawnInterval: 1.15,
      minObstacleSpeed: 105,
      maxObstacleSpeed: 145,
      powerUpChance: 0.50,
    ),
    GameLevel(
      number: 2,
      name: 'Jeunes pousses',
      backdrop: GameBackdrop.sprouts,
      scoreThreshold: 6,
      color: Color(0xFF8BC34A),
      accentColor: Color(0xFFD4E157),
      musicAsset: 'sounds/level_02.wav',
      musicTempo: 116,
      spawnInterval: 1.12,
      minObstacleSpeed: 109,
      maxObstacleSpeed: 150,
      powerUpChance: 0.49,
    ),
    GameLevel(
      number: 3,
      name: 'Le potager',
      backdrop: GameBackdrop.garden,
      scoreThreshold: 13,
      color: Color(0xFF009688),
      accentColor: Color(0xFF80CBC4),
      musicAsset: 'sounds/level_03.wav',
      musicTempo: 120,
      spawnInterval: 1.09,
      minObstacleSpeed: 114,
      maxObstacleSpeed: 156,
      powerUpChance: 0.48,
    ),
    GameLevel(
      number: 4,
      name: 'Le verger',
      backdrop: GameBackdrop.orchard,
      scoreThreshold: 22,
      color: Color(0xFF26A69A),
      accentColor: Color(0xFFFFB74D),
      musicAsset: 'sounds/level_04.wav',
      musicTempo: 124,
      spawnInterval: 1.06,
      minObstacleSpeed: 120,
      maxObstacleSpeed: 163,
      powerUpChance: 0.47,
    ),
    GameLevel(
      number: 5,
      name: 'Les récoltes',
      backdrop: GameBackdrop.harvest,
      scoreThreshold: 32,
      color: Color(0xFFFFA726),
      accentColor: Color(0xFFFFE082),
      musicAsset: 'sounds/level_05.wav',
      musicTempo: 128,
      spawnInterval: 1.03,
      minObstacleSpeed: 127,
      maxObstacleSpeed: 171,
      powerUpChance: 0.46,
    ),
    GameLevel(
      number: 6,
      name: 'La grande saison',
      backdrop: GameBackdrop.rainySeason,
      scoreThreshold: 44,
      color: Color(0xFFFF7043),
      accentColor: Color(0xFFFFCC80),
      musicAsset: 'sounds/level_06.wav',
      musicTempo: 132,
      spawnInterval: 1.00,
      minObstacleSpeed: 135,
      maxObstacleSpeed: 180,
      powerUpChance: 0.45,
    ),
    GameLevel(
      number: 7,
      name: 'Les terres rouges',
      backdrop: GameBackdrop.redLands,
      scoreThreshold: 58,
      color: Color(0xFFE65100),
      accentColor: Color(0xFFFFAB91),
      musicAsset: 'sounds/level_07.wav',
      musicTempo: 136,
      spawnInterval: 0.97,
      minObstacleSpeed: 144,
      maxObstacleSpeed: 190,
      powerUpChance: 0.44,
    ),
    GameLevel(
      number: 8,
      name: 'La savane',
      backdrop: GameBackdrop.savannah,
      scoreThreshold: 74,
      color: Color(0xFFAB47BC),
      accentColor: Color(0xFFE1BEE7),
      musicAsset: 'sounds/level_08.wav',
      musicTempo: 140,
      spawnInterval: 0.94,
      minObstacleSpeed: 154,
      maxObstacleSpeed: 201,
      powerUpChance: 0.43,
    ),
    GameLevel(
      number: 9,
      name: 'Les hautes plaines',
      backdrop: GameBackdrop.highlands,
      scoreThreshold: 91,
      color: Color(0xFF5C6BC0),
      accentColor: Color(0xFFC5CAE9),
      musicAsset: 'sounds/level_09.wav',
      musicTempo: 144,
      spawnInterval: 0.91,
      minObstacleSpeed: 165,
      maxObstacleSpeed: 213,
      powerUpChance: 0.42,
    ),
    GameLevel(
      number: 10,
      name: 'Le grand marché',
      backdrop: GameBackdrop.market,
      scoreThreshold: 110,
      color: Color(0xFF42A5F5),
      accentColor: Color(0xFFB3E5FC),
      musicAsset: 'sounds/level_10.wav',
      musicTempo: 148,
      spawnInterval: 0.88,
      minObstacleSpeed: 177,
      maxObstacleSpeed: 226,
      powerUpChance: 0.41,
    ),
    GameLevel(
      number: 11,
      name: 'Les terres d’or',
      backdrop: GameBackdrop.goldenLands,
      scoreThreshold: 131,
      color: Color(0xFFFFCA28),
      accentColor: Color(0xFFFFF59D),
      musicAsset: 'sounds/level_11.wav',
      musicTempo: 152,
      spawnInterval: 0.85,
      minObstacleSpeed: 190,
      maxObstacleSpeed: 240,
      powerUpChance: 0.40,
    ),
    GameLevel(
      number: 12,
      name: 'Légende FopCam',
      backdrop: GameBackdrop.legend,
      scoreThreshold: 154,
      color: Color(0xFFEF5350),
      accentColor: Color(0xFFFFCDD2),
      musicAsset: 'sounds/level_12.wav',
      musicTempo: 156,
      spawnInterval: 0.82,
      minObstacleSpeed: 204,
      maxObstacleSpeed: 255,
      powerUpChance: 0.39,
    ),
  ];

  static const List<GameLevel> challengeLandscapes = [
    GameLevel(
      number: 12,
      name: 'Falaises de la Petite Côte',
      backdrop: GameBackdrop.duelCoast,
      scoreThreshold: 0,
      color: Color(0xFF087E9B),
      accentColor: Color(0xFFFFD28A),
      musicAsset: 'sounds/legend_round_01.wav',
      musicTempo: 156,
      spawnInterval: 0.82,
      minObstacleSpeed: 204,
      maxObstacleSpeed: 255,
      powerUpChance: 0.39,
    ),
    GameLevel(
      number: 12,
      name: 'Vallée des baobabs',
      backdrop: GameBackdrop.duelBaobabValley,
      scoreThreshold: 0,
      color: Color(0xFFB64A2D),
      accentColor: Color(0xFFFFCB69),
      musicAsset: 'sounds/legend_round_02.wav',
      musicTempo: 160,
      spawnInterval: 0.82,
      minObstacleSpeed: 204,
      maxObstacleSpeed: 255,
      powerUpChance: 0.39,
    ),
    GameLevel(
      number: 12,
      name: 'Oasis du fleuve',
      backdrop: GameBackdrop.duelRiverOasis,
      scoreThreshold: 0,
      color: Color(0xFF268B77),
      accentColor: Color(0xFFB9F2D1),
      musicAsset: 'sounds/legend_round_03.wav',
      musicTempo: 164,
      spawnInterval: 0.82,
      minObstacleSpeed: 204,
      maxObstacleSpeed: 255,
      powerUpChance: 0.39,
    ),
  ];

  static GameLevel forScore(int score) {
    for (var index = all.length - 1; index >= 0; index--) {
      if (score >= all[index].scoreThreshold) {
        return all[index];
      }
    }
    return all.first;
  }

  static int durationSecondsFor(int level, {bool replayAfterDemotion = false}) {
    if (level < 1 || level > all.length) {
      throw RangeError.range(level, 1, all.length, 'level');
    }
    if (replayAfterDemotion) return 30;
    if (level <= 5) return 30 + (level - 1) * 15;
    return 55;
  }
}

class GameProgression {
  GameProgression({this.level = 1});

  static const int collisionsBeforeDemotion = 2;

  static int recoveryCostFor(int level) {
    if (level < 1 || level > GameLevel.all.length) {
      throw RangeError.range(level, 1, GameLevel.all.length, 'level');
    }
    return level >= 6 ? 100 : 50;
  }

  static int? scoreAfterRecovery(int score, int recoveredLevel) {
    if (score < 0) {
      throw RangeError.value(score, 'score', 'Must be zero or greater.');
    }
    final cost = recoveryCostFor(recoveredLevel);
    return score < cost ? null : score - cost;
  }

  int level;
  bool isCompleted = false;
  int _collisionCount = 0;

  bool registerCollision() {
    _collisionCount++;
    if (_collisionCount < collisionsBeforeDemotion) return false;
    _collisionCount = 0;
    return true;
  }

  void resetCollisionCount() {
    _collisionCount = 0;
  }

  bool recoverOneLevel() {
    if (isCompleted || level <= 1) return false;
    level++;
    resetCollisionCount();
    return true;
  }

  bool canValidate(int score) => !isCompleted && score >= validationThreshold;

  int get validationThreshold {
    if (level == GameLevel.all.length) {
      final current = GameLevel.all[level - 1].scoreThreshold;
      final previous = GameLevel.all[level - 2].scoreThreshold;
      return current + current - previous;
    }
    return GameLevel.all[level].scoreThreshold;
  }

  bool canCompleteWithinTimer(int score, double remainingSeconds) =>
      remainingSeconds <= 0 && canValidate(score);

  bool validate(int score) {
    if (!canValidate(score)) return false;

    resetCollisionCount();
    if (level == GameLevel.all.length) {
      isCompleted = true;
    } else {
      level++;
    }
    return true;
  }

  int fail(int score, int penalty, {bool demote = true}) {
    if (isCompleted) return score;

    final reducedScore = max(0, score - penalty);
    if (demote && level > 1) {
      level--;
    }
    return reducedScore;
  }
}
