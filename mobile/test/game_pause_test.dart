import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/game/fopcam_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('restores the saved score and level, including level 12', () async {
    SharedPreferences.setMockInitialValues({
      'paused_game_progress':
          '{"score":154,"level":12,"remainingMilliseconds":71523}',
    });

    expect(await FopcamGame.loadPausedProgress(), {
      'score': 154,
      'level': 12,
      'remainingMilliseconds': 71523,
    });
  });

  test('restores older saves with the current level time limit', () async {
    SharedPreferences.setMockInitialValues({
      'paused_game_progress': '{"score":60,"level":5}',
    });

    expect(await FopcamGame.loadPausedProgress(), {
      'score': 60,
      'level': 5,
      'remainingMilliseconds': 90000,
    });
  });

  test(
    'restores saved player position and a 30-second demotion replay',
    () async {
      SharedPreferences.setMockInitialValues({
        'paused_game_progress':
            '{"score":70,"level":5,"playerXMillionths":250000,'
            '"playerYMillionths":700000,"demotionReplay":true}',
      });

      expect(await FopcamGame.loadPausedProgress(), {
        'score': 70,
        'level': 5,
        'remainingMilliseconds': 30000,
        'playerXMillionths': 250000,
        'playerYMillionths': 700000,
        'demotionReplay': 1,
      });
    },
  );

  test('converts a save that recorded remaining whole seconds', () async {
    SharedPreferences.setMockInitialValues({
      'paused_game_progress': '{"score":75,"level":6,"remainingSeconds":48}',
    });

    expect(await FopcamGame.loadPausedProgress(), {
      'score': 75,
      'level': 6,
      'remainingMilliseconds': 48000,
    });
  });

  test(
    'keeps a completed level 12 reward available until it is claimed',
    () async {
      SharedPreferences.setMockInitialValues({});

      await FopcamGame.savePendingLevelTwelveReward(177);

      expect(await FopcamGame.loadPendingLevelTwelveReward(), 177);
      await FopcamGame.clearPendingLevelTwelveReward();
      expect(await FopcamGame.loadPendingLevelTwelveReward(), isNull);
    },
  );

  test('rejects invalid pending level 12 reward scores', () async {
    SharedPreferences.setMockInitialValues({});

    await expectLater(
      FopcamGame.savePendingLevelTwelveReward(176),
      throwsRangeError,
    );
  });

  test('discards a corrupted pending level 12 reward score', () async {
    SharedPreferences.setMockInitialValues({
      'pending_level_twelve_reward_score': 176,
    });

    expect(await FopcamGame.loadPendingLevelTwelveReward(), isNull);
    expect(
      (await SharedPreferences.getInstance()).containsKey(
        'pending_level_twelve_reward_score',
      ),
      isFalse,
    );
  });

  test(
    'discards a corrupted saved game instead of resuming invalid data',
    () async {
      SharedPreferences.setMockInitialValues({
        'paused_game_progress': 'not valid json',
      });

      expect(await FopcamGame.loadPausedProgress(), isNull);
      expect(
        (await SharedPreferences.getInstance()).containsKey(
          'paused_game_progress',
        ),
        isFalse,
      );
    },
  );
}
