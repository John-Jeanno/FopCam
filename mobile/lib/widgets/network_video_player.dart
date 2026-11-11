import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class NetworkVideoPlayer extends StatefulWidget {
  const NetworkVideoPlayer({
    super.key,
    required this.url,
    this.fit = BoxFit.contain,
    this.autoplay = true,
    this.looping = false,
    this.showControls = true,
    this.onCompleted,
  });

  final String url;
  final BoxFit fit;
  final bool autoplay;
  final bool looping;
  final bool showControls;
  final VoidCallback? onCompleted;

  @override
  State<NetworkVideoPlayer> createState() => _NetworkVideoPlayerState();
}

class _NetworkVideoPlayerState extends State<NetworkVideoPlayer> {
  late VideoPlayerController _controller;
  late Future<void> _initialization;
  bool _completionHandled = false;

  @override
  void initState() {
    super.initState();
    _createController();
  }

  void _createController() {
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _initialization = _initialize();
  }

  Future<void> _initialize() async {
    await _controller.initialize();
    _controller.addListener(_handlePlayback);
    await _controller.setLooping(widget.looping);
    if (widget.autoplay) await _controller.play();
  }

  void _handlePlayback() {
    if (!_controller.value.isCompleted) {
      _completionHandled = false;
    } else if (!_completionHandled) {
      _completionHandled = true;
      widget.onCompleted?.call();
    }
  }

  void _retry() {
    _controller.dispose();
    setState(() {
      _completionHandled = false;
      _createController();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ColoredBox(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'La lecture de cette vidéo est indisponible.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          );
        }
        if (snapshot.connectionState != ConnectionState.done ||
            !_controller.value.isInitialized) {
          return const ColoredBox(
            color: Colors.black,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final size = _controller.value.size;
        return Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: ClipRect(
                child: FittedBox(
                  fit: widget.fit,
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),
            ),
            if (widget.showControls)
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: _controller,
                builder: (context, value, _) => IconButton.filledTonal(
                  tooltip: value.isPlaying ? 'Mettre en pause' : 'Lire',
                  onPressed: () => value.isPlaying
                      ? _controller.pause()
                      : _controller.play(),
                  iconSize: 36,
                  icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                ),
              ),
          ],
        );
      },
    );
  }
}
