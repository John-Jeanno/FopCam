class Order {
  final int id;
  final double total;
  final String status;
  final DateTime createdAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.total,
    required this.status,
    required this.createdAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    List<OrderItem> items = [];
    if (json['items'] != null) {
      items = (json['items'] as List).map((item) => OrderItem.fromJson(item)).toList();
    }

    return Order(
      id: json['id'] ?? 0,
      total: (json['total'] ?? 0).toDouble(),
      status: json['status'] ?? 'pending',
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      items: items,
    );
  }
}

class OrderItem {
  final int id;
  final int productId;
  final String productTitle;
  final double price;
  final int quantity;
  final String? productImage;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.price,
    required this.quantity,
    this.productImage,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? 0,
      productId: json['product']?['id'] ?? json['product_id'] ?? 0,
      productTitle: json['product']?['title'] ?? json['product_title'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      productImage: json['product_image'],
    );
  }
}
