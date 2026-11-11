import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/services/story_offline_service.dart';
import 'package:mobile/widgets/story_options_bottom_sheet.dart';

enum StoryMediaAction {
  galleryImage,
  cameraImage,
  galleryVideo,
  cameraVideo,
  textOnly,
}

class StoryMediaSelection {
  const StoryMediaSelection({required this.action, required this.file});

  final StoryMediaAction action;
  final XFile? file;
}

class CreateStoryScreen extends StatefulWidget {
  const CreateStoryScreen({super.key, this.initialMediaSelection});

  final StoryMediaSelection? initialMediaSelection;

  @override
  State<CreateStoryScreen> createState() => _CreateStoryScreenState();
}

class _CreateStoryScreenState extends State<CreateStoryScreen> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  XFile? _videoFile;
  Uint8List? _imageBytes;
  String? _backgroundColor = '#1F2937';
  String? _textColor = '#FFFFFF';
  double _fontSize = 24;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final selection = widget.initialMediaSelection;
    if (selection == null || selection.file == null) return;

    if (selection.action == StoryMediaAction.galleryVideo ||
        selection.action == StoryMediaAction.cameraVideo) {
      _videoFile = selection.file;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyInitialSelection(selection);
      });
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _applyInitialSelection(StoryMediaSelection selection) async {
    final file = selection.file;
    if (file == null) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageFile = file;
      _videoFile = null;
      _imageBytes = bytes;
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
      );
      if (!mounted) return;
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          _imageFile = picked;
          _videoFile = null;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur sélection image : $e')));
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
      );
      if (!mounted) return;
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        setState(() {
          _imageFile = picked;
          _videoFile = null;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur capture photo : $e')));
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      if (!mounted) return;
      if (picked != null) {
        setState(() {
          _videoFile = picked;
          _imageFile = null;
          _imageBytes = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur sélection vidéo : $e')));
    }
  }

  Future<void> _pickVideoFromCamera() async {
    try {
      final XFile? picked = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );
      if (!mounted) return;
      if (picked != null) {
        setState(() {
          _videoFile = picked;
          _imageFile = null;
          _imageBytes = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erreur capture vidéo : $e')));
    }
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();

    if (content.isEmpty && _imageFile == null && _videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajoutez du texte, une image ou une vidéo.'),
        ),
      );
      return;
    }

    final userData = await StorageService.getUserData();
    if (!mounted) return;
    if (userData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous avant de publier un statut.'),
        ),
      );
      return;
    }

    final decodedUser = jsonDecode(userData);
    if (decodedUser is! Map<String, dynamic>) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de vérifier le compte à publier.'),
        ),
      );
      return;
    }
    final userId = int.tryParse(decodedUser['id']?.toString() ?? '');
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible de vérifier le compte à publier.'),
        ),
      );
      return;
    }

    String storyType = 'text';
    if (_imageFile != null) storyType = 'image';
    if (_videoFile != null) storyType = 'video';

    final Map<String, dynamic> payload = {
      'content': content,
      'story_type': storyType,
      'background_color': _backgroundColor,
      'text_color': _textColor,
      'font_size': _fontSize.toInt(),
    };

    setState(() => _isLoading = true);
    try {
      final published = await StoryOfflineService.enqueueAndSync(
        fields: payload,
        userId: userId,
        username: decodedUser['username']?.toString() ?? 'Vous',
        mediaFile: _imageFile ?? _videoFile,
      );

      if (!mounted) return;

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            published
                ? 'Statut publié avec succès. Il sera visible pendant 24 heures.'
                : 'Statut enregistré sur cet appareil. Il sera synchronisé dès le retour d’internet, puis visible pendant 24 heures.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d’enregistrer le statut sur cet appareil : $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un statut'),
        backgroundColor: const Color(0xFF111827),
      ),
      backgroundColor: const Color(0xFF020617),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Partagez un nouveau statut, visible pendant 24 heures.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Contenu du statut',
              _contentController,
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.palette),
                  label: const Text('Style'),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => StoryOptionsBottomSheet(
                        onOptionsSelected: (bgColor, textColor, fontSize) {
                          setState(() {
                            if (bgColor != null) _backgroundColor = bgColor;
                            if (textColor != null) _textColor = textColor;
                            _fontSize = fontSize;
                          });
                        },
                      ),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      isScrollControlled: true,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildMediaButton(
                  icon: Icons.photo,
                  label: 'Image galerie',
                  onPressed: _pickImage,
                ),
                _buildMediaButton(
                  icon: Icons.camera_alt,
                  label: 'Photo caméra',
                  onPressed: _pickImageFromCamera,
                ),
                _buildMediaButton(
                  icon: Icons.videocam,
                  label: 'Vidéo galerie',
                  onPressed: _pickVideo,
                ),
                _buildMediaButton(
                  icon: Icons.videocam_outlined,
                  label: 'Vidéo caméra',
                  onPressed: _pickVideoFromCamera,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_imageBytes != null)
              Stack(
                children: [
                  Image.memory(
                    _imageBytes!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() {
                        _imageFile = null;
                        _imageBytes = null;
                      }),
                    ),
                  ),
                ],
              ),
            if (_videoFile != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 200,
                    color: Colors.black12,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.videocam,
                            size: 48,
                            color: Colors.white70,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _videoFile!.name,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() => _videoFile = null),
                    ),
                  ),
                ],
              ),
            if (_contentController.text.isNotEmpty &&
                _imageFile == null &&
                _videoFile == null) ...[
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    color: _parseColor(_backgroundColor ?? '#1F2937'),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _contentController.text,
                        style: TextStyle(
                          color: _parseColor(_textColor ?? '#FFFFFF'),
                          fontSize: _fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _isLoading ? null : _submit,
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Publier le statut',
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF111827),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 160,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, overflow: TextOverflow.ellipsis),
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
}
