import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/offline_data_service.dart';
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
      'fopcam-offline-data-test-',
    );
    Hive.init(storageDirectory.path);
    SharedPreferences.setMockInitialValues({});
    await StorageService.saveAccessToken('offline-test-token');
    await StorageService.saveUserData('{"id":42,"username":"test"}');
    await OfflineDataService.initialize();
  });

  setUp(() async {
    await Hive.box<dynamic>('offline_api_cache').clear();
    SharedPreferences.setMockInitialValues({});
    await StorageService.saveAccessToken('offline-test-token');
    await StorageService.saveUserData('{"id":42,"username":"test"}');
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

  test(
    'serves an account-scoped cached API response after network failure',
    () async {
      final uri = Uri.parse('https://example.test/api/auth/profile/');
      final online = await http.runWithClient(
        () => OfflineDataService.get(
          uri,
          headers: const {'Authorization': 'Bearer offline-test-token'},
        ),
        () => MockClient(
          (_) async => http.Response(
            jsonEncode({'id': 42, 'username': 'test'}),
            200,
            headers: const {'content-type': 'application/json'},
          ),
        ),
      );
      expect(jsonDecode(online.body)['username'], 'test');

      final cached = await http.runWithClient(
        () => OfflineDataService.get(
          uri,
          headers: const {'Authorization': 'Bearer offline-test-token'},
        ),
        () => MockClient((_) async => throw http.ClientException('offline')),
      );
      expect(cached.statusCode, 200);
      expect(cached.headers['x-fopcam-offline-cache'], 'true');
      expect(jsonDecode(cached.body)['id'], 42);
      expect(OfflineDataService.isOnline.value, isFalse);

      await StorageService.saveUserData('{"id":99,"username":"other"}');
      await expectLater(
        http.runWithClient(
          () => OfflineDataService.get(
            uri,
            headers: const {'Authorization': 'Bearer offline-test-token'},
          ),
          () => MockClient((_) async => throw http.ClientException('offline')),
        ),
        throwsA(isA<http.ClientException>()),
      );
      await StorageService.saveUserData('{"id":42,"username":"test"}');
    },
  );

  test(
    'keeps safe profile edits in a queue until the server accepts them',
    () async {
      final uri = Uri.parse('https://example.test/api/auth/profile/');
      final queued = await http.runWithClient(
        () => OfflineDataService.patch(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'preferred_language': 'fr'}),
        ),
        () => MockClient((_) async => throw http.ClientException('offline')),
      );
      expect(queued.statusCode, 202);
      expect(jsonDecode(queued.body)['offline_pending'], isTrue);
      expect(OfflineDataService.pendingChanges.value, 1);

      OfflineDataService.isOnline.value = true;
      await http.runWithClient(
        OfflineDataService.syncPendingChanges,
        () => MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.headers['authorization'], 'Bearer offline-test-token');
          expect(jsonDecode(request.body)['preferred_language'], 'fr');
          return http.Response('{}', 200);
        }),
      );
      expect(OfflineDataService.pendingChanges.value, 0);
    },
  );

  test('does not queue arbitrary PATCH endpoints', () async {
    await expectLater(
      http.runWithClient(
        () => OfflineDataService.patch(
          Uri.parse('https://example.test/api/orders/15/'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'status': 'paid'}),
        ),
        () => MockClient((_) async => throw http.ClientException('offline')),
      ),
      throwsA(isA<http.ClientException>()),
    );
    expect(OfflineDataService.pendingChanges.value, 0);
  });
}
