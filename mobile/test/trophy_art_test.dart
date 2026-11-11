import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/trophy_art.dart';

void main() {
  testWidgets('Pro cup renders without painting errors', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrophyArtwork(medal: 'cup_pro', width: 200, height: 220),
        ),
      ),
    );

    expect(find.byType(TrophyArtwork), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
