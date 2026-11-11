import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/media_url_helper.dart';
import 'package:mobile/constants/api_endpoints.dart';

void main() {
  group('normalizeMediaUrl', () {
    test('returns null for empty values', () {
      expect(normalizeMediaUrl(null), isNull);
      expect(normalizeMediaUrl(''), isNull);
    });

    test('keeps absolute URLs unchanged', () {
      const absoluteUrl = 'https://example.com/media/photo.png';
      expect(normalizeMediaUrl(absoluteUrl), absoluteUrl);
    });

    test('prefixes relative media paths with the backend base URL', () {
      expect(
        normalizeMediaUrl('/media/profiles/photo.png'),
        '${ApiEndpoints.baseUrl}/media/profiles/photo.png',
      );
    });

    test('prefixes relative paths without leading slash', () {
      expect(
        normalizeMediaUrl('media/profiles/photo.png'),
        '${ApiEndpoints.baseUrl}/media/profiles/photo.png',
      );
    });

    test('does not duplicate the configured API prefix in media URLs', () {
      expect(
        normalizeMediaUrl(
          '/fopcam-api/media/profiles/photo.png',
          baseUrl: 'https://fopcam.example/fopcam-api',
        ),
        'https://fopcam.example/fopcam-api/media/profiles/photo.png',
      );
    });

    test('adds the API prefix to unprefixed media URLs', () {
      expect(
        normalizeMediaUrl(
          '/media/profiles/photo.png',
          baseUrl: 'https://fopcam.example/fopcam-api',
        ),
        'https://fopcam.example/fopcam-api/media/profiles/photo.png',
      );
    });
  });
}
