import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/models/story.dart';
import 'package:mobile/services/storage_service.dart';

typedef StoryPublisher =
    Future<Map<String, dynamic>> Function(
      Map<String, dynamic> fields, {
      XFile? imageFile,
      XFile? videoFile,
    });

class StoryOfflineService {
  StoryOfflineService._();

  static const _boxName = 'story_offline_data';
  static const _cachedStoriesKey = 'cached_stories';
  static const _pendingPrefix = 'pending_';
  static final _pendingCount = ValueNotifier<int>(0);

  static Box<dynamic>? _box;
  static StreamSubscription<List<ConnectivityResult>>?
  _connectivitySubscription;
  static Future<Set<String>>? _syncFuture;
  static int _nextLocalId = 0;
  static StoryPublisher? _publishStory;

  static ValueListenable<int> get pendingCount => _pendingCount;

  static Future<void> initialize({
    required StoryPublisher publishStory,
    bool listenForConnectivity = true,
    bool syncOnStart = true,
  }) async {
    _publishStory = publishStory;
    _box ??= await Hive.openBox<dynamic>(_boxName);
    _refreshPendingCount();
    if (listenForConnectivity) {
      _connectivitySubscription ??= Connectivity().onConnectivityChanged.listen(
        (results) {
          if (results.any((result) => result != ConnectivityResult.none)) {
            unawaited(syncPending());
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          debugPrint('Surveillance réseau des statuts impossible : $error');
        },
      );
    }
    if (syncOnStart) unawaited(syncPending());
  }

  static Box<dynamic> get _storage {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError(
        'StoryOfflineService.initialize() must be called first.',
      );
    }
    return box;
  }

  static Future<void> cacheStories(List<Map<String, dynamic>> stories) async {
    await _storage.put(_cachedStoriesKey, stories);
    await _storage.flush();
  }

  static List<Story> cachedStories() {
    final stored = _storage.get(_cachedStoriesKey);
    if (stored is! List) return const [];

    return stored
        .whereType<Map>()
        .map((item) => Story.fromJson(Map<String, dynamic>.from(item)))
        .where((story) => !story.isExpired)
        .toList();
  }

  static Future<List<Story>> pendingStories() async {
    final userData = await StorageService.getUserData();
    if (userData == null) return const [];
    final user = jsonDecode(userData);
    if (user is! Map<String, dynamic>) return const [];
    final userId = int.tryParse(user['id']?.toString() ?? '');
    if (userId == null) return const [];
    final records = _pendingRecords();
    return records
        .where(
          (record) =>
              int.tryParse(record['user_id']?.toString() ?? '') == userId,
        )
        .map(_storyFromPendingRecord)
        .toList();
  }

  static Future<String> enqueueStory({
    required Map<String, dynamic> fields,
    required int userId,
    required String username,
    XFile? mediaFile,
  }) async {
    final bytes = mediaFile == null ? null : await mediaFile.readAsBytes();
    final now = DateTime.now().toUtc();
    final key =
        '$_pendingPrefix${now.microsecondsSinceEpoch}_${_nextLocalId++}';
    final mediaName = mediaFile?.name.trim();
    final storedMediaName = mediaFile == null
        ? null
        : mediaName == null || mediaName.isEmpty
        ? 'statut.${fields['story_type'] == 'video' ? 'mp4' : 'jpg'}'
        : mediaName;
    await _storage.put(key, <String, dynamic>{
      'key': key,
      'fields': Map<String, dynamic>.from(fields),
      'user_id': userId,
      'username': username,
      'created_at': now.toIso8601String(),
      'local_id': -now.microsecondsSinceEpoch,
      'media_kind': fields['story_type'],
      'media_name': storedMediaName,
      'media_mime_type': mediaFile?.mimeType,
      'media_bytes': bytes?.toList(),
    });
    await _storage.flush();
    _refreshPendingCount();
    return key;
  }

  static Future<Set<String>> syncPending() {
    final running = _syncFuture;
    if (running != null) return running;

    final future = _syncPending();
    _syncFuture = future;
    return future.whenComplete(() {
      if (identical(_syncFuture, future)) _syncFuture = null;
    });
  }

  static Future<bool> enqueueAndSync({
    required Map<String, dynamic> fields,
    required int userId,
    required String username,
    XFile? mediaFile,
  }) async {
    final key = await enqueueStory(
      fields: fields,
      userId: userId,
      username: username,
      mediaFile: mediaFile,
    );
    var synced = await syncPending();
    if (!synced.contains(key) && _storage.containsKey(key)) {
      synced = await syncPending();
    }
    return synced.contains(key);
  }

  static Future<Set<String>> _syncPending() async {
    final syncedKeys = <String>{};
    final token = await StorageService.getAccessToken();
    final userData = await StorageService.getUserData();
    if (token == null || userData == null) return syncedKeys;

    final user = jsonDecode(userData);
    if (user is! Map<String, dynamic>) return syncedKeys;
    final currentUserId = int.tryParse(user['id']?.toString() ?? '');
    if (currentUserId == null) return syncedKeys;

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.every((result) => result == ConnectivityResult.none)) {
        return syncedKeys;
      }
    } catch (error) {
      debugPrint(
        'État réseau indisponible, tentative de synchronisation : $error',
      );
    }

    for (final record in _pendingRecords()) {
      final key = record['key']?.toString();
      if (key == null ||
          int.tryParse(record['user_id']?.toString() ?? '') != currentUserId) {
        continue;
      }

      final rawFields = record['fields'];
      if (rawFields is! Map) {
        debugPrint('Statut hors ligne $key conservé : données invalides.');
        continue;
      }

      final media = _mediaFromRecord(record);
      final publishStory = _publishStory;
      if (publishStory == null) {
        throw StateError(
          'A story publisher must be configured before syncing.',
        );
      }
      final result = await publishStory(
        Map<String, dynamic>.from(rawFields),
        imageFile: record['media_kind'] == 'image' ? media : null,
        videoFile: record['media_kind'] == 'video' ? media : null,
      );
      if (result['success'] == true) {
        await _storage.delete(key);
        await _storage.flush();
        syncedKeys.add(key);
      } else {
        await _storage.put(key, <String, dynamic>{
          ...Map<String, dynamic>.from(record),
          'last_error': result['error']?.toString() ?? 'Erreur inconnue',
        });
        await _storage.flush();
        debugPrint('Synchronisation du statut $key différée.');
        break;
      }
    }

    _refreshPendingCount();
    return syncedKeys;
  }

  static XFile? _mediaFromRecord(Map<String, dynamic> record) {
    final rawBytes = record['media_bytes'];
    final name = record['media_name']?.toString();
    if (rawBytes is! List || name == null) return null;

    final bytes = Uint8List.fromList(
      rawBytes.map((value) => (value as num).toInt()).toList(),
    );
    return XFile.fromData(
      bytes,
      name: name,
      path: '/fopcam_offline/$name',
      mimeType: record['media_mime_type']?.toString(),
    );
  }

  static List<Map<String, dynamic>> _pendingRecords() {
    return _storage.keys
        .whereType<String>()
        .where((key) => key.startsWith(_pendingPrefix))
        .map(_storage.get)
        .whereType<Map>()
        .map((record) => Map<String, dynamic>.from(record))
        .toList()
      ..sort(
        (a, b) => (a['created_at']?.toString() ?? '').compareTo(
          b['created_at']?.toString() ?? '',
        ),
      );
  }

  static Story _storyFromPendingRecord(Map<String, dynamic> record) {
    final fields = Map<String, dynamic>.from(record['fields'] as Map);
    final now =
        DateTime.tryParse(record['created_at']?.toString() ?? '') ??
        DateTime.now();
    final userId = int.tryParse(record['user_id']?.toString() ?? '') ?? 0;
    return Story.fromJson({
      'id': record['local_id'] ?? -++_nextLocalId,
      'story_type': fields['story_type'] ?? 'text',
      'content': fields['content'] ?? '',
      'background_color': fields['background_color'],
      'text_color': fields['text_color'],
      'font_size': fields['font_size'],
      'is_pending': true,
      'created_at': now.toIso8601String(),
      'author': {
        'id': userId,
        'username': record['username'] ?? 'Vous',
        'email': '',
        'role': 'producer',
      },
    });
  }

  static void _refreshPendingCount() {
    _pendingCount.value = _pendingRecords().length;
  }
}
