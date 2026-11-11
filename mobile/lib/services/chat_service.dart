import 'dart:async';
import 'dart:convert';

import 'package:mobile/constants/api_endpoints.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatService {
  static final Map<String, _RoomConnection> _connections = {};

  static Future<Stream<Map<String, dynamic>>> connect(String room) async {
    final existing = _connections[room];
    if (existing != null) return existing.events.stream;

    final token = await StorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw StateError('Connectez-vous pour ouvrir la discussion.');
    }

    final baseWsUri = Uri.parse(ApiEndpoints.wsUrl);
    final baseWsPath = baseWsUri.path.replaceAll(RegExp(r'/+$'), '');
    final wsUri = baseWsUri.replace(
      path: '$baseWsPath/chat/${Uri.encodeComponent(room)}/',
      queryParameters: {'token': token},
    );

    final channel = WebSocketChannel.connect(wsUri);
    await channel.ready;
    final connection = _RoomConnection(channel);
    _connections[room] = connection;

    channel.stream.listen(
      (data) {
        try {
          final payload = jsonDecode(data as String) as Map<String, dynamic>;
          connection.events.add(payload);
        } on Object catch (error, stackTrace) {
          connection.events.addError(error, stackTrace);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        _removeIfCurrent(room, connection);
        connection.events.addError(error, stackTrace);
      },
      onDone: () {
        _removeIfCurrent(room, connection);
        connection.closeEvents();
      },
    );

    return connection.events.stream;
  }

  static void sendText(String room, String message) {
    _send(room, {'room': room, 'message': message, 'message_type': 'text'});
  }

  static void sendTyping(String room) {
    _send(room, {'event_type': 'typing', 'room': room});
  }

  static void _send(String room, Map<String, dynamic> message) {
    final connection = _connections[room];
    if (connection != null) {
      connection.channel.sink.add(jsonEncode(message));
    }
  }

  static void _removeIfCurrent(String room, _RoomConnection connection) {
    if (identical(_connections[room], connection)) {
      _connections.remove(room);
    }
  }

  static Future<void> close([String? room]) async {
    if (room != null) {
      final connection = _connections.remove(room);
      if (connection != null) await connection.close();
      return;
    }

    final connections = _connections.values.toList();
    _connections.clear();
    await Future.wait(connections.map((connection) => connection.close()));
  }
}

class _RoomConnection {
  final WebSocketChannel channel;
  final StreamController<Map<String, dynamic>> events =
      StreamController<Map<String, dynamic>>.broadcast();

  _RoomConnection(this.channel);

  Future<void> close() async {
    await channel.sink.close();
    await closeEvents();
  }

  Future<void> closeEvents() async {
    if (!events.isClosed) await events.close();
  }
}
