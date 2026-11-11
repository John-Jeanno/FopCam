import 'package:flutter/material.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/models/shop.dart';
import 'package:mobile/services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late Future<List<Shop>> _shopsFuture;
  final TextEditingController _searchController = TextEditingController();
  Position? _currentPosition;
  bool _isLocating = false;

  @override
  void initState() {
    super.initState();
    _shopsFuture = ApiService.fetchShops();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _locateMe() async {
    setState(() => _isLocating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
          'Activez les services de localisation de votre appareil.',
        );
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Autorisez l’accès à votre position pour vous localiser.',
        );
      }

      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() => _currentPosition = position);
      await _openMap(
        position.latitude,
        position.longitude,
        label: 'Ma position',
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Bad state: ', '')),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _openShopLocation(Shop shop) async {
    if (shop.latitude != null && shop.longitude != null) {
      await _openMap(shop.latitude!, shop.longitude!, label: shop.name);
      return;
    }

    final address = [
      shop.name,
      shop.location,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(', ');
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette boutique n’a pas d’adresse renseignée.'),
        ),
      );
      return;
    }

    await _launchMapUri(
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': address,
      }),
    );
  }

  Future<void> _openMap(
    double latitude,
    double longitude, {
    required String label,
  }) async {
    await _launchMapUri(
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': '$label $latitude,$longitude',
      }),
    );
  }

  Future<void> _launchMapUri(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir le service de cartographie.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Carte sociale'),
        actions: [
          IconButton(
            tooltip: 'Actualiser les boutiques',
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
                      'Impossible de charger les boutiques. Vérifiez votre connexion.',
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

            final query = _searchController.text.trim().toLowerCase();
            final shops = (snapshot.data ?? []).where((shop) {
              return query.isEmpty ||
                  shop.name.toLowerCase().contains(query) ||
                  (shop.location?.toLowerCase().contains(query) ?? false);
            }).toList();

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Repérez les boutiques locales et ouvrez leur emplacement dans votre application de cartes.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Rechercher une boutique ou une ville',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _isLocating ? null : _locateMe,
                        icon: _isLocating
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.my_location),
                        label: Text(
                          _currentPosition == null
                              ? 'Ouvrir ma position sur la carte'
                              : 'Ma position : ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: shops.isEmpty
                      ? Center(
                          child: Text(
                            query.isEmpty
                                ? 'Aucune boutique active à afficher.'
                                : 'Aucune boutique ne correspond à cette recherche.',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: shops.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final shop = shops[index];
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.storefront,
                                    color: AppColors.primaryLight,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          shop.name,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          shop.location?.isNotEmpty == true
                                              ? shop.location!
                                              : 'Adresse non renseignée',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Ouvrir dans les cartes',
                                    onPressed: () => _openShopLocation(shop),
                                    icon: const Icon(
                                      Icons.directions,
                                      color: AppColors.primaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
