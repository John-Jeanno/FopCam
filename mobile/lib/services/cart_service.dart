import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/models/product.dart';

class CartService {
  static const String _cartKey = 'cart_items';

  static final ValueNotifier<int> itemCountNotifier = ValueNotifier<int>(0);
  static Map<String, Map<String, dynamic>> _items = {};

  static String _cartKeyFor(int productId, String? color, String? size) =>
      jsonEncode([productId, color ?? '', size ?? '']);

  static Future<void> initialize() async {
    await getCartItems();
  }

  static int _parseQuantity(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static Future<Map<String, Map<String, dynamic>>> getCartItems() async {
    if (_items.isNotEmpty) {
      return _items;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_cartKey);
    if (raw == null || raw.isEmpty) {
      _items = {};
      return _items;
    }

    try {
      final decoded = jsonDecode(raw);
      final items = <String, Map<String, dynamic>>{};
      if (decoded is List) {
        for (final item in decoded) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final productId = int.tryParse(map['product_id']?.toString() ?? '');
            if (productId != null) {
              final color = map['selected_color']?.toString() ?? '';
              final size = map['selected_size']?.toString() ?? '';
              items[_cartKeyFor(productId, color, size)] = {
                'product_id': productId,
                'title': map['title']?.toString() ?? '',
                'price': double.tryParse(map['price']?.toString() ?? '') ?? 0.0,
                'quantity': _parseQuantity(map['quantity']),
                'image': map['image']?.toString(),
                'shop_id': int.tryParse(map['shop_id']?.toString() ?? '') ?? 0,
                'selected_color': color,
                'selected_size': size,
              };
            }
          }
        }
      }
      _items = items;
      _notifyCountChange();
      return _items;
    } catch (_) {
      _items = {};
      _notifyCountChange();
      return _items;
    }
  }

  static Future<void> _saveCart() async {
    final items = _items.values.toList();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cartKey, jsonEncode(items));
    _notifyCountChange();
  }

  static void _notifyCountChange() {
    itemCountNotifier.value = _items.values.fold<int>(0, (sum, item) {
      return sum + _parseQuantity(item['quantity']);
    });
  }

  static Future<void> addItem(
    Product product, {
    int quantity = 1,
    String? selectedColor,
    String? selectedSize,
  }) async {
    final items = await getCartItems();
    final itemKey = _cartKeyFor(product.id, selectedColor, selectedSize);
    final existing = items[itemKey];
    if (existing != null) {
      existing['quantity'] = _parseQuantity(existing['quantity']) + quantity;
      existing['price'] = product.currentPrice;
      if (_parseQuantity(existing['quantity']) <= 0) {
        items.remove(itemKey);
      }
    } else {
      items[itemKey] = {
        'product_id': product.id,
        'title': product.title,
        'price': product.currentPrice,
        'quantity': quantity,
        'image': product.image,
        'shop_id': product.shopId,
        'selected_color': selectedColor ?? '',
        'selected_size': selectedSize ?? '',
      };
    }
    _items = items;
    await _saveCart();
  }

  static Future<void> updateQuantity(String itemKey, int quantity) async {
    final items = await getCartItems();
    if (quantity <= 0) {
      items.remove(itemKey);
    } else if (items.containsKey(itemKey)) {
      items[itemKey]!['quantity'] = quantity;
    }
    _items = items;
    await _saveCart();
  }

  static Future<void> removeItem(String itemKey) async {
    final items = await getCartItems();
    items.remove(itemKey);
    _items = items;
    await _saveCart();
  }

  static Future<void> clearCart() async {
    _items = {};
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cartKey);
    _notifyCountChange();
  }

  static Future<int> getItemCount() async {
    final items = await getCartItems();
    var count = 0;
    for (final item in items.values) {
      count += _parseQuantity(item['quantity']);
    }
    return count;
  }

  static Future<double> getTotal() async {
    final items = await getCartItems();
    var total = 0.0;
    for (final item in items.values) {
      final price = double.tryParse(item['price']?.toString() ?? '') ?? 0.0;
      total += price * _parseQuantity(item['quantity']);
    }
    return total;
  }
}
