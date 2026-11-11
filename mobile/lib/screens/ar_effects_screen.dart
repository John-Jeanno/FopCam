import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/services/api_service.dart';

class AREffectsScreen extends StatefulWidget {
  final String? initialFilter;

  const AREffectsScreen({super.key, this.initialFilter});

  @override
  State<AREffectsScreen> createState() => _AREffectsScreenState();
}

class _AREffectsScreenState extends State<AREffectsScreen> {
  static const _effects = {
    'Nature': Color(0x2222C55E),
    'Chaleur': Color(0x33F97316),
    'Violet': Color(0x443D1B69),
    'Lumière': Color(0x22FDE047),
  };
  static const _stickers = ['✨', '❤️', '🌟', '😎'];

  final _picker = ImagePicker();
  final _previewKey = GlobalKey();
  final _captionController = TextEditingController();
  Uint8List? _imageBytes;
  String? _effect;
  String? _sticker;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _effect = _effects.containsKey(widget.initialFilter)
        ? widget.initialFilter
        : null;
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        imageQuality: 92,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (mounted) setState(() => _imageBytes = bytes);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de sélectionner la photo : $error'),
          ),
        );
      }
    }
  }

  Future<Uint8List> _capturePreview() async {
    await WidgetsBinding.instance.endOfFrame;
    final renderObject = _previewKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) {
      throw StateError('Aperçu photo indisponible.');
    }
    final image = await renderObject.toImage(pixelRatio: 2);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('Export de la photo impossible.');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<void> _publish() async {
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisissez ou prenez une photo d’abord.'),
        ),
      );
      return;
    }
    setState(() => _publishing = true);
    try {
      await precacheImage(MemoryImage(_imageBytes!), context);
      final bytes = await _capturePreview();
      final imageFile = XFile.fromData(
        bytes,
        name: 'fopcam-photo-effet.png',
        mimeType: 'image/png',
      );
      final result = await ApiService.createStory({
        'content': _captionController.text.trim(),
        'story_type': 'image',
      }, imageFile: imageFile);
      if (!mounted) return;
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo publiée dans vos statuts pour 24 heures.'),
          ),
        );
        Navigator.of(context).pop();
      } else {
        throw StateError('${result['error'] ?? 'Publication refusée.'}');
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Publication impossible : $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  Widget _buildPreview() {
    final imageBytes = _imageBytes;
    return RepaintBoundary(
      key: _previewKey,
      child: Container(
        height: 420,
        width: double.infinity,
        color: const Color(0xFF111827),
        child: imageBytes == null
            ? const Center(
                child: Text(
                  'Choisissez une photo pour commencer',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    imageBytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, _) => Center(
                      child: Text(
                        'Lecture de la photo impossible : $error',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  if (_effect != null) ColoredBox(color: _effects[_effect]!),
                  if (_sticker != null)
                    Positioned(
                      top: 24,
                      right: 24,
                      child: Text(
                        _sticker!,
                        style: const TextStyle(fontSize: 48),
                      ),
                    ),
                  if (_captionController.text.trim().isNotEmpty)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 18,
                      child: Text(
                        _captionController.text.trim(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(blurRadius: 8, color: Colors.black)],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Effets photo')),
      backgroundColor: const Color(0xFF020617),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Prenez ou choisissez une photo, ajoutez un effet ou un autocollant, puis publiez-la comme statut.',
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Appareil photo'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galerie'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _buildPreview(),
          ),
          const SizedBox(height: 14),
          const Text(
            'Effets de couleur',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Aucun'),
                selected: _effect == null,
                onSelected: (_) => setState(() => _effect = null),
              ),
              ..._effects.keys.map(
                (effect) => ChoiceChip(
                  label: Text(effect),
                  selected: _effect == effect,
                  onSelected: (_) => setState(() => _effect = effect),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Autocollant',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Aucun'),
                selected: _sticker == null,
                onSelected: (_) => setState(() => _sticker = null),
              ),
              ..._stickers.map(
                (sticker) => ChoiceChip(
                  label: Text(sticker, style: const TextStyle(fontSize: 20)),
                  selected: _sticker == sticker,
                  onSelected: (_) => setState(() => _sticker = sticker),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _captionController,
            onChanged: (_) => setState(() {}),
            maxLength: 180,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Légende (facultative)',
              labelStyle: const TextStyle(color: Colors.white70),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Les effets sont appliqués à une photo fixe ; le suivi facial en direct n’est pas disponible.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _publishing ? null : _publish,
            icon: _publishing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('Publier dans les statuts'),
          ),
        ],
      ),
    );
  }
}
