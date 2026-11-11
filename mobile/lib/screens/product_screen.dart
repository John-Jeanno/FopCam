// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/widgets/chat_window_host.dart';
import 'package:mobile/services/cart_service.dart';
import 'package:mobile/services/share_link_service.dart';
import 'package:mobile/widgets/product_price_label.dart';
import 'package:mobile/utils/media_url_helper.dart';
import 'package:mobile/widgets/cart_badge.dart';
import 'package:mobile/widgets/product_image_gallery.dart';
import 'package:mobile/models/product.dart';
import 'package:mobile/models/shop.dart';

class ProductScreen extends StatefulWidget {
  final int productId;

  const ProductScreen({super.key, required this.productId});

  @override
  _ProductScreenState createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  late Future<Product?> _productFuture;
  Shop? _shop;
  String? _selectedColor;
  String? _selectedSize;

  @override
  void initState() {
    super.initState();
    _productFuture = ApiService.fetchProduct(widget.productId);
  }

  Future<void> _shareProduct(Product product) async {
    final text = [
      'Découvrez ${product.title} sur FopCam.',
      ShareLinkService.installHint,
      ShareLinkService.product(product.id).toString(),
    ].join('\n\n');
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: '${product.title} sur FopCam'),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de partager ce produit : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Produit'),
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Partager le produit',
            onPressed: () async {
              final product = await _productFuture;
              if (!mounted || product == null) return;
              await _shareProduct(product);
            },
            icon: const Icon(Icons.share_outlined),
          ),
          CartBadge(
            onPressed: () {
              Navigator.of(context).pushNamed('/cart');
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: FutureBuilder<Product?>(
          future: _productFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.12),
                    ),
                  ),
                  child: const Text(
                    'Produit non trouvé',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              );
            }

            final product = snapshot.data!;

            // Fetch shop info on first load
            if (_shop == null) {
              ApiService.fetchShop(product.shopId).then((shop) {
                if (mounted) {
                  setState(() {
                    _shop = shop;
                  });
                }
              });
            }

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () async {
                          if (_shop?.owner?.id == null) return;
                          final res = await ApiService.startConversation(
                            _shop!.owner!.id,
                          );
                          if (!context.mounted) return;
                          final roomId = res?['room_id']?.toString().trim();
                          if (roomId != null && roomId.isNotEmpty) {
                            final owner = _shop?.owner;
                            await ChatWindowHost.openChat(
                              context,
                              roomId: roomId,
                              title: owner == null
                                  ? null
                                  : ChatWindowHost.titleForUser(
                                      username: owner.username,
                                      firstName: owner.firstName,
                                      lastName: owner.lastName,
                                    ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Impossible de démarrer la conversation',
                                ),
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Contacter le vendeur'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.12),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(24),
                            ),
                            child: ProductImageGallery(
                              images: product.galleryImages,
                              height: 280,
                              fit: BoxFit.contain,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.title,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: ProductPriceLabel(
                                        product: product,
                                        color: const Color(0xFF93C5FD),
                                        fontSize: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF991B1B),
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Text(
                                        product.category?.translatedName ??
                                            product.category?.name ??
                                            'Sans catégorie',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                const Text(
                                  'Description',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  product.description,
                                  style: const TextStyle(
                                    color: Color(0xFFCBD5E1),
                                    height: 1.6,
                                  ),
                                ),
                                if (product.colorOptions.isNotEmpty ||
                                    product.sizeOptions.isNotEmpty) ...[
                                  const SizedBox(height: 20),
                                  const Text(
                                    'Choisissez vos options',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  if (product.colorOptions.isNotEmpty) ...[
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedColor,
                                      decoration: const InputDecoration(
                                        labelText: 'Couleur disponible',
                                        filled: true,
                                      ),
                                      items: product.colorOptions
                                          .map(
                                            (option) => DropdownMenuItem(
                                              value: option,
                                              child: Text(option),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) => setState(
                                        () => _selectedColor = value,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  if (product.sizeOptions.isNotEmpty)
                                    DropdownButtonFormField<String>(
                                      initialValue: _selectedSize,
                                      decoration: const InputDecoration(
                                        labelText: 'Taille disponible',
                                        filled: true,
                                      ),
                                      items: product.sizeOptions
                                          .map(
                                            (option) => DropdownMenuItem(
                                              value: option,
                                              child: Text(option),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) =>
                                          setState(() => _selectedSize = value),
                                    ),
                                ],
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF991B1B),
                                          Color(0xFF7F1D1D),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(18),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color.fromRGBO(
                                            153,
                                            27,
                                            27,
                                            0.35,
                                          ),
                                          blurRadius: 18,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () async {
                                        if ((product.colorOptions.isNotEmpty &&
                                                _selectedColor == null) ||
                                            (product.sizeOptions.isNotEmpty &&
                                                _selectedSize == null)) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Choisissez la couleur et la taille avant de continuer.',
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                        await CartService.addItem(
                                          product,
                                          selectedColor: _selectedColor,
                                          selectedSize: _selectedSize,
                                        );
                                        if (!context.mounted) return;
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Produit ajouté au panier',
                                            ),
                                          ),
                                        );
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'Ajouter au panier',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Seller info section
                    if (_shop != null && _shop!.owner != null)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(255, 255, 255, 0.08),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color.fromRGBO(255, 255, 255, 0.12),
                          ),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vendeur',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 40,
                                  backgroundColor: const Color(0xFF1F2937),
                                  backgroundImage: NetworkImage(
                                    normalizeMediaUrl(
                                          _shop!.owner!.profileImage ?? '',
                                        ) ??
                                        '',
                                  ),
                                  onBackgroundImageError: (_, _) {},
                                  child:
                                      normalizeMediaUrl(
                                            _shop!.owner!.profileImage ?? '',
                                          ) ==
                                          null
                                      ? const Icon(
                                          Icons.person,
                                          color: Colors.white70,
                                          size: 32,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _shop!.owner!.username,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _shop!.name,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
