import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mobile/constants/api_endpoints.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/cart_service.dart';
import 'package:mobile/services/share_link_service.dart';
import 'package:mobile/widgets/product_price_label.dart';
import 'package:mobile/widgets/cart_badge.dart';
import 'package:mobile/widgets/product_image_gallery.dart';
import 'package:mobile/models/product.dart';
import 'package:mobile/models/shop.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopScreen extends StatefulWidget {
  final int shopId;

  const ShopScreen({super.key, required this.shopId});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  late Future<Shop?> _shopFuture;
  late Future<List<Product>> _shopProductsFuture;
  bool _isUpdatingInteraction = false;

  @override
  void initState() {
    super.initState();
    _shopFuture = ApiService.fetchShop(widget.shopId);
    _shopProductsFuture = ApiService.fetchProducts(
      shopId: widget.shopId,
      pageSize: 50,
    );
  }

  Future<void> _toggleShopInteraction(String interaction) async {
    if (_isUpdatingInteraction) return;
    setState(() => _isUpdatingInteraction = true);
    final result = await ApiService.toggleShopInteraction(
      widget.shopId,
      interaction,
    );
    if (!mounted) return;
    setState(() {
      _isUpdatingInteraction = false;
      if (result['success'] == true) {
        _shopFuture = ApiService.fetchShop(widget.shopId);
      }
    });

    if (result['success'] == true) return;
    final message = result['statusCode'] == 401
        ? 'Connectez-vous pour interagir avec une boutique.'
        : 'Impossible d’enregistrer votre action. Réessayez.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareShop(Shop shop) async {
    final isLoggedIn = await AuthService.isLoggedIn();
    final details = <String>[
      'Découvrez la boutique ${shop.name} sur FopCam.',
      if (shop.description?.isNotEmpty == true) shop.description!,
      ShareLinkService.installHint,
      ShareLinkService.shop(shop.id).toString(),
    ];
    try {
      final result = await SharePlus.instance.share(
        ShareParams(
          text: details.join('\n\n'),
          subject: 'Boutique ${shop.name} sur FopCam',
        ),
      );
      if (result.status != ShareResultStatus.success || !mounted) return;

      if (!isLoggedIn) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lien de la boutique partagé.')),
        );
        return;
      }

      final recorded = await ApiService.recordShopShare(shop.id);
      if (!mounted) return;
      if (recorded['success'] == true) {
        setState(() => _shopFuture = ApiService.fetchShop(widget.shopId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boutique partagée avec succès.')),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de partager cette boutique : $error'),
        ),
      );
    }
  }

  Future<void> _callPhone(String phone) async {
    final normalizedPhone = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (normalizedPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce numéro de téléphone est invalide.')),
      );
      return;
    }
    try {
      final launched = await launchUrl(
        Uri(scheme: 'tel', path: normalizedPhone),
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de lancer l’appel.')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de lancer l’appel : $error')),
      );
    }
  }

  Future<void> _rateShop(int rating) async {
    if (_isUpdatingInteraction) return;
    if (!await AuthService.isLoggedIn()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour noter cette boutique.'),
        ),
      );
      return;
    }

    setState(() => _isUpdatingInteraction = true);
    final result = await ApiService.rateShop(widget.shopId, rating);
    if (!mounted) return;
    setState(() {
      _isUpdatingInteraction = false;
      if (result['success'] == true) {
        _shopFuture = ApiService.fetchShop(widget.shopId);
      }
    });

    if (result['success'] == true) return;
    final message = result['statusCode'] == 401
        ? 'Connectez-vous pour noter cette boutique.'
        : 'Impossible d’enregistrer votre note. Réessayez.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Boutique'),
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        actions: [
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
        child: SafeArea(
          child: FutureBuilder<Shop?>(
            future: _shopFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return const Center(
                  child: Text(
                    'Boutique introuvable.',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                );
              }

              final shop = snapshot.data!;
              final backgroundColor = _shopColor(
                shop.backgroundColor,
                const Color(0xFF0F172A),
              );
              final textColor = _shopColor(
                shop.textColor,
                const Color(0xFFF8FAFC),
              );
              final accentColor = _shopColor(
                shop.accentColor,
                const Color(0xFF7C3AED),
              );
              final fontSize = shop.fontSize.clamp(12, 24).toDouble();
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (shop.banner != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.network(
                                _resolveMediaUrl(shop.banner!),
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      height: 180,
                                      color: const Color(0xFF111827),
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey,
                                          size: 48,
                                        ),
                                      ),
                                    ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: const Color(0xFF1E293B),
                                backgroundImage: shop.logo == null
                                    ? null
                                    : NetworkImage(
                                        _resolveMediaUrl(shop.logo!),
                                      ),
                                child: shop.logo == null
                                    ? const Icon(
                                        Icons.storefront,
                                        color: Colors.white70,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  shop.name,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: fontSize + 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            shop.description ??
                                'Pas de description pour cette boutique.',
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.78),
                              fontSize: fontSize,
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isUpdatingInteraction
                                    ? null
                                    : () => _toggleShopInteraction('like'),
                                icon: Icon(
                                  shop.isLiked
                                      ? Icons.thumb_up
                                      : Icons.thumb_up_outlined,
                                ),
                                label: Text('J’aime · ${shop.likeCount}'),
                              ),
                              OutlinedButton.icon(
                                onPressed: _isUpdatingInteraction
                                    ? null
                                    : () => _toggleShopInteraction('vote'),
                                icon: Icon(
                                  shop.isVoted
                                      ? Icons.verified
                                      : Icons.verified_outlined,
                                ),
                                label: Text('Recommander · ${shop.voteCount}'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _shareShop(shop),
                                icon: const Icon(Icons.share_outlined),
                                label: Text('Partager · ${shop.shareCount}'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            shop.ratingCount == 0
                                ? 'Aucune note pour le moment'
                                : '${shop.averageRating.toStringAsFixed(1)} / 5 · ${shop.ratingCount} avis',
                            style: TextStyle(
                              color: textColor.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Row(
                            children: List.generate(5, (index) {
                              final rating = index + 1;
                              return IconButton(
                                tooltip: 'Donner $rating sur 5',
                                onPressed: _isUpdatingInteraction
                                    ? null
                                    : () => _rateShop(rating),
                                icon: Icon(
                                  rating <= (shop.userRating ?? 0)
                                      ? Icons.star
                                      : Icons.star_border,
                                  color: const Color(0xFFFBBF24),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 20),
                          if (shop.owner != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.person,
                                  color: Color(0xFF94A3B8),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Propriétaire: ${shop.owner!.username}',
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.75),
                                    fontSize: fontSize - 2,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),
                          if (shop.location != null)
                            _buildInfoRow(
                              Icons.location_on,
                              shop.location!,
                              textColor,
                              fontSize,
                            ),
                          if (shop.phoneNumbers.isNotEmpty)
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: shop.phoneNumbers.map((phone) {
                                return OutlinedButton.icon(
                                  onPressed: () => _callPhone(phone),
                                  icon: const Icon(Icons.call),
                                  label: Text(phone),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: textColor,
                                    side: BorderSide(color: accentColor),
                                  ),
                                );
                              }).toList(),
                            ),
                          if (shop.email != null)
                            _buildInfoRow(
                              Icons.email,
                              shop.email!,
                              textColor,
                              fontSize,
                            ),
                          if (shop.website != null)
                            _buildInfoRow(
                              Icons.link,
                              shop.website!,
                              textColor,
                              fontSize,
                            ),
                          const SizedBox(height: 24),
                          Text(
                            'Produits de la boutique',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          FutureBuilder<List<Product>>(
                            future: _shopProductsFuture,
                            builder: (context, productSnapshot) {
                              if (productSnapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              if (!productSnapshot.hasData ||
                                  productSnapshot.data!.isEmpty) {
                                return Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111827),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: const Text(
                                    'Aucun produit disponible pour cette boutique.',
                                    style: TextStyle(
                                      color: Color(0xFFCBD5E1),
                                      fontSize: 15,
                                    ),
                                  ),
                                );
                              }

                              final grouped = <String, List<Product>>{};
                              for (final product in productSnapshot.data!) {
                                final category =
                                    product.category?.translatedName ??
                                    product.category?.name ??
                                    'Autres';
                                grouped
                                    .putIfAbsent(category, () => [])
                                    .add(product);
                              }
                              final categories = grouped.keys.toList()..sort();
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: categories.map((category) {
                                  final products = grouped[category]!;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          category,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: fontSize + 1,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            const columns = 2;
                                            const spacing = 12.0;
                                            final width =
                                                (constraints.maxWidth -
                                                    spacing * (columns - 1)) /
                                                columns;
                                            return Wrap(
                                              spacing: spacing,
                                              runSpacing: spacing,
                                              children: products
                                                  .map(
                                                    (product) => SizedBox(
                                                      width: width,
                                                      child:
                                                          _buildShopProductCard(
                                                            product,
                                                            shop,
                                                          ),
                                                    ),
                                                  )
                                                  .toList(),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String _resolveMediaUrl(String value) {
    if (value.startsWith('http')) {
      return value;
    }
    return '${ApiEndpoints.baseUrl}$value';
  }

  Widget _buildShopProductCard(Product product, Shop shop) {
    final textColor = _shopColor(shop.textColor, const Color(0xFFF8FAFC));
    final accentColor = _shopColor(shop.accentColor, const Color(0xFF7C3AED));
    final fontSize = shop.fontSize.clamp(12, 24).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ProductImageGallery(
              images: product.galleryImages,
              aspectRatio: 1.12,
              backgroundColor: textColor.withValues(alpha: 0.08),
              enableFullscreenViewer: true,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  product.title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: fontSize.clamp(12, 16),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () async {
                  if (product.colorOptions.isNotEmpty ||
                      product.sizeOptions.isNotEmpty) {
                    Navigator.of(
                      context,
                    ).pushNamed('/product', arguments: product.id);
                    return;
                  }
                  await CartService.addItem(product);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Produit ajouté au panier')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Ajouter',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProductPriceLabel(
            product: product,
            color: accentColor,
            fontSize: fontSize - 1,
          ),
          const SizedBox(height: 6),
          Text(
            product.description,
            style: TextStyle(
              color: textColor.withValues(alpha: 0.75),
              fontSize: fontSize - 2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text,
    Color textColor,
    double fontSize,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: textColor.withValues(alpha: 0.7), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: textColor.withValues(alpha: 0.75),
                fontSize: fontSize - 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _shopColor(String value, Color fallback) {
    final normalized = value.replaceFirst('#', '');
    if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) return fallback;
    return Color(int.parse('FF$normalized', radix: 16));
  }
}
