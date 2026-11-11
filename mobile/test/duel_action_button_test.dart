import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/duel_action_button.dart';

void main() {
  testWidgets('duel action is a prominent, labeled one-tap button', (
    tester,
  ) async {
    var pressed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DuelActionButton(
            label: 'DÉFIER EN DUEL',
            onPressed: () => pressed = true,
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(tester.getSize(find.byType(FilledButton)).height, 54);
    expect(find.text('DÉFIER EN DUEL'), findsOneWidget);
    expect(find.byIcon(Icons.sports_kabaddi), findsOneWidget);
    expect(button.onPressed, isNotNull);

    await tester.tap(find.byType(FilledButton));
    expect(pressed, isTrue);
  });
}
