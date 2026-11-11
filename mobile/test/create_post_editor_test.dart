import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/constants/app_theme.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/screens/create_post_screen.dart';

void main() {
  testWidgets('inserts an emoji and previews the selected post palette', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CreatePostScreen(
          currentUser: User(
            id: 1,
            username: 'auteur',
            email: 'auteur@example.com',
            role: 'buyer',
          ),
        ),
      ),
    );

    final contentField = find.byType(TextField).first;
    await tester.enterText(contentField, 'Bonjour ');
    await tester.tap(find.text('Émoticônes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🔥'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(contentField).controller!.text,
      'Bonjour 🔥',
    );

    await tester.tap(find.byKey(const ValueKey('post-palette-#1E293B')));
    await tester.pump();
    final contentCard = tester.widget<Container>(
      find.byKey(const ValueKey('post-content-card')),
    );
    expect(
      (contentCard.decoration! as BoxDecoration).color,
      const Color(0xFF1E293B),
    );
    expect(tester.widget<TextField>(contentField).style?.color, Colors.white);
  });

  testWidgets('keeps the composer readable and actions wrapped on mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: MediaQuery(
          data: const MediaQueryData(
            textScaler: TextScaler.linear(2),
            boldText: true,
          ),
          child: CreatePostScreen(
            currentUser: User(
              id: 1,
              username: 'auteur',
              email: 'auteur@example.com',
              role: 'buyer',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final content = find.byKey(const ValueKey('create-post-content'));
    final actions = find.byKey(const ValueKey('create-post-actions'));
    final mediaQuery = MediaQuery.of(tester.element(content));

    expect(tester.getTopLeft(content).dy, lessThan(120));
    expect(tester.getSize(actions).width, lessThanOrEqualTo(390));
    expect(mediaQuery.textScaler.scale(16), closeTo(20.8, 0.01));
    expect(mediaQuery.boldText, isTrue);
    expect(tester.takeException(), isNull);
  });
}
