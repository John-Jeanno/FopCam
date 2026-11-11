// ignore_for_file: library_private_types_in_public_api
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/chat_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/utils/message_audio_format.dart';
import 'package:mobile/utils/media_url_helper.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final String? initialTitle;
  final bool showWindowControls;
  final VoidCallback? onClose;
  final VoidCallback? onMinimize;

  const ChatScreen({
    super.key,
    required this.roomId,
    this.initialTitle,
    this.showWindowControls = false,
    this.onClose,
    this.onMinimize,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  final List<Map<String, dynamic>> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _chatSubscription;
  StreamSubscription<void>? _audioCompleteSubscription;
  StreamSubscription<Duration>? _audioPositionSubscription;
  StreamSubscription<Duration>? _audioDurationSubscription;
  StreamSubscription<Amplitude>? _recordingAmplitudeSubscription;
  Timer? _socketReconnectTimer;
  Timer? _recordingTimer;
  bool _isConnectingSocket = false;
  bool _isLoading = true;
  bool _isTyping = false;
  bool _isSending = false;
  bool _isRecording = false;
  String? _messagesError;
  String? _conversationTitle;
  String? _playingAudioUrl;
  Map<String, dynamic>? _replyingToMessage;
  double _replySwipeDistance = 0;
  DateTime? _recordingStartedAt;
  Duration _recordingElapsed = Duration.zero;
  Duration _audioPosition = Duration.zero;
  Duration _audioDuration = Duration.zero;
  final List<double> _recordingWaveform = [];
  int? _currentUserId;
  String? _currentUsername;

  String get _displayTitle => _conversationTitle?.trim().isNotEmpty == true
      ? _conversationTitle!.trim()
      : widget.initialTitle?.trim().isNotEmpty == true
      ? widget.initialTitle!.trim()
      : 'Discussion';

  @override
  void initState() {
    super.initState();
    _conversationTitle = widget.initialTitle;
    if (widget.roomId.trim().isNotEmpty) {
      _loadCurrentUser();
      _loadMessages();
      _connectWebSocket();
    } else {
      _isLoading = false;
      _messagesError =
          'Cette discussion est invalide. Ouvrez-la depuis Messages.';
    }
    _audioCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playingAudioUrl = null;
          _audioPosition = Duration.zero;
        });
      }
    });
    _audioPositionSubscription = _audioPlayer.onPositionChanged.listen((
      position,
    ) {
      if (mounted) setState(() => _audioPosition = position);
    });
    _audioDurationSubscription = _audioPlayer.onDurationChanged.listen((
      duration,
    ) {
      if (mounted) setState(() => _audioDuration = duration);
    });
  }

  Future<void> _loadCurrentUser() async {
    final userData = await StorageService.getUserData();
    if (userData != null && userData.isNotEmpty) {
      try {
        final decoded = jsonDecode(userData) as Map<String, dynamic>;
        final user = decoded['user'] as Map<String, dynamic>? ?? decoded;
        if (!mounted) return;
        setState(() {
          _currentUserId = user['id'] as int?;
          _currentUsername = user['username'] as String?;
          _conversationTitle ??= _findConversationTitle(_messages);
        });
      } catch (_) {
        // ignore parsing errors
      }
    }
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _socketReconnectTimer?.cancel();
    _recordingTimer?.cancel();
    ChatService.close(widget.roomId);
    _audioCompleteSubscription?.cancel();
    _audioPositionSubscription?.cancel();
    _audioDurationSubscription?.cancel();
    _recordingAmplitudeSubscription?.cancel();
    unawaited(_audioRecorder.dispose());
    unawaited(_audioPlayer.dispose());
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _messagesError = null;
    });
    try {
      if (widget.roomId.startsWith('private_')) {
        try {
          await ApiService.markRoomMessagesRead(widget.roomId);
        } catch (error) {
          debugPrint('Impossible de marquer les messages comme lus: $error');
        }
      }
      final messages = await ApiService.fetchMessages(widget.roomId);
      if (!mounted) return;
      setState(() {
        if (_currentUserId != null) {
          _conversationTitle ??= _findConversationTitle(messages);
        }
        for (final message in messages) {
          final id = message['id'];
          final existingIndex = id == null
              ? -1
              : _messages.indexWhere((existing) => existing['id'] == id);
          if (existingIndex >= 0) {
            _messages[existingIndex] = message;
          } else {
            _messages.add(message);
          }
        }
        _sortMessages();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messagesError = _messages.isEmpty ? error.toString() : null;
        _isLoading = false;
      });
    }
  }

  String? _findConversationTitle(List<Map<String, dynamic>> messages) {
    for (final message in messages) {
      final sender = message['user'];
      final recipient = message['recipient'];
      if (sender is! Map || recipient is! Map) continue;

      final senderData = Map<String, dynamic>.from(sender);
      final recipientData = Map<String, dynamic>.from(recipient);
      final senderId = int.tryParse(senderData['id']?.toString() ?? '');
      final recipientId = int.tryParse(recipientData['id']?.toString() ?? '');
      final peer = _currentUserId == null
          ? recipientData
          : senderId == _currentUserId
          ? recipientData
          : recipientId == _currentUserId
          ? senderData
          : null;
      if (peer == null) continue;

      final username = peer['username']?.toString().trim() ?? '';
      final displayName =
          '${peer['first_name'] ?? ''} '
                  '${peer['last_name'] ?? ''}'
              .trim();
      if (displayName.isNotEmpty) return displayName;
      if (username.isNotEmpty) return username;
    }
    return null;
  }

  Future<void> _connectWebSocket() async {
    if (_isConnectingSocket || !mounted) return;
    _isConnectingSocket = true;
    try {
      await _chatSubscription?.cancel();
      _chatSubscription = null;
      final stream = await ChatService.connect(widget.roomId);
      if (!mounted) {
        await ChatService.close(widget.roomId);
        return;
      }
      _chatSubscription = stream.listen(
        (event) {
          if (event['event'] == 'typing') {
            _handleTypingEvent(event);
            return;
          }
          if (event['event'] == 'message_deleted') {
            _removeMessage(event['message_id']);
            return;
          }
          if (event['event'] == 'conversation_deleted') {
            if (mounted) {
              setState(() {
                _messages.clear();
                _replyingToMessage = null;
                _playingAudioUrl = null;
              });
            }
            return;
          }
          if (event['event'] == 'error') {
            _showChatError(
              event['message']?.toString() ?? 'Envoi du message impossible.',
            );
            return;
          }

          _addOrUpdateMessage(event);
        },
        onError: (error) {
          debugPrint('Erreur socket chat : $error');
          _scheduleSocketReconnect();
        },
        onDone: () {
          debugPrint('Socket chat fermée');
          _scheduleSocketReconnect();
        },
      );
    } catch (error) {
      debugPrint('Impossible de connecter le socket de chat : $error');
      _scheduleSocketReconnect();
    } finally {
      _isConnectingSocket = false;
    }
  }

  void _scheduleSocketReconnect() {
    _socketReconnectTimer?.cancel();
    _socketReconnectTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) _connectWebSocket();
    });
  }

  void _removeMessage(dynamic messageId) {
    if (messageId == null) return;
    final id = messageId.toString();
    if (!mounted) return;
    setState(() {
      _messages.removeWhere((message) => message['id']?.toString() == id);
      if (_replyingToMessage?['id']?.toString() == id) {
        _replyingToMessage = null;
      }
    });
  }

  Future<void> _confirmDeleteMessage(Map<String, dynamic> message) async {
    final id = int.tryParse(message['id']?.toString() ?? '');
    if (id == null || !_isCurrentUserMessage(message)) return;
    final isAudio = message['message_type'] == 'audio';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer ce message ?'),
        content: Text(
          'Ce message${isAudio ? ' vocal' : ''} sera supprimé pour les deux personnes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.deleteMessage(id);
      _removeMessage(id);
    } catch (error) {
      _showChatError('Suppression impossible : $error');
    }
  }

  void _handleTypingEvent(Map<String, dynamic> event) {
    final typingUser = event['user'] as Map<String, dynamic>?;
    if (typingUser != null &&
        typingUser['id'] != _currentUserId &&
        typingUser['username'] != _currentUsername) {
      setState(() {
        _isTyping = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _isTyping = false;
          });
        }
      });
    }
  }

  void _addOrUpdateMessage(Map<String, dynamic> message) {
    final messageId = message['id'];
    if (messageId != null) {
      final existingIndex = _messages.indexWhere((m) => m['id'] == messageId);
      if (existingIndex != -1) {
        _messages[existingIndex] = message;
      } else {
        final pendingIndex = _messages.indexWhere(
          (existing) =>
              existing['pending'] == true &&
              (existing['content'] ?? existing['message']) ==
                  (message['content'] ?? message['message']),
        );
        if (pendingIndex >= 0) {
          _messages[pendingIndex] = message;
        } else {
          _messages.add(message);
        }
      }
    } else {
      _messages.add(message);
    }

    if (mounted) {
      setState(_sortMessages);
    }
  }

  void _sortMessages() {
    DateTime timestamp(Map<String, dynamic> message) {
      final value = message['created_at'] ?? message['timestamp'];
      return DateTime.tryParse(value?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
    }

    _messages.sort(
      (left, right) => timestamp(left).compareTo(timestamp(right)),
    );
  }

  Future<void> _sendMessage() async {
    if (_isSending ||
        widget.roomId.trim().isEmpty ||
        _messageController.text.isEmpty) {
      return;
    }

    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final replyingTo = _replyingToMessage;
    final replyToId = _messageId(replyingTo);

    final pendingMessage = {
      'content': text,
      'message_type': 'text',
      'user': {'id': _currentUserId, 'username': _currentUsername ?? 'Vous'},
      'created_at': DateTime.now().toIso8601String(),
      'pending': true,
      if (replyingTo != null) 'reply_to': _replyPreview(replyingTo),
    };

    setState(() {
      _messages.add(pendingMessage);
      _messageController.clear();
      _isTyping = false;
      _isSending = true;
    });

    final result = await ApiService.sendMessage({
      'room': widget.roomId,
      'content': text,
      'message_type': 'text',
      'reply_to_id': ?replyToId,
    });
    if (!mounted) return;
    setState(() => _isSending = false);
    if (result['success'] == true && result['data'] is Map) {
      _addOrUpdateMessage(Map<String, dynamic>.from(result['data'] as Map));
      if (identical(_replyingToMessage, replyingTo)) {
        setState(() => _replyingToMessage = null);
      }
    } else {
      _messages.remove(pendingMessage);
      setState(() {});
      _showChatError('Message non envoyé : ${result['error']}');
    }
  }

  Future<void> _chooseAttachment() async {
    final source = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: !widget.showWindowControls,
      backgroundColor: const Color(0xFF111827),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text(
                'Choisir une photo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, 'image_gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text(
                'Prendre une photo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, 'image_camera'),
            ),
            ListTile(
              leading: const Icon(Icons.video_library, color: Colors.white),
              title: const Text(
                'Choisir une vidéo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, 'video_gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.white),
              title: const Text(
                'Filmer une vidéo',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () => Navigator.pop(context, 'video_camera'),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    try {
      final file = source.startsWith('video')
          ? await _imagePicker.pickVideo(
              source: source.endsWith('camera')
                  ? ImageSource.camera
                  : ImageSource.gallery,
              maxDuration: const Duration(minutes: 5),
            )
          : await _imagePicker.pickImage(
              source: source.endsWith('camera')
                  ? ImageSource.camera
                  : ImageSource.gallery,
              maxWidth: 1920,
              imageQuality: 85,
            );
      if (file == null) return;
      await _sendAttachment(
        file,
        messageType: source.startsWith('video') ? 'video' : 'image',
      );
    } on Object catch (error) {
      _showChatError('Impossible de sélectionner le média : $error');
    }
  }

  Future<void> _sendAttachment(
    XFile file, {
    required String messageType,
    int? audioDuration,
  }) async {
    if (_isSending) return;
    if (widget.roomId.trim().isEmpty) {
      _showChatError(
        'Cette discussion est invalide. Ouvrez-la depuis Messages.',
      );
      return;
    }
    final replyingTo = _replyingToMessage;
    setState(() => _isSending = true);
    final result = await ApiService.sendMessageAttachment(
      room: widget.roomId.trim(),
      file: file,
      messageType: messageType,
      attachmentType: messageType == 'audio' ? 'audio' : messageType,
      content: messageType == 'audio' ? 'Message vocal' : file.name,
      audioDuration: audioDuration,
      replyToId: _messageId(replyingTo),
    );
    if (!mounted) return;
    setState(() => _isSending = false);
    if (result['success'] == true && result['data'] is Map) {
      _addOrUpdateMessage(Map<String, dynamic>.from(result['data'] as Map));
      if (identical(_replyingToMessage, replyingTo)) {
        setState(() => _replyingToMessage = null);
      }
    } else {
      _showChatError('Fichier non envoyé : ${result['error']}');
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      await _stopVoiceRecording();
      return;
    }
    try {
      if (!await _audioRecorder.hasPermission()) {
        _showChatError('Autorisez l’accès au microphone pour enregistrer.');
        return;
      }
      final recordingName =
          'message-vocal-${DateTime.now().millisecondsSinceEpoch}.wav';
      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      );
      final path = kIsWeb
          ? recordingName
          : '${(await getTemporaryDirectory()).path}/$recordingName';
      await _audioRecorder.start(config, path: path);
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingStartedAt = DateTime.now();
        _recordingElapsed = Duration.zero;
        _recordingWaveform.clear();
      });
      _recordingAmplitudeSubscription = _audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen(
            (amplitude) {
              if (!mounted || !_isRecording) return;
              final level = ((amplitude.current + 60) / 60).clamp(0.08, 1.0);
              setState(() {
                _recordingWaveform.add(level);
                if (_recordingWaveform.length > 48) {
                  _recordingWaveform.removeAt(0);
                }
              });
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Voice recording amplitude stream failed: $error');
            },
          );
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
        if (!mounted || !_isRecording) return;
        setState(() {
          _recordingElapsed = DateTime.now().difference(
            _recordingStartedAt ?? DateTime.now(),
          );
        });
      });
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('Voice recorder plugin is unavailable: $error\n$stackTrace');
      _showChatError(
        'Le module d’enregistrement vocal n’est pas chargé. '
        'Fermez complètement puis mettez à jour l’application.',
      );
    } on Object catch (error) {
      _showChatError('Impossible de démarrer l’enregistrement : $error');
    }
  }

  Future<void> _stopVoiceRecording() async {
    final startedAt = _recordingStartedAt;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await _recordingAmplitudeSubscription?.cancel();
    _recordingAmplitudeSubscription = null;
    try {
      final recordedPath = await _audioRecorder.stop();
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordingElapsed = Duration.zero;
        _recordingWaveform.clear();
      });
      if (recordedPath == null || recordedPath.isEmpty) {
        _showChatError('Aucun fichier audio n’a été enregistré.');
        return;
      }
      final duration = startedAt == null
          ? 0
          : (DateTime.now().difference(startedAt).inMilliseconds / 1000).ceil();
      final recordedFile = XFile(recordedPath);
      final audioBytes = await recordedFile.readAsBytes();
      if (!MessageAudioFormat.hasAudioPayload(audioBytes)) {
        _showChatError(
          'Aucun son n’a été capté. Vérifiez l’autorisation du microphone, '
          'puis réessayez.',
        );
        return;
      }
      final format = MessageAudioFormat.detect(
        audioBytes,
        sourceUrl: recordedPath,
      );
      final fileName =
          'message-vocal-${DateTime.now().millisecondsSinceEpoch}.'
          '${format.extension}';
      await _sendAttachment(
        XFile.fromData(audioBytes, name: fileName, mimeType: format.mimeType),
        messageType: 'audio',
        audioDuration: duration,
      );
    } on MissingPluginException catch (error, stackTrace) {
      debugPrint('Voice recorder plugin is unavailable: $error\n$stackTrace');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingElapsed = Duration.zero;
          _recordingWaveform.clear();
        });
        _showChatError(
          'L’enregistrement vocal n’est pas disponible dans cette version. '
          'Mets à jour ou réinstalle l’application.',
        );
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingElapsed = Duration.zero;
          _recordingWaveform.clear();
        });
        _showChatError('Impossible de terminer l’enregistrement : $error');
      }
    }
  }

  String? _messageMediaUrl(Map<String, dynamic> message) {
    final raw = message['attachment_file'] ?? message['audio_file'];
    return normalizeMediaUrl(raw?.toString());
  }

  int? _messageId(Map<String, dynamic>? message) =>
      int.tryParse(message?['id']?.toString() ?? '');

  Map<String, dynamic> _replyPreview(Map<String, dynamic> message) {
    final user = message['user'];
    return {
      'id': message['id'],
      'content': message['content'] ?? message['message'] ?? '',
      'message_type': message['message_type'] ?? 'text',
      if (user is Map) 'user': Map<String, dynamic>.from(user),
    };
  }

  String _messageSummary(Map<String, dynamic> message) {
    final content = (message['content'] ?? message['message'] ?? '')
        .toString()
        .trim();
    if (content.isNotEmpty) return content;
    return switch (message['message_type']) {
      'audio' => 'Message vocal',
      'image' => 'Photo',
      'video' => 'Vidéo',
      'document' => 'Fichier',
      _ => 'Message',
    };
  }

  void _replyToMessage(Map<String, dynamic> message) {
    if (_messageId(message) == null) return;
    setState(() => _replyingToMessage = message);
  }

  Widget _buildQuotedMessage(Map<String, dynamic> message) {
    final user = message['user'];
    final username = user is Map
        ? user['username']?.toString() ?? 'Utilisateur'
        : 'Utilisateur';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        border: const Border(
          left: BorderSide(color: Color(0xFFF87171), width: 3),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFCA5A5),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            _messageSummary(message),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyComposerPreview() {
    final message = _replyingToMessage;
    if (message == null) return const SizedBox.shrink();
    final user = message['user'];
    final username = user is Map
        ? user['username']?.toString() ?? 'Utilisateur'
        : 'Utilisateur';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Réponse à $username',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _messageSummary(message),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Annuler la réponse',
            onPressed: () => setState(() => _replyingToMessage = null),
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(Map<String, dynamic> message) {
    final type = message['message_type']?.toString() ?? 'text';
    final mediaUrl = _messageMediaUrl(message);
    if (type == 'image' && mediaUrl != null) {
      return GestureDetector(
        onTap: () => _showImage(mediaUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.network(
            mediaUrl,
            width: 240,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Text(
              'Image indisponible',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }
    if (type == 'video' && mediaUrl != null) {
      return InkWell(
        onTap: () => _openMedia(mediaUrl),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill, color: Colors.white, size: 38),
              SizedBox(width: 10),
              Text('Lire la vidéo', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
      );
    }
    if (type == 'audio' && mediaUrl != null) {
      final isPlaying = _playingAudioUrl == mediaUrl;
      final duration = isPlaying
          ? (_audioDuration > Duration.zero
                ? _audioDuration
                : Duration(
                    seconds:
                        int.tryParse(
                          message['audio_duration']?.toString() ?? '',
                        ) ??
                        0,
                  ))
          : Duration(
              seconds:
                  int.tryParse(message['audio_duration']?.toString() ?? '') ??
                  0,
            );
      final position = isPlaying ? _audioPosition : Duration.zero;
      final progress = duration.inMilliseconds == 0
          ? 0.0
          : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => _toggleAudioPlayback(mediaUrl),
            icon: Icon(
              isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 118,
            child: _VoiceWaveform(
              progress: progress,
              samples: _playbackWaveform(mediaUrl),
              activeColor: Colors.white,
              inactiveColor: Colors.white38,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatVoiceDuration(isPlaying ? position : duration),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      );
    }
    return Text(
      message['message'] ?? message['content'] ?? '',
      style: const TextStyle(color: Colors.white, fontSize: 15),
    );
  }

  Future<void> _toggleAudioPlayback(String url) async {
    try {
      if (_playingAudioUrl == url) {
        await _audioPlayer.stop();
        if (mounted) {
          setState(() {
            _playingAudioUrl = null;
            _audioPosition = Duration.zero;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _playingAudioUrl = url;
          _audioPosition = Duration.zero;
          _audioDuration = Duration.zero;
        });
      }
      final response = await ApiService.fetchMessageAudio(url);
      if (!MessageAudioFormat.hasAudioPayload(response.bodyBytes)) {
        throw const FormatException(
          'Ce message vocal est vide ou incomplet. Demandez à votre contact de le renvoyer.',
        );
      }
      final responseMimeType = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (responseMimeType != null &&
          !responseMimeType.startsWith('audio/') &&
          responseMimeType != 'application/octet-stream') {
        throw const FormatException(
          'Le serveur n’a pas renvoyé un fichier audio valide.',
        );
      }
      final format = MessageAudioFormat.detect(
        response.bodyBytes,
        contentType: responseMimeType,
        sourceUrl: url,
      );
      if (kIsWeb) {
        await _audioPlayer.play(
          BytesSource(response.bodyBytes, mimeType: format.mimeType),
        );
      } else {
        final fileName =
            'fopcam-message-${DateTime.now().microsecondsSinceEpoch}.'
            '${format.extension}';
        final path = '${(await getTemporaryDirectory()).path}/$fileName';
        await XFile.fromData(
          response.bodyBytes,
          name: fileName,
          mimeType: format.mimeType,
        ).saveTo(path);
        await _audioPlayer.play(DeviceFileSource(path));
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _playingAudioUrl = null;
          _audioPosition = Duration.zero;
        });
      }
      _showChatError('Impossible de lire le message vocal : $error');
    }
  }

  List<double> _playbackWaveform(String seed) =>
      List<double>.generate(36, (index) {
        final phase = (index + seed.hashCode.abs() % 17) * 0.72;
        return (0.18 +
                (math.sin(phase).abs() * 0.52) +
                (math.sin(phase * 0.41).abs() * 0.3))
            .clamp(0.12, 1.0);
      });

  Future<void> _showImage(String url) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: !widget.showWindowControls,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMedia(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showChatError('Impossible d’ouvrir cette vidéo.');
    }
  }

  void _showChatError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  bool _isCurrentUserMessage(Map<String, dynamic> message) {
    final user = message['user'] as Map<String, dynamic>?;
    if (user == null) return false;
    final senderId = user['id'];
    final senderName = user['username'] as String?;
    if (_currentUserId != null && senderId != null) {
      return senderId == _currentUserId;
    }
    if (_currentUsername != null && senderName != null) {
      return senderName == _currentUsername;
    }
    return false;
  }

  Future<void> _closeChat() async {
    final onClose = widget.onClose;
    if (onClose != null) {
      onClose();
      return;
    }

    final navigator = Navigator.of(context);
    if (!await navigator.maybePop() && mounted) {
      navigator.pushReplacementNamed('/messages');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.roomId.trim().isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0f172a),
        appBar: AppBar(
          title: const Text('Discussion indisponible'),
          backgroundColor: const Color(0xFF7F1D1D),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Cette discussion n’a pas d’identifiant valide. '
                  'Ouvrez une conversation depuis Messages.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pushNamedAndRemoveUntil('/messages', (route) => false),
                  child: const Text('Ouvrir Messages'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0f172a),
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: _closeChat,
          icon: const Icon(Icons.arrow_back),
        ),
        title: Text(
          _displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF7F1D1D),
        actions: [
          if (widget.showWindowControls && widget.onMinimize != null)
            IconButton(
              tooltip: 'Réduire la discussion',
              onPressed: widget.onMinimize,
              icon: const Icon(Icons.remove),
            ),
          if (widget.showWindowControls)
            IconButton(
              tooltip: 'Fermer la discussion',
              onPressed: _closeChat,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messagesError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _messagesError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _loadMessages,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun message',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    reverse: true,
                    itemCount: _messages.length,
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      final user = message['user'] as Map<String, dynamic>?;
                      final sender = user != null
                          ? user['username'] as String?
                          : null;
                      final isMine = _isCurrentUserMessage(message);
                      final bubbleColor = isMine
                          ? const Color(0xFF7F1D1D)
                          : const Color(0xFF1F2937);
                      final borderColor = isMine
                          ? const Color(0xFFB91C1C)
                          : const Color.fromRGBO(255, 255, 255, 0.12);
                      final align = isMine
                          ? Alignment.centerRight
                          : Alignment.centerLeft;
                      final crossAlignment = isMine
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Align(
                          alignment: align,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75,
                            ),
                            child: GestureDetector(
                              onHorizontalDragStart: (_) {
                                _replySwipeDistance = 0;
                              },
                              onHorizontalDragUpdate: (details) {
                                _replySwipeDistance += details.delta.dx;
                              },
                              onHorizontalDragEnd: (_) {
                                if (_replySwipeDistance >= 48) {
                                  _replyToMessage(message);
                                }
                                _replySwipeDistance = 0;
                              },
                              onHorizontalDragCancel: () {
                                _replySwipeDistance = 0;
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: bubbleColor,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(
                                      isMine ? 16 : 4,
                                    ),
                                    bottomRight: Radius.circular(
                                      isMine ? 4 : 16,
                                    ),
                                  ),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1.2,
                                  ),
                                  boxShadow: [
                                    const BoxShadow(
                                      color: Color.fromRGBO(0, 0, 0, 0.18),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: crossAlignment,
                                  children: [
                                    if (message['reply_to'] is Map)
                                      _buildQuotedMessage(
                                        Map<String, dynamic>.from(
                                          message['reply_to'] as Map,
                                        ),
                                      ),
                                    if (!isMine && sender != null)
                                      Text(
                                        sender,
                                        style: const TextStyle(
                                          color: Color(0xFFf8fafc),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    if (!isMine && sender != null)
                                      const SizedBox(height: 6),
                                    _buildMessageContent(message),
                                    if (isMine &&
                                        message['pending'] != true &&
                                        message['id'] != null)
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: IconButton(
                                          tooltip: 'Supprimer pour tous',
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          padding: EdgeInsets.zero,
                                          onPressed: () =>
                                              _confirmDeleteMessage(message),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_isTyping)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.centerLeft,
              child: const Text(
                'L’autre personne est en train d’écrire...',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF111827),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildReplyComposerPreview(),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Ajouter une photo ou une vidéo',
                      onPressed: _isSending ? null : _chooseAttachment,
                      icon: const Icon(
                        Icons.attach_file,
                        color: Colors.white70,
                      ),
                    ),
                    IconButton(
                      tooltip: _isRecording
                          ? 'Arrêter et envoyer le vocal'
                          : 'Enregistrer un message vocal',
                      onPressed: _isSending ? null : _toggleVoiceRecording,
                      icon: Icon(
                        _isRecording ? Icons.stop_circle : Icons.mic,
                        color: _isRecording ? Colors.redAccent : Colors.white70,
                      ),
                    ),
                    Expanded(
                      child: _isRecording
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1f2937),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 9,
                                    height: 9,
                                    decoration: const BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _formatVoiceDuration(_recordingElapsed),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _VoiceWaveform(
                                      samples: List<double>.of(
                                        _recordingWaveform,
                                      ),
                                      progress: 1,
                                      activeColor: Colors.redAccent,
                                      inactiveColor: Colors.white24,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : TextField(
                              controller: _messageController,
                              enabled: !_isSending,
                              style: const TextStyle(color: Colors.white),
                              onChanged: (_) =>
                                  ChatService.sendTyping(widget.roomId),
                              decoration: InputDecoration(
                                hintText: 'Envoyer un message...',
                                hintStyle: const TextStyle(color: Colors.grey),
                                filled: true,
                                fillColor: const Color(0xFF1f2937),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: _isSending || _isRecording ? null : _sendMessage,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7c3aed),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatVoiceDuration(Duration duration) {
  final seconds = duration.inSeconds;
  final minutesText = (seconds ~/ 60).toString().padLeft(2, '0');
  final secondsText = (seconds % 60).toString().padLeft(2, '0');
  return '$minutesText:$secondsText';
}

class _VoiceWaveform extends StatelessWidget {
  final List<double> samples;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  const _VoiceWaveform({
    required this.samples,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 28),
    painter: _VoiceWaveformPainter(
      samples: samples,
      progress: progress,
      activeColor: activeColor,
      inactiveColor: inactiveColor,
    ),
  );
}

class _VoiceWaveformPainter extends CustomPainter {
  final List<double> samples;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  const _VoiceWaveformPainter({
    required this.samples,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.isEmpty) return;

    final gap = 2.0;
    final barWidth = math.max(
      1.0,
      (size.width - gap * (samples.length - 1)) / samples.length,
    );
    final inactivePaint = Paint()..color = inactiveColor;
    final activePaint = Paint()..color = activeColor;

    for (var index = 0; index < samples.length; index++) {
      final height = (samples[index].clamp(0.08, 1.0) * size.height).clamp(
        3.0,
        size.height,
      );
      final left = index * (barWidth + gap);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, (size.height - height) / 2, barWidth, height),
        Radius.circular(barWidth / 2),
      );
      canvas.drawRRect(rect, inactivePaint);
      if (left + barWidth <= size.width * progress) {
        canvas.drawRRect(rect, activePaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _VoiceWaveformPainter oldDelegate) =>
      oldDelegate.samples != samples ||
      oldDelegate.progress != progress ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.inactiveColor != inactiveColor;
}
