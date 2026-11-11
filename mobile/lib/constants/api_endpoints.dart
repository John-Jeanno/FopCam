import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

// Helper to detect if we're running inside the iOS simulator.
bool isIosSimulatorFromEnv(Map<String, String> env) {
  final home = env['HOME'] ?? '';
  return env.containsKey('SIMULATOR_DEVICE_NAME') ||
      env.containsKey('SIMULATOR_LAUNCH_DEFAULTS') ||
      env.containsKey('SIMULATOR_HOST_HOME') ||
      env.containsKey('SIMULATOR_MODEL_IDENTIFIER') ||
      env.containsKey('SIMULATOR_STATUS_BAR_DATA') ||
      env.containsKey('SIMULATOR_ROOT') ||
      home.contains('/Library/Developer/CoreSimulator/Devices/');
}

bool get _isIosSimulator {
  try {
    if (!Platform.isIOS) {
      return false;
    }
    return isIosSimulatorFromEnv(Platform.environment);
  } catch (_) {
    return false;
  }
}

class ApiEndpoints {
  static const String _envBackendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://5nmg.l.time4vps.cloud/fopcam-api',
  );
  static const String _fallbackHost = String.fromEnvironment(
    'BACKEND_HOST',
    defaultValue: '5nmg.l.time4vps.cloud',
  );
  static const String _fallbackPath = String.fromEnvironment(
    'BACKEND_PATH',
    defaultValue: '/fopcam-api',
  );

  static String _fallbackScheme(String host) {
    final port = host.contains(':') ? int.tryParse(host.split(':').last) : null;
    if (port != null) {
      return port == 443 ? 'https' : 'http';
    }
    return 'https';
  }

  static String get _fallbackBaseUrl =>
      '${_fallbackScheme(_fallbackHost)}://$_fallbackHost$_fallbackPath';

  static String get _fallbackWsUrl {
    final scheme = _fallbackScheme(_fallbackHost) == 'https' ? 'wss' : 'ws';
    return '$scheme://$_fallbackHost${_normalizeWsPath(_fallbackPath)}';
  }

  static bool _iosSimulatorOverride = false;

  static void setIosSimulator(bool value) {
    _iosSimulatorOverride = value;
  }

  static bool get _effectiveIosSimulator =>
      _iosSimulatorOverride || _isIosSimulator;

  static String _normalizeWsPath(String path) {
    if (path.isEmpty || path == '/') {
      return '/ws/';
    }

    final normalizedPath = path.replaceAll(RegExp(r'/+$'), '');
    if (normalizedPath.endsWith('/ws')) {
      return '$normalizedPath/';
    }

    return '$normalizedPath/ws/';
  }

  static String buildBaseUrl({
    String? envBackendUrl,
    bool isAndroid = false,
    bool isIOS = false,
    bool isMacOS = false,
    bool? isIosSimulator,
  }) {
    final backendUrl = (envBackendUrl ?? _envBackendUrl).trim();
    final simulator = isIosSimulator ?? _effectiveIosSimulator;
    debugPrint(
      'ApiEndpoints.buildBaseUrl: envBackendUrl=$backendUrl, '
      'isAndroid=$isAndroid, isIOS=$isIOS, isMacOS=$isMacOS, '
      'isIosSimulator=$simulator, '
      '_iosSimulatorOverride=$_iosSimulatorOverride, '
      '_isIosSimulator=$_isIosSimulator',
    );

    if (backendUrl.isNotEmpty) {
      // If a backend URL was explicitly provided and we're running on an
      // Android emulator, rewrite localhost to 10.0.2.2 so the emulator can
      // reach the host machine.
      try {
        final uri = Uri.parse(backendUrl);
        final scheme = uri.scheme.isNotEmpty ? uri.scheme : 'http';
        final port = uri.hasPort && uri.port != 0
            ? uri.port
            : (scheme == 'https' ? 443 : 80);
        final path = uri.path.isNotEmpty ? uri.path : '';
        final isLocalHost = uri.host == '127.0.0.1' || uri.host == 'localhost';

        // If a backend URL points to localhost on a physical iOS device or
        // macOS, use the configured fallback host instead of attempting to
        // contact the local machine.
        if (isLocalHost && (isMacOS || (isIOS && !simulator))) {
          return _fallbackBaseUrl;
        }

        final host = isAndroid && isLocalHost
            ? '10.0.2.2'
            : (isIOS && simulator && isLocalHost)
            ? '127.0.0.1'
            : uri.host;
        final effectivePort =
            (scheme == 'https' && port == 443) ||
                (scheme == 'http' && port == 80)
            ? null
            : port;
        return Uri(
          scheme: scheme,
          host: host,
          port: effectivePort,
          path: path,
        ).toString();
      } catch (_) {
        return backendUrl;
      }
    }

    if (isAndroid) {
      return 'http://10.0.2.2:8000';
    }

    if (isMacOS) {
      // For macOS builds, default to the configured fallback backend host.
      return _fallbackBaseUrl;
    }

    if (isIOS && simulator) {
      // An explicitly empty backend URL opts the simulator into local API
      // development.
      return 'http://127.0.0.1:8000';
    }

    if (isIOS) {
      // Use the configured fallback backend host on physical iOS devices.
      return _fallbackBaseUrl;
    }

    // For other platforms default to the configured fallback backend host.
    return _fallbackBaseUrl;
  }

  static String get baseUrl {
    if (kIsWeb) {
      return buildBaseUrl();
    }

    if (Platform.isMacOS) {
      final val = _fallbackBaseUrl;
      debugPrint('ApiEndpoints.baseUrl (override macOS) = $val');
      return val;
    }

    final base = buildBaseUrl(
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
      isMacOS: Platform.isMacOS,
    );
    debugPrint('ApiEndpoints.baseUrl = $base');
    return base;
  }

  // Auth endpoints
  static const String register = '/api/auth/register/';
  static const String login = '/api/auth/token/';
  static const String refreshToken = '/api/auth/token/refresh/';
  static const String logout = '/api/auth/logout/';
  static const String passwordResetRequest =
      '/api/auth/password-reset/request/';
  static const String passwordResetConfirm =
      '/api/auth/password-reset/confirm/';
  static const String profile = '/api/auth/profile/';
  static const String userDirectory = '/api/users/directory/';
  static const String userPresence = '/api/users/presence/';
  static const String userPublicProfiles = '/api/users/';
  static const String gameLevelTwelveReward = '/api/game/rewards/level-12/';
  static const String gameLegends = '/api/game/legends/';
  static const String gameChallenges = '/api/game/challenges/';
  static const String gameTournaments = '/api/game/tournaments/';
  static const String liveGameChallenges = '/api/game/challenges/live/';
  static const String profiles = '/api/profiles/';

  // Products
  static const String products = '/api/products/';
  static const String myProducts = '/api/products/my/';

  // Shops
  static const String shops = '/api/shops/';
  static const String myShop = '/api/shops/my/';
  static String shopAnalytics(int shopId) => '/api/shops/$shopId/analytics/';
  static const String shopSeedProducts = '/api/shops/seed_products/';

  // Friends
  static const String friends = '/api/friends/';

  // Orders
  static const String orders = '/api/orders/';
  static const String salesOrders = '/api/orders/sales/';
  static const String stockMovements = '/api/products/stock_movements/';

  // Messages
  static const String messages = '/api/messages/';

  // Categories
  static const String categories = '/api/categories/';

  // Groups
  static const String groups = '/api/groups/';
  static const String groupEvents = '/api/group-events/';
  static const String jobPostings = '/api/job-postings/';
  static const String jobSeekerPosts = '/api/job-seeker-posts/';
  static const String jobApplications = '/api/job-applications/';
  static const String profileRoleChange = '/api/auth/profile/change-role/';
  static const String profileAnalytics = '/api/auth/profile/analytics/';

  // Stories
  static const String stories = '/api/stories/';

  // Reels & Live
  static const String reels = '/api/reels/';
  static const String liveStreams = '/api/live-streams/';

  // Posts, likes, comments
  static const String posts = '/api/posts/';
  static const String likes = '/api/likes/';
  static const String comments = '/api/comments/';
  static const String shares = '/api/shares/';

  // Notifications
  static const String notifications = '/api/notifications/';

  // Producer Reviews
  static const String producerReviews = '/api/producer-reviews/';

  // WebSocket
  static String buildWsUrl({
    String? envBackendUrl,
    bool isAndroid = false,
    bool isIOS = false,
    bool isMacOS = false,
    bool? isIosSimulator,
  }) {
    final backendUrl = (envBackendUrl ?? _envBackendUrl).trim();
    final simulator = isIosSimulator ?? _effectiveIosSimulator;
    debugPrint(
      'ApiEndpoints.buildWsUrl: envBackendUrl=$backendUrl, '
      'isAndroid=$isAndroid, isIOS=$isIOS, isMacOS=$isMacOS, '
      'isIosSimulator=$simulator',
    );

    if (backendUrl.isNotEmpty) {
      Uri uri;
      try {
        uri = Uri.parse(backendUrl);
      } catch (_) {
        return 'ws://$backendUrl/ws/';
      }

      if (uri.scheme.isEmpty && uri.host.isEmpty) {
        uri = Uri.parse('http://$backendUrl');
      }

      // If a build-time BACKEND_URL points to localhost but we're running
      // on macOS or the iOS simulator, prefer the production fallback
      // WebSocket host instead of attempting to contact the developer machine.
      final isLocalHost = uri.host == '127.0.0.1' || uri.host == 'localhost';

      if (isLocalHost && (isMacOS || (isIOS && !simulator))) {
        return _fallbackWsUrl;
      }

      final scheme = uri.scheme == 'https'
          ? 'wss'
          : uri.scheme == 'ws' || uri.scheme == 'wss'
          ? uri.scheme
          : 'ws';
      final host = isAndroid && isLocalHost
          ? '10.0.2.2'
          : (isIOS && simulator && isLocalHost)
          ? '127.0.0.1'
          : uri.host;
      final port = uri.hasPort ? uri.port : null;
      final path = _normalizeWsPath(uri.path);

      return Uri(
        scheme: scheme,
        userInfo: uri.userInfo,
        host: host,
        port: port,
        path: path,
        query: uri.query.isNotEmpty ? uri.query : null,
        fragment: uri.fragment.isNotEmpty ? uri.fragment : null,
      ).toString();
    }

    if (isAndroid) {
      return 'ws://10.0.2.2:8000/ws/';
    }

    if (isMacOS) {
      return _fallbackWsUrl;
    }

    if (isIOS && simulator) {
      return 'ws://127.0.0.1:8000/ws/';
    }

    if (isIOS) {
      return _fallbackWsUrl;
    }

    return _fallbackWsUrl;
  }

  static String get wsUrl {
    if (kIsWeb) {
      return buildWsUrl();
    }

    if (Platform.isMacOS) {
      final val = _fallbackWsUrl;
      debugPrint('ApiEndpoints.wsUrl (override macOS) = $val');
      return val;
    }

    return buildWsUrl(
      isAndroid: Platform.isAndroid,
      isIOS: Platform.isIOS,
      isMacOS: Platform.isMacOS,
    );
  }
}
