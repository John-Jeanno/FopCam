import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile/screens/chat_screen.dart';

class ChatWindowHost extends StatefulWidget {
  const ChatWindowHost({super.key, required this.child});

  final Widget child;

  static final GlobalKey<_ChatWindowHostState> _key =
      GlobalKey<_ChatWindowHostState>();

  static Widget wrap(Widget child) => ChatWindowHost(key: _key, child: child);

  static String titleForUser({
    required String username,
    String? firstName,
    String? lastName,
  }) {
    final name = '${firstName ?? ''} ${lastName ?? ''}'.trim();
    return name.isEmpty ? username : name;
  }

  static Future<void> openChat(
    BuildContext context, {
    required String roomId,
    String? title,
  }) async {
    final arguments = {'roomId': roomId, 'title': title};
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 1000;
    final host = _key.currentState;

    if (desktop && host != null) {
      host.open(roomId: roomId, title: title);
      return;
    }

    await Navigator.of(context).pushNamed('/chat', arguments: arguments);
  }

  @override
  State<ChatWindowHost> createState() => _ChatWindowHostState();
}

class _ChatWindow {
  final String roomId;
  final String? title;
  bool isMinimized;

  _ChatWindow({required this.roomId, required this.title})
    : isMinimized = false;
}

class _ChatWindowHostState extends State<ChatWindowHost> {
  final List<_ChatWindow> _windows = [];

  void open({required String roomId, String? title}) {
    final existingIndex = _windows.indexWhere(
      (window) => window.roomId == roomId,
    );
    setState(() {
      if (existingIndex >= 0) {
        final existing = _windows.removeAt(existingIndex);
        existing.isMinimized = false;
        _windows.add(existing);
      } else {
        _windows.add(_ChatWindow(roomId: roomId, title: title));
      }
    });
  }

  void _close(_ChatWindow window) {
    setState(() => _windows.remove(window));
  }

  void _toggleMinimized(_ChatWindow window) {
    setState(() => window.isMinimized = !window.isMinimized);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final desktop = kIsWeb && constraints.maxWidth >= 1000;
      if (!desktop || _windows.isEmpty) return widget.child;

      const minimumWindowWidth = 320.0;
      const preferredWindowWidth = 380.0;
      final availableWidth = constraints.maxWidth - 32;
      final horizontalGap =
          _windows.length * preferredWindowWidth + (_windows.length - 1) * 12 <=
              availableWidth
          ? preferredWindowWidth + 12
          : 48.0;
      final maxWindows =
          ((availableWidth - minimumWindowWidth) / 48).floor() + 1;
      final visibleWindows = _windows.length <= maxWindows
          ? _windows
          : _windows.sublist(_windows.length - maxWindows);
      final windowWidth = math.min(
        preferredWindowWidth,
        availableWidth - horizontalGap * (visibleWindows.length - 1),
      );
      final windowHeight = math
          .min(620.0, constraints.maxHeight - 24)
          .toDouble();

      return Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          for (var index = 0; index < visibleWindows.length; index++)
            Positioned(
              right: 16 + horizontalGap * index,
              bottom: 0,
              width: windowWidth,
              height: visibleWindows[index].isMinimized ? 52 : windowHeight,
              child: Material(
                elevation: 18,
                clipBehavior: Clip.antiAlias,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: visibleWindows[index].isMinimized
                    ? _MinimizedChatWindow(
                        title: visibleWindows[index].title ?? 'Discussion',
                        onExpand: () => _toggleMinimized(visibleWindows[index]),
                        onClose: () => _close(visibleWindows[index]),
                      )
                    : Navigator(
                        key: ValueKey(visibleWindows[index].roomId),
                        onGenerateInitialRoutes: (_, initialRoute) => [
                          MaterialPageRoute<void>(
                            settings: RouteSettings(name: initialRoute),
                            builder: (_) => ChatScreen(
                              roomId: visibleWindows[index].roomId,
                              initialTitle: visibleWindows[index].title,
                              showWindowControls: true,
                              onClose: () => _close(visibleWindows[index]),
                              onMinimize: () =>
                                  _toggleMinimized(visibleWindows[index]),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
        ],
      );
    },
  );
}

class _MinimizedChatWindow extends StatelessWidget {
  const _MinimizedChatWindow({
    required this.title,
    required this.onExpand,
    required this.onClose,
  });

  final String title;
  final VoidCallback onExpand;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF7F1D1D),
    child: Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: onExpand,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              alignment: Alignment.centerLeft,
            ),
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        IconButton(
          tooltip: 'Fermer la discussion',
          onPressed: onClose,
          icon: const Icon(Icons.close, color: Colors.white),
        ),
      ],
    ),
  );
}
