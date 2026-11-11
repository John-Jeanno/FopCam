import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/services/story_offline_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory storageDirectory;

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (methodCall) async => <String>['wifi'],
        );
    storageDirectory = await Directory.systemTemp.createTemp(
      'fopcam-story-offline-test-',
    );
    Hive.init(storageDirectory.path);
    SharedPreferences.setMockInitialValues({});
    await StoryOfflineService.initialize(
      publishStory: (fields, {imageFile, videoFile}) async => {
        'success': false,
        'error': 'offline',
      },
      listenForConnectivity: false,
      syncOnStart: false,
    );
  });

  setUp(() async {
    await Hive.box<dynamic>('story_offline_data').clear();
    SharedPreferences.setMockInitialValues({});
    await StorageService.saveAccessToken('test-token');
    await StorageService.saveUserData('{"id":25,"username":"vendeur"}');
  });

  tearDownAll(() async {
    await Hive.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          null,
        );
    await storageDirectory.delete(recursive: true);
  });

  test('persists selected media and fields before synchronization', () async {
    final file = XFile.fromData(
      Uint8List.fromList([1, 2, 3, 4]),
      name: 'produit.jpg',
      path: '/tmp/produit.jpg',
      mimeType: 'image/jpeg',
    );

    final key = await StoryOfflineService.enqueueStory(
      fields: {
        'content': 'Exemple de statut hors ligne',
        'story_type': 'image',
        'background_color': '#14532D',
      },
      userId: 25,
      username: 'vendeur',
      mediaFile: file,
    );

    final stored = Hive.box<dynamic>('story_offline_data').get(key) as Map;
    expect(stored['fields']['content'], 'Exemple de statut hors ligne');
    expect(stored['user_id'], 25);
    expect(stored['media_name'], 'produit.jpg');
    expect(stored['media_mime_type'], 'image/jpeg');
    expect(stored['media_bytes'], [1, 2, 3, 4]);
    expect(StoryOfflineService.pendingCount.value, 1);
  });

  test(
    'keeps a failed upload and removes it only after server success',
    () async {
      final key = await StoryOfflineService.enqueueStory(
        fields: {'content': 'À synchroniser', 'story_type': 'text'},
        userId: 25,
        username: 'vendeur',
      );

      await StoryOfflineService.syncPending();
      expect(Hive.box<dynamic>('story_offline_data').containsKey(key), isTrue);

      await StoryOfflineService.initialize(
        publishStory: (fields, {imageFile, videoFile}) async => {
          'success': true,
          'data': {'id': 42},
        },
        listenForConnectivity: false,
        syncOnStart: false,
      );
      final syncedKeys = await StoryOfflineService.syncPending();

      expect(syncedKeys, contains(key));
      expect(Hive.box<dynamic>('story_offline_data').containsKey(key), isFalse);
      expect(StoryOfflineService.pendingCount.value, 0);
    },
  );
}
