import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/screens/messages_screen.dart';

void main() {
  final user = User(
    id: 2,
    username: 'amadou',
    email: 'amadou@example.com',
    role: 'buyer',
  );

  testWidgets('highlights unread conversations with a burgundy count badge', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageConversationTile(
            user: user,
            preview: 'Un message récent',
            unreadCount: 3,
            onTap: _noop,
            onDelete: _noop,
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
    final badge = tester.widget<Container>(
      find.ancestor(of: find.text('3'), matching: find.byType(Container)).first,
    );
    expect((badge.decoration! as BoxDecoration).color, AppColors.primaryDark);
    expect(
      tester.widget<Text>(find.text('amadou')).style?.fontWeight,
      FontWeight.w700,
    );
    expect(
      tester.widget<Text>(find.text('Un message récent')).style?.fontWeight,
      FontWeight.w600,
    );
  });

  testWidgets('does not badge or bold a conversation with no unread messages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageConversationTile(
            user: user,
            preview: 'Message déjà lu',
            unreadCount: 0,
            onTap: _noop,
            onDelete: _noop,
          ),
        ),
      ),
    );

    expect(find.text('0'), findsNothing);
    expect(
      tester.widget<Text>(find.text('amadou')).style?.fontWeight,
      FontWeight.normal,
    );
    expect(
      tester.widget<Text>(find.text('Message déjà lu')).style?.fontWeight,
      FontWeight.normal,
    );
  });

  testWidgets('offers a delete action for a conversation', (tester) async {
    var deleted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MessageConversationTile(
            user: user,
            preview: 'Message récent',
            unreadCount: 0,
            onTap: _noop,
            onDelete: () => deleted = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Options de la discussion'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Supprimer pour tous'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
  });
}

void _noop() {}
