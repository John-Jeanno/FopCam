import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/api_service.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (request.uri.path == '/missing.m4a') {
        request.response.statusCode = HttpStatus.notFound;
      } else if (request.uri.path != '/empty.m4a') {
        request.response.headers.contentType = ContentType('audio', 'mp4');
        request.response.add([1, 2, 3]);
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('downloads valid audio bytes for local playback', () async {
    final response = await ApiService.fetchMessageAudio(
      'http://127.0.0.1:${server.port}/voice.m4a',
    );

    expect(response.statusCode, HttpStatus.ok);
    expect(response.headers[HttpHeaders.contentTypeHeader], 'audio/mp4');
    expect(response.bodyBytes, [1, 2, 3]);
  });

  test('rejects inaccessible and empty audio files', () async {
    await expectLater(
      ApiService.fetchMessageAudio(
        'http://127.0.0.1:${server.port}/missing.m4a',
      ),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      ApiService.fetchMessageAudio(
        'http://127.0.0.1:${server.port}/empty.m4a',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('rejects non-http audio sources', () async {
    await expectLater(
      ApiService.fetchMessageAudio('file:///tmp/voice.m4a'),
      throwsA(isA<FormatException>()),
    );
  });
}
