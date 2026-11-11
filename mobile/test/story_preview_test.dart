import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/story.dart';
import 'package:mobile/widgets/story_preview.dart';

void main() {
  test('example statuses cover product categories and are marked as demos', () {
    final examples = Story.exampleStories();

    expect(examples.length, greaterThanOrEqualTo(12));
    expect(examples.every((story) => story.isDemo), isTrue);
    expect(examples.every((story) => story.viewsCount == 0), isTrue);
    expect(examples.every((story) => story.likesCount == 0), isTrue);
    expect(
      examples.any(
        (story) => story.author.username.toLowerCase().contains('électronique'),
      ),
      isTrue,
    );
  });

  test('story is expired at and after its expiry timestamp', () {
    final story = Story.fromJson({
      'id': 42,
      'story_type': 'text',
      'content': 'Statut terminé',
      'expires_at': DateTime.now()
          .subtract(const Duration(seconds: 1))
          .toIso8601String(),
      'created_at': DateTime.now()
          .subtract(const Duration(hours: 24))
          .toIso8601String(),
      'author': {'id': 7, 'username': 'vendeur'},
    });

    expect(story.isExpired, isTrue);
  });

  testWidgets('text status preview shows the published text', (tester) async {
    final story = Story.mockStories().first;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StoryPreview(story: story)),
      ),
    );

    expect(find.text(story.content!), findsOneWidget);
    expect(find.byType(CircleAvatar), findsNothing);
  });

  testWidgets('video status preview shows its text and play indicator', (
    tester,
  ) async {
    final story = Story.fromJson({
      'id': 20,
      'story_type': 'video',
      'content': 'Une vidéo de mon marché',
      'background_color': '#14532D',
      'created_at': '2026-10-23T18:00:00Z',
      'author': {'id': 10, 'username': 'vendeur'},
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: StoryPreview(story: story)),
      ),
    );

    expect(find.text('Une vidéo de mon marché'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}
