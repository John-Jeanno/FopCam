import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/game_screen_frame.dart';

void main() {
  testWidgets('centers and caps game screens on desktop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const childKey = Key('game-screen-content');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameScreenFrame(child: SizedBox.expand(key: childKey)),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(childKey)), const Size(1120, 900));
    expect(tester.getTopLeft(find.byKey(childKey)), const Offset(400, 90));
  });

  testWidgets('keeps game screens full width on mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const childKey = Key('game-screen-content');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GameScreenFrame(child: SizedBox.expand(key: childKey)),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(childKey)), const Size(390, 844));
    expect(tester.getTopLeft(find.byKey(childKey)), Offset.zero);
  });
}
