// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:mobile/constants/api_endpoints.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/constants/ui_helpers.dart';
import 'package:mobile/models/product.dart';
import 'package:mobile/models/shop.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';

class ProducerDashboardScreen extends StatefulWidget {
  const ProducerDashboardScreen({super.key});

  @override
  State<ProducerDashboardScreen> createState() =>
      _ProducerDashboardScreenState();
}

class _ProducerDashboardScreenState extends State<ProducerDashboardScreen> {
  bool _isLoading = true;
  bool _hasBoutiqueAccess = false;
  String? _profileVerificationError;
  bool _isSeeding = false;
  String? _operationsError;
  User? _currentUser;
  Shop? _myShop;
  Map<String, dynamic>? _shopAnalytics;
  String? _shopAnalyticsError;
  List<Product> _myProducts = [];
  List<Map<String, dynamic>> _salesOrders = [];
  List<Map<String, dynamic>> _stockMovements = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _acceptedClients = [];
  List<Map<String, dynamic>> _reviews = [];
  final Set<int> _selectedProductIds = {};
  bool _isDeletingSelectedProducts = false;
  String _statusFilter = 'all';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDashboard();
    _searchController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
    });

    final profileResult = await AuthService.getProfile();
    if (profileResult['success'] != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de charger le profil.')),
      );
      setState(() {
        _profileVerificationError =
            profileResult['error']?.toString() ??
            'Le profil ne peut pas être vérifié.';
        _hasBoutiqueAccess = false;
        _isLoading = false;
      });
      return;
    }

    final user = profileResult['data'] as User;
    if (user.role.trim().toLowerCase() != 'boutique') {
      if (!mounted) return;
      setState(() {
        _currentUser = user;
        _hasBoutiqueAccess = false;
        _profileVerificationError = null;
        _isLoading = false;
      });
      return;
    }

    final shop = await ApiService.fetchMyShop();
    final products = await ApiService.fetchMyProducts();
    Map<String, dynamic>? shopAnalytics;
    String? shopAnalyticsError;
    if (shop != null) {
      try {
        shopAnalytics = await ApiService.fetchShopAnalytics(shop.id);
      } on Object catch (error) {
        shopAnalyticsError = error.toString();
        debugPrint('Impossible de charger les statistiques boutique : $error');
      }
    }
    var salesOrders = <Map<String, dynamic>>[];
    var stockMovements = <Map<String, dynamic>>[];
    String? operationsError;
    try {
      salesOrders = await ApiService.fetchSalesOrders();
      stockMovements = await ApiService.fetchStockMovements();
    } on Object catch (error) {
      operationsError = error.toString();
      debugPrint('Impossible de charger les données commerciales : $error');
    }
    final friendItems = await ApiService.fetchFriendRequests();
    final reviews = await ApiService.fetchProducerReviews(user.id);
    final loadedProducts = _uniqueProducts(products);

    final pending = friendItems.where((item) {
      final receiver = item['receiver'] as Map<String, dynamic>?;
      return receiver != null &&
          receiver['id'] == user.id &&
          item['status'] == 'pending';
    }).toList();

    final accepted = friendItems.where((item) {
      final receiver = item['receiver'] as Map<String, dynamic>?;
      final requester = item['requester'] as Map<String, dynamic>?;
      final userId = user.id;
      return item['status'] == 'accepted' &&
          ((receiver != null && receiver['id'] == userId) ||
              (requester != null && requester['id'] == userId));
    }).toList();

    if (!mounted) return;
    setState(() {
      _currentUser = user;
      _hasBoutiqueAccess = true;
      _profileVerificationError = null;
      _myShop = shop;
      _shopAnalytics = shopAnalytics;
      _shopAnalyticsError = shopAnalyticsError;
      _myProducts = loadedProducts;
      final loadedProductIds = loadedProducts
          .map((product) => product.id)
          .toSet();
      _selectedProductIds.removeWhere(
        (productId) => !loadedProductIds.contains(productId),
      );
      _salesOrders = _uniqueRecords(salesOrders);
      _stockMovements = _uniqueRecords(stockMovements);
      _operationsError = operationsError;
      _pendingRequests = _uniqueRecords(pending);
      _acceptedClients = _uniqueRecords(accepted);
      _reviews = _uniqueRecords(reviews);
      _isLoading = false;
    });
  }

  List<Product> _uniqueProducts(Iterable<Product> products) {
    final seenIds = <int>{};
    return products.where((product) => seenIds.add(product.id)).toList();
  }

  List<Map<String, dynamic>> _uniqueRecords(
    Iterable<Map<String, dynamic>> records,
  ) {
    final seenIds = <String>{};
    return records.where((record) {
      final id = record['id'];
      return id == null || seenIds.add(id.toString());
    }).toList();
  }

  Future<void> _seedProducts() async {
    if (_myShop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Créez d’abord une boutique pour générer des produits.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSeeding = true;
    });

    final result = await ApiService.seedShopProducts();
    if (!mounted) return;
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result['data']?['detail'] ?? 'Produits d’exemple ajoutés.',
          ),
        ),
      );
      await _loadDashboard();
    } else {
      final error = result['error'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de générer les produits: ${error ?? 'erreur'}',
          ),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _isSeeding = false;
    });
  }

  Future<void> _acceptRequest(int requestId) async {
    final success = await ApiService.handleFriendRequestAction(
      requestId,
      'accept',
    );
    if (!mounted) return;
    if (success) {
      await _loadDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’accepter la demande.')),
      );
    }
  }

  Future<void> _rejectRequest(int requestId) async {
    final success = await ApiService.handleFriendRequestAction(
      requestId,
      'decline',
    );
    if (!mounted) return;
    if (success) {
      await _loadDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de refuser la demande.')),
      );
    }
  }

  Future<void> _removeClient(int friendshipId) async {
    final success = await ApiService.removeFriend(friendshipId);
    if (!mounted) return;
    if (success) {
      await _loadDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de retirer le client.')),
      );
    }
  }

  List<Product> get _filteredProducts {
    final filter = _searchController.text.trim().toLowerCase();
    return _myProducts.where((product) {
      final matchesSearch =
          filter.isEmpty ||
          product.title.toLowerCase().contains(filter) ||
          product.description.toLowerCase().contains(filter) ||
          (product.category?.name.toLowerCase().contains(filter) ?? false);

      final matchesStatus =
          _statusFilter == 'all' ||
          (_statusFilter == 'low' &&
              product.quantity > 0 &&
              product.quantity <= 5) ||
          (_statusFilter == 'out' && product.quantity == 0) ||
          (_statusFilter == 'available' && product.quantity > 5);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  double get _averageRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<double>(0, (sum, item) {
      final rating = item['rating'];
      return sum +
          (rating is num ? rating.toDouble() : double.tryParse('$rating') ?? 0);
    });
    return total / _reviews.length;
  }

  List<Map<String, dynamic>> get _orderItems => _uniqueRecords(
    _salesOrders
        .expand((order) => (order['items'] as List? ?? const []))
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item)),
  );

  int _itemsInStatus(String status) =>
      _orderItems.where((item) => item['fulfillment_status'] == status).length;

  double _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value') ?? 0;

  double get _grossProfit => _orderItems.fold<double>(
    0,
    (total, item) => total + _number(item['line_profit']),
  );

  int get _returnedUnits => _stockMovements
      .where((movement) => movement['movement_type'] == 'return')
      .fold<int>(
        0,
        (total, movement) =>
            total + (_number(movement['quantity_change']).toInt()),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Tableau vendeur'),
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadDashboard,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !_hasBoutiqueAccess
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF020617),
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                  ],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.store_outlined,
                        color: Colors.white70,
                        size: 48,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _profileVerificationError == null
                            ? 'Le tableau vendeur est réservé au type de profil Boutique.'
                            : 'Impossible de vérifier votre type de profil. '
                                  '$_profileVerificationError',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _profileVerificationError == null
                            ? () => Navigator.of(context).pushNamed('/profile')
                            : _loadDashboard,
                        icon: Icon(
                          _profileVerificationError == null
                              ? Icons.settings
                              : Icons.refresh,
                        ),
                        label: Text(
                          _profileVerificationError == null
                              ? 'Ouvrir Mes paramètres'
                              : 'Réessayer',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF020617),
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                  ],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeader(),
                          const SizedBox(height: 20),
                          _buildShopAnalyticsSection(),
                          const SizedBox(height: 20),
                          _buildMetricsRow(),
                          const SizedBox(height: 20),
                          _buildShopCard(),
                          const SizedBox(height: 20),
                          _buildOrdersSection(),
                          const SizedBox(height: 20),
                          _buildStockHistorySection(),
                          const SizedBox(height: 20),
                          _buildActionRow(),
                          const SizedBox(height: 20),
                          _buildProductFilters(),
                          const SizedBox(height: 16),
                          _buildProductsSection(),
                          const SizedBox(height: 20),
                          _buildReviewsSection(),
                          const SizedBox(height: 20),
                          _buildFriendRequestsSection(),
                          const SizedBox(height: 20),
                          _buildAcceptedClientsSection(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bienvenue sur votre espace vendeur',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _myShop != null
              ? 'Gérez votre boutique ${_myShop!.name} et suivez vos ventes en temps réel.'
              : 'Vous n’avez pas encore de boutique. Créez-en une pour commencer à vendre.',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildShopAnalyticsSection() {
    if (_myShop == null) return const SizedBox.shrink();
    final analytics = _shopAnalytics;
    return Container(
      decoration: buildPanelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistiques réelles de la boutique',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Données enregistrées par le serveur. Les consultations sont comptées à chaque ouverture de la page, pas comme visiteurs uniques.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
          const SizedBox(height: 16),
          if (_shopAnalyticsError != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statistiques indisponibles : $_shopAnalyticsError',
                  style: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 13,
                  ),
                ),
                TextButton.icon(
                  onPressed: _isLoading ? null : _loadDashboard,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'),
                ),
              ],
            )
          else if (analytics == null)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 560
                    ? 2
                    : 1;
                final cardWidth =
                    (constraints.maxWidth - 12 * (columns - 1)) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMetricCard(
                      cardWidth,
                      'Visites · 90 jours',
                      '${_analyticsCount(analytics['shop_views_90d'])}',
                      _trendLabel(analytics['shop_views_change_percent']),
                    ),
                    _buildMetricCard(
                      cardWidth,
                      'Apparitions en recherche · 7 jours',
                      '${_analyticsCount(analytics['search_appearances_7d'])}',
                      _trendLabel(
                        analytics['search_appearances_change_percent'],
                      ),
                    ),
                    _buildMetricCard(
                      cardWidth,
                      'Commandes reçues · 7 jours',
                      '${_analyticsCount(analytics['orders_7d'])}',
                      _trendLabel(analytics['orders_change_percent']),
                    ),
                    _buildMetricCard(
                      cardWidth,
                      'Ventes confirmées · 7 jours',
                      '${_currencyAmount(analytics['sales_revenue_7d'])} FCFA',
                      _trendLabel(analytics['sales_revenue_change_percent']),
                    ),
                    _buildMetricCard(
                      cardWidth,
                      'Ventes confirmées · 90 jours',
                      '${_currencyAmount(analytics['sales_revenue_90d'])} FCFA',
                      'Articles vendus moins retours acceptés',
                    ),
                    _buildMetricCard(
                      cardWidth,
                      'Note moyenne',
                      '${_number(analytics['average_rating']).toStringAsFixed(1)} / 5',
                      '${_analyticsCount(analytics['ratings_total'])} avis clients',
                    ),
                    _buildMetricCard(
                      cardWidth,
                      'J’aime',
                      '${_analyticsCount(analytics['likes_total'])}',
                      'J’aime reçus par la boutique',
                    ),
                    _buildMetricCard(
                      cardWidth,
                      'Partages',
                      '${_analyticsCount(analytics['shares_total'])}',
                      'Partages enregistrés',
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'Visites quotidiennes · 7 jours',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            _buildShopViewsChart(analytics['daily_activity']),
            const SizedBox(height: 20),
            _buildProductAnalytics(analytics['product_metrics']),
          ],
        ],
      ),
    );
  }

  Widget _buildProductAnalytics(Object? value) {
    final products = value is List
        ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : <Map<String, dynamic>>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Statistiques par produit',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Vues et recherches depuis l’activation du suivi. Ventes nettes des retours acceptés sur 90 jours.',
          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (products.isEmpty)
          const Text(
            'Aucun produit actif à afficher.',
            style: TextStyle(color: Color(0xFF94A3B8)),
          )
        else
          for (final product in products.take(10))
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.inventory_2_outlined,
                    color: Color(0xFF60A5FA),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['title']?.toString() ?? 'Produit',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_analyticsCount(product['views_total'])} vues · ${_analyticsCount(product['search_appearances_7d'])} recherches / 7 j · ${_analyticsCount(product['favorites_total'])} favoris',
                          style: const TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${_analyticsCount(product['units_sold_90d'])} vendu(s)',
                        style: const TextStyle(
                          color: Color(0xFF86EFAC),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${_currencyAmount(product['revenue_90d'])} FCFA / 90 j',
                        style: const TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }

  int _analyticsCount(Object? value) =>
      value is num ? value.toInt() : int.tryParse('$value') ?? 0;

  String _currencyAmount(Object? value) => _number(value).toStringAsFixed(0);

  String _trendLabel(Object? value) {
    if (value is! num) return 'Pas encore de période comparable';
    final change = value.toInt();
    return '${change > 0 ? '+' : ''}$change % par rapport aux 7 jours précédents';
  }

  Widget _buildShopViewsChart(Object? value) {
    final days = value is List
        ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : <Map<String, dynamic>>[];
    if (days.isEmpty) {
      return const Text(
        'Aucune donnée quotidienne disponible pour le moment.',
        style: TextStyle(color: Color(0xFF94A3B8)),
      );
    }
    final maxViews = days.fold<int>(
      0,
      (maximum, day) => maximum > _analyticsCount(day['shop_views'])
          ? maximum
          : _analyticsCount(day['shop_views']),
    );
    const weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return SizedBox(
      height: 118,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final day in days)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${_analyticsCount(day['shop_views'])}',
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: maxViews == 0
                          ? 4
                          : 50 * _analyticsCount(day['shop_views']) / maxViews,
                      decoration: BoxDecoration(
                        color: const Color(0xFF60A5FA),
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _weekdayLabel(day['date'], weekdayLabels),
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _weekdayLabel(Object? value, List<String> labels) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    return date == null ? '—' : labels[date.weekday - 1];
  }

  Widget _buildMetricsRow() {
    final total = _myProducts.length;
    final lowStock = _myProducts
        .where((p) => p.quantity > 0 && p.quantity <= 5)
        .length;
    final outOfStock = _myProducts.where((p) => p.quantity == 0).length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        final cardWidth = (constraints.maxWidth - 12 * (columns - 1)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildMetricCard(
              cardWidth,
              'Produits',
              '$total',
              'Actifs dans votre boutique',
            ),
            _buildMetricCard(
              cardWidth,
              'Stock faible',
              '$lowStock',
              'Quantités ≤ 5',
            ),
            _buildMetricCard(
              cardWidth,
              'Rupture',
              '$outOfStock',
              'Produits épuisés',
            ),
            _buildMetricCard(
              cardWidth,
              'Boutique',
              _myShop != null ? 'Active' : 'A créer',
              _myShop != null ? _myShop!.name : 'Créez une boutique',
            ),
            _buildMetricCard(
              cardWidth,
              'Commandes à traiter',
              '${_itemsInStatus('pending') + _itemsInStatus('preparing')}',
              'Reçues ou en préparation',
            ),
            _buildMetricCard(
              cardWidth,
              'Livraisons en cours',
              '${_itemsInStatus('in_delivery')}',
              'Articles confiés au livreur',
            ),
            _buildMetricCard(
              cardWidth,
              'Bénéfice brut livré',
              '${_grossProfit.toStringAsFixed(0)} FCFA',
              'Après retours acceptés',
            ),
            _buildMetricCard(
              cardWidth,
              'Retours acceptés',
              '$_returnedUnits',
              'Articles remis en stock',
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(
    double width,
    String title,
    String value,
    String subtitle,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF172554), Color(0xFF111827)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                switch (title) {
                  'Produits' => Icons.inventory_2_outlined,
                  'Stock faible' => Icons.warning_amber_rounded,
                  'Rupture' => Icons.remove_shopping_cart_outlined,
                  'Boutique' => Icons.storefront_outlined,
                  'Commandes à traiter' => Icons.receipt_long_outlined,
                  'Livraisons en cours' => Icons.local_shipping_outlined,
                  'Bénéfice brut livré' => Icons.trending_up,
                  'Retours acceptés' => Icons.assignment_return_outlined,
                  'Visites · 90 jours' => Icons.storefront_outlined,
                  'Apparitions en recherche · 7 jours' =>
                    Icons.manage_search_outlined,
                  'Commandes reçues · 7 jours' => Icons.receipt_long_outlined,
                  'Ventes confirmées · 7 jours' => Icons.payments_outlined,
                  'Ventes confirmées · 90 jours' =>
                    Icons.account_balance_wallet_outlined,
                  'Note moyenne' => Icons.star_outline,
                  'J’aime' => Icons.favorite_border,
                  'Partages' => Icons.share_outlined,
                  _ => Icons.insights_outlined,
                },
                color: const Color(0xFF93C5FD),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersSection() {
    final ordersWithItems = _salesOrders.where((order) {
      final items = order['items'] as List? ?? const [];
      return items.isNotEmpty;
    }).toList();
    return Container(
      decoration: buildPanelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Commandes et livraisons',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Faites avancer chaque article jusqu’à sa livraison.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),
          const SizedBox(height: 14),
          if (_operationsError != null)
            Text(
              'Données commerciales indisponibles : $_operationsError',
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
            )
          else if (ordersWithItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Aucune commande reçue pour le moment.',
                style: TextStyle(color: Color(0xFF94A3B8)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: ordersWithItems.length.clamp(0, 8),
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final order = ordersWithItems[index];
                final orderId = order['id'] as int? ?? 0;
                final items = _uniqueRecords(
                  (order['items'] as List? ?? const []).whereType<Map>().map(
                    (item) => Map<String, dynamic>.from(item),
                  ),
                );
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Commande #$orderId · ${order['buyer_username'] ?? 'Client'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${_number(order['total']).toStringAsFixed(0)} FCFA',
                            style: const TextStyle(
                              color: Color(0xFF93C5FD),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...items.map((item) => _buildOrderItem(order, item)),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(
    Map<String, dynamic> order,
    Map<String, dynamic> item,
  ) {
    final orderId = order['id'] as int? ?? 0;
    final itemId = item['id'] as int? ?? 0;
    final status = item['fulfillment_status']?.toString() ?? 'pending';
    final returned = _number(item['returned_quantity']).toInt();
    final quantity = _number(item['quantity']).toInt();
    final nextStatus = switch (status) {
      'pending' => 'preparing',
      'preparing' => 'in_delivery',
      'in_delivery' => 'delivered',
      _ => null,
    };
    final statusLabel = switch (status) {
      'pending' => 'À traiter',
      'preparing' => 'En préparation',
      'in_delivery' => 'En livraison',
      'delivered' => 'Livrée',
      'cancelled' => 'Annulée',
      'returned' => 'Retournée',
      _ => status,
    };

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${item['product_title'] ?? 'Produit'} · $quantity article(s)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  statusLabel,
                  style: const TextStyle(
                    color: Color(0xFFBFDBFE),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Vente ${_number(item['price']).toStringAsFixed(0)} · '
              'achat ${_number(item['purchase_price']).toStringAsFixed(0)} · '
              'marge livrée ${_number(item['line_profit']).toStringAsFixed(0)} FCFA'
              '${returned == 0 ? '' : ' · retours $returned'}',
              style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
            ),
            if (nextStatus != null ||
                (status == 'delivered' && returned < quantity))
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (nextStatus != null)
                    TextButton.icon(
                      onPressed: () =>
                          _updateFulfillment(orderId, itemId, nextStatus),
                      icon: Icon(
                        nextStatus == 'in_delivery'
                            ? Icons.local_shipping_outlined
                            : nextStatus == 'delivered'
                            ? Icons.check_circle_outline
                            : Icons.inventory_2_outlined,
                        size: 17,
                      ),
                      label: Text(switch (nextStatus) {
                        'preparing' => 'Préparer',
                        'in_delivery' => 'Expédier',
                        _ => 'Confirmer livré',
                      }),
                    ),
                  if (status == 'delivered' && returned < quantity)
                    TextButton.icon(
                      onPressed: () => _recordReturn(orderId, item),
                      icon: const Icon(
                        Icons.assignment_return_outlined,
                        size: 17,
                      ),
                      label: const Text('Enregistrer un retour'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateFulfillment(
    int orderId,
    int itemId,
    String status,
  ) async {
    final result = await ApiService.updateOrderItemFulfillment(
      orderId: orderId,
      itemId: itemId,
      status: status,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      await _loadDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de mettre à jour la livraison : ${result['error']}',
          ),
        ),
      );
    }
  }

  Future<void> _recordReturn(int orderId, Map<String, dynamic> item) async {
    final quantityController = TextEditingController(text: '1');
    final noteController = TextEditingController();
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Accepter un retour reçu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Produit : ${item['product_title'] ?? 'Produit'}'),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantité retournée',
              ),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(
                labelText: 'Motif (facultatif)',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Le stock sera augmenté après confirmation du retour.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Accepter et remettre en stock'),
          ),
        ],
      ),
    );
    if (approved != true) {
      quantityController.dispose();
      noteController.dispose();
      return;
    }

    final quantity = int.tryParse(quantityController.text.trim());
    final note = noteController.text.trim();
    quantityController.dispose();
    noteController.dispose();
    if (!mounted) return;
    if (quantity == null || quantity < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez une quantité valide.')),
      );
      return;
    }

    final result = await ApiService.acceptOrderItemReturn(
      orderId: orderId,
      itemId: item['id'] as int? ?? 0,
      quantity: quantity,
      note: note,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      await _loadDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retour non enregistré : ${result['error']}')),
      );
    }
  }

  Widget _buildStockHistorySection() {
    const typeLabels = {
      'restock': 'Approvisionnement',
      'adjustment': 'Décrémentation / ajustement',
      'sale': 'Vente',
      'return': 'Retour accepté',
      'cancellation': 'Annulation de commande',
    };
    return Container(
      decoration: buildPanelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stock et mouvements récents',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          if (_operationsError != null)
            Text(
              'Historique indisponible : $_operationsError',
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13),
            )
          else if (_stockMovements.isEmpty)
            const Text(
              'Les approvisionnements, ventes, retours et ajustements apparaîtront ici.',
              style: TextStyle(color: Color(0xFF94A3B8)),
            )
          else
            ..._stockMovements.take(8).map((movement) {
              final delta = _number(movement['quantity_change']).toInt();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  delta >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: delta >= 0
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCA5A5),
                ),
                title: Text(
                  movement['product_title']?.toString() ?? 'Produit',
                  style: const TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  typeLabels[movement['movement_type']] ??
                      movement['movement_type']?.toString() ??
                      'Mouvement',
                  style: const TextStyle(color: Color(0xFF94A3B8)),
                ),
                trailing: Text(
                  '${delta > 0 ? '+' : ''}$delta',
                  style: TextStyle(
                    color: delta >= 0
                        ? const Color(0xFF86EFAC)
                        : const Color(0xFFFCA5A5),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _manageStock(
    Product product, {
    required String movementType,
    required String direction,
  }) async {
    final quantityController = TextEditingController();
    final costController = TextEditingController(
      text: product.purchasePrice?.toStringAsFixed(0) ?? '',
    );
    final noteController = TextEditingController();
    final isRestock = movementType == 'restock';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isRestock ? 'Approvisionner le stock' : 'Décrémenter le stock',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(product.title),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Quantité ${isRestock ? 'reçue' : 'à retirer'}',
              ),
            ),
            if (isRestock)
              TextField(
                controller: costController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Nouveau prix d’achat unitaire (FCFA)',
                ),
              ),
            TextField(
              controller: noteController,
              decoration: InputDecoration(
                labelText: isRestock
                    ? 'Fournisseur / note'
                    : 'Motif obligatoire',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              isRestock ? 'Enregistrer l’entrée' : 'Confirmer le retrait',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      quantityController.dispose();
      costController.dispose();
      noteController.dispose();
      return;
    }

    final quantity = int.tryParse(quantityController.text.trim());
    final purchasePrice = isRestock
        ? double.tryParse(costController.text.trim().replaceAll(',', '.'))
        : null;
    final note = noteController.text.trim();
    quantityController.dispose();
    costController.dispose();
    noteController.dispose();
    if (!mounted) return;
    if (quantity == null ||
        quantity < 1 ||
        (isRestock && (purchasePrice == null || purchasePrice < 0)) ||
        note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vérifiez la quantité, le prix d’achat et le motif.'),
        ),
      );
      return;
    }

    final result = await ApiService.adjustProductStock(
      productId: product.id,
      movementType: movementType,
      quantity: quantity,
      direction: direction,
      purchasePrice: purchasePrice,
      note: note,
    );
    if (!mounted) return;
    if (result['success'] == true) {
      await _loadDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mouvement non enregistré : ${result['error']}'),
        ),
      );
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer le produit'),
        content: Text('Supprimer « ${product.title} » de votre catalogue ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final success = await ApiService.deleteProduct(product.id);
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Produit supprimé.')));
      await _loadDashboard();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de supprimer le produit.')),
      );
    }
  }

  Future<void> _deleteSelectedProducts() async {
    final selectedProducts = _myProducts
        .where((product) => _selectedProductIds.contains(product.id))
        .toList();
    if (selectedProducts.isEmpty || _isDeletingSelectedProducts) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer les produits sélectionnés'),
        content: Text(
          'Supprimer définitivement ${selectedProducts.length} produit(s) ? '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Tout supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _isDeletingSelectedProducts = true);
    final deletedIds = <int>{};
    final failedProducts = <Product>[];
    try {
      for (final product in selectedProducts) {
        if (await ApiService.deleteProduct(product.id)) {
          deletedIds.add(product.id);
        } else {
          failedProducts.add(product);
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingSelectedProducts = false;
          _selectedProductIds.removeAll(deletedIds);
        });
      }
    }

    if (!mounted) return;
    await _loadDashboard();
    if (!mounted) return;

    final deletedCount = deletedIds.length;
    final failedCount = failedProducts.length;
    final message = failedCount == 0
        ? '$deletedCount produit(s) supprimé(s).'
        : '$deletedCount supprimé(s), $failedCount échec(s). '
              'Les produits en échec restent sélectionnés.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _setVisibleProductsSelected(
    List<Product> products, {
    required bool selected,
  }) {
    setState(() {
      if (selected) {
        _selectedProductIds.addAll(products.map((product) => product.id));
      } else {
        _selectedProductIds.removeAll(products.map((product) => product.id));
      }
    });
  }

  Widget _buildShopCard() {
    return Container(
      decoration: buildPanelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_myShop?.banner != null) ...[
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              child: Image.network(
                _resolveMediaUrl(_myShop!.banner!),
                fit: BoxFit.cover,
                width: double.infinity,
                height: 180,
                errorBuilder: (context, error, stackTrace) => Container(
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
          ],
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: const Color(0xFF1E293B),
                      backgroundImage: _myShop?.logo == null
                          ? null
                          : NetworkImage(_resolveMediaUrl(_myShop!.logo!)),
                      child: _myShop?.logo == null
                          ? const Icon(Icons.storefront, color: Colors.white70)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _myShop?.name ?? 'Aucune boutique définie',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _myShop?.description ??
                      'Créez votre boutique pour commencer à vendre.',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    if (_myShop?.location != null)
                      _buildInfoChip(Icons.location_on, _myShop!.location!),
                    if (_myShop?.phone != null)
                      _buildInfoChip(Icons.phone, _myShop!.phone!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      margin: const EdgeInsets.only(right: 10, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primaryLight, size: 16),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 480
            ? constraints.maxWidth
            : (constraints.maxWidth - 24) / 3;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildActionButton(
              width: cardWidth,
              icon: Icons.add_shopping_cart,
              label: 'Ajouter produit',
              onTap: () => Navigator.of(context).pushNamed('/create_product'),
            ),
            _buildActionButton(
              width: cardWidth,
              icon: _myShop == null ? Icons.store : Icons.edit,
              label: _myShop == null
                  ? 'Créer boutique'
                  : 'Personnaliser boutique',
              onTap: _openShopEditor,
            ),
            _buildActionButton(
              width: cardWidth,
              icon: Icons.auto_awesome,
              label: 'Exemples',
              onTap: _isSeeding ? null : _seedProducts,
              loading: _isSeeding,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionButton({
    required double width,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.08)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primaryLight, size: 24),
            const SizedBox(height: 8),
            Text(
              loading ? 'Chargement...' : label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openShopEditor() async {
    await Navigator.of(context).pushNamed(
      '/create_shop',
      arguments: _myShop == null ? null : {'shop': _myShop},
    );
    if (mounted) await _loadDashboard();
  }

  Widget _buildProductFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filtrer les produits',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: buildPanelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Rechercher un produit...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderSide: BorderSide.none),
                  filled: true,
                  fillColor: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        iconEnabledColor: Colors.white,
                        dropdownColor: const Color(0xFF111827),
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text(
                              'Tous',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'available',
                            child: Text(
                              'Disponible',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'low',
                            child: Text(
                              'Faible',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'out',
                            child: Text(
                              'Rupture',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _statusFilter = value);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _statusFilter = 'all';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Réinitialiser'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProductsSection() {
    final filteredProducts = _filteredProducts;
    final groupedProducts = <String, List<Product>>{};
    for (final product in filteredProducts) {
      final category = product.category?.name ?? 'Autres';
      groupedProducts.putIfAbsent(category, () => []).add(product);
    }
    final categoryNames = groupedProducts.keys.toList()..sort();

    return Container(
      decoration: buildPanelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mes produits',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (_myProducts.isNotEmpty) ...[
            _buildProductSelectionControls(filteredProducts),
            const SizedBox(height: 8),
          ],
          if (filteredProducts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Aucun produit ne correspond aux filtres.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
            )
          else
            ...categoryNames.map((category) {
              final products = groupedProducts[category]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category,
                      style: const TextStyle(
                        color: Color(0xFFCBD5E1),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1000
                            ? 4
                            : constraints.maxWidth >= 680
                            ? 3
                            : 2;
                        final cardWidth =
                            (constraints.maxWidth - 12 * (columns - 1)) /
                            columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: products
                              .map(
                                (product) => SizedBox(
                                  width: cardWidth,
                                  child: _buildProductCard(product),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildProductSelectionControls(List<Product> products) {
    final selectedVisibleCount = products
        .where((product) => _selectedProductIds.contains(product.id))
        .length;
    final allVisibleSelected =
        products.isNotEmpty && selectedVisibleCount == products.length;
    final selectionValue = allVisibleSelected
        ? true
        : selectedVisibleCount > 0
        ? null
        : false;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: selectionValue,
              tristate: true,
              onChanged: _isDeletingSelectedProducts || products.isEmpty
                  ? null
                  : (selected) => _setVisibleProductsSelected(
                      products,
                      selected: selected != false,
                    ),
              activeColor: AppColors.primaryLight,
            ),
            const Text(
              'Tout sélectionner',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        Text(
          '${_selectedProductIds.length} sélectionné(s)',
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
        ),
        if (_selectedProductIds.isNotEmpty)
          TextButton(
            onPressed: _isDeletingSelectedProducts
                ? null
                : () => setState(_selectedProductIds.clear),
            child: const Text('Effacer la sélection'),
          ),
        FilledButton.icon(
          onPressed: _selectedProductIds.isEmpty || _isDeletingSelectedProducts
              ? null
              : _deleteSelectedProducts,
          icon: _isDeletingSelectedProducts
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
          label: Text(
            _isDeletingSelectedProducts
                ? 'Suppression...'
                : 'Supprimer (${_selectedProductIds.length})',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF991B1B),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Product product) {
    final imagePath = product.images != null && product.images!.isNotEmpty
        ? product.images!.first
        : product.image;
    final imageUrl = imagePath == null ? null : _resolveMediaUrl(imagePath);
    final marginColor =
        product.purchasePrice != null &&
            product.currentPrice >= product.purchasePrice!
        ? const Color(0xFF86EFAC)
        : product.purchasePrice == null
        ? const Color(0xFFFBBF24)
        : const Color(0xFFFCA5A5);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1.45,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _productImagePlaceholder(),
                  )
                else
                  _productImagePlaceholder(),
                if (product.isOnPromotion)
                  Positioned(
                    left: 8,
                    top: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        child: Text(
                          '-${product.discountPercentage}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Material(
                    color: const Color(0xCC0F172A),
                    shape: const CircleBorder(),
                    child: _buildProductMenu(product),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _selectedProductIds.contains(product.id),
                      onChanged: _isDeletingSelectedProducts
                          ? null
                          : (selected) => setState(() {
                              if (selected == true) {
                                _selectedProductIds.add(product.id);
                              } else {
                                _selectedProductIds.remove(product.id);
                              }
                            }),
                      activeColor: AppColors.primaryLight,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(
                          product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${product.currentPrice.toStringAsFixed(0)} FCFA',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (product.isOnPromotion)
                  Text(
                    'Prix normal ${product.price.toStringAsFixed(0)} FCFA',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 10,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                const SizedBox(height: 5),
                Text(
                  product.purchasePrice == null
                      ? 'Achat à renseigner'
                      : 'Marge : ${(product.currentPrice - product.purchasePrice!).toStringAsFixed(0)} FCFA',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: marginColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Stock : ${product.quantity}',
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 11,
                  ),
                ),
                if (product.colorOptions.isNotEmpty ||
                    product.sizeOptions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (product.colorOptions.isNotEmpty)
                        'Couleurs : ${product.colorOptions.join(', ')}',
                      if (product.sizeOptions.isNotEmpty)
                        'Tailles : ${product.sizeOptions.join(', ')}',
                    ].join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFCBD5E1),
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productImagePlaceholder() => Container(
    color: const Color(0xFF1F2937),
    child: const Center(
      child: Icon(Icons.image_outlined, color: Colors.white54, size: 36),
    ),
  );

  Widget _buildProductMenu(Product product) {
    return PopupMenuButton<String>(
      tooltip: 'Gérer le produit',
      enabled: !_isDeletingSelectedProducts,
      onSelected: (action) async {
        switch (action) {
          case 'restock':
            await _manageStock(
              product,
              movementType: 'restock',
              direction: 'increase',
            );
          case 'decrease':
            await _manageStock(
              product,
              movementType: 'adjustment',
              direction: 'decrease',
            );
          case 'edit':
            await Navigator.of(
              context,
            ).pushNamed('/create_product', arguments: {'product': product});
            if (mounted) await _loadDashboard();
          case 'delete':
            await _deleteProduct(product);
        }
      },
      icon: const Icon(Icons.more_vert, color: Colors.white70),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: 'restock',
          child: ListTile(
            leading: Icon(Icons.add_box_outlined),
            title: Text('Approvisionner'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'decrease',
          child: ListTile(
            leading: Icon(Icons.remove_circle_outline),
            title: Text('Décrémenter'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Modifier le produit'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.redAccent),
            title: Text('Supprimer le produit'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewsSection() {
    return Container(
      decoration: buildPanelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Avis clients',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.star, color: Color(0xFFFBBF24)),
              const SizedBox(width: 8),
              Text(
                _reviews.isNotEmpty
                    ? _averageRating.toStringAsFixed(1)
                    : 'Aucun avis',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'sur ${_reviews.length} avis',
                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_reviews.isEmpty)
            const Text(
              'Vos clients n’ont pas encore laissé d’avis.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reviews.length.clamp(0, 4),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final review = _reviews[index];
                final reviewer = review['reviewer'] as Map<String, dynamic>?;
                final rating = review['rating'] ?? 0;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              reviewer != null
                                  ? reviewer['username'] ?? 'Client'
                                  : 'Client',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Row(
                            children: List.generate(
                              5,
                              (starIndex) => Icon(
                                starIndex < (rating is num ? rating.toInt() : 0)
                                    ? Icons.star
                                    : Icons.star_border,
                                size: 16,
                                color: const Color(0xFFFBBF24),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        review['comment'] ??
                            review['message'] ??
                            'Aucun commentaire fourni.',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFriendRequestsSection() {
    return Container(
      decoration: buildPanelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Demandes clients',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (_pendingRequests.isEmpty)
            const Text(
              'Aucune demande client en attente.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _pendingRequests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final request = _pendingRequests[index];
                final requester = request['requester'] as Map<String, dynamic>?;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        requester != null
                            ? requester['username'] ?? 'Client'
                            : 'Client',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Demande client en attente.',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _acceptRequest(request['id'] ?? 0),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Accepter'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _rejectRequest(request['id'] ?? 0),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.primaryLight,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Refuser',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildAcceptedClientsSection() {
    return Container(
      decoration: buildPanelDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Clients connectés',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (_acceptedClients.isEmpty)
            const Text(
              'Aucun client connecté pour le moment.',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _acceptedClients.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final friend = _acceptedClients[index];
                final requester = friend['requester'] as Map<String, dynamic>?;
                final receiver = friend['receiver'] as Map<String, dynamic>?;
                final partner = requester?['id'] == _currentUser?.id
                    ? receiver
                    : requester;
                final name = partner != null
                    ? partner['username'] ?? 'Client'
                    : 'Client';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111827),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Client connecté',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.white70),
                        onPressed: () => _removeClient(friend['id'] ?? 0),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _resolveMediaUrl(String value) {
    if (value.startsWith('http')) {
      return value;
    }
    return '${ApiEndpoints.baseUrl}$value';
  }
}
