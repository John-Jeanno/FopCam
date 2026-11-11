// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:mobile/services/cart_service.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final Map<String, Map<String, dynamic>> _cartItems = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  Future<void> _loadCartItems() async {
    final items = await CartService.getCartItems();
    if (!mounted) return;
    setState(() {
      _cartItems
        ..clear()
        ..addAll(items);
      _loading = false;
    });
  }

  Future<void> _removeFromCart(String itemKey) async {
    await CartService.removeItem(itemKey);
    await _loadCartItems();
  }

  Future<void> _updateQuantity(String itemKey, int quantity) async {
    await CartService.updateQuantity(itemKey, quantity);
    await _loadCartItems();
  }

  double _calculateTotal() {
    double total = 0;
    _cartItems.forEach((id, item) {
      total += item['price'] * item['quantity'];
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0f172a),
      appBar: AppBar(title: Text('Panier'), backgroundColor: Color(0xFF1f2937)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cartItems.isEmpty
          ? Center(
              child: Text(
                'Panier vide',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: _cartItems.length,
                    itemBuilder: (context, index) {
                      final productIds = _cartItems.keys.toList();
                      final itemKey = productIds[index];
                      final Map<String, dynamic> item =
                          Map<String, dynamic>.from(_cartItems[itemKey]!);
                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Color(0xFF111827),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    item['title'],
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _removeFromCart(itemKey),
                                  child: Icon(Icons.close, color: Colors.red),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '${(item['price'] as num).toStringAsFixed(0)} FCFA',
                              style: TextStyle(color: Color(0xFFa5b4fc)),
                            ),
                            if ((item['selected_color'] as String? ?? '')
                                    .isNotEmpty ||
                                (item['selected_size'] as String? ?? '')
                                    .isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                [
                                  if ((item['selected_color'] as String? ?? '')
                                      .isNotEmpty)
                                    'Couleur : ${item['selected_color']}',
                                  if ((item['selected_size'] as String? ?? '')
                                      .isNotEmpty)
                                    'Taille : ${item['selected_size']}',
                                ].join(' · '),
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                            ],
                            SizedBox(height: 12),
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _updateQuantity(
                                    itemKey,
                                    item['quantity'] - 1,
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF1f2937),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '-',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '${(item['quantity'] as int)}',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _updateQuantity(
                                    itemKey,
                                    item['quantity'] + 1,
                                  ),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF1f2937),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '+',
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
                ),
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Color(0xFF111827),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total:',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          Text(
                            '${_calculateTotal().toStringAsFixed(0)} FCFA',
                            style: TextStyle(
                              color: Color(0xFFa5b4fc),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) =>
                                    CheckoutScreen(cartItems: _cartItems),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF7c3aed),
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Procéder au paiement',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
