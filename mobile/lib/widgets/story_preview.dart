import 'package:flutter/material.dart';
import 'package:mobile/models/story.dart';
import 'package:mobile/utils/media_url_helper.dart';

class StoryPreview extends StatelessWidget {
  const StoryPreview({super.key, required this.story, this.size = 66});

  final Story story;
  final double size;

  Color get _backgroundColor {
    final value = story.backgroundColor?.replaceFirst('#', '');
    if (value == null) return const Color(0xFF334155);
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return const Color(0xFF334155);
    return Color(value.length == 6 ? 0xFF000000 | parsed : parsed);
  }

  Color get _textColor {
    final value = story.textColor?.replaceFirst('#', '');
    if (value == null) return Colors.white;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return Colors.white;
    return Color(value.length == 6 ? 0xFF000000 | parsed : parsed);
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = story.storyType == 'image'
        ? normalizeMediaUrl(story.image)
        : null;
    return SizedBox.square(
      dimension: size,
      child: ClipOval(
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildContentPreview(),
              )
            : _buildContentPreview(),
      ),
    );
  }

  Widget _buildContentPreview() {
    final content = story.content?.trim() ?? '';
    final isVideo = story.storyType == 'video';
    return ColoredBox(
      color: _backgroundColor,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (content.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(size * 0.12),
              child: Center(
                child: Text(
                  content,
                  maxLines: isVideo ? 3 : 5,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _textColor,
                    fontSize: size * 0.15,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
              ),
            )
          else
            Icon(
              isVideo
                  ? Icons.videocam_rounded
                  : story.storyType == 'image'
                  ? Icons.image_rounded
                  : Icons.text_fields_rounded,
              color: _textColor.withValues(alpha: 0.8),
              size: size * 0.42,
            ),
          if (isVideo)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                color: Colors.black.withValues(alpha: 0.55),
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: size * 0.28,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
