import 'package:flutter/material.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/constants/ui_helpers.dart';
import 'package:mobile/models/product.dart';
import 'package:mobile/models/shop.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/utils/media_url_helper.dart';
import 'package:mobile/widgets/product_price_label.dart';
import 'package:mobile/widgets/cart_badge.dart';

String explorerScopeForCategory(Category category) =>
    category.categoryType == 'professional' ? 'services' : 'products';

List<Category> sortExplorerCategories(Iterable<Category> categories) {
  final sorted = categories.toList();
  sorted.sort((left, right) {
    final leftName = _categorySortKey(left.translatedName ?? left.name);
    final rightName = _categorySortKey(right.translatedName ?? right.name);
    final comparison = leftName.compareTo(rightName);
    if (comparison != 0) return comparison;
    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  });
  return sorted;
}

String _categorySortKey(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[àáâãäå]'), 'a')
    .replaceAll(RegExp('[ç]'), 'c')
    .replaceAll(RegExp('[èéêë]'), 'e')
    .replaceAll(RegExp('[ìíîï]'), 'i')
    .replaceAll(RegExp('[ñ]'), 'n')
    .replaceAll(RegExp('[òóôõö]'), 'o')
    .replaceAll(RegExp('[ùúûü]'), 'u')
    .replaceAll(RegExp('[ýÿ]'), 'y')
    .replaceAll('œ', 'oe')
    .replaceAll('æ', 'ae');

class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key, this.initialCategoryId, this.loadData});

  final int? initialCategoryId;
  final Future<ExplorerData> Function()? loadData;

  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen> {
  late Future<ExplorerData> _explorerDataFuture;
  final TextEditingController _searchController = TextEditingController();
  String _selectedScope = 'all';
  int? _selectedCategoryId;
  Future<ExplorerSearchResults>? _filterResultsFuture;

  @override
  void initState() {
    super.initState();
    _explorerDataFuture = _loadExplorerData();
    _selectedCategoryId = widget.initialCategoryId;
    if (_selectedCategoryId != null) {
      _filterResultsFuture = _fetchSearchResults(
        query: '',
        scope: _selectedScope,
        categoryId: _selectedCategoryId,
      );
    }
  }

  Future<ExplorerData> _fetchExplorerData() async {
    final results = await Future.wait([
      ApiService.fetchCategories(),
      ApiService.fetchShops(),
    ]);
    return ExplorerData(
      categories: results[0] as List<Category>,
      shops: results[1] as List<Shop>,
    );
  }

  Future<ExplorerData> _loadExplorerData() =>
      widget.loadData?.call() ?? _fetchExplorerData();

  void _openShop(Shop shop) {
    Navigator.of(context).pushNamed('/shop', arguments: {'shopId': shop.id});
  }

  void _openCategoryProducts(Category category) {
    setState(() {
      _selectedCategoryId = category.id;
      _selectedScope = explorerScopeForCategory(category);
    });
    _applyFilters();
  }

  void _retryExplorerData() {
    setState(() => _explorerDataFuture = _loadExplorerData());
  }

  void _applyFilters({int pageSize = 30}) {
    final query = _searchController.text.trim();
    setState(() {
      _filterResultsFuture = _fetchSearchResults(
        query: query,
        scope: _selectedScope,
        categoryId: _selectedCategoryId,
        pageSize: pageSize,
      );
    });
  }

  Future<ExplorerSearchResults> _fetchSearchResults({
    required String query,
    required String scope,
    int? categoryId,
    int pageSize = 30,
  }) async {
    final includeProducts = scope != 'shops';
    final includeShops = scope == 'all' || scope == 'shops';
    final categoryType = switch (scope) {
      'products' => 'product',
      'services' => 'professional',
      _ => null,
    };
    final results = await Future.wait([
      includeProducts
          ? ApiService.fetchProducts(
              pageSize: pageSize,
              search: query.isEmpty ? null : query,
              categoryId: categoryId,
              categoryType: categoryType,
            )
          : Future.value(<Product>[]),
      includeShops
          ? ApiService.fetchShops(search: query.isEmpty ? null : query)
          : Future.value(<Shop>[]),
    ]);
    return ExplorerSearchResults(
      products: results[0] as List<Product>,
      shops: results[1] as List<Shop>,
    );
  }

  void _selectScope(String scope) {
    setState(() {
      _selectedScope = scope;
      _selectedCategoryId = null;
    });
    _applyFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Découvrir'),
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
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() => _explorerDataFuture = _loadExplorerData());
              if (_filterResultsFuture != null) _applyFilters();
              await _explorerDataFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle(
                  'Explorer tous les modules',
                  'Accédez aux commerces, contenus et activités de FopCam.',
                ),
                const SizedBox(height: 14),
                _buildQuickActions(),
                const SizedBox(height: 18),
                _buildSectionTitle(
                  'Recherche & filtres',
                  'Trouvez des produits, services ou boutiques.',
                ),
                const SizedBox(height: 12),
                _buildFilterRow(),
                const SizedBox(height: 12),
                FutureBuilder<ExplorerData>(
                  future: _explorerDataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return _buildErrorState(onRetry: _retryExplorerData);
                    }
                    final data = snapshot.data;
                    if (data == null) {
                      return _buildPlaceholderCard(
                        'Aucun contenu disponible',
                        'Réessayez pour charger les catégories et boutiques.',
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectionTitle(
                          'Parcourir par catégorie',
                          'Choisissez une catégorie pour filtrer les offres.',
                        ),
                        const SizedBox(height: 12),
                        _buildCategoryDropdown(data.categories),
                        const SizedBox(height: 18),
                        if (_filterResultsFuture == null) ...[
                          _buildSectionTitle(
                            'Boutiques populaires',
                            'Touchez une boutique pour consulter ses offres.',
                          ),
                          const SizedBox(height: 12),
                          _buildShopList(data.shops),
                        ],
                      ],
                    );
                  },
                ),
                if (_filterResultsFuture != null) ...[
                  const SizedBox(height: 18),
                  FutureBuilder<ExplorerSearchResults>(
                    future: _filterResultsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return _buildPlaceholderCard(
                          'Recherche indisponible',
                          'Vérifiez votre connexion puis réessayez.',
                        );
                      }
                      if (!snapshot.hasData) {
                        return _buildPlaceholderCard(
                          'Aucun résultat',
                          'Ajustez les filtres pour trouver du contenu.',
                        );
                      }
                      return _buildSearchResults(snapshot.data!);
                    },
                  ),
                ],
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState({required VoidCallback onRetry}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: buildPanelDecoration(),
      child: Column(
        children: [
          const Text(
            'Impossible de charger les catégories et boutiques. Les autres modules restent accessibles.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      _ExplorerAction(
        icon: Icons.shopping_bag,
        title: 'Produits',
        subtitle: 'Parcourir les offres',
        onTap: () => _selectScope('products'),
      ),
      _ExplorerAction(
        icon: Icons.handshake,
        title: 'Services',
        subtitle: 'Trouver des prestataires',
        onTap: () => _selectScope('services'),
      ),
      _ExplorerAction(
        icon: Icons.storefront,
        title: 'Boutiques',
        subtitle: 'Découvrir les commerces',
        onTap: () => _selectScope('shops'),
      ),
      _ExplorerAction(
        icon: Icons.auto_awesome,
        title: 'Statuts',
        subtitle: 'Voir les partages récents',
        onTap: () => Navigator.of(context).pushNamed('/stories'),
      ),
      _ExplorerAction(
        icon: Icons.video_library,
        title: 'Clips',
        subtitle: 'Explorer les vidéos courtes',
        onTap: () => Navigator.of(context).pushNamed('/reels'),
      ),
      _ExplorerAction(
        icon: Icons.wifi_tethering,
        title: 'Directs',
        subtitle: 'Rejoindre une diffusion',
        onTap: () => Navigator.of(context).pushNamed('/live'),
      ),
      _ExplorerAction(
        icon: Icons.map_outlined,
        title: 'Carte sociale',
        subtitle: 'Découvrir les environs',
        onTap: () => Navigator.of(context).pushNamed('/map'),
      ),
      _ExplorerAction(
        icon: Icons.handshake_outlined,
        title: 'Collaborations',
        subtitle: 'Voir les projets communautaires',
        onTap: () => Navigator.of(context).pushNamed('/collaboration'),
      ),
      _ExplorerAction(
        icon: Icons.groups_outlined,
        title: 'Communautés',
        subtitle: 'Rejoindre ou créer un groupe',
        onTap: () => Navigator.of(context).pushNamed('/groups'),
      ),
      _ExplorerAction(
        icon: Icons.event_available_outlined,
        title: 'Événements',
        subtitle: 'Consulter, rejoindre ou publier des événements',
        onTap: () => Navigator.of(context).pushNamed('/create_event'),
      ),
      _ExplorerAction(
        icon: Icons.auto_fix_high,
        title: 'Effets AR',
        subtitle: 'Créer une publication avec effets',
        onTap: () => Navigator.of(context).pushNamed('/ar_effects'),
      ),
      _ExplorerAction(
        icon: Icons.manage_search,
        title: 'Recherche avancée',
        subtitle: 'Affiner la recherche de produits',
        onTap: () => Navigator.of(context).pushNamed('/advanced_search'),
      ),
      _ExplorerAction(
        icon: Icons.sports_esports,
        title: 'Jeu FopCam',
        subtitle: 'Lancer une partie',
        onTap: () => Navigator.of(context).pushNamed('/game'),
      ),
      _ExplorerAction(
        icon: Icons.emoji_events_outlined,
        title: 'Légendes',
        subtitle: 'Voir les joueurs légendaires',
        onTap: () => Navigator.of(context).pushNamed('/game/legends'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 620
            ? 2
            : 1;
        final cardWidth = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: actions.map((action) {
            return SizedBox(
              width: cardWidth,
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(24),
                child: InkWell(
                  onTap: action.onTap,
                  borderRadius: BorderRadius.circular(24),
                  child: Ink(
                    padding: const EdgeInsets.all(16),
                    decoration: buildPanelDecoration(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(10),
                          child: Icon(
                            action.icon,
                            color: AppColors.primaryLight,
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          action.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          action.subtitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildFilterRow() {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final searchField = TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Rechercher produits, boutiques...',
                hintStyle: const TextStyle(color: Colors.white),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _applyFilters(),
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _applyFilters,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text('Appliquer'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/advanced_search');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                  ),
                  icon: const Icon(Icons.tune, size: 18),
                  label: const Text('Avancé'),
                ),
              ],
            );
            return constraints.maxWidth < 620
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [searchField, const SizedBox(height: 8), actions],
                  )
                : Row(
                    children: [
                      Expanded(child: searchField),
                      const SizedBox(width: 10),
                      actions,
                    ],
                  );
          },
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Tous'),
              selected: _selectedScope == 'all',
              onSelected: (_) => _selectScope('all'),
              selectedColor: AppColors.surfaceAlt,
              backgroundColor: AppColors.surface,
              labelStyle: const TextStyle(color: Colors.white),
            ),
            ChoiceChip(
              label: const Text('Produits'),
              selected: _selectedScope == 'products',
              onSelected: (_) => _selectScope('products'),
              selectedColor: AppColors.surfaceAlt,
              backgroundColor: AppColors.surface,
              labelStyle: const TextStyle(color: Colors.white),
            ),
            ChoiceChip(
              label: const Text('Services'),
              selected: _selectedScope == 'services',
              onSelected: (_) => _selectScope('services'),
              selectedColor: AppColors.surfaceAlt,
              backgroundColor: AppColors.surface,
              labelStyle: const TextStyle(color: Colors.white),
            ),
            ChoiceChip(
              label: const Text('Boutiques'),
              selected: _selectedScope == 'shops',
              onSelected: (_) => _selectScope('shops'),
              selectedColor: AppColors.surfaceAlt,
              backgroundColor: AppColors.surface,
              labelStyle: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchResults(ExplorerSearchResults results) {
    if (results.products.isEmpty && results.shops.isEmpty) {
      return _buildPlaceholderCard(
        'Aucun résultat',
        'Ajustez la recherche ou choisissez une autre catégorie.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (results.products.isNotEmpty) ...[
          _buildSectionTitle(
            'Offres (${results.products.length})',
            'Touchez une offre pour ouvrir sa boutique.',
          ),
          const SizedBox(height: 10),
          ...results.products.map(_buildProductResultCard),
        ],
        if (results.shops.isNotEmpty) ...[
          _buildSectionTitle(
            'Boutiques (${results.shops.length})',
            'Faites défiler les enseignes et ouvrez leur vitrine.',
          ),
          const SizedBox(height: 10),
          _buildShopList(results.shops),
        ],
      ],
    );
  }

  Widget _buildProductResultCard(Product product) {
    return GestureDetector(
      onTap: () =>
          Navigator.of(context).pushNamed('/product', arguments: product.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: buildGhostPanelDecoration(),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(10),
              ),
              child: normalizeMediaUrl(product.image) != null
                  ? Image.network(
                      normalizeMediaUrl(product.image)!,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, st) => const Icon(
                        Icons.image_not_supported,
                        color: Colors.grey,
                      ),
                    )
                  : const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ProductPriceLabel(
                    product: product,
                    color: AppColors.primaryLight,
                    fontSize: 13,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    product.category?.translatedName ??
                        product.category?.name ??
                        '',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryDropdown(List<Category> categories) {
    if (categories.isEmpty) {
      return _buildPlaceholderCard(
        'Aucune catégorie trouvée',
        'Les catégories seront disponibles dès que le backend fournira des données.',
      );
    }

    final sortedCategories = sortExplorerCategories(categories);
    final selectedCategoryId =
        sortedCategories.any((category) => category.id == _selectedCategoryId)
        ? _selectedCategoryId
        : null;

    return DropdownButtonFormField<int?>(
      initialValue: selectedCategoryId,
      isExpanded: true,
      dropdownColor: AppColors.surface,
      style: const TextStyle(color: Colors.white),
      iconEnabledColor: Colors.white,
      decoration: InputDecoration(
        labelText: 'Catégorie',
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      items: [
        const DropdownMenuItem<int?>(
          value: null,
          child: Text('Toutes les catégories'),
        ),
        ...sortedCategories.map(
          (category) => DropdownMenuItem<int?>(
            value: category.id,
            child: Text(
              category.translatedName ?? category.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
      onChanged: (categoryId) {
        if (categoryId == null) {
          setState(() {
            _selectedCategoryId = null;
            _selectedScope = 'all';
          });
          _applyFilters();
          return;
        }
        final category = sortedCategories.firstWhere(
          (item) => item.id == categoryId,
        );
        _openCategoryProducts(category);
      },
    );
  }

  Widget _buildPlaceholderCard(String title, String subtitle) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: buildPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildShopList(List<Shop> shops) {
    if (shops.isEmpty) {
      return _buildPlaceholderCard(
        'Aucune boutique disponible',
        'Les commerces seront listés dès qu’ils publieront.',
      );
    }

    const portraits = [
      'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=160&q=80',
      'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=160&q=80',
      'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?auto=format&fit=crop&w=160&q=80',
      'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=160&q=80',
    ];
    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: shops.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final shop = shops[index];
          final logo =
              normalizeMediaUrl(shop.logo) ??
              portraits[index % portraits.length];
          return SizedBox(
            width: 82,
            child: InkWell(
              onTap: () => _openShop(shop),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.surfaceAlt,
                    child: ClipOval(
                      child: Image.network(
                        logo,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.storefront, color: Colors.white70),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    shop.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class ExplorerData {
  final List<Category> categories;
  final List<Shop> shops;

  ExplorerData({required this.categories, required this.shops});
}

class ExplorerSearchResults {
  final List<Product> products;
  final List<Shop> shops;

  ExplorerSearchResults({required this.products, required this.shops});
}

class _ExplorerAction {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  _ExplorerAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}
