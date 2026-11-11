import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/services/api_service.dart';

class LiveBroadcastScreen extends StatefulWidget {
  const LiveBroadcastScreen({super.key});

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> {
  final _titleController = TextEditingController();
  final _room = Room(
    roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
  );
  String? _roomName;
  String? _error;
  bool _starting = false;
  bool _isLive = false;
  bool _ending = false;

  @override
  void initState() {
    super.initState();
    _room.addListener(_onRoomChanged);
  }

  void _onRoomChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _startBroadcast() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Saisissez le titre de votre direct.');
      return;
    }

    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final credentials = await ApiService.startLiveStream(title: title);
      final roomName = credentials['room_name']?.toString();
      final url = credentials['url']?.toString();
      final token = credentials['token']?.toString();
      if (roomName == null || url == null || token == null) {
        throw const FormatException(
          'Les identifiants du direct sont incomplets.',
        );
      }
      _roomName = roomName;
      await _room.connect(url, token);
      final localParticipant = _room.localParticipant;
      if (localParticipant == null) {
        throw StateError('La connexion au direct n’a pas créé de participant.');
      }
      await localParticipant.setCameraEnabled(true);
      await localParticipant.setMicrophoneEnabled(true);
      if (mounted) {
        setState(() {
          _starting = false;
          _isLive = true;
        });
      }
    } catch (error) {
      final roomName = _roomName;
      if (roomName != null) {
        try {
          await ApiService.endLiveStream(roomName);
        } catch (cleanupError) {
          debugPrint('Could not close failed LiveKit room: $cleanupError');
        }
      }
      try {
        await _room.disconnect();
      } catch (cleanupError) {
        debugPrint('Could not disconnect failed LiveKit room: $cleanupError');
      }
      if (mounted) {
        setState(() {
          _starting = false;
          _isLive = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _endBroadcast() async {
    final roomName = _roomName;
    if (roomName == null || _ending) return;
    setState(() {
      _ending = true;
      _error = null;
    });
    try {
      await ApiService.endLiveStream(roomName);
      await _room.disconnect();
      if (mounted) {
        setState(() => _isLive = false);
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _ending = false;
          _error = error.toString();
        });
      }
    }
  }

  Widget _cameraPreview() {
    final publications = _room.localParticipant?.videoTrackPublications ?? [];
    for (final publication in publications) {
      final track = publication.track;
      if (track is VideoTrack) {
        return VideoTrackRenderer(track as VideoTrack);
      }
    }
    return const Center(
      child: Icon(Icons.videocam_off, color: Colors.white54, size: 56),
    );
  }

  @override
  void dispose() {
    _room.removeListener(_onRoomChanged);
    final roomName = _roomName;
    if (_isLive && roomName != null) {
      unawaited(
        ApiService.endLiveStream(roomName).catchError((error) {
          debugPrint('Could not close LiveKit room on exit: $error');
        }),
      );
    }
    unawaited(
      _room.disconnect().catchError((error) {
        debugPrint('Could not disconnect LiveKit room on exit: $error');
      }),
    );
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isLive && !_ending && !_starting,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isLive) _endBroadcast();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Diffusion en direct'),
          actions: [
            if (_isLive)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.circle, color: Colors.redAccent, size: 10),
                    SizedBox(width: 6),
                    Text('EN DIRECT'),
                  ],
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (_isLive)
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: double.infinity,
                        color: Colors.black,
                        child: _cameraPreview(),
                      ),
                    ),
                  )
                else ...[
                  const Icon(
                    Icons.videocam_outlined,
                    color: Colors.white70,
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Présentez vos produits ou partagez un moment avec la communauté.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _titleController,
                    enabled: !_starting,
                    maxLength: 120,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Titre du direct',
                      hintText: 'Ex. Présentation de ma boutique',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _starting || _ending
                        ? null
                        : _isLive
                        ? _endBroadcast
                        : _startBroadcast,
                    icon: _starting || _ending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(_isLive ? Icons.stop : Icons.videocam),
                    label: Text(
                      _starting
                          ? 'Connexion…'
                          : _ending
                          ? 'Arrêt…'
                          : _isLive
                          ? 'Terminer le direct'
                          : 'Démarrer le direct',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
