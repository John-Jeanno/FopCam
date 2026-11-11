import 'package:flutter/material.dart';
import 'package:mobile/models/post.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mobile/screens/create_post_screen.dart';
import 'package:mobile/widgets/post_card.dart';
import 'package:mobile/utils/media_url_helper.dart';

class FeedScreen extends StatefulWidget {
  final bool isLoggedIn;
  final bool isSessionChecked;
  final User? currentUser;

  const FeedScreen({
    super.key,
    this.isLoggedIn = false,
    this.isSessionChecked = true,
    this.currentUser,
  });

  @override
  FeedScreenState createState() => FeedScreenState();
}

class FeedScreenState extends State<FeedScreen> {
  final List<Post> _posts = [];
  final Map<int, Post> _postsById = {};
  final ScrollController _scrollController = ScrollController();
  int _feedGeneration = 0;
  bool _loading = true;
  int _page = 1;
  final int _pageSize = 10;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _hasNextPage = false;
  String? _feedError;
  String? _loadMoreError;
  final Set<int> _pendingLikes = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    final generation = ++_feedGeneration;
    setState(() {
      _loading = true;
      _feedError = null;
      _loadMoreError = null;
      _hasMore = true;
      _hasNextPage = false;
      _loadingMore = false;
      _page = 1;
      _posts.clear();
      _postsById.clear();
    });
    try {
      final pageResult = await ApiService.fetchPostPage(
        pageSize: _pageSize,
        page: _page,
        throwOnError: true,
      );
      if (!mounted || generation != _feedGeneration) return;
      final posts = _reusePosts(pageResult.posts);
      setState(() {
        _posts.addAll(posts);
        _loading = false;
        _hasMore = posts.isNotEmpty;
        _hasNextPage = pageResult.hasNextPage;
      });
      _scheduleViewportFill();
    } catch (error) {
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        _loading = false;
        _feedError = error.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _loadingMore) return;
    final generation = _feedGeneration;
    setState(() => _loadingMore = true);
    var nextPage = _hasNextPage ? _page + 1 : 1;
    try {
      var pageResult = await ApiService.fetchPostPage(
        pageSize: _pageSize,
        page: nextPage,
        throwOnError: true,
      );
      if (pageResult.posts.isEmpty && nextPage != 1) {
        nextPage = 1;
        pageResult = await ApiService.fetchPostPage(
          pageSize: _pageSize,
          page: nextPage,
          throwOnError: true,
        );
      }
      if (!mounted || generation != _feedGeneration) return;
      final posts = _reusePosts(pageResult.posts);
      setState(() {
        _page = nextPage;
        _posts.addAll(posts);
        _hasMore = posts.isNotEmpty;
        _hasNextPage = pageResult.hasNextPage;
        _loadingMore = false;
        _loadMoreError = null;
      });
      _scheduleViewportFill();
    } catch (error) {
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        _loadingMore = false;
        _loadMoreError = error.toString();
      });
    }
  }

  Future<void> refreshAndScrollTop() async {
    await _loadInitial();
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_scrollController.hasClients) return;
    final max = _scrollController.position.maxScrollExtent;
    final current = _scrollController.position.pixels;
    if (current >= (max - 200)) {
      _loadMore();
    }
  }

  List<Post> _reusePosts(List<Post> posts) =>
      posts.map((post) => _postsById.putIfAbsent(post.id, () => post)).toList();

  void _scheduleViewportFill() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_hasMore ||
          _loading ||
          _loadingMore ||
          !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
  }

  Widget _buildFeedError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Impossible de charger le fil d’actualité.',
              textAlign: TextAlign.center,
            ),
            if (_feedError != null) ...[
              const SizedBox(height: 8),
              Text(
                _feedError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
            TextButton.icon(
              onPressed: _loadInitial,
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleLike(Post post) async {
    if (_pendingLikes.contains(post.id)) return;
    final wasLiked = post.isLiked;
    setState(() {
      _pendingLikes.add(post.id);
      post.isLiked = !post.isLiked;
      post.likesCount += post.isLiked ? 1 : -1;
    });

    final success = post.isLiked
        ? await ApiService.likePost(post.id)
        : await ApiService.unlikePost(post.id);

    if (!mounted) return;
    setState(() {
      _pendingLikes.remove(post.id);
      if (!success) {
        post.isLiked = wasLiked;
        post.likesCount += wasLiked ? 1 : -1;
      }
    });

    if (!success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Action échouée')));
    }
  }

  Future<void> _openComments(Post post) async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _CommentsSheet(
        post: post,
        canComment: widget.isLoggedIn,
        currentUserId: widget.currentUser?.id,
        onCommentCountChanged: (count) {
          if (!mounted) return;
          setState(() => post.commentsCount = count);
        },
      ),
    );
  }

  Future<void> _editPost(Post post) async {
    final controller = TextEditingController(text: post.content);
    final content = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier la publication'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 6,
          maxLength: 5000,
          decoration: const InputDecoration(
            labelText: 'Texte de la publication',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (content == null || content == post.content || !mounted) return;
    final updated = await ApiService.updatePostContent(post.id, content);
    if (!mounted) return;
    if (!updated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Modification impossible. Réessayez.')),
      );
      return;
    }
    setState(() => post.content = content);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Publication modifiée.')));
  }

  Future<void> _deletePost(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la publication ?'),
        content: const Text('Cette action ne peut pas être annulée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await ApiService.deletePost(post.id);
    if (!mounted) return;
    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Suppression impossible. Réessayez.')),
      );
      return;
    }
    setState(() {
      _posts.removeWhere((item) => item.id == post.id);
      _postsById.remove(post.id);
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Publication supprimée.')));
  }

  Future<void> _sharePost(Post post) async {
    if (!widget.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connectez-vous pour partager.')),
      );
      return;
    }

    final shareText = post.content.isNotEmpty
        ? post.content
        : 'Découvrez cette publication sur FopCam.';

    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: '$shareText\n\nVoir plus sur FopCam',
          subject: 'Partage FopCam',
        ),
      );
      if (result.status != ShareResultStatus.success) return;

      final success = await ApiService.sharePost(post.id);
      if (!mounted) return;
      if (success) {
        setState(() => post.sharesCount++);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publication partagée avec succès')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Le partage a été effectué, mais son enregistrement a échoué.',
            ),
          ),
        );
      }
    } catch (error) {
      debugPrint('Error sharing post: $error');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de partager cette publication.'),
        ),
      );
    }
  }

  Future<void> _openCreatePost() async {
    final currentUser = widget.currentUser;
    if (currentUser == null) {
      Navigator.of(context).pushNamed('/login');
      return;
    }

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreatePostScreen(currentUser: currentUser),
      ),
    );
    if (result == true) {
      _loadInitial();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: _loading
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 24),
              children: const [Center(child: CircularProgressIndicator())],
            )
          : ListView.separated(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount:
                  1 +
                  (_feedError != null ? 1 : 0) +
                  _posts.length +
                  (_loadingMore || _loadMoreError != null ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildPostComposer();
                }

                if (_feedError != null && index == 1) {
                  return _buildFeedError();
                }

                final postIndex = index - 1 - (_feedError != null ? 1 : 0);
                if (postIndex >= _posts.length) {
                  if (_loadMoreError != null) {
                    return Center(
                      child: TextButton.icon(
                        onPressed: _loadMore,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer le chargement'),
                      ),
                    );
                  }
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final post = _posts[postIndex];
                return PostCard(
                  post: post,
                  onLike: () => _toggleLike(post),
                  onShare: () => _sharePost(post),
                  onCommentTap: () => _openComments(post),
                  currentUserId: widget.currentUser?.id,
                  onEditPost: () => _editPost(post),
                  onDeletePost: () => _deletePost(post),
                );
              },
            ),
    );
  }

  Widget _buildPostComposer() {
    if (!widget.isSessionChecked) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Chargement de votre profil...',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    if (!widget.isLoggedIn) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connectez-vous pour publier des contenus.',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Se connecter'),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.currentUser == null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Impossible de récupérer les informations du profil.',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pushNamed('/login'),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Se reconnecter'),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Author info row
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage:
                    (widget.currentUser?.profileImage != null &&
                        Uri.tryParse(
                              widget.currentUser!.profileImage!,
                            )?.hasAbsolutePath ==
                            true)
                    ? NetworkImage(
                        normalizeMediaUrl(widget.currentUser!.profileImage) ??
                            '',
                      )
                    : null,
                child:
                    widget.currentUser?.profileImage == null ||
                        Uri.tryParse(
                              widget.currentUser!.profileImage!,
                            )?.hasAbsolutePath !=
                            true
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _openCreatePost,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Text(
                      'Écrivez quelque chose...',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Media action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                icon: Icons.image_outlined,
                label: 'Photos/Vidéos',
                onTap: _openCreatePost,
              ),
              _buildActionButton(
                icon: Icons.location_on_outlined,
                label: 'Localisation',
                onTap: _openCreatePost,
              ),
              _buildActionButton(
                icon: Icons.tag_outlined,
                label: 'Hashtags',
                onTap: _openCreatePost,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  final Post post;
  final bool canComment;
  final int? currentUserId;
  final ValueChanged<int> onCommentCountChanged;

  const _CommentsSheet({
    required this.post,
    required this.canComment,
    required this.currentUserId,
    required this.onCommentCountChanged,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  int _visibleCommentCount = 6;
  bool _loading = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    final comments = await ApiService.fetchComments(widget.post.id);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _loading = false;
    });
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty || _submitting || !widget.canComment) {
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final success = await ApiService.createComment(widget.post.id, content);
    if (!mounted) return;
    if (!success) {
      setState(() {
        _submitting = false;
        _errorMessage =
            'Impossible d’envoyer le commentaire. Vérifiez votre connexion puis réessayez.';
      });
      return;
    }
    _commentController.clear();
    await _loadComments();
    if (!mounted) return;
    widget.onCommentCountChanged(
      _comments.length > widget.post.commentsCount
          ? _comments.length
          : widget.post.commentsCount + 1,
    );
    setState(() => _submitting = false);
  }

  int? _commentAuthorId(Map<String, dynamic> comment) {
    final author = comment['user'] ?? comment['author'];
    if (author is! Map) return null;
    final id = author['id'];
    return id is int ? id : int.tryParse(id?.toString() ?? '');
  }

  Future<void> _editComment(Map<String, dynamic> comment) async {
    final commentId = comment['id'];
    if (commentId is! int) return;
    final controller = TextEditingController(
      text: comment['content']?.toString() ?? '',
    );
    final content = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier le commentaire'),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: 'Commentaire',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (content == null ||
        content.isEmpty ||
        content == comment['content'] ||
        !mounted) {
      return;
    }
    final updated = await ApiService.updateComment(commentId, content);
    if (!mounted) return;
    if (!updated) {
      setState(() => _errorMessage = 'Impossible de modifier ce commentaire.');
      return;
    }
    setState(() => comment['content'] = content);
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final commentId = comment['id'];
    if (commentId is! int) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le commentaire ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await ApiService.deleteComment(commentId);
    if (!mounted) return;
    if (!deleted) {
      setState(() => _errorMessage = 'Impossible de supprimer ce commentaire.');
      return;
    }
    setState(() => _comments.remove(comment));
    widget.onCommentCountChanged(
      _comments.length > widget.post.commentsCount
          ? _comments.length
          : (widget.post.commentsCount - 1).clamp(0, 1 << 31).toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.75,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Commentaires',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _comments.isEmpty
                      ? const Center(
                          child: Text(
                            'Aucun commentaire',
                            style: TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.separated(
                          itemCount:
                              (_comments.length < _visibleCommentCount
                                  ? _comments.length
                                  : _visibleCommentCount) +
                              (_comments.length > _visibleCommentCount ? 1 : 0),
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final visibleCount =
                                _comments.length < _visibleCommentCount
                                ? _comments.length
                                : _visibleCommentCount;
                            if (index == visibleCount &&
                                _comments.length > _visibleCommentCount) {
                              return Center(
                                child: TextButton(
                                  onPressed: () =>
                                      setState(() => _visibleCommentCount += 6),
                                  child: const Text('Voir plus'),
                                ),
                              );
                            }
                            final comment = _comments[index];
                            final author = comment['user'] ?? comment['author'];
                            var displayName = 'Anonyme';
                            if (author is Map) {
                              final first = (author['first_name'] ?? '')
                                  .toString();
                              final last = (author['last_name'] ?? '')
                                  .toString();
                              if (first.isNotEmpty || last.isNotEmpty) {
                                displayName = '$first $last'.trim();
                              } else if ((author['username'] ?? '')
                                  .toString()
                                  .isNotEmpty) {
                                displayName = author['username'].toString();
                              }
                            }
                            final isOwner =
                                widget.currentUserId != null &&
                                widget.currentUserId ==
                                    _commentAuthorId(comment);
                            return ListTile(
                              title: Text(
                                displayName,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                comment['content']?.toString() ?? '',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: isOwner
                                  ? PopupMenuButton<String>(
                                      tooltip: 'Gérer mon commentaire',
                                      onSelected: (action) {
                                        if (action == 'edit') {
                                          _editComment(comment);
                                        } else if (action == 'delete') {
                                          _deleteComment(comment);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Modifier'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Supprimer'),
                                        ),
                                      ],
                                    )
                                  : null,
                            );
                          },
                        ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                if (!widget.canComment)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Connectez-vous pour commenter.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commentController,
                        enabled: widget.canComment && !_submitting,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Écrire un commentaire',
                          hintStyle: const TextStyle(color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF111827),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: widget.canComment && !_submitting
                          ? _submitComment
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Envoyer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
