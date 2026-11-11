import 'package:flutter/material.dart';
import 'package:mobile/models/story.dart';
import 'package:mobile/services/api_service.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'package:mobile/utils/media_url_helper.dart';
import 'package:mobile/widgets/network_video_player.dart';
import 'package:mobile/widgets/chat_window_host.dart';
import 'package:mobile/widgets/story_author_profile_sheet.dart';

class StoryViewerScreen extends StatefulWidget {
  final List<Story> stories;
  final int initialIndex;

  const StoryViewerScreen({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  late int currentIndex;
  late List<Story> stories;
  late AnimationController _progressController;
  Timer? _timer;
  bool _isPlaying = true;
  bool _showViewerList = false;
  List<dynamic> _viewers = [];
  bool _loadingViewers = false;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    stories = widget.stories;
    _progressController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    );
    _startStoryTimer();
    _markStoryAsViewed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressController.dispose();
    super.dispose();
  }

  void _startStoryTimer() {
    if (stories[currentIndex].storyType == 'video' &&
        stories[currentIndex].video != null) {
      return;
    }
    _progressController.forward();
    _timer = Timer(const Duration(seconds: 5), _nextStory);
  }

  void _resetTimer() {
    _timer?.cancel();
    _progressController.reset();
    _startStoryTimer();
  }

  void _nextStory() {
    if (!mounted) return;
    if (currentIndex < stories.length - 1) {
      setState(() {
        currentIndex++;
      });
      _resetTimer();
      _markStoryAsViewed();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _previousStory() {
    if (currentIndex > 0) {
      setState(() {
        currentIndex--;
      });
      _resetTimer();
      _markStoryAsViewed();
    }
  }

  void _markStoryAsViewed() async {
    final story = stories[currentIndex];
    if (story.isDemo || story.isPending) return;
    try {
      await ApiService.markStoryAsViewed(story.id);
    } catch (e) {
      debugPrint('Erreur en marquant l’histoire comme vue : $e');
    }
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      _progressController.forward();
      _timer = Timer(
        Duration(
          milliseconds: (5000 * (1 - _progressController.value)).toInt(),
        ),
        _nextStory,
      );
    } else {
      _progressController.stop();
      _timer?.cancel();
    }
  }

  void _likeStory() async {
    final story = stories[currentIndex];
    if (story.isDemo || story.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce statut de démonstration ne peut pas être aimé.'),
        ),
      );
      return;
    }
    try {
      final liked = await ApiService.likeStory(story.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            liked
                ? 'Histoire aimée.'
                : 'Impossible d’aimer cette histoire. Réessayez.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Erreur en aimant l’histoire : $e');
    }
  }

  void _loadViewers() async {
    final story = stories[currentIndex];
    if (story.isDemo || story.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les vues ne sont pas disponibles pour ce statut.'),
        ),
      );
      return;
    }
    setState(() => _loadingViewers = true);
    try {
      final viewers = await ApiService.getStoryViewers(story.id);
      if (mounted) {
        setState(() {
          _viewers = viewers;
          _showViewerList = true;
        });
      }
    } catch (e) {
      debugPrint('Erreur en chargeant les spectateurs : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de charger les vues.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingViewers = false);
    }
  }

  Future<void> _replyToStory() async {
    final story = stories[currentIndex];
    if (story.isDemo || story.isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce statut de démonstration ne reçoit pas de réponse.'),
        ),
      );
      return;
    }

    final conversation = await ApiService.startConversation(story.author.id);
    if (!mounted) return;
    final roomId = conversation?['room_id']?.toString().trim();
    if (roomId == null || roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ouvrir la discussion.')),
      );
      return;
    }
    await ChatWindowHost.openChat(
      context,
      roomId: roomId,
      title: story.author.username,
    );
  }

  Future<void> _shareStory() async {
    final story = stories[currentIndex];
    final mediaUrl = story.storyType == 'video' ? story.video : story.image;
    final content = story.content?.trim();
    final details = [
      if (content != null && content.isNotEmpty) content,
      ?mediaUrl,
      'Retrouvez ce statut sur FopCam : https://5nmg.l.time4vps.cloud/fopcam/',
    ];
    try {
      await SharePlus.instance.share(
        ShareParams(text: details.join('\n\n'), subject: 'Statut FopCam'),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de partager ce statut : $error')),
      );
    }
  }

  Future<void> _openAuthorProfile() async {
    if (stories[currentIndex].isDemo || stories[currentIndex].isPending) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Le profil de ce statut de démonstration n’est pas réel.',
          ),
        ),
      );
      return;
    }
    final wasPlaying = _isPlaying;
    _timer?.cancel();
    _progressController.stop();
    await showStoryAuthorProfile(context, stories[currentIndex].author);
    if (!mounted || !wasPlaying) return;

    _progressController.forward();
    _timer = Timer(
      Duration(milliseconds: (5000 * (1 - _progressController.value)).toInt()),
      _nextStory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final story = stories[currentIndex];
    final author = story.author;
    final isVideoStory = story.storyType == 'video' && story.video != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx < width / 2) {
            _previousStory();
          } else {
            _nextStory();
          }
        },
        onLongPressStart: isVideoStory ? null : (_) => _togglePlayPause(),
        onLongPressEnd: isVideoStory
            ? null
            : (_) {
                if (!_isPlaying) _togglePlayPause();
              },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Story content background
            _buildStoryContent(story),

            // Progress bars at top
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: List.generate(
                      stories.length,
                      (index) => Expanded(
                        child: Container(
                          height: 3,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: index < currentIndex
                                ? Colors.white
                                : Colors.white30,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: index == currentIndex
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(2),
                                  child: LinearProgressIndicator(
                                    value: _progressController.value,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                    backgroundColor: Colors.white30,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Header with author info
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _openAuthorProfile,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundImage:
                                  author.profileImage != null &&
                                      author.profileImage!.isNotEmpty
                                  ? NetworkImage(
                                      normalizeMediaUrl(author.profileImage) ??
                                          '',
                                    )
                                  : null,
                              child:
                                  author.profileImage == null ||
                                      author.profileImage!.isEmpty
                                  ? Text(
                                      author.username.isNotEmpty
                                          ? author.username[0].toUpperCase()
                                          : 'U',
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  author.username,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                if (story.isDemo || story.isPending)
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: story.isPending
                                          ? const Color(0xFF92400E)
                                          : const Color(0xFF334155),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      child: Text(
                                        story.isPending
                                            ? 'À synchroniser'
                                            : 'Exemple',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                Text(
                                  _formatTime(story.createdAt),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        color: Colors.white,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom actions
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildActionButton(
                        icon: Icons.favorite_border,
                        label: story.likesCount.toString(),
                        onTap: _likeStory,
                      ),
                      _buildActionButton(
                        icon: Icons.remove_red_eye_outlined,
                        label: story.viewsCount.toString(),
                        onTap: _loadViewers,
                      ),
                      _buildActionButton(
                        icon: Icons.reply_outlined,
                        label: 'Répondre',
                        onTap: _replyToStory,
                      ),
                      _buildActionButton(
                        icon: Icons.share_outlined,
                        label: 'Partager',
                        onTap: _shareStory,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Viewers list modal
            if (_showViewerList)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _showViewerList = false),
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF111827),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        width: MediaQuery.of(context).size.width * 0.8,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Vues',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close),
                                    color: Colors.white,
                                    onPressed: () {
                                      setState(() => _showViewerList = false);
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const Divider(
                              color: Color.fromARGB(50, 255, 255, 255),
                            ),
                            Expanded(
                              child: _loadingViewers
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : ListView.builder(
                                      itemCount: _viewers.length,
                                      itemBuilder: (context, index) {
                                        final viewer = _viewers[index];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16.0,
                                            vertical: 8.0,
                                          ),
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundImage:
                                                    viewer['profile_image'] !=
                                                        null
                                                    ? NetworkImage(
                                                        normalizeMediaUrl(
                                                              viewer['profile_image'],
                                                            ) ??
                                                            '',
                                                      )
                                                    : null,
                                                child:
                                                    viewer['profile_image'] ==
                                                        null
                                                    ? Text(
                                                        viewer['username']
                                                            .substring(0, 1)
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                        ),
                                                      )
                                                    : null,
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      viewer['username'],
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                    Text(
                                                      _formatTime(
                                                        DateTime.parse(
                                                          viewer['viewed_at'],
                                                        ),
                                                      ),
                                                      style: const TextStyle(
                                                        color: Colors.white54,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoryContent(Story story) {
    if (story.storyType == 'image' && story.image != null) {
      return Image.network(
        story.image!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white70),
        ),
      );
    } else if (story.storyType == 'video' && story.video != null) {
      return NetworkVideoPlayer(
        url: story.video!,
        fit: BoxFit.cover,
        looping: false,
        showControls: true,
        onCompleted: _nextStory,
      );
    } else {
      // Text story with background color
      return Container(
        color: _parseColor(story.backgroundColor ?? '#1F2937'),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text(
              story.content ?? '',
              style: TextStyle(
                color: _parseColor(story.textColor ?? '#FFFFFF'),
                fontSize: story.fontSize.toDouble(),
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xff')));
    } catch (e) {
      return Colors.black;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return dateTime.toString().split(' ')[0];
    }
  }
}
