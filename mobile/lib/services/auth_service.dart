import 'dart:convert';
import 'dart:io' show Platform, SocketException;
import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint, ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:mobile/constants/api_endpoints.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/offline_data_service.dart';
import 'storage_service.dart';

class AuthService {
  static Completer<bool>? _refreshCompleter;
  static final ValueNotifier<bool> sessionExpired = ValueNotifier<bool>(false);

  static dynamic _parseResponseBody(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } catch (e) {
      debugPrint('AuthService._parseResponseBody failed: $e');
      return body;
    }
  }

  static Map<String, dynamic>? _parseResponseBodyAsMap(String body) {
    final result = _parseResponseBody(body);
    if (result is Map<String, dynamic>) return result;
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }

  static String formatAuthError(Object? error, {required bool isRegistration}) {
    if (error is Map) {
      final errors = Map<String, dynamic>.from(error);
      for (final field in const [
        'email',
        'username',
        'password',
        'phone',
        'motorcycle_plate',
        'first_name',
        'last_name',
        'address',
        'city',
        'country',
      ]) {
        final value = errors[field];
        if (value == null) continue;
        final message = _firstErrorMessage(value);
        if (message == null) continue;
        return _formatFieldError(field, message);
      }

      final detail =
          errors['detail'] ?? errors['error'] ?? errors['non_field_errors'];
      if (detail != null) {
        return _formatGeneralAuthError(
          _firstErrorMessage(detail) ?? '',
          isRegistration: isRegistration,
        );
      }
      return isRegistration
          ? 'Inscription impossible. Vérifiez les informations saisies puis réessayez.'
          : 'Connexion impossible. Vérifiez votre nom d’utilisateur et votre mot de passe.';
    }

    return _formatGeneralAuthError(
      error?.toString() ?? '',
      isRegistration: isRegistration,
    );
  }

  static Map<String, String> fieldErrors(Object? error) {
    if (error is! Map) return const {};
    final errors = <String, String>{};
    for (final field in const [
      'email',
      'username',
      'password',
      'phone',
      'motorcycle_plate',
      'first_name',
      'last_name',
      'address',
      'city',
      'country',
    ]) {
      final message = _firstErrorMessage(error[field]);
      if (message != null) errors[field] = _formatFieldError(field, message);
    }
    return errors;
  }

  static String? _firstErrorMessage(Object? value) {
    if (value is List) {
      for (final item in value) {
        final message = _firstErrorMessage(item);
        if (message != null) return message;
      }
      return null;
    }
    if (value is Map) {
      for (final item in value.values) {
        final message = _firstErrorMessage(item);
        if (message != null) return message;
      }
      return null;
    }
    final message = value?.toString().trim();
    return message == null || message.isEmpty ? null : message;
  }

  static String _formatFieldError(String field, String message) {
    final normalized = message.toLowerCase();
    final isUniqueError =
        normalized.contains('unique') ||
        normalized.contains('already exists') ||
        normalized.contains('already in use') ||
        normalized.contains('déjà utilisé') ||
        normalized.contains('déjà utilisée');

    if (field == 'email' && isUniqueError) {
      return 'Cette adresse email est déjà utilisée. Utilisez une autre adresse ou connectez-vous.';
    }
    if (field == 'username' && isUniqueError) {
      return 'Ce nom d’utilisateur est déjà utilisé. Choisissez-en un autre.';
    }
    if (field == 'email' &&
        (normalized.contains('valid email') ||
            normalized.contains('adresse email valide'))) {
      return 'L’adresse email saisie n’est pas valide.';
    }
    if (field == 'password' && normalized.contains('too short')) {
      return 'Le mot de passe est trop court. Choisissez un mot de passe plus long.';
    }

    const labels = {
      'email': 'Adresse email',
      'username': 'Nom d’utilisateur',
      'password': 'Mot de passe',
      'phone': 'Téléphone',
      'motorcycle_plate': 'Matricule de la moto',
      'first_name': 'Prénom',
      'last_name': 'Nom',
      'address': 'Adresse',
      'city': 'Ville',
      'country': 'Pays',
    };
    if (_isReadableFrench(message)) return message;
    return '${labels[field] ?? 'Ce champ'} invalide. Vérifiez cette information puis réessayez.';
  }

  static String _formatGeneralAuthError(
    String message, {
    required bool isRegistration,
  }) {
    final normalized = message.toLowerCase();
    if (normalized.contains('no active account') ||
        normalized.contains('given credentials') ||
        normalized.contains('invalid credentials') ||
        normalized.contains('identifiants incorrects') ||
        normalized.contains('identifiant ou mot de passe')) {
      return 'Nom d’utilisateur ou mot de passe incorrect. Vérifiez vos identifiants puis réessayez.';
    }
    if (normalized.contains('connexion au serveur impossible') ||
        normalized.contains('socketexception') ||
        normalized.contains('clientexception') ||
        normalized.contains('timed out') ||
        normalized.contains('timeout')) {
      return 'Connexion au serveur impossible. Vérifiez votre connexion internet puis réessayez.';
    }
    if (_isReadableFrench(message)) {
      return message;
    }
    return isRegistration
        ? 'Inscription impossible. Vérifiez les informations saisies puis réessayez.'
        : 'Connexion impossible. Vérifiez votre nom d’utilisateur et votre mot de passe.';
  }

  static bool _isReadableFrench(String message) {
    final normalized = message.trimLeft().toLowerCase();
    return normalized.startsWith('ce ') ||
        normalized.startsWith('cette ') ||
        normalized.startsWith('le ') ||
        normalized.startsWith('la ') ||
        normalized.startsWith('l’') ||
        normalized.startsWith("l'") ||
        normalized.startsWith('votre ') ||
        normalized.startsWith('veuillez ') ||
        normalized.startsWith('un ') ||
        normalized.startsWith('une ');
  }

  static Future<Map<String, dynamic>> register(
    String email,
    String password,
    String username,
    String firstName,
    String lastName,
    String phone,
    String address,
    String city,
    String country,
    String userType,
    String motorcyclePlate,
    double? latitude,
    double? longitude, {
    String countryCode = '',
    String preferredLanguage = '',
  }) async {
    try {
      final payload = <String, dynamic>{
        'email': email,
        'password': password,
        'username': username,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'address': address,
        'city': city,
        'country': country,
        'country_code': countryCode,
        'preferred_language': preferredLanguage,
        'user_type': userType,
        'motorcycle_plate': motorcyclePlate,
      };
      if (latitude != null) payload['latitude'] = latitude;
      if (longitude != null) payload['longitude'] = longitude;

      final response = await http.post(
        Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.register),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return {'success': true, 'data': _parseResponseBody(response.body)};
      } else {
        final responseError = _parseResponseBody(response.body);
        return {
          'success': false,
          'error': formatAuthError(responseError, isRegistration: true),
          'fieldErrors': fieldErrors(responseError),
        };
      }
    } on Object catch (error, stackTrace) {
      debugPrint('AuthService.register failed: $error\n$stackTrace');
      return {
        'success': false,
        'error': formatAuthError(error, isRegistration: true),
      };
    }
  }

  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    final loginUrl = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.login);

    try {
      final response = await http.post(
        loginUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = _parseResponseBody(response.body);
        if (data is Map<String, dynamic>) {
          await StorageService.saveAccessToken(data['access'] ?? '');
          if (data['refresh'] != null) {
            await StorageService.saveRefreshToken(data['refresh']);
          }
        }
        await getProfile();
        return {'success': true, 'data': data};
      } else {
        final responseError = _parseResponseBody(response.body);
        return {
          'success': false,
          'error': response.statusCode >= 500
              ? 'Le service de connexion est temporairement indisponible. Réessayez plus tard.'
              : formatAuthError(responseError, isRegistration: false),
          'fieldErrors': fieldErrors(responseError),
        };
      }
    } on SocketException catch (e, stackTrace) {
      debugPrint('AuthService.login socket error: $e');
      debugPrint('AuthService.login socket stack: $stackTrace');

      // Only attempt fallbacks when the configured host is a localhost-style
      // address. Avoid trying to contact local hosts when the app is
      // configured to use a remote production backend.
      final fallbackUris = <Uri>[];
      final isLocalHost =
          loginUrl.host == '127.0.0.1' || loginUrl.host == 'localhost';
      if (isLocalHost) {
        if (Platform.isAndroid) {
          // Android emulator must use 10.0.2.2 to reach host machine.
          fallbackUris.add(loginUrl.replace(host: '10.0.2.2'));
        }
        // For other platforms we keep the original localhost entry only;
        // no additional wild fallback is attempted.
      }

      try {
        for (final fallbackUri in fallbackUris) {
          debugPrint(
            'AuthService.login retrying with fallback URL: $fallbackUri',
          );
          final retryResponse = await http.post(
            fallbackUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          );

          debugPrint(
            'AuthService.login retry response: ${retryResponse.statusCode}',
          );

          if (retryResponse.statusCode == 200) {
            final data = _parseResponseBodyAsMap(retryResponse.body);
            if (data != null) {
              await StorageService.saveAccessToken(data['access'] ?? '');
              if (data['refresh'] != null) {
                await StorageService.saveRefreshToken(data['refresh']);
              }
            }
            await getProfile();
            return {'success': true, 'data': data};
          }
        }
      } catch (retryError, retryStack) {
        debugPrint('AuthService.login retry failed: $retryError');
        debugPrint('AuthService.login retry stack: $retryStack');
      }

      return {
        'success': false,
        'error': formatAuthError(e, isRegistration: false),
      };
    } catch (e, stackTrace) {
      debugPrint('AuthService.login error: $e');
      debugPrint('AuthService.login stack: $stackTrace');
      return {
        'success': false,
        'error': formatAuthError(e, isRegistration: false),
      };
    }
  }

  static Future<bool> refreshToken() async {
    // Prevent concurrent refresh attempts: reuse the same future for callers.
    if (_refreshCompleter != null) {
      try {
        return await _refreshCompleter!.future;
      } catch (_) {
        return false;
      }
    }

    _refreshCompleter = Completer<bool>();
    try {
      final refreshToken = await StorageService.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('AuthService.refreshToken: aucun jeton de renouvellement.');
        await StorageService.clearAll();
        sessionExpired.value = true;
        _refreshCompleter!.complete(false);
        return false;
      }

      final response = await http
          .post(
            Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.refreshToken),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': refreshToken}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = _parseResponseBodyAsMap(response.body);
        if (data == null || data['access'] is! String) {
          throw const FormatException('Réponse de renouvellement invalide.');
        }
        await StorageService.saveAccessToken(data['access'] as String);
        if (data['refresh'] is String) {
          await StorageService.saveRefreshToken(data['refresh'] as String);
        }
        sessionExpired.value = false;
        _refreshCompleter!.complete(true);
        return true;
      }

      debugPrint(
        'AuthService.refreshToken rejected with HTTP ${response.statusCode}.',
      );
      if (response.statusCode == 400 || response.statusCode == 401) {
        await StorageService.clearAll();
        sessionExpired.value = true;
      }
      _refreshCompleter!.complete(false);
      return false;
    } on SocketException catch (e, stackTrace) {
      debugPrint('AuthService.refreshToken network error: $e');
      debugPrint('AuthService.refreshToken stack: $stackTrace');
      _refreshCompleter!.complete(false);
      return false;
    } on TimeoutException catch (e, stackTrace) {
      debugPrint('AuthService.refreshToken timed out: $e');
      debugPrint('AuthService.refreshToken stack: $stackTrace');
      _refreshCompleter!.complete(false);
      return false;
    } on http.ClientException catch (e, stackTrace) {
      debugPrint('AuthService.refreshToken request failed: $e');
      debugPrint('AuthService.refreshToken stack: $stackTrace');
      _refreshCompleter!.complete(false);
      return false;
    } catch (e) {
      debugPrint('AuthService.refreshToken failed: $e');
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(false);
      }
      return false;
    } finally {
      // allow next refresh after current completes
      _refreshCompleter = null;
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final token = await StorageService.getAccessToken();
    if (token == null) {
      return {'success': false, 'error': 'No token'};
    }

    try {
      final profileUri = Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.profile);
      final response = await OfflineDataService.get(
        profileUri,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final parsedBody = _parseResponseBodyAsMap(response.body);
        if (parsedBody != null) {
          final user = User.fromJson(parsedBody);
          await StorageService.saveUserData(jsonEncode(parsedBody));
          return {'success': true, 'data': user};
        }
        return {'success': false, 'error': _parseResponseBody(response.body)};
      }

      if (response.statusCode == 401) {
        final didRefresh = await refreshToken();
        if (didRefresh) {
          return await getProfile();
        }
        final accessTokenAfterRefresh = await StorageService.getAccessToken();
        final cachedProfile = await StorageService.getUserData();
        if (accessTokenAfterRefresh != null &&
            accessTokenAfterRefresh.isNotEmpty &&
            cachedProfile != null) {
          return {
            'success': false,
            'cached': true,
            'data': cachedProfile,
            'error': 'Connexion au serveur impossible',
          };
        }
        return {'success': false, 'error': 'Unauthorized'};
      }

      return {'success': false, 'error': _parseResponseBody(response.body)};
    } on SocketException catch (e, stackTrace) {
      debugPrint('AuthService.getProfile socket error: $e');
      debugPrint('AuthService.getProfile socket stack: $stackTrace');

      try {
        final profileUri = Uri.parse(
          ApiEndpoints.baseUrl + ApiEndpoints.profile,
        );
        final isLocalHost =
            profileUri.host == '127.0.0.1' || profileUri.host == 'localhost';

        if (isLocalHost) {
          final fallbackUri = profileUri.host == 'localhost'
              ? profileUri.replace(host: '127.0.0.1')
              : profileUri;

          if (fallbackUri.toString() != profileUri.toString()) {
            final retryResponse = await OfflineDataService.get(
              fallbackUri,
              headers: {'Authorization': 'Bearer $token'},
            );
            if (retryResponse.statusCode == 200) {
              final parsedBody = _parseResponseBodyAsMap(retryResponse.body);
              if (parsedBody != null) {
                final user = User.fromJson(parsedBody);
                await StorageService.saveUserData(jsonEncode(parsedBody));
                return {'success': true, 'data': user};
              }
              return {
                'success': false,
                'error': _parseResponseBody(retryResponse.body),
              };
            }
            if (retryResponse.statusCode == 401) {
              final didRefresh = await refreshToken();
              if (didRefresh) {
                return await getProfile();
              }
              final accessTokenAfterRefresh =
                  await StorageService.getAccessToken();
              final cachedProfile = await StorageService.getUserData();
              if (accessTokenAfterRefresh != null &&
                  accessTokenAfterRefresh.isNotEmpty &&
                  cachedProfile != null) {
                return {
                  'success': false,
                  'cached': true,
                  'data': cachedProfile,
                  'error': 'Connexion au serveur impossible',
                };
              }
              return {'success': false, 'error': 'Unauthorized'};
            }
          }
        }
      } catch (retryError, retryStack) {
        debugPrint('AuthService.getProfile retry failed: $retryError');
        debugPrint('AuthService.getProfile retry stack: $retryStack');
      }

      return {
        'success': false,
        'error': 'Connexion au serveur impossible: ${e.message}',
      };
    } catch (e, stackTrace) {
      debugPrint('AuthService.getProfile error: $e');
      debugPrint('AuthService.getProfile stack: $stackTrace');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<void> logout() async {
    final refreshToken = await StorageService.getRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse(ApiEndpoints.baseUrl + ApiEndpoints.logout),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'refresh': refreshToken}),
            )
            .timeout(const Duration(seconds: 10));
      } on Object catch (error, stackTrace) {
        debugPrint('AuthService.logout server revocation failed: $error');
        debugPrint('AuthService.logout stack: $stackTrace');
      }
    }
    await StorageService.clearAll();
  }

  static Future<bool> isLoggedIn() async {
    final token = await StorageService.getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<bool> validateSession() async {
    final token = await StorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      return false;
    }

    final result = await getProfile();
    if (result['success'] == true) {
      return true;
    }

    if (result['cached'] == true) {
      debugPrint('AuthService.validateSession: using cached profile data');
      return true;
    }

    final error = result['error']?.toString().toLowerCase() ?? '';
    if (error.contains('socket') ||
        error.contains('network') ||
        error.contains('unreachable')) {
      debugPrint(
        'AuthService.validateSession: network issue detected, preserving session',
      );
      return true;
    }

    return isLoggedIn();
  }
}
