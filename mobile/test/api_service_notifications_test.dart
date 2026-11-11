import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('fetchNotifications returns newest notifications first', () async {
    SharedPreferences.setMockInitialValues({});
    final notifications = await http.runWithClient(
      ApiService.fetchNotifications,
      () => MockClient(
        (_) async => http.Response(
          jsonEncode([
            {'id': 1, 'created_at': '2026-10-27T09:00:00Z'},
            {'id': 3, 'created_at': '2026-10-28T09:00:00Z'},
            {'id': 2, 'created_at': '2026-10-27T14:00:00Z'},
          ]),
          200,
        ),
      ),
    );

    expect(notifications.map((notification) => notification.id), [3, 2, 1]);
  });

  test(
    'fetchConversations returns unread totals from the inbox endpoint',
    () async {
      SharedPreferences.setMockInitialValues({});
      final conversations = await http.runWithClient(
        ApiService.fetchConversations,
        () => MockClient((request) async {
          expect(request.url.path, '/fopcam-api/api/messages/conversations/');
          return http.Response(
            jsonEncode([
              {
                'room_id': 'private_1_2',
                'profile': {'id': 2, 'username': 'amadou'},
                'last_message': 'Un message récent',
                'unread_count': 3,
                'updated_at': '2026-11-01T20:00:00Z',
              },
            ]),
            200,
          );
        }),
      );

      expect(conversations, hasLength(1));
      expect(conversations.single['unread_count'], 3);
      expect(conversations.single['room_id'], 'private_1_2');
    },
  );
}
