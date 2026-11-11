import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/screens/feed_screen.dart';
import 'package:mobile/widgets/home_sections.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/widgets/cart_badge.dart';
import 'package:mobile/widgets/user_directory_section.dart';
import 'package:mobile/services/storage_service.dart';

class HomeScreen extends StatefulWidget {
  final ValueNotifier<int>? refreshNotifier;
  final ValueNotifier<int>? incomingGameChallengeCount;

  const HomeScreen({
    super.key,
    this.refreshNotifier,
    this.incomingGameChallengeCount,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoggedIn = false;
  bool _sessionChecked = false;
  User? _currentUser;
  final GlobalKey<FeedScreenState> _feedKey = GlobalKey<FeedScreenState>();

  bool get _hasBoutiqueProfile =>
      _currentUser?.role.trim().toLowerCase() == 'boutique';

  @override
  void initState() {
    super.initState();
    _checkLogin();
    widget.refreshNotifier?.addListener(_onRefreshRequest);
  }

  @override
  void dispose() {
    widget.refreshNotifier?.removeListener(_onRefreshRequest);
    super.dispose();
  }

  Future<void> _checkLogin() async {
    setState(() => _sessionChecked = false);
    final logged = await AuthService.isLoggedIn();
    if (!mounted) return;

    if (!logged) {
      setState(() {
        _isLoggedIn = false;
        _currentUser = null;
        _sessionChecked = true;
      });
      return;
    }

    final profileResult = await AuthService.getProfile();
    if (!mounted) return;

    final accessToken = await StorageService.getAccessToken();
    if (!mounted) return;
    if (accessToken == null || accessToken.isEmpty) {
      setState(() {
        _isLoggedIn = false;
        _currentUser = null;
        _sessionChecked = true;
      });
      return;
    }

    final profileData = profileResult['data'];
    User? profile;
    if (profileResult['success'] == true && profileData is User) {
      profile = profileData;
    } else if (profileResult['cached'] == true && profileData is String) {
      try {
        final decoded = jsonDecode(profileData);
        if (decoded is Map<String, dynamic>) {
          profile = User.fromJson(decoded);
        }
      } on FormatException catch (error) {
        debugPrint('HomeScreen: profil en cache invalide: $error');
      }
    }

    setState(() {
      _isLoggedIn = true;
      _currentUser = profile;
      _sessionChecked = true;
    });
  }

  void _onRefreshRequest() {
    _feedKey.currentState?.refreshAndScrollTop();
  }

  Future<void> _openGameLegends() async {
    await Navigator.of(context).pushNamed('/game/legends');
    if (!mounted) return;
    try {
      final count = await ApiService.fetchIncomingGameChallengeCount();
      widget.incomingGameChallengeCount?.value = count;
    } catch (error) {
      debugPrint('Impossible de rafraîchir les demandes de duel: $error');
    }
  }

  Future<void> _openShopDestination() async {
    if (_isLoggedIn || !_sessionChecked) {
      await _checkLogin();
      if (!mounted) return;
    }

    await Navigator.of(
      context,
    ).pushNamed(_hasBoutiqueProfile ? '/producer_dashboard' : '/shops');
  }

  Widget _gameLegendsIcon() {
    final notifier = widget.incomingGameChallengeCount;
    if (notifier == null) return const Icon(Icons.workspace_premium);
    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (context, count, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.workspace_premium),
          if (count > 0)
            Positioned(
              right: -8,
              top: -7,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F1D1D),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.videogame_asset),
            onPressed: () => Navigator.of(context).pushNamed('/game'),
          ),
          IconButton(
            tooltip: 'Légendes du jeu',
            icon: _gameLegendsIcon(),
            onPressed: _openGameLegends,
          ),
          CartBadge(onPressed: () => Navigator.of(context).pushNamed('/cart')),
          IconButton(
            tooltip: _hasBoutiqueProfile
                ? 'Ma boutique'
                : 'Visiter les boutiques',
            icon: const Icon(Icons.storefront),
            onPressed: _openShopDestination,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: NestedScrollView(
              headerSliverBuilder: (context, _) => [
                SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 18,
                    ),
                    color: AppColors.background,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Bienvenue sur FopCam',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Découvrez les dernières publications et partagez vos idées si vous êtes connecté.',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                const SliverToBoxAdapter(child: HomeSections()),
                if (_isLoggedIn)
                  const SliverToBoxAdapter(child: UserDirectorySection()),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
              ],
              body: FeedScreen(
                key: _feedKey,
                isLoggedIn: _isLoggedIn,
                currentUser: _currentUser,
                isSessionChecked: _sessionChecked,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
