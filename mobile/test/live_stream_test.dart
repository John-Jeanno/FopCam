import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/live_stream.dart';

void main() {
  test('maps a LiveKit room name to the stream identifier', () {
    final stream = LiveStream.fromJson({
      'room_name': 'fopcam-live-room',
      'title': 'Présentation en direct',
      'host': {'id': 12, 'username': 'vendeur', 'role': 'producer'},
      'viewers': 3,
      'is_live': true,
      'started_at': '2026-06-15T10:00:00+00:00',
      'category': 'Commerce',
    });

    expect(stream.id, 'fopcam-live-room');
    expect(stream.title, 'Présentation en direct');
    expect(stream.host.username, 'vendeur');
    expect(stream.viewers, 3);
    expect(stream.isLive, isTrue);
  });
}
