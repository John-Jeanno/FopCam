import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/story.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/screens/stories_screen.dart';
import 'package:mobile/screens/story_viewer_screen.dart';

void main() {
  testWidgets('opening a story launches its fullscreen viewer', (tester) async {
    final story = Story(
      id: 1,
      storyType: 'text',
      content: 'Une histoire à lire',
      fontSize: 24,
      isViewed: false,
      isExpired: false,
      isDemo: true,
      createdAt: DateTime(2026),
      author: User(
        id: 1,
        username: 'demo',
        email: 'demo@example.com',
        role: 'buyer',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: StoriesScreen(loadStories: () async => [story])),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Une histoire à lire').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(StoryViewerScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(StoryViewerScreen),
        matching: find.text('Une histoire à lire'),
      ),
      findsOneWidget,
    );
  });
}
