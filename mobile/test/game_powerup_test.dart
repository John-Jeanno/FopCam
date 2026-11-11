import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/game/fopcam_game.dart';

void main() {
  test('yellow bonus doubles exactly the next gift reward', () {
    final bonus = NextGiftScoreBonus();

    expect(bonus.applyTo(FopcamGame.shieldBonus), FopcamGame.shieldBonus);
    bonus.activate();
    expect(bonus.isArmed, isTrue);
    expect(bonus.applyTo(FopcamGame.shieldBonus), 6);
    expect(bonus.isArmed, isFalse);
    expect(bonus.applyTo(FopcamGame.birdRewardPoints), 5);
  });

  test('repeated yellow bonuses keep one pending doubled gift', () {
    final bonus = NextGiftScoreBonus()
      ..activate()
      ..activate();

    expect(bonus.applyTo(FopcamGame.birdRewardPoints), 10);
    expect(bonus.isArmed, isFalse);
  });
}
