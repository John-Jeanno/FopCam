import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/models/product.dart';
import 'package:mobile/models/shop.dart';
import 'package:mobile/services/api_service.dart';

class CreateProductScreen extends StatefulWidget {
  const CreateProductScreen({super.key});

  @override
  State<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends State<CreateProductScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _purchasePriceController =
      TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _promoPriceController = TextEditingController();
  final TextEditingController _colorOptionsController = TextEditingController();
  final TextEditingController _sizeOptionsController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(
    text: '1',
  );
  final TextEditingController _categoryController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = true;
  bool _isSubmitting = false;
  Shop? _myShop;
  List<Category> _categories = [];
  Category? _selectedCategory;
  List<XFile> _selectedImages = [];
  List<Uint8List> _selectedImageBytes = [];
  bool _isEditing = false;
  bool _isPromotionEnabled = false;
  Product? _editingProduct;
  bool _didInitFromArgs = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitFromArgs) {
      final route = ModalRoute.of(context);
      final args = route?.settings.arguments as Map<String, dynamic>?;
      if (args != null &&
          args['product'] != null &&
          args['product'] is Product) {
        _isEditing = true;
        _editingProduct = args['product'] as Product;
        final p = _editingProduct!;
        _titleController.text = p.title;
        _descriptionController.text = p.description;
        _purchasePriceController.text = p.purchasePrice?.toString() ?? '';
        _priceController.text = p.price.toString();
        _isPromotionEnabled = p.isOnPromotion;
        _promoPriceController.text = p.promoPrice?.toString() ?? '';
        _colorOptionsController.text = p.colorOptions.join(', ');
        _sizeOptionsController.text = p.sizeOptions.join(', ');
        _quantityController.text = p.quantity.toString();
        // category mapping will attempt to match after categories load
      }
      _didInitFromArgs = true;
    }
  }

  Future<void> _loadData() async {
    final myShop = await ApiService.fetchMyShop();
    final categories = await ApiService.fetchCategories(
      categoryType: 'product',
      useMockData: false,
    );
    // If editing, try to preselect category
    if (_editingProduct != null && categories.isNotEmpty) {
      final prodCatName = _editingProduct!.category?.name;
      if (prodCatName != null) {
        for (final category in categories) {
          if (category.name == prodCatName &&
              category.categoryType == 'product') {
            _selectedCategory = category;
            break;
          }
        }
      }
    }

    setState(() {
      _myShop = myShop;
      _categories = categories;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _purchasePriceController.dispose();
    _priceController.dispose();
    _promoPriceController.dispose();
    _colorOptionsController.dispose();
    _sizeOptionsController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final images = await _picker.pickMultiImage();
      if (images.isNotEmpty) {
        final imageBytes = await Future.wait(
          images.map((image) => image.readAsBytes()),
        );
        setState(() {
          _selectedImages = images;
          _selectedImageBytes = imageBytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de sélectionner les images.'),
          ),
        );
      }
    }
  }

  List<String> _parseOptions(String input) {
    return input
        .split(RegExp(r'[,;\n]'))
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toSet()
        .toList();
  }

  Future<void> _submit() async {
    if (_myShop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vous devez créer une boutique avant de publier un produit.',
          ),
        ),
      );
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final purchaseText = _purchasePriceController.text.trim();
    final purchasePrice = purchaseText.isEmpty
        ? null
        : double.tryParse(purchaseText.replaceAll(',', '.'));
    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText.replaceAll(',', '.'));
    final promoText = _promoPriceController.text.trim();
    final promoPrice = _isPromotionEnabled
        ? double.tryParse(promoText.replaceAll(',', '.'))
        : null;
    final quantity = int.tryParse(_quantityController.text.trim());
    final categoryName = _categoryController.text.trim();
    final colorOptions = _parseOptions(_colorOptionsController.text);
    final sizeOptions = _parseOptions(_sizeOptionsController.text);

    if (title.isEmpty ||
        price == null ||
        price <= 0 ||
        (purchaseText.isNotEmpty &&
            (purchasePrice == null || purchasePrice < 0)) ||
        (_isPromotionEnabled &&
            (promoPrice == null || promoPrice <= 0 || promoPrice >= price)) ||
        quantity == null ||
        quantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Saisissez un titre, un prix de vente et une quantité valides. Le coût d’achat doit être positif s’il est renseigné, et le prix promotionnel doit être inférieur au prix de vente.',
          ),
        ),
      );
      return;
    }

    final canKeepExistingCategory =
        _isEditing && _editingProduct?.category != null;
    if (_selectedCategory == null &&
        categoryName.isEmpty &&
        !canKeepExistingCategory) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner ou saisir une catégorie.'),
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final requestBody = {
      'title': title,
      'description': description,
      'purchase_price': purchasePrice,
      'price': priceText,
      'promo_price': promoPrice,
      'color_options': colorOptions,
      'size_options': sizeOptions,
      'quantity': quantity,
      'shop_id': _myShop!.id,
      if (_selectedCategory != null) 'category_id': _selectedCategory!.id,
      if (_selectedCategory == null) 'category_name': categoryName,
    };

    Map<String, dynamic> responseResult;
    if (_isEditing && _editingProduct != null) {
      responseResult = await ApiService.updateProduct(
        _editingProduct!.id,
        requestBody,
        images: _selectedImages.isNotEmpty ? _selectedImages : null,
      );
    } else {
      responseResult = await ApiService.createProduct(
        requestBody,
        images: _selectedImages.isNotEmpty ? _selectedImages : null,
      );
    }

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (responseResult['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditing
                ? 'Produit mis à jour avec succès.'
                : 'Produit publié avec succès.',
          ),
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    final error = responseResult['error'];
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur : ${error ?? (_isEditing ? 'Impossible de mettre à jour le produit.' : 'Impossible de publier le produit.')}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Modifier le produit' : 'Ajouter un produit'),
        backgroundColor: const Color(0xFF111827),
      ),
      backgroundColor: const Color(0xFF020617),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isEditing
                        ? 'Modifiez votre produit'
                        : 'Publiez un produit local',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_myShop == null) ...[
                    const Text(
                      'Vous n’avez pas encore de boutique active. Créez-en une pour pouvoir publier un produit.',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (_myShop != null) ...[
                    _buildInfoCard('Boutique sélectionnée', _myShop!.name),
                    const SizedBox(height: 16),
                  ],
                  _buildTextField('Titre du produit', _titleController),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Description',
                    _descriptionController,
                    maxLines: 4,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Coût d’achat unitaire (FCFA, facultatif et privé)',
                    _purchasePriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Prix de vente au client (FCFA)',
                    _priceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                    value: _isPromotionEnabled,
                    onChanged: (enabled) {
                      setState(() {
                        _isPromotionEnabled = enabled;
                        if (!enabled) _promoPriceController.clear();
                      });
                    },
                    activeThumbColor: const Color(0xFF22C55E),
                    title: const Text(
                      'Mettre ce produit en promotion',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Le prix réduit sera affiché aux acheteurs.',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                  ),
                  if (_isPromotionEnabled) ...[
                    const SizedBox(height: 8),
                    _buildTextField(
                      'Prix promotionnel pour le client (FCFA)',
                      _promoPriceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ce prix doit être inférieur au prix de vente normal.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Quantité en stock',
                    _quantityController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Couleurs disponibles (ex. Rouge, Gris, Noir)',
                    _colorOptionsController,
                    helperText: 'Séparez les couleurs par des virgules.',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Tailles disponibles (ex. L, XL, XXL)',
                    _sizeOptionsController,
                    helperText: 'Séparez les tailles par des virgules.',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: _pickImages,
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Ajouter des images'),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedImages.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              _selectedImageBytes[index],
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<Category>(
                    initialValue: _selectedCategory,
                    items: _categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(
                              category.translatedName ?? category.name,
                            ),
                          ),
                        )
                        .toList(),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF111827),
                      hintText: 'Sélectionnez une catégorie',
                      hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) =>
                        setState(() => _selectedCategory = value),
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    'Ou saisissez une nouvelle catégorie',
                    _categoryController,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Center(
                            child: Text(
                              _isEditing
                                  ? 'Mettre à jour le produit'
                                  : 'Publier le produit',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? helperText,
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
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF111827),
            helperText: helperText,
            helperStyle: const TextStyle(color: Color(0xFF94A3B8)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
