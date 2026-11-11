import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/cart_service.dart';
import 'package:mobile/screens/payment_webview.dart';

class PaymentResultScreen extends StatefulWidget {
  final int orderId;
  final String provider;
  final String status;
  final String title;

  const PaymentResultScreen({
    super.key,
    required this.orderId,
    required this.provider,
    required this.status,
    required this.title,
  });

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    if (widget.status.toLowerCase() == 'paid') {
      CartService.clearCart();
    }
  }

  Future<void> _retryPayment() async {
    setState(() => _isRetrying = true);
    try {
      final paymentRes = await ApiService.createPayment(
        orderId: widget.orderId,
        provider: widget.provider,
      );
      if (paymentRes == null || paymentRes['payment_url'] == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible de relancer le paiement.')),
        );
        return;
      }

      final paymentUrl = paymentRes['payment_url'] as String;
      if (!mounted) return;

      final webRes = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              PaymentWebView(orderId: widget.orderId, url: paymentUrl),
        ),
      );

      if (!mounted) return;
      if (webRes != null && webRes is Map && webRes['status'] == 'paid') {
        await CartService.clearCart();
        if (!mounted) return;
        Navigator.of(context).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Paiement confirmé.')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Paiement non confirmé.')));
      }
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = widget.status.toLowerCase() == 'paid';
    final isFailed = widget.status.toLowerCase() == 'failed';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFF1f2937),
      ),
      backgroundColor: const Color(0xFF0f172a),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              isPaid ? Icons.check_circle : Icons.warning_rounded,
              size: 80,
              color: isPaid ? Colors.greenAccent : Colors.amber,
            ),
            const SizedBox(height: 24),
            Text(
              isPaid
                  ? 'Paiement confirmé'
                  : isFailed
                  ? 'Paiement échoué'
                  : 'Paiement en attente',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isPaid
                  ? 'Votre commande a bien été enregistrée et le paiement a été confirmé.'
                  : isFailed
                  ? 'Le paiement n’a pas été finalisé. Vous pouvez réessayer ou vérifier vos commandes plus tard.'
                  : 'Le paiement est en attente. Vous pouvez rafraîchir ou fermer cet écran pour revenir plus tard.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 36),
            if (!isPaid)
              ElevatedButton(
                onPressed: _isRetrying ? null : _retryPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurpleAccent,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  _isRetrying ? 'Relance en cours...' : 'Réessayer le paiement',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                isPaid ? 'Retour à l’accueil' : 'Voir mes commandes',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
