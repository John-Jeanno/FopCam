import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/post.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/widgets/post_card.dart';
import 'package:mobile/widgets/trophy_art.dart';

void main() {
  testWidgets('renders a selected publication palette with readable text', (
    tester,
  ) async {
    final post = Post(
      id: 2,
      content: 'Publication colorée',
      backgroundColor: '#1E293B',
      author: User(
        id: 1,
        username: 'auteur',
        email: 'auteur@example.com',
        role: 'buyer',
      ),
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(post: post, onLike: () {}, onShare: () {}),
        ),
      ),
    );

    final content = tester.widget<Text>(find.text('Publication colorée'));
    expect(content.style?.color, Colors.white);
    expect(
      find.ancestor(
        of: find.text('Publication colorée'),
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Container && widget.color == const Color(0xFF1E293B),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('uses white feed cards and replaces burgundy text backgrounds', (
    tester,
  ) async {
    final post = Post(
      id: 3,
      content: 'Publication bordeaux',
      backgroundColor: '#7F1D1D',
      author: User(
        id: 1,
        username: 'auteur',
        email: 'auteur@example.com',
        role: 'buyer',
      ),
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(post: post, onLike: () {}, onShare: () {}),
        ),
      ),
    );

    expect(tester.widget<Card>(find.byType(Card)).color, Colors.white);
    expect(
      tester.widget<Text>(find.text('Publication bordeaux')).style?.color,
      Colors.black87,
    );
    expect(
      find.ancestor(
        of: find.text('Publication bordeaux'),
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.color == Colors.white,
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows the first image from an image publication album', (
    tester,
  ) async {
    final post = Post(
      id: 4,
      content: 'Travail de terrain',
      images: const ['https://images.example.com/field.jpg'],
      postType: 'image',
      author: User(
        id: 1,
        username: 'auteur',
        email: 'auteur@example.com',
        role: 'buyer',
      ),
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(post: post, onLike: () {}, onShare: () {}),
        ),
      ),
    );

    final image = tester.widget<Image>(find.byType(Image).first);
    expect(image.image, isA<NetworkImage>());
    expect(
      (image.image as NetworkImage).url,
      'https://images.example.com/field.jpg',
    );
  });

  testWidgets('opens publication images in an interactive zoom viewer', (
    tester,
  ) async {
    final post = Post(
      id: 5,
      content: 'Photo à agrandir',
      image: 'https://images.example.com/large.jpg',
      postType: 'image',
      author: User(
        id: 1,
        username: 'auteur',
        email: 'auteur@example.com',
        role: 'buyer',
      ),
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(post: post, onLike: () {}, onShare: () {}),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('post-image-5')));
    await tester.pump();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('Fermer'), findsOneWidget);
  });

  testWidgets(
    'like button delegates the action without toggling the post twice',
    (tester) async {
      final post = Post(
        id: 1,
        content: 'Publication de test',
        author: User(
          id: 1,
          username: 'auteur',
          email: 'auteur@example.com',
          role: 'buyer',
        ),
        createdAt: DateTime(2026),
      );
      var likeActionCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostCard(
              post: post,
              onLike: () => likeActionCount++,
              onShare: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text("J'aime"));

      expect(likeActionCount, 1);
      expect(post.isLiked, isFalse);
      expect(post.likesCount, 0);
    },
  );

  testWidgets('shows post editing controls only to the author', (tester) async {
    final post = Post(
      id: 6,
      content: 'Publication personnelle',
      author: User(
        id: 1,
        username: 'auteur',
        email: 'auteur@example.com',
        role: 'buyer',
      ),
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: post,
            currentUserId: 2,
            onLike: () {},
            onShare: () {},
            onEditPost: () {},
            onDeletePost: () {},
          ),
        ),
      ),
    );
    expect(find.byType(PopupMenuButton<String>), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(
            post: post,
            currentUserId: 1,
            onLike: () {},
            onShare: () {},
            onEditPost: () {},
            onDeletePost: () {},
          ),
        ),
      ),
    );
    expect(find.byType(PopupMenuButton<String>), findsOneWidget);
  });

  testWidgets('renders a duel trophy publication', (tester) async {
    final post = Post(
      id: 7,
      content: 'Champion 1ère Ligue · Cup',
      postType: 'trophy',
      trophyData: const {
        'medal': 'cup',
        'title': 'Champion 1ère Ligue',
        'opponent': 'adversaire',
        'winner_score': 230,
        'opponent_score': 190,
      },
      author: User(
        id: 1,
        username: 'champion',
        email: 'champion@example.com',
        role: 'buyer',
      ),
      createdAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostCard(post: post, onLike: () {}, onShare: () {}),
        ),
      ),
    );
    expect(find.byType(TrophyArtwork), findsOneWidget);

    expect(find.byType(TrophyArtwork), findsOneWidget);
    expect(find.text('Champion 1ère Ligue'), findsOneWidget);
    expect(find.textContaining('adversaire'), findsOneWidget);
  });
}
