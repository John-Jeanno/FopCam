import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/services/api_service.dart';

class CreateReelScreen extends StatefulWidget {
  const CreateReelScreen({super.key});

  @override
  State<CreateReelScreen> createState() => _CreateReelScreenState();
}

class _CreateReelScreenState extends State<CreateReelScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _videoFile;
  XFile? _beforeVideoFile;
  String _selectedTheme = 'Produits';
  String _selectedEffect = 'none';
  String _selectedSticker = 'sparkle';
  static const _themes = ['Produits', 'Recettes', 'Vie locale', 'Tendances'];
  static const _effects = <String, String>{
    'none': 'Aucun',
    'light': 'Lumière',
    'stickers': 'Autocollants',
    'before_after': 'Avant / après',
    'face': 'Visage',
  };
  static const _stickers = <String, String>{
    'sparkle': 'Étincelles ✨',
    'heart': 'Cœur ❤️',
    'star': 'Étoile 🌟',
    'cool': 'Lunettes 😎',
  };
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isUploading = false;

  Future<void> _pickVideo(ImageSource source, {bool before = false}) async {
    if (_isUploading) return;
    try {
      final file = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 60),
      );
      if (file == null || !mounted) return;
      setState(() {
        if (before) {
          _beforeVideoFile = file;
        } else {
          _videoFile = file;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de sélectionner la vidéo : $error')),
      );
    }
  }

  Future<void> _submitReel() async {
    final videoFile = _videoFile;
    if (videoFile == null ||
        (_selectedEffect == 'before_after' && _beforeVideoFile == null)) {
      return;
    }
    setState(() {
      _isUploading = true;
    });

    final result = await ApiService.createReel(
      videoFile,
      title: _titleController.text.trim().isEmpty
          ? 'Nouveau clip'
          : _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      theme: _selectedTheme,
      effect: _selectedEffect,
      sticker: _selectedSticker,
      beforeVideo: _selectedEffect == 'before_after' ? _beforeVideoFile : null,
    );

    if (!mounted) return;
    setState(() => _isUploading = false);
    final success = result['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Clip publié avec succès !'
              : 'Publication impossible : ${_errorMessage(result['error'])}',
        ),
      ),
    );

    if (success) {
      Navigator.of(context).pop(true);
    }
  }

  String _errorMessage(dynamic error) {
    if (error is Map) {
      for (final field in ['video', 'before_video', 'effect', 'detail']) {
        final value = error[field];
        if (value is List && value.isNotEmpty) return value.first.toString();
        if (value is String && value.isNotEmpty) return value;
      }
    }
    return error?.toString() ?? 'Veuillez réessayer.';
  }

  Widget _selectedVideo(String label, XFile? video) {
    return Row(
      children: [
        const Icon(Icons.video_file_outlined, color: Colors.white70),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            video == null
                ? '$label · aucune sélection'
                : '$label · ${video.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Créer un clip')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Ajoutez un thème et un effet vidéo avant de publier votre clip.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Filmer'),
                    onPressed: _isUploading
                        ? null
                        : () => _pickVideo(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.video_library),
                    label: const Text('Galerie'),
                    onPressed: _isUploading
                        ? null
                        : () => _pickVideo(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Titre du clip',
                hintStyle: const TextStyle(color: Colors.white),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _selectedVideo('Après', _videoFile),
                  if (_selectedEffect == 'before_after') ...[
                    const SizedBox(height: 8),
                    _selectedVideo('Avant', _beforeVideoFile),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Effet vidéo',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _effects.entries.map((entry) {
                final selected = entry.key == _selectedEffect;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedEffect = entry.key;
                    });
                  },
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primary,
                  labelStyle: const TextStyle(color: Colors.white),
                );
              }).toList(),
            ),
            if (_selectedEffect == 'stickers') ...[
              const SizedBox(height: 16),
              const Text(
                'Autocollant',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: _stickers.entries.map((entry) {
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: entry.key == _selectedSticker,
                    onSelected: (_) =>
                        setState(() => _selectedSticker = entry.key),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primary,
                    labelStyle: const TextStyle(color: Colors.white),
                  );
                }).toList(),
              ),
            ],
            if (_selectedEffect == 'before_after') ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Filmer avant'),
                      onPressed: _isUploading
                          ? null
                          : () => _pickVideo(ImageSource.camera, before: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.video_library),
                      label: const Text('Choisir avant'),
                      onPressed: _isUploading
                          ? null
                          : () => _pickVideo(ImageSource.gallery, before: true),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Thème',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _themes.map((theme) {
                final selected = theme == _selectedTheme;
                return ChoiceChip(
                  label: Text(theme),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _selectedTheme = theme;
                    });
                  },
                  backgroundColor: AppColors.surface,
                  selectedColor: AppColors.primary,
                  labelStyle: TextStyle(color: Colors.white),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _descriptionController,
              maxLines: 4,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Décris ton clip...',
                hintStyle: const TextStyle(color: Colors.white),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed:
                  _videoFile == null ||
                      (_selectedEffect == 'before_after' &&
                          _beforeVideoFile == null) ||
                      _isUploading
                  ? null
                  : _submitReel,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Publier le clip'),
            ),
          ],
        ),
      ),
    );
  }
}
