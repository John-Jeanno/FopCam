import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/models/shop.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/utils/media_url_helper.dart';

class CreateShopScreen extends StatefulWidget {
  const CreateShopScreen({super.key, this.shop});

  final Shop? shop;

  @override
  State<CreateShopScreen> createState() => _CreateShopScreenState();
}

class _CreateShopScreenState extends State<CreateShopScreen> {
  static const _colorPresets = [
    '#0F172A',
    '#1D4ED8',
    '#047857',
    '#7C3AED',
    '#BE123C',
    '#F8FAFC',
    '#FDE68A',
    '#111827',
  ];

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _backgroundColorController =
      TextEditingController();
  final TextEditingController _textColorController = TextEditingController();
  final TextEditingController _accentColorController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _logo;
  XFile? _banner;
  Uint8List? _logoBytes;
  Uint8List? _bannerBytes;
  bool _isSaving = false;
  double _fontSize = 16;
  late Future<Map<String, dynamic>> _createProfileFuture;

  @override
  void initState() {
    super.initState();
    if (widget.shop == null) {
      _createProfileFuture = AuthService.getProfile();
    }
    final shop = widget.shop;
    _nameController.text = shop?.name ?? '';
    _locationController.text = shop?.location ?? '';
    _descriptionController.text = shop?.description ?? '';
    _phoneController.text = shop?.phoneNumbers.join('\n') ?? '';
    _emailController.text = shop?.email ?? '';
    _websiteController.text = shop?.website ?? '';
    _backgroundColorController.text = shop?.backgroundColor ?? '#0F172A';
    _textColorController.text = shop?.textColor ?? '#F8FAFC';
    _accentColorController.text = shop?.accentColor ?? '#7C3AED';
    _fontSize = shop?.fontSize ?? 16;
    for (final controller in [
      _nameController,
      _locationController,
      _descriptionController,
      _phoneController,
      _emailController,
      _websiteController,
      _backgroundColorController,
      _textColorController,
      _accentColorController,
    ]) {
      controller.addListener(_refreshAppearancePreview);
    }
  }

  void _refreshAppearancePreview() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _websiteController.dispose();
    _backgroundColorController.dispose();
    _textColorController.dispose();
    _accentColorController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isLogo}) async {
    try {
      final image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      setState(() {
        if (isLogo) {
          _logo = image;
          _logoBytes = bytes;
        } else {
          _banner = image;
          _bannerBytes = bytes;
        }
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de sélectionner cette image : $error'),
        ),
      );
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom de la boutique est requis.')),
      );
      return;
    }
    final phoneNumbers = _phoneController.text
        .split(RegExp(r'[\n,;]+'))
        .map((number) => number.trim())
        .where((number) => number.isNotEmpty)
        .toList(growable: false);
    final backgroundColor = _backgroundColorController.text.trim();
    final textColor = _textColorController.text.trim();
    final accentColor = _accentColorController.text.trim();
    final colorPattern = RegExp(r'^#[0-9A-Fa-f]{6}$');
    if (!colorPattern.hasMatch(backgroundColor) ||
        !colorPattern.hasMatch(textColor) ||
        !colorPattern.hasMatch(accentColor)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Utilisez un code couleur hexadécimal, par ex. #1A2B3C.',
          ),
        ),
      );
      return;
    }
    if (phoneNumbers.length > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous pouvez ajouter jusqu’à 5 numéros.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final data = <String, dynamic>{
      'name': name,
      'location': _locationController.text.trim(),
      'description': _descriptionController.text.trim(),
      'phone': phoneNumbers.isEmpty ? '' : phoneNumbers.first,
      'phone_numbers': phoneNumbers,
      'email': _emailController.text.trim(),
      'website': _websiteController.text.trim(),
      'background_color': backgroundColor,
      'text_color': textColor,
      'accent_color': accentColor,
      'font_size': _fontSize.round(),
    };
    final result = widget.shop == null
        ? await ApiService.createShop(data, logo: _logo, banner: _banner)
        : await ApiService.updateShop(
            widget.shop!.id,
            data,
            logo: _logo,
            banner: _banner,
          );

    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.shop == null
                ? 'Boutique créée avec succès.'
                : 'Boutique mise à jour avec succès.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Erreur : ${result['error'] ?? 'Impossible d’enregistrer la boutique.'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          shop == null ? 'Ajouter une boutique' : 'Personnaliser la boutique',
        ),
        backgroundColor: const Color(0xFF111827),
      ),
      backgroundColor: const Color(0xFF020617),
      body: shop == null
          ? FutureBuilder<Map<String, dynamic>>(
              future: _createProfileFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final profile = snapshot.data;
                final user = profile?['data'];
                if (profile?['success'] == true &&
                    user is User &&
                    user.role == 'boutique') {
                  return _buildShopForm(shop);
                }
                final canRetry =
                    profile?['success'] != true || snapshot.hasError;
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          canRetry ? Icons.error_outline : Icons.store_outlined,
                          color: Colors.white70,
                          size: 44,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          canRetry
                              ? 'Impossible de vérifier votre type de profil.'
                              : 'La création d’une boutique est réservée au '
                                    'type de profil Boutique.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (canRetry)
                          FilledButton.icon(
                            onPressed: () => setState(
                              () => _createProfileFuture =
                                  AuthService.getProfile(),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Réessayer'),
                          )
                        else
                          FilledButton.icon(
                            onPressed: () =>
                                Navigator.of(context).pushNamed('/profile'),
                            icon: const Icon(Icons.settings),
                            label: const Text('Ouvrir Mes paramètres'),
                          ),
                      ],
                    ),
                  ),
                );
              },
            )
          : _buildShopForm(shop),
    );
  }

  Widget _buildShopForm(Shop? shop) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              shop == null
                  ? 'Inscrivez une nouvelle boutique'
                  : 'Personnalisez la vitrine de ${shop.name}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            _imagePickerCard(
              title: 'Logo / photo de profil',
              onPressed: () => _pickImage(isLogo: true),
              bytes: _logoBytes,
              currentUrl: shop?.logo,
              isLogo: true,
            ),
            const SizedBox(height: 14),
            _imagePickerCard(
              title: 'Image d’en-tête',
              onPressed: () => _pickImage(isLogo: false),
              bytes: _bannerBytes,
              currentUrl: shop?.banner,
            ),
            const SizedBox(height: 20),
            _buildTextField('Nom de la boutique', _nameController),
            const SizedBox(height: 12),
            _buildTextField('Localisation', _locationController),
            const SizedBox(height: 12),
            _buildTextField('Description', _descriptionController, maxLines: 4),
            const SizedBox(height: 12),
            _buildTextField(
              'Numéros de téléphone (un par ligne)',
              _phoneController,
              maxLines: 3,
              hintText: '+221 77 000 00 00',
            ),
            const SizedBox(height: 12),
            _buildTextField('E-mail', _emailController),
            const SizedBox(height: 12),
            _buildTextField('Site web', _websiteController),
            const SizedBox(height: 20),
            _buildAppearanceEditor(),
            const SizedBox(height: 12),
            _buildAppearancePreview(shop),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              onPressed: _isSaving ? null : _submit,
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      shop == null
                          ? 'Enregistrer la boutique'
                          : 'Enregistrer les changements',
                      style: const TextStyle(fontSize: 16, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePickerCard({
    required String title,
    required VoidCallback onPressed,
    required Uint8List? bytes,
    required String? currentUrl,
    bool isLogo = false,
  }) {
    final imageUrl = normalizeMediaUrl(currentUrl);
    Widget preview;
    if (bytes != null) {
      preview = Image.memory(bytes, fit: BoxFit.cover);
    } else if (imageUrl != null) {
      preview = Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            const Icon(Icons.storefront, color: Colors.white70),
      );
    } else {
      preview = const Icon(Icons.add_photo_alternate, color: Colors.white70);
    }
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(isLogo ? 48 : 12),
          child: Container(
            width: isLogo ? 88 : 148,
            height: isLogo ? 88 : 82,
            color: const Color(0xFF111827),
            child: preview,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onPressed,
                icon: const Icon(Icons.upload),
                label: const Text('Choisir une image'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hintText,
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
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(color: Colors.white38),
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

  Widget _buildAppearanceEditor() => Card(
    color: const Color(0xFF111827),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Personnalisation de la vitrine',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField('Fond · code couleur', _backgroundColorController),
          _buildColorSwatches(_backgroundColorController),
          const SizedBox(height: 12),
          _buildTextField('Texte · code couleur', _textColorController),
          _buildColorSwatches(_textColorController),
          const SizedBox(height: 12),
          _buildTextField('Boutons · code couleur', _accentColorController),
          _buildColorSwatches(_accentColorController),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Taille du texte',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              Text(
                '${_fontSize.round()} px',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
          Slider(
            value: _fontSize,
            min: 12,
            max: 24,
            divisions: 6,
            label: '${_fontSize.round()} px',
            onChanged: (value) => setState(() => _fontSize = value),
          ),
        ],
      ),
    ),
  );

  Widget _buildAppearancePreview(Shop? shop) {
    final backgroundColor = _parseColor(
      _backgroundColorController.text,
      const Color(0xFF0F172A),
    );
    final textColor = _parseColor(
      _textColorController.text,
      const Color(0xFFF8FAFC),
    );
    final accentColor = _parseColor(
      _accentColorController.text,
      const Color(0xFF7C3AED),
    );
    final bannerUrl = normalizeMediaUrl(shop?.banner);
    final logoUrl = normalizeMediaUrl(shop?.logo);
    final name = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final location = _locationController.text.trim();

    return Card(
      color: const Color(0xFF111827),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aperçu direct de la vitrine',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                color: backgroundColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 110,
                      width: double.infinity,
                      child: _bannerBytes != null
                          ? Image.memory(_bannerBytes!, fit: BoxFit.cover)
                          : bannerUrl != null
                          ? Image.network(
                              bannerUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => ColoredBox(
                                color: backgroundColor,
                                child: Icon(
                                  Icons.storefront,
                                  color: textColor.withValues(alpha: 0.45),
                                  size: 42,
                                ),
                              ),
                            )
                          : ColoredBox(
                              color: backgroundColor,
                              child: Icon(
                                Icons.storefront,
                                color: textColor.withValues(alpha: 0.45),
                                size: 42,
                              ),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 58,
                              height: 58,
                              color: accentColor.withValues(alpha: 0.2),
                              child: _logoBytes != null
                                  ? Image.memory(_logoBytes!, fit: BoxFit.cover)
                                  : logoUrl != null
                                  ? Image.network(
                                      logoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Icon(
                                        Icons.storefront,
                                        color: accentColor,
                                      ),
                                    )
                                  : Icon(Icons.storefront, color: accentColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isEmpty ? 'Nom de votre boutique' : name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: _fontSize,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (location.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    location,
                                    style: TextStyle(
                                      color: textColor.withValues(alpha: 0.75),
                                      fontSize: (_fontSize - 3)
                                          .clamp(10, 21)
                                          .toDouble(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: Text(
                          description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.88),
                            fontSize: (_fontSize - 2).clamp(10, 22).toDouble(),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Contacter la boutique',
                            style: TextStyle(
                              color: _contrastColor(accentColor),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorSwatches(TextEditingController controller) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Wrap(
      spacing: 10,
      runSpacing: 8,
      children: _colorPresets.map((hex) {
        final selected = controller.text.toUpperCase() == hex;
        return Tooltip(
          message: hex,
          child: InkWell(
            onTap: () => controller.text = hex,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _parseColor(hex, Colors.transparent),
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : Colors.white38,
                  width: selected ? 3 : 1,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    ),
  );

  Color _parseColor(String value, Color fallback) {
    final normalized = value.trim().replaceFirst('#', '');
    if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) return fallback;
    return Color(int.parse('FF$normalized', radix: 16));
  }

  Color _contrastColor(Color color) =>
      color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
}
