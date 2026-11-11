// ignore_for_file: library_private_types_in_public_api, deprecated_member_use
import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/cart_service.dart';
import 'package:mobile/screens/payment_result_screen.dart';
import 'package:mobile/screens/payment_webview.dart';
import 'package:mobile/utils/senegal_phone.dart';

class CheckoutScreen extends StatefulWidget {
  final Map<String, Map<String, dynamic>> cartItems;

  const CheckoutScreen({super.key, required this.cartItems});

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String _paymentMethod = 'wave';
  bool _isLoading = false;

  @override
  void dispose() {
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _createOrder() async {
    final address = _addressController.text.trim();
    if (widget.cartItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Votre panier est vide.')));
      return;
    }
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saisissez une adresse de livraison.')),
      );
      return;
    }
    final paymentPhone = normalizeSenegalPhone(_phoneController.text);
    if (_paymentMethod != 'cash_on_delivery' && paymentPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saisissez un numéro sénégalais de 9 chiffres.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final items = widget.cartItems.entries
        .map(
          (entry) => {
            'product': entry.value['product_id'],
            'quantity': entry.value['quantity'],
            if ((entry.value['selected_color'] as String? ?? '').isNotEmpty)
              'selected_color': entry.value['selected_color'],
            if ((entry.value['selected_size'] as String? ?? '').isNotEmpty)
              'selected_size': entry.value['selected_size'],
          },
        )
        .toList();

    final orderData = {
      'items': items,
      'address': address,
      'payment_phone': paymentPhone,
      'payment_method': _paymentMethod,
    };

    Map<String, dynamic> result;
    try {
      result = await ApiService.createOrder(orderData);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La commande n’a pas été créée : $error'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (!result['success']) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erreur: ${result['error']}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final created = result['data'];
    if (_paymentMethod == 'wave' || _paymentMethod == 'orange_money') {
      final provider = _paymentMethod == 'wave' ? 'wave' : 'orange';
      final paymentRes = await ApiService.createPayment(
        orderId: created['id'],
        provider: provider,
      );

      if (!mounted) return;

      if (paymentRes == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Paiement impossible, réessayez.')),
        );
        return;
      }

      final paymentUrl = paymentRes['payment_url'];
      if (paymentUrl == null || paymentUrl is! String || paymentUrl.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Impossible d’ouvrir le paiement.')),
        );
        return;
      }

      final webRes = await navigator.push(
        MaterialPageRoute(
          builder: (_) =>
              PaymentWebView(orderId: created['id'], url: paymentUrl),
        ),
      );

      if (!mounted) return;

      final paymentStatus = webRes is Map && webRes['status'] is String
          ? webRes['status'] as String
          : 'pending';

      await navigator.push(
        MaterialPageRoute(
          builder: (_) => PaymentResultScreen(
            orderId: created['id'],
            provider: provider,
            status: paymentStatus,
            title: paymentStatus == 'paid'
                ? 'Paiement confirmé'
                : paymentStatus == 'failed'
                ? 'Paiement échoué'
                : 'Paiement en attente',
          ),
        ),
      );
      return;
    }

    if (_paymentMethod == 'cash_on_delivery') {
      await CartService.clearCart();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Commande créée avec succès')),
      );
      navigator.popUntil((route) => route.isFirst);
      return;
    }
  }

  double _calculateTotal() {
    double total = 0;
    widget.cartItems.forEach((id, item) {
      total += item['price'] * item['quantity'];
    });
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0f172a),
      appBar: AppBar(
        title: Text('Paiement'),
        backgroundColor: Color(0xFF1f2937),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Adresse de livraison',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _addressController,
                style: TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Adresse complète',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Color(0xFF1f2937),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24),
              Text(
                'Numéro de téléphone',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                style: TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                maxLength: 9,
                enabled: _paymentMethod != 'cash_on_delivery',
                decoration: InputDecoration(
                  hintText: '77 000 00 00',
                  prefixText: _paymentMethod == 'cash_on_delivery'
                      ? null
                      : '+221 ',
                  hintStyle: TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: Color(0xFF1f2937),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'Méthode de paiement',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              ...['wave', 'orange_money', 'cash_on_delivery'].map((method) {
                return GestureDetector(
                  onTap: () => setState(() => _paymentMethod = method),
                  child: Container(
                    margin: EdgeInsets.only(bottom: 12),
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _paymentMethod == method
                          ? Color(0xFF7c3aed)
                          : Color(0xFF1f2937),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _paymentMethod == method
                            ? Color(0xFF7c3aed)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Radio(
                          value: method,
                          groupValue: _paymentMethod,
                          onChanged: (value) =>
                              setState(() => _paymentMethod = value!),
                          activeColor: Colors.white,
                        ),
                        SizedBox(width: 12),
                        Text(
                          method == 'wave'
                              ? 'Wave'
                              : method == 'orange_money'
                              ? 'Orange Money'
                              : 'Espèces à la livraison',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFF111827),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
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
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createOrder,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF7c3aed),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isLoading ? 'Traitement...' : 'Passer la commande',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
