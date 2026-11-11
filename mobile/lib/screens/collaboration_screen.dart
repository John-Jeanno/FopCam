import 'package:flutter/material.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/models/shop.dart';
import 'package:mobile/services/api_service.dart';

class CollaborationScreen extends StatefulWidget {
  const CollaborationScreen({super.key});

  @override
  State<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends State<CollaborationScreen> {
  late Future<List<Shop>> _shopsFuture;
  final Set<int> _sendingRequests = {};
  final Set<int> _sentRequests = {};

  @override
  void initState() {
    super.initState();
    _shopsFuture = ApiService.fetchShops();
  }

  Future<void> _requestCollaboration(Shop shop) async {
    final ownerId = shop.owner?.id;
    if (ownerId == null || _sendingRequests.contains(shop.id)) return;

    setState(() => _sendingRequests.add(shop.id));
    final sent = await ApiService.sendFriendRequest(ownerId);
    if (!mounted) return;

    setState(() {
      _sendingRequests.remove(shop.id);
      if (sent) _sentRequests.add(shop.id);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? 'Demande de contact envoyée à ${shop.name}. Vous pourrez proposer votre collaboration après acceptation.'
              : 'La demande n’a pas pu être envoyée. Vérifiez votre connexion ou vos demandes en attente.',
        ),
      ),
    );
  }

  void _openShop(Shop shop) {
    Navigator.of(context).pushNamed('/shop', arguments: {'shopId': shop.id});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Collaborations'),
        actions: [
          IconButton(
            tooltip: 'Actualiser les partenaires',
            onPressed: () => setState(() {
              _shopsFuture = ApiService.fetchShops();
            }),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Shop>>(
          future: _shopsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Impossible de charger les partenaires. Vérifiez votre connexion.',
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _shopsFuture = ApiService.fetchShops();
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            }

            final shops = snapshot.data ?? [];
            if (shops.isEmpty) {
              return const Center(
                child: Text(
                  'Aucune boutique active ne peut être contactée pour le moment.',
                  style: TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                setState(() => _shopsFuture = ApiService.fetchShops());
                await _shopsFuture;
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Trouvez un partenaire local. Envoyez une demande de contact, puis échangez pour définir votre projet ensemble.',
                    style: TextStyle(color: Colors.white70, height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  ...shops.map(_buildShopCard),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildShopCard(Shop shop) {
    final ownerName = shop.owner == null
        ? 'Propriétaire non renseigné'
        : [shop.owner!.firstName, shop.owner!.lastName]
              .whereType<String>()
              .where((name) => name.isNotEmpty)
              .join(' ')
              .trim();
    final isSending = _sendingRequests.contains(shop.id);
    final isSent = _sentRequests.contains(shop.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            shop.name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ownerName.isEmpty
                ? shop.owner?.username ?? 'Propriétaire non renseigné'
                : ownerName,
            style: const TextStyle(color: Colors.white),
          ),
          if (shop.description?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Text(
              shop.description!,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white),
            ),
          ],
          if (shop.location?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.white),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    shop.location!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _openShop(shop),
                icon: const Icon(Icons.storefront),
                label: const Text('Voir la boutique'),
              ),
              ElevatedButton.icon(
                onPressed: shop.owner == null || isSending || isSent
                    ? null
                    : () => _requestCollaboration(shop),
                icon: isSending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(isSent ? Icons.check : Icons.handshake_outlined),
                label: Text(
                  isSending
                      ? 'Envoi...'
                      : isSent
                      ? 'Demande envoyée'
                      : 'Contacter pour collaborer',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
