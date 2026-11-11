import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/utils/media_url_helper.dart';

class CreatePostScreen extends StatefulWidget {
  final User currentUser;

  const CreatePostScreen({super.key, required this.currentUser});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _hashtagController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<XFile> _selectedImages = [];
  List<Uint8List> _selectedImageBytes = [];
  XFile? _selectedVideo;
  String _privacy = 'public'; // public, friends, private
  String _postType = 'text'; // text, image, video, album
  bool _isPosting = false;
  String? _error;
  String? _backgroundColor;

  final List<String> _hashtags = [];
  static const Map<String, Color> _postPalettes = {
    '#FFFFFF': Color(0xFFFFFFFF),
    '#FFF7ED': Color(0xFFFFF7ED),
    '#E0F2FE': Color(0xFFE0F2FE),
    '#DCFCE7': Color(0xFFDCFCE7),
    '#FCE7F3': Color(0xFFFCE7F3),
    '#1E293B': Color(0xFF1E293B),
  };
  static const List<String> _emojis = [
    '😀',
    '😂',
    '🥰',
    '😍',
    '😊',
    '😉',
    '😎',
    '🤔',
    '😭',
    '😡',
    '👏',
    '🙏',
    '❤️',
    '🔥',
    '🎉',
    '🌟',
    '👍',
    '👎',
    '💪',
    '🤝',
    '🌱',
    '🌍',
    '📸',
    '✨',
  ];

  @override
  void dispose() {
    _contentController.dispose();
    _locationController.dispose();
    _hashtagController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final imageBytes = await Future.wait(
          images.map((image) => image.readAsBytes()),
        );
        if (!mounted) return;
        setState(() {
          _selectedImages = images;
          _selectedImageBytes = imageBytes;
          if (_selectedImages.length == 1) {
            _postType = 'image';
          } else {
            _postType = 'album';
          }
        });
      }
    } catch (e) {
      setState(() => _error = 'Erreur lors du choix des images');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final video = await _picker.pickVideo(source: ImageSource.gallery);
      if (video != null && mounted) {
        setState(() {
          _selectedVideo = video;
          _postType = 'video';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Erreur lors du choix de la vidéo');
    }
  }

  void _addHashtag() {
    final tag = _hashtagController.text.trim();
    if (tag.isNotEmpty && !_hashtags.contains(tag)) {
      setState(() {
        _hashtags.add(tag);
        _hashtagController.clear();
      });
    }
  }

  void _removeHashtag(String tag) {
    setState(() => _hashtags.remove(tag));
  }

  String _formatPublishError(Object? error) {
    if (error is Map) {
      for (final key in const [
        'detail',
        'error',
        'content',
        'image',
        'video',
      ]) {
        final value = error[key];
        if (value == null) continue;
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        return value.toString();
      }
      return 'La publication a été refusée. Vérifiez les informations saisies.';
    }
    if (error is String && error.trim().isNotEmpty) return error;
    return 'La publication n’a pas pu être envoyée. Réessayez.';
  }

  Future<void> _publishPost() async {
    final content = _contentController.text.trim();

    if (content.isEmpty && _selectedImages.isEmpty && _selectedVideo == null) {
      setState(() => _error = 'Veuillez ajouter du contenu (texte ou médias)');
      return;
    }

    setState(() {
      _isPosting = true;
      _error = null;
    });

    try {
      Map<String, dynamic> result = {'success': false};

      if (_postType == 'text') {
        result = await ApiService.createPost(
          content,
          privacy: _privacy,
          location: _locationController.text.isEmpty
              ? null
              : _locationController.text,
          hashtags: _hashtags.isEmpty ? null : _hashtags,
          backgroundColor: _backgroundColor,
        );
      } else if (_postType == 'image' && _selectedImages.isNotEmpty) {
        result = await ApiService.createPostWithImage(
          content,
          _selectedImages[0],
          privacy: _privacy,
          location: _locationController.text.isEmpty
              ? null
              : _locationController.text,
          hashtags: _hashtags.isEmpty ? null : _hashtags,
          backgroundColor: _backgroundColor,
        );
      } else if (_postType == 'album' && _selectedImages.isNotEmpty) {
        result = await ApiService.createPostWithImages(
          content,
          _selectedImages,
          privacy: _privacy,
          location: _locationController.text.isEmpty
              ? null
              : _locationController.text,
          hashtags: _hashtags.isEmpty ? null : _hashtags,
          backgroundColor: _backgroundColor,
        );
      } else if (_postType == 'video' && _selectedVideo != null) {
        result = await ApiService.createPostWithVideo(
          content,
          _selectedVideo!,
          privacy: _privacy,
          location: _locationController.text.isEmpty
              ? null
              : _locationController.text,
          hashtags: _hashtags.isEmpty ? null : _hashtags,
          backgroundColor: _backgroundColor,
        );
      }

      if (!mounted) return;
      setState(() => _isPosting = false);

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Publication créée avec succès'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() => _error = _formatPublishError(result['error']));
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isPosting = false;
          _error = _formatPublishError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screen = Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Créer une publication'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (!_isPosting)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed:
                    _contentController.text.isNotEmpty ||
                        _selectedImages.isNotEmpty ||
                        _selectedVideo != null
                    ? _publishPost
                    : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(82, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text('Publier'),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            key: const ValueKey('create-post-content'),
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              children: [
                // Author Info
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFF1F2937),
                          backgroundImage:
                              widget.currentUser.profileImage != null
                              ? (normalizeMediaUrl(
                                          widget.currentUser.profileImage,
                                        ) !=
                                        null
                                    ? NetworkImage(
                                        normalizeMediaUrl(
                                          widget.currentUser.profileImage,
                                        )!,
                                      )
                                    : null)
                              : null,
                          child:
                              (widget.currentUser.profileImage == null ||
                                  normalizeMediaUrl(
                                        widget.currentUser.profileImage,
                                      ) ==
                                      null)
                              ? Text(
                                  widget.currentUser.username[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.currentUser.username,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _privacy == 'public'
                                              ? Icons.public
                                              : _privacy == 'friends'
                                              ? Icons.people
                                              : Icons.lock,
                                          size: 14,
                                          color: theme
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _privacy == 'public'
                                              ? 'Public'
                                              : _privacy == 'friends'
                                              ? 'Amis'
                                              : 'Privé',
                                          style: theme.textTheme.labelMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Modifier la confidentialité',
                                    onSelected: (value) {
                                      setState(() => _privacy = value);
                                    },
                                    itemBuilder: (BuildContext context) => [
                                      const PopupMenuItem(
                                        value: 'public',
                                        child: Row(
                                          children: [
                                            Icon(Icons.public, size: 16),
                                            SizedBox(width: 8),
                                            Text('Public'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'friends',
                                        child: Row(
                                          children: [
                                            Icon(Icons.people, size: 16),
                                            SizedBox(width: 8),
                                            Text('Amis'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'private',
                                        child: Row(
                                          children: [
                                            Icon(Icons.lock, size: 16),
                                            SizedBox(width: 8),
                                            Text('Privé'),
                                          ],
                                        ),
                                      ),
                                    ],
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

                // Content Input
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _backgroundColor == null
                          ? theme.colorScheme.surface
                          : _postPalettes[_backgroundColor],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _backgroundColor == null
                            ? theme.colorScheme.outlineVariant
                            : Colors.transparent,
                      ),
                    ),
                    key: const ValueKey('post-content-card'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _contentController,
                          onChanged: (value) => setState(() {}),
                          maxLines: 6,
                          minLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(color: _postTextColor),
                          decoration: InputDecoration(
                            hintText:
                                'À quoi pensez-vous, ${widget.currentUser.username} ?',
                            hintStyle: TextStyle(
                              color: _postTextColor.withValues(alpha: 0.6),
                            ),
                            border: InputBorder.none,
                            filled: false,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _showEmojiPicker,
                              icon: const Icon(Icons.emoji_emotions_outlined),
                              label: const Text('Émoticônes'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _postTextColor,
                                side: BorderSide(
                                  color: _postTextColor.withValues(alpha: 0.35),
                                ),
                              ),
                            ),
                            Text(
                              'Couleur',
                              style: TextStyle(
                                color: _postTextColor.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                            ),
                            ..._postPalettes.entries.map(
                              (entry) => InkWell(
                                onTap: () => setState(
                                  () => _backgroundColor =
                                      _backgroundColor == entry.key
                                      ? null
                                      : entry.key,
                                ),
                                key: ValueKey('post-palette-${entry.key}'),
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: entry.value,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _backgroundColor == entry.key
                                          ? theme.colorScheme.primary
                                          : Colors.black26,
                                      width: _backgroundColor == entry.key
                                          ? 3
                                          : 1,
                                    ),
                                  ),
                                  child: _backgroundColor == entry.key
                                      ? const Icon(Icons.check, size: 15)
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Selected Images Preview
                if (_selectedImages.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_postType == 'album')
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                ),
                            itemCount: _selectedImages.length,
                            itemBuilder: (context, index) {
                              return Stack(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: DecorationImage(
                                        image: MemoryImage(
                                          _selectedImageBytes[index],
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedImages.removeAt(index);
                                          _selectedImageBytes.removeAt(index);
                                          if (_selectedImages.isEmpty) {
                                            _postType = 'text';
                                          } else if (_selectedImages.length ==
                                              1) {
                                            _postType = 'image';
                                          }
                                        });
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(
                                            alpha: 0.6,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          )
                        else if (_postType == 'image' &&
                            _selectedImages.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _selectedImageBytes[0],
                              height: 300,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                // Selected Video Preview
                if (_selectedVideo != null && _postType == 'video')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey[200],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                Icons.videocam,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedVideo = null;
                                      _postType = 'text';
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),

                // Hashtags
                if (_hashtags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _hashtags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              onDeleted: () => _removeHashtag(tag),
                              backgroundColor:
                                  theme.colorScheme.surfaceContainerHighest,
                              labelStyle: TextStyle(
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),

                // Error Message
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        border: Border.all(
                          color: theme.colorScheme.error.withValues(
                            alpha: 0.35,
                          ),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),

                Divider(color: theme.colorScheme.outlineVariant),

                // Action Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Wrap(
                    key: const ValueKey('create-post-actions'),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ActionButton(
                        icon: Icons.photo_library,
                        label: 'Photos/Vidéos',
                        onPressed: _pickImages,
                      ),
                      _ActionButton(
                        icon: Icons.videocam,
                        label: 'Vidéo',
                        onPressed: _pickVideo,
                      ),
                      _ActionButton(
                        icon: Icons.location_on,
                        label: 'Lieu',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Ajouter un lieu'),
                              content: TextField(
                                controller: _locationController,
                                decoration: const InputDecoration(
                                  hintText: 'Entrez le lieu',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Annuler'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text('OK'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      _ActionButton(
                        icon: Icons.tag_faces,
                        label: 'Hashtags',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Ajouter un hashtag'),
                              content: TextField(
                                controller: _hashtagController,
                                decoration: const InputDecoration(
                                  hintText: 'Ex: #FopCam',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Annuler'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    _addHashtag();
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Ajouter'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
    if (kIsWeb) return screen;

    final mediaQuery = MediaQuery.of(context);
    return MediaQuery(
      data: mediaQuery.copyWith(
        textScaler: mediaQuery.textScaler.clamp(maxScaleFactor: 1.3),
      ),
      child: screen,
    );
  }

  Color get _postTextColor {
    final hex = _backgroundColor;
    if (hex == null) return Theme.of(context).colorScheme.onSurface;
    final color = _postPalettes[hex]!;
    return color.computeLuminance() < 0.45 ? Colors.white : Colors.black87;
  }

  Future<void> _showEmojiPicker() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            crossAxisCount: 6,
            shrinkWrap: true,
            children: _emojis
                .map(
                  (item) => IconButton(
                    tooltip: item,
                    onPressed: () => Navigator.of(context).pop(item),
                    icon: Text(item, style: const TextStyle(fontSize: 28)),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
    if (emoji == null || !mounted) return;

    final value = _contentController.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final text = value.text.replaceRange(start, end, emoji);
    _contentController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
    setState(() {});
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
    );
  }
}
