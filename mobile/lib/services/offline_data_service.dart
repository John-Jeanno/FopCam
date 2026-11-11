import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:http/http.dart' as http;
import 'package:mobile/services/storage_service.dart';

class OfflineDataService {
  OfflineDataService._();

  static const _boxName = 'offline_api_cache';
  static const _pendingPrefix = 'pending_patch_';
  static const _cachePrefix = 'get_';
  static const _maxCachedResponses = 400;
  static final ValueNotifier<bool> isOnline = ValueNotifier<bool>(true);
  static final ValueNotifier<int> pendingChanges = ValueNotifier<int>(0);

  static Box<dynamic>? _box;
  static StreamSubscription<List<ConnectivityResult>>? _connectivity;
  static Future<void>? _syncFuture;
  static int _nextQueueId = 0;

  static Future<void> initialize() async {
    _box ??= await Hive.openBox<dynamic>(_boxName);
    _refreshPendingCount();
    _connectivity ??= Connectivity().onConnectivityChanged.listen(
      (results) {
        _updateConnectivity(results);
        if (isOnline.value) unawaited(syncPendingChanges());
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Surveillance réseau impossible : $error');
      },
    );
    try {
      _updateConnectivity(await Connectivity().checkConnectivity());
      if (isOnline.value) unawaited(syncPendingChanges());
    } catch (error) {
      debugPrint('Vérification de la connexion impossible : $error');
    }
  }

  static Box<dynamic> get _storage {
    final box = _box;
    if (box == null || !box.isOpen) {
      throw StateError('OfflineDataService.initialize() must be called first.');
    }
    return box;
  }

  static void _updateConnectivity(List<ConnectivityResult> results) {
    isOnline.value = results.any((result) => result != ConnectivityResult.none);
  }

  static void _markOnline() {
    isOnline.value = true;
    if (_box != null) unawaited(syncPendingChanges());
  }

  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
  }) async {
    final cacheKey = await _cacheKey(uri, headers);
    final canCache = cacheKey != null && _isCacheable(uri);
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (canCache) await _save(cacheKey, response);
        _markOnline();
        return response;
      }
      if (response.statusCode >= 500 && canCache) {
        final cached = _read(cacheKey, uri);
        if (cached != null) return cached;
      }
      return response;
    } on http.ClientException catch (error, stackTrace) {
      isOnline.value = false;
      final cached = canCache ? _read(cacheKey, uri) : null;
      if (cached != null) return cached;
      Error.throwWithStackTrace(error, stackTrace);
    } on TimeoutException catch (error, stackTrace) {
      isOnline.value = false;
      final cached = canCache ? _read(cacheKey, uri) : null;
      if (cached != null) return cached;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<http.Response> patch(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    try {
      final response = await http.patch(uri, headers: headers, body: body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        _markOnline();
      }
      return response;
    } on http.ClientException catch (error, stackTrace) {
      isOnline.value = false;
      final key = await _enqueuePatch(uri, body);
      if (key == null) Error.throwWithStackTrace(error, stackTrace);
      return _pendingResponse(uri, key);
    } on TimeoutException catch (error, stackTrace) {
      isOnline.value = false;
      final key = await _enqueuePatch(uri, body);
      if (key == null) Error.throwWithStackTrace(error, stackTrace);
      return _pendingResponse(uri, key);
    }
  }

  static Future<String?> _enqueuePatch(Uri uri, String body) async {
    if (!_isQueueablePatch(uri)) return null;
    final userData = await StorageService.getUserData();
    if (await StorageService.getAccessToken() == null || userData == null) {
      return null;
    }

    final decodedUser = jsonDecode(userData);
    if (decodedUser is! Map) return null;
    final userId = int.tryParse(decodedUser['id']?.toString() ?? '');
    if (userId == null) return null;
    final key =
        '$_pendingPrefix${DateTime.now().toUtc().microsecondsSinceEpoch}_'
        '${_nextQueueId++}';
    await _storage.put(key, {
      'uri': uri.toString(),
      'body': body,
      'user_id': userId,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await _storage.flush();
    _refreshPendingCount();
    return key;
  }

  static bool _isQueueablePatch(Uri uri) {
    final path = uri.path.toLowerCase();
    return RegExp(
      r'/api/auth/profile/$|/api/(posts|comments|products|shops)/\d+/$',
    ).hasMatch(path);
  }

  static http.Response _pendingResponse(Uri uri, String key) => http.Response(
    jsonEncode({'offline_pending': true, 'queue_id': key}),
    202,
    request: http.Request('PATCH', uri),
    headers: const {'content-type': 'application/json'},
  );

  static Future<void> syncPendingChanges() {
    final existing = _syncFuture;
    if (existing != null) return existing;
    final future = _syncChanges();
    _syncFuture = future;
    return future.whenComplete(() {
      if (identical(_syncFuture, future)) _syncFuture = null;
    });
  }

  static Future<void> _syncChanges() async {
    final token = await StorageService.getAccessToken();
    final userData = await StorageService.getUserData();
    if (token == null || userData == null || !isOnline.value) return;
    final decodedUser = jsonDecode(userData);
    if (decodedUser is! Map) return;
    final userId = int.tryParse(decodedUser['id']?.toString() ?? '');
    if (userId == null) return;

    final queued =
        _storage.keys
            .whereType<String>()
            .where((key) => key.startsWith(_pendingPrefix))
            .toList()
          ..sort();
    for (final key in queued) {
      final record = _storage.get(key);
      if (record is! Map ||
          int.tryParse(record['user_id']?.toString() ?? '') != userId) {
        continue;
      }
      try {
        final response = await http.patch(
          Uri.parse(record['uri'] as String),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: record['body'] as String,
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          await _storage.delete(key);
          await _storage.flush();
        } else {
          debugPrint(
            'Modification hors ligne conservée après HTTP '
            '${response.statusCode}.',
          );
          break;
        }
      } on http.ClientException catch (error) {
        isOnline.value = false;
        debugPrint('Synchronisation hors ligne interrompue : $error');
        break;
      } on TimeoutException catch (error) {
        isOnline.value = false;
        debugPrint('Synchronisation hors ligne interrompue : $error');
        break;
      }
    }
    _refreshPendingCount();
  }

  static void _refreshPendingCount() {
    pendingChanges.value = _storage.keys
        .whereType<String>()
        .where((key) => key.startsWith(_pendingPrefix))
        .length;
  }

  static bool _isCacheable(Uri uri) {
    if (!uri.path.contains('/api/')) return false;
    final path = uri.path.toLowerCase();
    const excludedPathFragments = [
      '/game/',
      '/live',
      '/presence',
      '/payments/',
      '/orders/',
      'unread_count',
      'pending_count',
      'resume_links',
      'mark_read',
      'mark_all_read',
    ];
    if (excludedPathFragments.any(path.contains)) return false;
    if (path.contains('/auth/') && !path.endsWith('/auth/profile/')) {
      return false;
    }
    if (uri.queryParameters['online'] == 'true') return false;
    if (uri.queryParameters.keys.any(
      (key) => const {'token', 'signature', 'expires'}.contains(key),
    )) {
      return false;
    }
    return true;
  }

  static Future<String?> _cacheKey(
    Uri uri,
    Map<String, String>? headers,
  ) async {
    final hasAuthorization =
        headers?.keys.any((key) => key.toLowerCase() == 'authorization') ??
        false;
    var scope = 'public';
    if (hasAuthorization) {
      final userData = await StorageService.getUserData();
      if (userData == null) return null;
      try {
        final decoded = jsonDecode(userData);
        final userId = decoded is Map
            ? int.tryParse(decoded['id']?.toString() ?? '')
            : null;
        if (userId == null) return null;
        scope = 'user:$userId';
      } on FormatException {
        return null;
      }
    }
    return 'get_${base64Url.encode(utf8.encode('$scope|$uri'))}';
  }

  static Future<void> _save(String? key, http.Response response) async {
    if (key == null) return;
    try {
      await _storage.put(key, {
        'body': response.body,
        'content_type': response.headers['content-type'] ?? 'application/json',
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      });
      final cachedKeys =
          _storage.keys
              .whereType<String>()
              .where((storedKey) => storedKey.startsWith(_cachePrefix))
              .toList()
            ..sort((left, right) {
              final leftAt = (_storage.get(left) as Map?)?['saved_at']
                  ?.toString();
              final rightAt = (_storage.get(right) as Map?)?['saved_at']
                  ?.toString();
              return (leftAt ?? '').compareTo(rightAt ?? '');
            });
      while (cachedKeys.length > _maxCachedResponses) {
        await _storage.delete(cachedKeys.removeAt(0));
      }
      await _storage.flush();
    } catch (error) {
      debugPrint('Impossible de conserver une réponse hors ligne : $error');
    }
  }

  static http.Response? _read(String? key, Uri uri) {
    if (key == null) return null;
    final value = _storage.get(key);
    if (value is! Map || value['body'] is! String) return null;
    debugPrint('Réponse hors ligne utilisée pour $uri');
    return http.Response(
      value['body'] as String,
      200,
      request: http.Request('GET', uri),
      headers: {
        'content-type': value['content_type']?.toString() ?? 'application/json',
        'x-fopcam-offline-cache': 'true',
      },
    );
  }
}
