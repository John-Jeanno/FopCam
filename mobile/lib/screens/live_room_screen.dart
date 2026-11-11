import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/models/live_stream.dart';
import 'package:mobile/services/api_service.dart';

class LiveRoomScreen extends StatefulWidget {
  final LiveStream stream;

  const LiveRoomScreen({super.key, required this.stream});

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> {
  final _room = Room(
    roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
  );
  String? _error;
  bool _connecting = true;

  @override
  void initState() {
    super.initState();
    _room.addListener(_onRoomChanged);
    _join();
  }

  void _onRoomChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _join() async {
    setState(() {
      _connecting = true;
      _error = null;
    });
    try {
      final credentials = await ApiService.joinLiveStream(widget.stream.id);
      final url = credentials['url']?.toString();
      final token = credentials['token']?.toString();
      if (url == null || token == null) {
        throw const FormatException(
          'Les identifiants de visionnage sont incomplets.',
        );
      }
      await _room.connect(url, token);
      if (mounted) setState(() => _connecting = false);
    } catch (error) {
      try {
        await _room.disconnect();
      } catch (cleanupError) {
        debugPrint('Could not disconnect LiveKit viewer room: $cleanupError');
      }
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = error.toString();
        });
      }
    }
  }

  Widget _videoContent() {
    for (final participant in _room.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        final track = publication.track;
        if (track is VideoTrack) {
          return VideoTrackRenderer(track as VideoTrack);
        }
      }
    }
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam_outlined, color: Colors.white54, size: 56),
          SizedBox(height: 12),
          Text(
            'En attente de la vidéo de l’hôte…',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _room.removeListener(_onRoomChanged);
    unawaited(
      _room.disconnect().catchError((error) {
        debugPrint('Could not disconnect LiveKit viewer room: $error');
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remoteParticipantCount = _room.remoteParticipants.length;
    final viewerCount = _room.remoteParticipants.isEmpty
        ? 0
        : remoteParticipantCount - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.stream.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                color: Colors.black,
                child: _connecting
                    ? const Center(child: CircularProgressIndicator())
                    : _error == null
                    ? _videoContent()
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _join,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Réessayer'),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(
                widget.stream.host.username,
                style: const TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                '${widget.stream.category} · $viewerCount spectateur(s)',
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
