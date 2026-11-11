import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService.formatAuthError', () {
    test('explains that the registration email is already in use', () {
      expect(
        AuthService.formatAuthError({
          'email': ['Ce champ doit être unique.'],
        }, isRegistration: true),
        'Cette adresse email est déjà utilisée. Utilisez une autre adresse ou connectez-vous.',
      );
    });

    test('formats username validation errors without showing JSON', () {
      final message = AuthService.formatAuthError({
        'username': ['This field must be unique.'],
      }, isRegistration: true);

      expect(
        message,
        'Ce nom d’utilisateur est déjà utilisé. Choisissez-en un autre.',
      );
      expect(message, isNot(contains('{')));
      expect(message, isNot(contains('[')));
    });

    test('describes incorrect login credentials in French', () {
      expect(
        AuthService.formatAuthError({
          'detail': 'No active account found with the given credentials',
        }, isRegistration: false),
        'Nom d’utilisateur ou mot de passe incorrect. Vérifiez vos identifiants puis réessayez.',
      );
    });

    test('hides network exception details from the form', () {
      expect(
        AuthService.formatAuthError(
          const SocketException('Connection refused'),
          isRegistration: false,
        ),
        'Connexion au serveur impossible. Vérifiez votre connexion internet puis réessayez.',
      );
    });

    test('uses a readable fallback for unknown server validation payloads', () {
      final message = AuthService.formatAuthError({
        'unexpected_field': ['technical error'],
      }, isRegistration: true);

      expect(
        message,
        'Inscription impossible. Vérifiez les informations saisies puis réessayez.',
      );
      expect(message, isNot(contains('{')));
    });
  });

  group('AuthService.refreshToken', () {
    test('stores rotated access and refresh tokens', () async {
      AuthService.sessionExpired.value = false;
      SharedPreferences.setMockInitialValues({
        'access_token': 'expired-access',
        'refresh_token': 'current-refresh',
      });

      final refreshed = await http.runWithClient(
        AuthService.refreshToken,
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'refresh': 'current-refresh'});
          return http.Response(
            jsonEncode({'access': 'new-access', 'refresh': 'new-refresh'}),
            200,
          );
        }),
      );

      expect(refreshed, isTrue);
      expect(await StorageService.getAccessToken(), 'new-access');
      expect(await StorageService.getRefreshToken(), 'new-refresh');
      expect(AuthService.sessionExpired.value, isFalse);
    });

    test('invalidates a session that has no refresh token', () async {
      AuthService.sessionExpired.value = false;
      SharedPreferences.setMockInitialValues({
        'access_token': 'expired-access',
        'user_data': '{"id":1,"username":"auteur"}',
      });

      final refreshed = await AuthService.refreshToken();

      expect(refreshed, isFalse);
      expect(await StorageService.getAccessToken(), isNull);
      expect(await StorageService.getUserData(), isNull);
      expect(AuthService.sessionExpired.value, isTrue);
    });

    test(
      'clears local session when the server rejects the refresh token',
      () async {
        AuthService.sessionExpired.value = false;
        SharedPreferences.setMockInitialValues({
          'access_token': 'expired-access',
          'refresh_token': 'revoked-refresh',
          'user_data': '{"id":1,"username":"auteur"}',
        });
        var refreshRequests = 0;

        final refreshed = await http.runWithClient(
          AuthService.refreshToken,
          () => MockClient((request) async {
            if (request.url.path.endsWith('/token/refresh/')) {
              refreshRequests++;
              return http.Response(
                '{"detail":"Token is invalid or expired"}',
                401,
              );
            }
            return http.Response('', 200);
          }),
        );

        expect(refreshed, isFalse);
        expect(refreshRequests, 1);
        expect(await StorageService.getAccessToken(), isNull);
        expect(await StorageService.getRefreshToken(), isNull);
        expect(await StorageService.getUserData(), isNull);
        expect(AuthService.sessionExpired.value, isTrue);
      },
    );

    test(
      'rejects cached sessions after the server rejects refresh tokens',
      () async {
        AuthService.sessionExpired.value = false;
        SharedPreferences.setMockInitialValues({
          'access_token': 'expired-access',
          'refresh_token': 'revoked-refresh',
          'user_data':
              '{"id":1,"username":"auteur","email":"auteur@example.com","role":"buyer"}',
        });

        final sessionValid = await http.runWithClient(
          AuthService.validateSession,
          () => MockClient((request) async {
            if (request.url.path.endsWith('/api/auth/profile/')) {
              return http.Response('{"detail":"Invalid token"}', 401);
            }
            if (request.url.path.endsWith('/api/auth/token/refresh/')) {
              return http.Response(
                '{"detail":"Token is invalid or expired"}',
                401,
              );
            }
            return http.Response('', 404);
          }),
        );

        expect(sessionValid, isFalse);
        expect(await StorageService.getAccessToken(), isNull);
        expect(await StorageService.getUserData(), isNull);
      },
    );
  });

  group('AuthService.login', () {
    test('distinguishes server errors from invalid credentials', () async {
      final result = await http.runWithClient(
        () => AuthService.login('probe-user', 'invalid-password'),
        () => MockClient(
          (_) async => http.Response('<html>Server Error</html>', 500),
        ),
      );

      expect(result['success'], isFalse);
      expect(
        result['error'],
        'Le service de connexion est temporairement indisponible. Réessayez plus tard.',
      );
    });
  });
}
