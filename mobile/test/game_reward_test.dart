import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/game_reward.dart';

void main() {
  test('parses the synchronized level 12 reward response', () {
    final reward = GameReward.fromJson({
      'level': 12,
      'score': 204,
      'points': 500,
      'title': 'Trophée Awa · Légende FopCam',
      'earned_at': '2026-10-22T01:29:00Z',
      'already_claimed': false,
    });

    expect(reward.level, 12);
    expect(reward.score, 204);
    expect(reward.points, 500);
    expect(reward.title, 'Trophée Awa · Légende FopCam');
    expect(reward.earnedAt, DateTime.utc(2026, 10, 22, 1, 29));
    expect(reward.alreadyClaimed, isFalse);
  });
}
