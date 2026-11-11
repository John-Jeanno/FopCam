import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile/models/product.dart';
import 'package:mobile/models/shop.dart';
import 'package:mobile/screens/explorer_screen.dart';
import 'package:mobile/services/api_service.dart';

class AdvancedSearchScreen extends StatefulWidget {
  const AdvancedSearchScreen({super.key});

  @override
  State<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends State<AdvancedSearchScreen>
    with SingleTickerProviderStateMixin {
  late TextEditingController _searchController;
  late TextEditingController _minimumPriceController;
  late TextEditingController _maximumPriceController;
  late TabController _tabController;

  List<Product> _searchProducts = [];
  List<Shop> _searchShops = [];
  List<Category> _searchCategories = [];
  List<Category> _productCategories = [];

  bool _isLoading = false;
  bool _inStockOnly = false;
  String _sortOrder = 'newest';
  int? _selectedCategoryId;
  String? _errorMessage;
  Timer? _searchDebounce;
  int _searchRequestId = 0;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _minimumPriceController = TextEditingController();
    _maximumPriceController = TextEditingController();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_scheduleSearch);
    _loadProductCategories();
    _performSearch();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _minimumPriceController.dispose();
    _maximumPriceController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProductCategories() async {
    final categories = await ApiService.fetchCategories(useMockData: false);
    if (!mounted) return;
    setState(() {
      _productCategories = categories
          .where((category) => category.categoryType == 'product')
          .toList();
    });
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchRequestId++;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _performSearch(),
    );
  }

  Future<void> _performSearch() async {
    final minimumPrice = _parsePrice(_minimumPriceController.text);
    final maximumPrice = _parsePrice(_maximumPriceController.text);
    if ((_minimumPriceController.text.trim().isNotEmpty &&
            (minimumPrice == null || !minimumPrice.isFinite)) ||
        (_maximumPriceController.text.trim().isNotEmpty &&
            (maximumPrice == null || !maximumPrice.isFinite))) {
      _searchRequestId++;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Saisissez un prix valide.';
      });
      return;
    }
    if (minimumPrice != null &&
        maximumPrice != null &&
        minimumPrice > maximumPrice) {
      _searchRequestId++;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Le prix minimum doit être inférieur au prix maximum.';
      });
      return;
    }

    final requestId = ++_searchRequestId;
    final query = _searchController.text.trim();
    final filters = <String, String>{
      if (minimumPrice != null) 'price_min': '$minimumPrice',
      if (maximumPrice != null) 'price_max': '$maximumPrice',
      if (_inStockOnly) 'in_stock': 'true',
      'ordering': _sortOrder,
    };

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        ApiService.fetchProducts(
          pageSize: 100,
          search: query.isEmpty ? null : query,
          categoryId: _selectedCategoryId,
          extraFilters: filters,
        ),
        ApiService.fetchShops(search: query),
        ApiService.fetchCategories(search: query, useMockData: false),
      ]);

      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _searchProducts = results[0] as List<Product>;
        _searchShops = results[1] as List<Shop>;
        _searchCategories = results[2] as List<Category>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error performing advanced search: $e');
      if (!mounted || requestId != _searchRequestId) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'La recherche a échoué. Vérifiez votre connexion puis réessayez.';
      });
    }
  }

  double? _parsePrice(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_scheduleSearch);
    _searchController.clear();
    _searchController.addListener(_scheduleSearch);
    _minimumPriceController.clear();
    _maximumPriceController.clear();
    setState(() {
      _selectedCategoryId = null;
      _inStockOnly = false;
      _sortOrder = 'newest';
      _searchProducts = [];
      _searchShops = [];
      _searchCategories = [];
      _errorMessage = null;
      _isLoading = false;
      _searchRequestId++;
    });
    _scheduleSearch();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche Avancée'),
        backgroundColor: const Color(0xFF1F2937),
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Chercher produits, vendeurs, catégories...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Filtres avancés'),
              leading: const Icon(Icons.tune),
              children: [
                DropdownButtonFormField<int>(
                  key: ValueKey(_selectedCategoryId ?? 0),
                  initialValue: _selectedCategoryId ?? 0,
                  decoration: const InputDecoration(labelText: 'Catégorie'),
                  items: [
                    const DropdownMenuItem(
                      value: 0,
                      child: Text('Toutes les catégories'),
                    ),
                    ..._productCategories.map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(
                      () => _selectedCategoryId = value == 0 ? null : value,
                    );
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minimumPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Prix minimum',
                          suffixText: 'XOF',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maximumPriceController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Prix maximum',
                          suffixText: 'XOF',
                        ),
                      ),
                    ),
                  ],
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey(_sortOrder),
                  initialValue: _sortOrder,
                  decoration: const InputDecoration(labelText: 'Trier par'),
                  items: const [
                    DropdownMenuItem(
                      value: 'newest',
                      child: Text('Plus récents'),
                    ),
                    DropdownMenuItem(
                      value: 'price_asc',
                      child: Text('Prix croissant'),
                    ),
                    DropdownMenuItem(
                      value: 'price_desc',
                      child: Text('Prix décroissant'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _sortOrder = value);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Produits en stock uniquement'),
                  value: _inStockOnly,
                  onChanged: (value) => setState(() => _inStockOnly = value),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _performSearch,
                    icon: const Icon(Icons.search),
                    label: const Text('Rechercher'),
                  ),
                ),
              ],
            ),
          ),

          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),

          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: const Color(0xFF3B82F6),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFF3B82F6),
            tabs: [
              Tab(text: 'Produits (${_searchProducts.length})'),
              Tab(text: 'Vendeurs (${_searchShops.length})'),
              Tab(text: 'Catégories (${_searchCategories.length})'),
              Tab(text: 'Tous'),
            ],
          ),

          // Tab content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Products tab
                      _buildProductsList(_searchProducts),

                      // Shops tab
                      _buildShopsList(_searchShops),

                      // Categories tab
                      _buildCategoriesList(_searchCategories),

                      // All results tab
                      _buildAllResults(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList(List<Product> products) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'Aucun produit trouvé',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: Colors.grey[200],
              ),
              child: product.image != null
                  ? Image.network(
                      product.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) {
                        return Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[400],
                        );
                      },
                    )
                  : Icon(Icons.shopping_bag, color: Colors.grey[400]),
            ),
            title: Text(
              product.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${product.price} XOF',
              style: const TextStyle(
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () {
              Navigator.pushNamed(context, '/product', arguments: product.id);
            },
          ),
        );
      },
    );
  }

  Widget _buildShopsList(List<Shop> shops) {
    if (shops.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Aucun vendeur trouvé',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: shops.length,
      itemBuilder: (context, index) {
        final shop = shops[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFFF3F4F6),
              child: Icon(Icons.store, color: Colors.grey[400]),
            ),
            title: Text(shop.name),
            subtitle: Text(
              shop.description ?? 'Pas de description',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => Navigator.pushNamed(
              context,
              '/shop',
              arguments: {'shopId': shop.id},
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoriesList(List<Category> categories) {
    if (categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Aucune catégorie trouvée',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ExplorerScreen(initialCategoryId: category.id),
              ),
            );
          },
          child: Card(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.category, size: 32, color: Colors.grey[600]),
                  const SizedBox(height: 8),
                  Text(
                    category.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAllResults() {
    final totalResults =
        _searchProducts.length + _searchShops.length + _searchCategories.length;

    if (totalResults == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Aucun résultat trouvé',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (_searchProducts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_bag,
                  size: 20,
                  color: Color(0xFF3B82F6),
                ),
                const SizedBox(width: 8),
                Text(
                  'Produits (${_searchProducts.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ..._searchProducts.take(3).map((product) {
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.grey[200],
                  ),
                  child: product.image != null
                      ? Image.network(
                          product.image!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) {
                            return Icon(
                              Icons.image_not_supported,
                              color: Colors.grey[400],
                            );
                          },
                        )
                      : Icon(Icons.shopping_bag, color: Colors.grey[400]),
                ),
                title: Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text('${product.price} XOF'),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/product',
                  arguments: product.id,
                ),
              ),
            );
          }),
        ],
        if (_searchShops.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.store, size: 20, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Text(
                  'Vendeurs (${_searchShops.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ..._searchShops.take(3).map((shop) {
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFF3F4F6),
                  child: Icon(Icons.store, color: Colors.grey[400]),
                ),
                title: Text(shop.name),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/shop',
                  arguments: {'shopId': shop.id},
                ),
              ),
            );
          }),
        ],
        if (_searchCategories.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.category, size: 20, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Text(
                  'Catégories (${_searchCategories.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ...(_searchCategories.take(3).map((category) {
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: Icon(Icons.category, color: Colors.grey[400]),
                title: Text(category.name),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ExplorerScreen(initialCategoryId: category.id),
                  ),
                ),
              ),
            );
          }).toList()),
        ],
      ],
    );
  }
}
