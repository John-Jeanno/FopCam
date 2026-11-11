import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/game_legends_screen.dart';

void main() {
  testWidgets('native leaderboard limits system text size and bold text', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2.5),
            boldText: true,
          ),
          child: const GameLegendsScreen(),
        ),
      ),
    );

    final screenMediaQuery = MediaQuery.of(
      tester.element(find.byType(Scaffold)),
    );
    expect(screenMediaQuery.textScaler.scale(16), closeTo(19.2, 0.01));
    expect(screenMediaQuery.boldText, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
