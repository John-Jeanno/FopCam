import 'package:flutter/material.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/models/live_stream.dart';
import 'package:mobile/screens/live_broadcast_screen.dart';
import 'package:mobile/screens/live_room_screen.dart';
import 'package:mobile/services/api_service.dart';

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  late Future<List<LiveStream>> _liveStreamsFuture;

  @override
  void initState() {
    super.initState();
    _liveStreamsFuture = ApiService.fetchLiveStreams();
  }

  Future<void> _refreshLiveStreams() async {
    setState(() {
      _liveStreamsFuture = ApiService.fetchLiveStreams();
    });
  }

  Future<void> _openBroadcast() async {
    final ended = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const LiveBroadcastScreen()),
    );
    if (ended == true && mounted) {
      await _refreshLiveStreams();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Directs'),
        actions: [
          IconButton(
            tooltip: 'Actualiser les diffusions',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLiveStreams,
          ),
          IconButton(
            icon: const Icon(Icons.wifi_tethering),
            onPressed: _openBroadcast,
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<LiveStream>>(
          future: _liveStreamsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.videocam_off_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Impossible de charger les diffusions en direct.',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        style: const TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _refreshLiveStreams,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/reels'),
                        icon: const Icon(Icons.video_library),
                        label: const Text('Explorer les clips disponibles'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final liveStreams = snapshot.data ?? [];

            return RefreshIndicator(
              onRefresh: _refreshLiveStreams,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Diffusions en direct pour vendre, présenter ou inviter la communauté.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _openBroadcast,
                    icon: const Icon(Icons.videocam),
                    label: const Text('Démarrer un direct'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Diffusions populaires',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (liveStreams.isEmpty)
                    Center(
                      child: Text(
                        'Aucune diffusion disponible pour le moment.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  else
                    ...liveStreams.map((stream) {
                      return Column(
                        children: [
                          InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      LiveRoomScreen(stream: stream),
                                ),
                              );
                              if (mounted) await _refreshLiveStreams();
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    height: 160,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF111827),
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.videocam,
                                        color: Colors.white38,
                                        size: 48,
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          stream.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              stream.host.username,
                                              style: const TextStyle(
                                                color: Colors.white,
                                              ),
                                            ),
                                            const Spacer(),
                                            Text(
                                              '${stream.viewers} spectateurs',
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
                          ),
                        ],
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
