import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/models/reel.dart';
import 'package:mobile/screens/create_reel_screen.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/utils/media_url_helper.dart';
import 'package:mobile/widgets/network_video_player.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late Future<List<Reel>> _reelsFuture;
  final List<String> _themes = [
    'Tous',
    'Produits',
    'Recettes',
    'Vie locale',
    'Tendances',
  ];
  String _selectedTheme = 'Tous';

  @override
  void initState() {
    super.initState();
    _reelsFuture = ApiService.fetchReels();
  }

  void _refreshReels() {
    setState(() {
      _reelsFuture = ApiService.fetchReels();
    });
  }

  bool _matchesTheme(Reel reel) {
    return _selectedTheme == 'Tous' || reel.theme == _selectedTheme;
  }

  void _openReel(Reel reel) {
    final videoUrl = normalizeMediaUrl(reel.video);
    if (videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce clip ne contient pas de vidéo.')),
      );
      return;
    }

    unawaited(ApiService.viewReel(reel.id));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReelPlaybackScreen(reel: reel, videoUrl: videoUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Clips'),
        actions: [
          IconButton(
            tooltip: 'Actualiser les clips',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshReels,
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const CreateReelScreen()),
              );
              if (created == true) {
                _refreshReels();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: const [
                  Icon(Icons.explore, color: Colors.white70),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Filtrer par thèmes et découvrir les vidéos populaires.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 40,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _themes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final theme = _themes[index];
                  final selected = theme == _selectedTheme;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTheme = theme),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        theme,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: FutureBuilder<List<Reel>>(
                future: _reelsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Impossible de charger les clips.',
                            style: TextStyle(color: Colors.white70),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _refreshReels,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    );
                  }

                  final reels = (snapshot.data ?? [])
                      .where(_matchesTheme)
                      .toList();

                  if (reels.isEmpty) {
                    return Center(
                      child: Text(
                        'Aucun clip trouvé pour ce thème.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: reels.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final reel = reels[index];
                      final thumbnailUrl = normalizeMediaUrl(reel.thumbnail);
                      return InkWell(
                        onTap: () => _openReel(reel),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    height: 180,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF111827),
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    child: thumbnailUrl == null
                                        ? const Center(
                                            child: Icon(
                                              Icons.video_library_outlined,
                                              color: Colors.white54,
                                              size: 52,
                                            ),
                                          )
                                        : Image.network(
                                            thumbnailUrl,
                                            width: double.infinity,
                                            height: 180,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, _, _) =>
                                                const Center(
                                                  child: Icon(
                                                    Icons
                                                        .video_library_outlined,
                                                    color: Colors.white54,
                                                    size: 52,
                                                  ),
                                                ),
                                          ),
                                  ),
                                  const Icon(
                                    Icons.play_circle_fill,
                                    color: Colors.white,
                                    size: 56,
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reel.title,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      reel.description,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppColors.primary,
                                          child: const Icon(
                                            Icons.person,
                                            size: 16,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            reel.author.username,
                                            style: const TextStyle(
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          reel.duration ?? '00s',
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReelPlaybackScreen extends StatelessWidget {
  const ReelPlaybackScreen({
    super.key,
    required this.reel,
    required this.videoUrl,
  });

  final Reel reel;
  final String videoUrl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(reel.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: Column(
        children: [
          Expanded(
            child: NetworkVideoPlayer(
              url: videoUrl,
              fit: BoxFit.contain,
              showControls: true,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    reel.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (reel.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      reel.description,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '@${reel.author.username}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
