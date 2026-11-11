import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/constants/api_endpoints.dart';

void main() {
  group('ApiEndpoints', () {
    test('exposes the authenticated profile analytics endpoint', () {
      expect(ApiEndpoints.profileAnalytics, '/api/auth/profile/analytics/');
    });

    test('builds the analytics endpoint for a specific shop', () {
      expect(ApiEndpoints.shopAnalytics(42), '/api/shops/42/analytics/');
    });

    test('uses override when provided', () {
      expect(
        ApiEndpoints.buildBaseUrl(envBackendUrl: 'http://192.168.1.10:9000'),
        'http://192.168.1.10:9000',
      );
    });

    test('uses the public API by default on Android', () {
      expect(
        ApiEndpoints.buildBaseUrl(isAndroid: true),
        'https://5nmg.l.time4vps.cloud/fopcam-api',
      );
    });

    test('uses the public API by default on iOS and macOS', () {
      expect(
        ApiEndpoints.buildBaseUrl(isIOS: true),
        'https://5nmg.l.time4vps.cloud/fopcam-api',
      );
      expect(
        ApiEndpoints.buildBaseUrl(isMacOS: true),
        'https://5nmg.l.time4vps.cloud/fopcam-api',
      );
    });

    test('uses public API by default on iOS simulator', () {
      expect(
        ApiEndpoints.buildBaseUrl(isIOS: true, isIosSimulator: true),
        'https://5nmg.l.time4vps.cloud/fopcam-api',
      );
    });
                                    
    test('uses local backend on iOS simulator when explicitly configured', () {
      expect(
        ApiEndpoints.buildBaseUrl(
          envBackendUrl: '',
          isIOS: true,
          isIosSimulator: true,
        ),
        'http://127.0.0.1:8000',
      );
    });

    test('uses the public fallback on macOS with no backend override', () {
      expect(
        ApiEndpoints.buildBaseUrl(envBackendUrl: '', isMacOS: true),
        'https://5nmg.l.time4vps.cloud/fopcam-api',
      );
    });

    test('detects iOS simulator from HOME env path', () {
      expect(
        isIosSimulatorFromEnv({
          'HOME': '/Users/test/Library/Developer/CoreSimulator/Devices/ABCDEFG',
          'SIMULATOR_DEVICE_NAME': '',
        }),
        true,
      );
    });

    test(
      'rewrites localhost backend URL for iOS simulator when env is provided',
      () {
        expect(
          ApiEndpoints.buildBaseUrl(
            envBackendUrl: 'http://localhost:8000',
            isIOS: true,
            isIosSimulator: true,
          ),
          'http://127.0.0.1:8000',
        );
      },
    );

    test(
      'does not rewrite production backend URL to localhost on iOS simulator',
      () {
        expect(
          ApiEndpoints.buildBaseUrl(
            envBackendUrl: 'https://5nmg.l.time4vps.cloud',
            isIOS: true,
            isIosSimulator: true,
          ),
          'https://5nmg.l.time4vps.cloud',
        );
      },
    );

    test('rewrites localhost backend URL to fallback host on physical iOS', () {
      expect(
        ApiEndpoints.buildBaseUrl(
          envBackendUrl: 'http://127.0.0.1:8000',
          isIOS: true,
          isIosSimulator: false,
        ),
        'https://5nmg.l.time4vps.cloud/fopcam-api',
      );
    });

    test('preserves IP backend URL on iOS simulator', () {
      expect(
        ApiEndpoints.buildBaseUrl(
          envBackendUrl: 'http://192.168.1.7:8000',
          isIOS: true,
          isIosSimulator: true,
        ),
        'http://192.168.1.7:8000',
      );
    });

    test('normalizes websocket URL from explicit backend URL', () {
      expect(
        ApiEndpoints.buildWsUrl(envBackendUrl: 'http://192.168.1.7:8000'),
        'ws://192.168.1.7:8000/ws/',
      );
      expect(
        ApiEndpoints.buildWsUrl(envBackendUrl: 'https://example.com/api'),
        'wss://example.com/api/ws/',
      );
    });

    test('uses public websocket API by default on iOS simulator', () {
      expect(
        ApiEndpoints.buildWsUrl(isIOS: true, isIosSimulator: true),
        'wss://5nmg.l.time4vps.cloud/fopcam-api/ws/',
      );
    });

    test('uses public websocket API by default on macOS', () {
      expect(
        ApiEndpoints.buildWsUrl(isMacOS: true),
        'wss://5nmg.l.time4vps.cloud/fopcam-api/ws/',
      );
    });

    test(
      'rewrites explicit localhost websocket url to simulator localhost on iOS simulator',
      () {
        expect(
          ApiEndpoints.buildWsUrl(
            envBackendUrl: 'http://localhost:8000',
            isIOS: true,
            isIosSimulator: true,
          ),
          'ws://127.0.0.1:8000/ws/',
        );
      },
    );

    test(
      'does not rewrite production websocket url to localhost on iOS simulator',
      () {
        expect(
          ApiEndpoints.buildWsUrl(
            envBackendUrl: 'https://5nmg.l.time4vps.cloud',
            isIOS: true,
            isIosSimulator: true,
          ),
          'wss://5nmg.l.time4vps.cloud/ws/',
        );
      },
    );

    test(
      'rewrites localhost websocket URL to the public API on physical iOS',
      () {
        expect(
          ApiEndpoints.buildWsUrl(
            envBackendUrl: 'http://127.0.0.1:8000',
            isIOS: true,
            isIosSimulator: false,
          ),
          'wss://5nmg.l.time4vps.cloud/fopcam-api/ws/',
        );
      },
    );
  });
}
