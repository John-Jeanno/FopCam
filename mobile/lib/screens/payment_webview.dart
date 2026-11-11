// ignore_for_file: use_build_context_synchronously, library_private_types_in_public_api
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:mobile/services/api_service.dart';

class PaymentWebView extends StatefulWidget {
  final int orderId;
  final String url;

  const PaymentWebView({super.key, required this.orderId, required this.url});

  @override
  _PaymentWebViewState createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  late final WebViewController _controller;
  Timer? _pollTimer;
  bool _isChecking = false;
  bool _isPageLoading = true;
  String _statusText = 'Vérification du paiement...';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            setState(() => _isPageLoading = true);
          },
          onPageFinished: (_) {
            setState(() => _isPageLoading = false);
          },
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkOrderStatus();
    });

    Future.delayed(const Duration(seconds: 30), () {
      if (!mounted) return;
      if (_pollTimer?.isActive ?? false) {
        setState(
          () => _statusText = 'Vérification en cours, veuillez patienter...',
        );
      }
    });
  }

  Future<void> _checkOrderStatus() async {
    if (_isChecking) return;
    _isChecking = true;
    setState(() => _statusText = 'Vérification du paiement...');
    try {
      final order = await ApiService.getOrder(widget.orderId);
      if (order != null) {
        final status = (order['status'] ?? '').toString().toLowerCase();
        if (status == 'paid' ||
            status == 'completed' ||
            status == 'paid_online') {
          _pollTimer?.cancel();
          if (!mounted) return;
          Navigator.of(context).pop({'status': 'paid'});
          return;
        }
        if (status == 'failed' || status == 'cancelled') {
          _pollTimer?.cancel();
          if (!mounted) return;
          Navigator.of(context).pop({'status': 'failed'});
          return;
        }
        if (mounted) {
          setState(() => _statusText = 'Statut actuel: ${order['status']}');
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _statusText = 'Impossible de vérifier le statut. Réessayez.',
        );
      }
    } finally {
      _isChecking = false;
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paiement'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _controller.reload();
              _checkOrderStatus();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isPageLoading) const LinearProgressIndicator(minHeight: 4),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _statusText,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!_isChecking)
                    TextButton(
                      onPressed: _checkOrderStatus,
                      child: const Text(
                        'Rafraîchir',
                        style: TextStyle(color: Colors.white),
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
}
