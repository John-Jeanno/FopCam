import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/create_reel_screen.dart';

void main() {
  testWidgets('shows sticker choices when the sticker effect is selected', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateReelScreen()));

    expect(find.text('Effet vidéo'), findsOneWidget);
    expect(find.text('Thème'), findsOneWidget);

    await tester.tap(find.text('Autocollants'));
    await tester.pumpAndSettle();

    expect(find.text('Autocollant'), findsOneWidget);
    expect(find.text('Étincelles ✨'), findsOneWidget);
  });

  testWidgets('offers the before clip input for before-and-after reels', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: CreateReelScreen()));

    await tester.tap(find.text('Avant / après'));
    await tester.pumpAndSettle();

    expect(find.text('Filmer avant'), findsOneWidget);
    expect(find.text('Choisir avant'), findsOneWidget);
  });
}
