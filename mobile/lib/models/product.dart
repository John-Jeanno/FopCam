int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? 0;
  }
  return 0;
}

double _parseDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ??
        double.tryParse(value.replaceAll(',', '.')) ??
        0.0;
  }
  return 0.0;
}

String? _parseString(dynamic value) {
  if (value == null) return null;
  return value.toString();
}

class Product {
  final int id;
  final String title;
  final String description;
  final double price;
  final double? promoPrice;
  final List<String> colorOptions;
  final List<String> sizeOptions;
  final double? purchasePrice;
  final int quantity;
  final String? image;
  final List<String>? images;
  final String? video;
  final Category? category;
  final int shopId;
  final bool isActive;
  final DateTime createdAt;

  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    this.promoPrice,
    this.colorOptions = const [],
    this.sizeOptions = const [],
    this.purchasePrice,
    required this.quantity,
    this.image,
    this.images,
    this.video,
    this.category,
    required this.shopId,
    required this.isActive,
    required this.createdAt,
  });

  bool get isOnPromotion =>
      promoPrice != null && promoPrice! > 0 && promoPrice! < price;

  List<String> get galleryImages => {
    ...?images,
    ?image,
  }.where((path) => path.trim().isNotEmpty).toList(growable: false);

  double get currentPrice => isOnPromotion ? promoPrice! : price;

  int get discountPercentage =>
      isOnPromotion ? ((price - currentPrice) * 100 / price).round() : 0;

  factory Product.fromJson(Map<String, dynamic> json) {
    final shopValue = json['shop'];
    final dynamic shopIdValue = shopValue is Map ? shopValue['id'] : shopValue;

    return Product(
      id: _parseInt(json['id']),
      title: _parseString(json['title']) ?? '',
      description: _parseString(json['description']) ?? '',
      price: _parseDouble(json['price']),
      promoPrice: json['promo_price'] == null
          ? null
          : _parseDouble(json['promo_price']),
      colorOptions: _parseOptions(json['color_options']),
      sizeOptions: _parseOptions(json['size_options']),
      purchasePrice: json['purchase_price'] == null
          ? null
          : _parseDouble(json['purchase_price']),
      quantity: _parseInt(json['quantity']),
      image: _parseString(json['image']),
      images: json['images'] != null
          ? (json['images'] is List
                ? (json['images'] as List)
                      .map((e) => _parseString(e) ?? '')
                      .where((s) => s.isNotEmpty)
                      .toList()
                : null)
          : null,
      video: _parseString(json['video']),
      category: json['category'] != null && json['category'] is Map
          ? Category.fromJson(Map<String, dynamic>.from(json['category']))
          : null,
      shopId: _parseInt(shopIdValue),
      isActive: json['is_active'] is bool
          ? json['is_active']
          : (json['is_active'] == null
                ? true
                : json['is_active'].toString().toLowerCase() == 'true'),
      createdAt:
          DateTime.tryParse(_parseString(json['created_at']) ?? '') ??
          DateTime.now(),
    );
  }

  static List<String> _parseOptions(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toSet()
        .toList();
  }

  static List<Product> mockProducts() {
    final categories = Category.mockCategories();
    return [
      Product(
        id: 201,
        title: 'Tomates cerises bio',
        description: 'Tomates fraîches récoltées ce matin.',
        price: 3.50,
        quantity: 24,
        image:
            'https://images.unsplash.com/photo-1464965911861-746a04bca7f2?auto=format&fit=crop&w=900&q=80',
        category: categories[0],
        shopId: 1,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Product(
        id: 202,
        title: 'Panier de légumes du jour',
        description: 'Assortiment de légumes de saison.',
        price: 8.90,
        quantity: 18,
        image:
            'https://images.unsplash.com/photo-1540420773420-3366772f4999?auto=format&fit=crop&w=900&q=80',
        category: categories[0],
        shopId: 1,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Product(
        id: 203,
        title: 'Riz local premium',
        description: 'Riz parfumé issu de production locale.',
        price: 5.20,
        quantity: 16,
        image:
            'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=900&q=80',
        category: categories[1],
        shopId: 2,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      Product(
        id: 204,
        title: 'Épices du terroir',
        description: 'Mélange d’épices maison à base de produits locaux.',
        price: 4.70,
        quantity: 12,
        image:
            'https://images.unsplash.com/photo-1476718406336-bb5a9690ee2a?auto=format&fit=crop&w=900&q=80',
        category: categories[1],
        shopId: 2,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      ),
      Product(
        id: 205,
        title: 'Fromage de chèvre frais',
        description: 'Produit laitier artisanal à consommer frais.',
        price: 6.10,
        quantity: 10,
        image:
            'https://images.unsplash.com/photo-1486297678162-eb2a19b0a32d?auto=format&fit=crop&w=900&q=80',
        category: categories[2],
        shopId: 3,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Product(
        id: 206,
        title: 'Yaourt fermenté maison',
        description: 'Yaourt nature préparé en petite production.',
        price: 2.90,
        quantity: 14,
        image:
            'https://images.unsplash.com/photo-1571212515416-0d9f3d337fef?auto=format&fit=crop&w=900&q=80',
        category: categories[2],
        shopId: 3,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      Product(
        id: 207,
        title: 'Tissu de pagne traditionnel',
        description: 'Pièce artisanale colorée fabriquée localement.',
        price: 14.50,
        quantity: 8,
        image:
            'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=900&q=80',
        category: categories[3],
        shopId: 4,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 7)),
      ),
      Product(
        id: 208,
        title: 'Coffret cadeau artisanal',
        description: 'Coffret avec objets faits main et produits du terroir.',
        price: 19.90,
        quantity: 6,
        image:
            'https://images.unsplash.com/photo-1512436991641-6745cdb1723f?auto=format&fit=crop&w=900&q=80',
        category: categories[3],
        shopId: 4,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      Product(
        id: 209,
        title: 'Mangues de saison',
        description: 'Mangues sucrées cultivées localement.',
        price: 4.20,
        quantity: 15,
        image:
            'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=900&q=80',
        category: categories[0],
        shopId: 1,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 9)),
      ),
      Product(
        id: 210,
        title: 'Huile d’olive artisanale',
        description: 'Huile de qualité pour une cuisine gourmande.',
        price: 7.50,
        quantity: 9,
        image:
            'https://images.unsplash.com/photo-1473093295043-cdd812d0e601?auto=format&fit=crop&w=900&q=80',
        category: categories[1],
        shopId: 2,
        isActive: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 10)),
      ),
    ];
  }
}

class Category {
  final int id;
  final String name;
  final String? translatedName;
  final String categoryType;

  Category({
    required this.id,
    required this.name,
    this.translatedName,
    required this.categoryType,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: _parseInt(json['id']),
      name: _parseString(json['name']) ?? '',
      translatedName: _parseString(json['translated_name']),
      categoryType: _parseString(json['category_type']) ?? 'product',
    );
  }

  static List<Category> mockCategories() {
    return [
      Category(
        id: 1,
        name: 'Fruits & Légumes',
        translatedName: 'Fruits & Légumes',
        categoryType: 'product',
      ),
      Category(
        id: 2,
        name: 'Épicerie locale',
        translatedName: 'Épicerie locale',
        categoryType: 'product',
      ),
      Category(
        id: 3,
        name: 'Produits laitiers',
        translatedName: 'Produits laitiers',
        categoryType: 'product',
      ),
      Category(
        id: 4,
        name: 'Artisanat',
        translatedName: 'Artisanat',
        categoryType: 'product',
      ),
      Category(
        id: 5,
        name: 'Services de santé',
        translatedName: 'Services de santé',
        categoryType: 'professional',
      ),
      Category(
        id: 6,
        name: 'Transport & livraison',
        translatedName: 'Transport & livraison',
        categoryType: 'professional',
      ),
      Category(
        id: 7,
        name: 'Formation',
        translatedName: 'Formation',
        categoryType: 'professional',
      ),
    ];
  }
}
