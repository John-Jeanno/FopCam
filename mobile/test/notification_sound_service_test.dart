import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/notification.dart';
import 'package:mobile/services/notification_sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  NotificationItem notification(String type) => NotificationItem(
    id: 1,
    title: '',
    message: 'Awa vous invite à un duel.',
    type: type,
    isRead: false,
    createdAt: DateTime.utc(2026),
  );

  test('uses distinct spoken announcements for legendary invitations', () {
    expect(
      NotificationSoundService.announcementFor(notification('game_challenge')),
      'Nouveau défi de légende en attente. Awa vous invite à un duel.',
    );
    expect(
      NotificationSoundService.announcementFor(notification('game_rematch')),
      'Nouvelle demande de revanche en attente. Awa vous invite à un duel.',
    );
  });

  test('ordinary notifications use the alert sound instead of speech', () {
    expect(
      NotificationSoundService.announcementFor(notification('message')),
      isNull,
    );
    expect(NotificationSoundService.webAlertAsset, 'sounds/score.wav');
  });

  test('notifications are grouped by type for individual sound preferences', () {
    expect(NotificationSoundService.categoryForType('message'), 'messages');
    expect(
      NotificationSoundService.categoryForType('game_challenge'),
      'games',
    );
    expect(NotificationSoundService.categoryForType('order'), 'orders');
    expect(
      NotificationSoundService.categoryForType('friend_request'),
      'social',
    );
    expect(NotificationSoundService.categoryForType('general'), 'other');
  });

  test('sound preferences are persisted per notification category', () async {
    SharedPreferences.setMockInitialValues({});
    await NotificationSoundService.initialize();
    await NotificationSoundService.savePreferences({
      'messages': 'soft',
      'games': 'festive',
    });

    expect(NotificationSoundService.preferences['messages'], 'soft');
    expect(NotificationSoundService.preferences['games'], 'festive');
    expect(NotificationSoundService.preferences['orders'], 'system');
  });

  test('server sound preferences replace local values for all categories', () async {
    SharedPreferences.setMockInitialValues({});
    await NotificationSoundService.initialize();
    await NotificationSoundService.savePreferences({'messages': 'soft'});
    await NotificationSoundService.applyServerPreferences({
      'messages': 'alert',
      'games': 'festive',
    });

    expect(NotificationSoundService.preferences['messages'], 'alert');
    expect(NotificationSoundService.preferences['games'], 'festive');
    expect(NotificationSoundService.preferences['social'], 'system');
  });
}
