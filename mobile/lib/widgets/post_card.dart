import 'package:flutter/material.dart';
import 'package:mobile/models/post.dart';
import 'package:mobile/utils/media_url_helper.dart';
import 'package:mobile/widgets/post_image_viewer.dart';
import 'package:mobile/widgets/trophy_art.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onLike;
  final VoidCallback onShare;
  final VoidCallback? onCommentTap;
  final int? currentUserId;
  final VoidCallback? onEditPost;
  final VoidCallback? onDeletePost;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onShare,
    this.onCommentTap,
    this.currentUserId,
    this.onEditPost,
    this.onDeletePost,
  });

  @override
  Widget build(BuildContext context) {
    final singleImage =
        post.image ??
        (post.images?.isNotEmpty == true ? post.images!.first : null);
    return Card(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header (Author info)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 20,
                  backgroundImage: post.author.profileImage != null
                      ? NetworkImage(
                          normalizeMediaUrl(post.author.profileImage) ?? '',
                        )
                      : null,
                  backgroundColor: Colors.blueGrey,
                  child: post.author.profileImage == null
                      ? Text(
                          post.author.username.isNotEmpty
                              ? post.author.username[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // Author info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              post.author.username,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            post.getTimeAgo(),
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                          if (post.privacy != 'public') ...[
                            const SizedBox(width: 4),
                            Icon(
                              post.privacy == 'friends'
                                  ? Icons.people
                                  : Icons.lock,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (currentUserId == post.author.id)
                  PopupMenuButton<String>(
                    color: Colors.white,
                    icon: const Icon(Icons.more_vert, color: Colors.black54),
                    onSelected: (value) {
                      if (value == 'edit') onEditPost?.call();
                      if (value == 'delete') onDeletePost?.call();
                    },
                    itemBuilder: (BuildContext context) => [
                      if (onEditPost != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text(
                            'Modifier',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                      if (onDeletePost != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Supprimer',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Location (if available)
          if (post.location != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 4.0,
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    post.location!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ),

          // Content
          if (post.content.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: _backgroundColor ?? Colors.white,
              child: Text(
                post.content,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color:
                      (_backgroundColor ?? Colors.white).computeLuminance() >=
                          0.45
                      ? Colors.black87
                      : Colors.white,
                ),
              ),
            ),

          if (post.postType == 'trophy' && post.trophyData != null)
            _TrophyPostCard(trophy: post.trophyData!),

          // Single Image
          if (post.postType == 'image' && singleImage != null)
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 400),
              child: GestureDetector(
                key: ValueKey('post-image-${post.id}'),
                onTap: () => showPostImageViewer(
                  context,
                  singleImage,
                  title: post.author.username,
                ),
                child: Image.network(
                  singleImage,
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: const Center(child: Icon(Icons.broken_image)),
                  ),
                ),
              ),
            ),

          // Multiple Images (Album)
          if (post.postType == 'album' &&
              post.images != null &&
              post.images!.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: post.images!.length > 1 ? 2 : 1,
                mainAxisSpacing: 2,
                crossAxisSpacing: 2,
              ),
              itemCount: post.images!.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  key: ValueKey('post-image-${post.id}-$index'),
                  onTap: () => showPostImageViewer(
                    context,
                    post.images![index],
                    title: post.author.username,
                  ),
                  child: Image.network(
                    post.images![index],
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                );
              },
            ),

          // Video Placeholder
          if (post.postType == 'video' && post.video != null)
            Container(
              width: double.infinity,
              height: 300,
              color: Colors.black,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.play_circle_fill,
                    size: 80,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),

          // Engagement Stats
          if (post.likesCount > 0 ||
              post.commentsCount > 0 ||
              post.sharesCount > 0)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.thumb_up, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        '${post.likesCount}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '${post.commentsCount} commentaire${post.commentsCount > 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${post.sharesCount} partage${post.sharesCount > 1 ? 's' : ''}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const Divider(height: 1),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Like Button
                _ActionButton(
                  icon: Icons.thumb_up,
                  label: 'J\'aime',
                  isActive: post.isLiked,
                  onPressed: onLike,
                ),
                // Comment Button
                _ActionButton(
                  icon: Icons.comment,
                  label: 'Commenter',
                  onPressed: onCommentTap ?? () {},
                ),
                // Share Button
                _ActionButton(
                  icon: Icons.share,
                  label: 'Partager',
                  onPressed: onShare,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color? get _backgroundColor {
    final value = post.backgroundColor;
    if (value == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value)) {
      return null;
    }
    final color = Color(int.parse('FF${value.substring(1)}', radix: 16));
    final hsl = HSLColor.fromColor(color);
    final isRedBackground =
        (hsl.hue < 20 || hsl.hue > 340) &&
        hsl.saturation > 0.4 &&
        hsl.lightness < 0.7;
    return isRedBackground ? Colors.white : color;
  }
}

class _TrophyPostCard extends StatelessWidget {
  const _TrophyPostCard({required this.trophy});

  final Map<String, dynamic> trophy;

  @override
  Widget build(BuildContext context) {
    final medal = trophy['medal']?.toString() ?? 'cup';
    final title = trophy['title']?.toString() ?? 'Champion FopCam';
    final opponent = trophy['opponent']?.toString();
    final winnerScore = trophy['winner_score'];
    final opponentScore = trophy['opponent_score'];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF302047), Color(0xFF131B30), Color(0xFF563B1D)],
        ),
        border: Border.all(color: const Color(0xFFD4AF37), width: 1.3),
        boxShadow: const [
          BoxShadow(
            color: Color(0x334B3010),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          TrophyArtwork(medal: medal, width: 94, height: 108),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'TROPHÉE DE DUEL',
                  style: TextStyle(
                    color: Color(0xFFFFE8A3),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  medal == 'cup_pro'
                      ? 'Coupe · Champion League Pro'
                      : medal == 'cup'
                      ? 'Coupe · Champion 1ère Ligue'
                      : medal.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFFFD36A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (opponent?.isNotEmpty == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      'Victoire contre $opponent'
                      '${winnerScore is int && opponentScore is int ? ' · $winnerScore–$opponentScore' : ''}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.blue : Colors.grey[700],
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.blue : Colors.grey[700],
                  fontSize: 14,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
