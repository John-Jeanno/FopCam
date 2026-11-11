import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/screens/create_hub_screen.dart';
import 'package:mobile/screens/explorer_screen.dart';
import 'package:mobile/screens/home_screen.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/messages_screen.dart';
import 'package:mobile/screens/notifications_screen.dart';
import 'package:mobile/screens/profile_screen.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/notification_sound_service.dart';
import 'package:mobile/services/app_badge_service.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/story_offline_service.dart';
import 'package:mobile/services/offline_data_service.dart';
import 'package:mobile/widgets/offline_status_banner.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final ValueNotifier<int> _homeRefreshNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _unreadNotificationCount = ValueNotifier<int>(0);
  final ValueNotifier<int> _unreadMessageCount = ValueNotifier<int>(0);
  final ValueNotifier<int> _pendingFriendRequestCount = ValueNotifier<int>(0);
  final ValueNotifier<int> _incomingGameChallengeCount = ValueNotifier<int>(0);
  Timer? _badgeRefreshTimer;
  Timer? _presenceRefreshTimer;
  Timer? _notificationRefreshTimer;
  bool _loadingBadges = false;
  bool _checkingNotifications = false;
  bool _hasNotificationBaseline = false;
  bool _appIsActive = true;
  bool _redirectingToLogin = false;
  final DateTime _appOpenedAt = DateTime.now();
  final Set<int> _knownNotificationIds = {};
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthService.sessionExpired.addListener(_onSessionExpired);
    _screens = [
      HomeScreen(
        refreshNotifier: _homeRefreshNotifier,
        incomingGameChallengeCount: _incomingGameChallengeCount,
      ),
      const ExplorerScreen(),
      CreateHubScreen(onStoryCreated: _onStoryCreated),
      MessagesScreen(onMessagesRead: _loadBadgeCounts),
      NotificationsScreen(onNotificationRead: _loadBadgeCounts),
      ProfileScreen(onFriendRequestsChanged: _loadBadgeCounts),
    ];
    _selectedIndex = widget.initialIndex.clamp(0, _screens.length - 1).toInt();
    _loadBadgeCounts();
    unawaited(_loadNotificationSoundPreferences());
    _checkForNewNotifications();
    _refreshPresence();
    _presenceRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _refreshPresence(),
    );
    _badgeRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadBadgeCounts(),
    );
    _notificationRefreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _checkForNewNotifications(),
    );
  }

  void _onSessionExpired() {
    if (!AuthService.sessionExpired.value || _redirectingToLogin || !mounted) {
      return;
    }

    _redirectingToLogin = true;
    AuthService.sessionExpired.value = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appIsActive = state == AppLifecycleState.resumed;
    if (_appIsActive) {
      _loadBadgeCounts();
      unawaited(StoryOfflineService.syncPending());
      unawaited(OfflineDataService.syncPendingChanges());
      _refreshPresence();
      _checkForNewNotifications();
    }
  }

  Future<void> _refreshPresence() async {
    if (!_appIsActive) return;
    final updated = await ApiService.pingUserPresence();
    if (!updated) {
      debugPrint('La présence utilisateur n’a pas pu être synchronisée.');
    }
  }

  Future<void> _loadNotificationSoundPreferences() async {
    final result = await AuthService.getProfile();
    final user = result['data'];
    if (result['success'] == true && user is User) {
      await NotificationSoundService.applyServerPreferences(
        user.notificationSounds,
      );
    } else if (result['success'] != true) {
      debugPrint(
        'Préférences de sonneries non synchronisées: ${result['error']}',
      );
    }
  }

  Future<void> _checkForNewNotifications() async {
    if (!_appIsActive || _checkingNotifications) return;
    _checkingNotifications = true;
    try {
      final notifications = await ApiService.fetchNotifications();
      if (!mounted) return;
      final currentIds = notifications.map((item) => item.id).toSet();
      final establishingBaseline = !_hasNotificationBaseline;
      final pendingChallengeIds = establishingBaseline
          ? (await ApiService.fetchGameChallenges())
                .where(
                  (challenge) =>
                      challenge.isIncoming && challenge.status == 'pending',
                )
                .map((challenge) => challenge.id)
                .toSet()
          : const <int>{};
      if (!mounted) return;
      final received =
          notifications.where((item) {
              final challengeId = int.tryParse(
                item.data?['challenge_id']?.toString() ?? '',
              );
              final isPendingChallenge =
                  establishingBaseline &&
                  (item.type == 'game_challenge' ||
                      item.type == 'game_rematch') &&
                  challengeId != null &&
                  pendingChallengeIds.contains(challengeId);
              return isPendingChallenge ||
                  (!item.isRead &&
                      (establishingBaseline
                          ? item.createdAt.isAfter(_appOpenedAt)
                          : !_knownNotificationIds.contains(item.id)));
            }).toList()
            ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
      _knownNotificationIds.addAll(currentIds);
      _hasNotificationBaseline = true;
      for (final notification in received) {
        await NotificationSoundService.play(notification);
      }
    } catch (error, stackTrace) {
      debugPrint('Détection des nouvelles notifications impossible: $error');
      debugPrint('$stackTrace');
    } finally {
      _checkingNotifications = false;
    }
  }

  Future<void> _loadBadgeCounts() async {
    if (_loadingBadges) return;
    _loadingBadges = true;
    try {
      final results = await Future.wait<Object>([
        ApiService.fetchNotifications(),
        ApiService.fetchPendingFriendRequestCount(),
        ApiService.fetchUnreadMessageCount(),
        ApiService.fetchIncomingGameChallengeCount(),
      ]);
      if (!mounted) return;
      final notifications = results[0] as List;
      _unreadNotificationCount.value = notifications
          .where((item) => !item.isRead)
          .length;
      _pendingFriendRequestCount.value = results[1] as int;
      _unreadMessageCount.value = results[2] as int;
      _incomingGameChallengeCount.value = results[3] as int;
      unawaited(
        AppBadgeService.updateCount(
          _unreadNotificationCount.value + _unreadMessageCount.value,
        ),
      );
    } catch (error) {
      debugPrint('Impossible de rafraîchir les badges: $error');
    } finally {
      _loadingBadges = false;
    }
  }

  Widget _buildBadgeIcon(IconData icon, ValueNotifier<int> countNotifier) {
    return ValueListenableBuilder<int>(
      valueListenable: countNotifier,
      builder: (context, count, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon),
          if (count > 0)
            Positioned(
              right: -8,
              top: -7,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
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

  Future<void> _openCreateShortcut() async {
    final action = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.add_photo_alternate),
              title: const Text('Publier un statut'),
              subtitle: const Text('Photo, vidéo ou texte'),
              onTap: () => Navigator.pop(context, 0),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_customize),
              title: const Text('Autres créations'),
              subtitle: const Text('Produits, boutique, direct, emploi…'),
              onTap: () => Navigator.pop(context, 1),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 1) {
      setState(() => _selectedIndex = 2);
      return;
    }

    if (!await AuthService.isLoggedIn()) {
      if (!mounted) return;
      await Navigator.of(context, rootNavigator: true).pushNamed('/login');
      if (!mounted) return;
      final loggedInAfterLogin = await AuthService.isLoggedIn();
      if (!mounted || !loggedInAfterLogin) return;
    }
    if (!mounted) return;
    final created = await Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamed<bool>('/create_story');
    if (created == true) _onStoryCreated();
  }

  void _onNavTapped(int index) {
    if (index == 2) {
      _loadBadgeCounts();
      _openCreateShortcut();
      return;
    }
    if (index == 0 && _selectedIndex == 0) {
      _homeRefreshNotifier.value += 1;
    }
    _loadBadgeCounts();
    setState(() => _selectedIndex = index);
  }

  void _onStoryCreated() {
    _homeRefreshNotifier.value += 1;
    if (mounted) setState(() => _selectedIndex = 0);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AuthService.sessionExpired.removeListener(_onSessionExpired);
    _badgeRefreshTimer?.cancel();
    _presenceRefreshTimer?.cancel();
    _notificationRefreshTimer?.cancel();
    _homeRefreshNotifier.dispose();
    _unreadNotificationCount.dispose();
    _unreadMessageCount.dispose();
    _pendingFriendRequestCount.dispose();
    _incomingGameChallengeCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWideLayout = MediaQuery.sizeOf(context).width >= 1000;
    final selectedScreen = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1920),
        child: _screens[_selectedIndex],
      ),
    );

    return Scaffold(
      body: Column(
        children: [
          const OfflineStatusBanner(),
          Expanded(
            child: isWideLayout
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: _selectedIndex,
                        onDestinationSelected: _onNavTapped,
                        labelType: NavigationRailLabelType.selected,
                        minWidth: 76,
                        backgroundColor: Theme.of(
                          context,
                        ).scaffoldBackgroundColor,
                        destinations: [
                          NavigationRailDestination(
                            icon: Icon(Icons.home),
                            label: Text('Accueil'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.travel_explore),
                            label: Text('Découvrir'),
                          ),
                          NavigationRailDestination(
                            icon: Icon(Icons.add_circle),
                            label: Text('Créer'),
                          ),
                          NavigationRailDestination(
                            icon: _buildBadgeIcon(
                              Icons.chat_bubble,
                              _unreadMessageCount,
                            ),
                            label: Text('Messages'),
                          ),
                          NavigationRailDestination(
                            icon: _buildBadgeIcon(
                              Icons.notifications,
                              _unreadNotificationCount,
                            ),
                            label: Text('Notifications'),
                          ),
                          NavigationRailDestination(
                            icon: _buildBadgeIcon(
                              Icons.person,
                              _pendingFriendRequestCount,
                            ),
                            label: Text('Profil'),
                          ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: selectedScreen),
                    ],
                  )
                : selectedScreen,
          ),
        ],
      ),
      bottomNavigationBar: isWideLayout
          ? null
          : BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onNavTapped,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Theme.of(
                context,
              ).bottomNavigationBarTheme.backgroundColor,
              selectedItemColor: Theme.of(
                context,
              ).bottomNavigationBarTheme.selectedItemColor,
              unselectedItemColor: Theme.of(
                context,
              ).bottomNavigationBarTheme.unselectedItemColor,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'Accueil',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.travel_explore),
                  label: 'Découvrir',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle),
                  label: '+',
                ),
                BottomNavigationBarItem(
                  icon: _buildBadgeIcon(Icons.chat_bubble, _unreadMessageCount),
                  label: 'Messages',
                ),
                BottomNavigationBarItem(
                  icon: ValueListenableBuilder<int>(
                    valueListenable: _unreadNotificationCount,
                    builder: (context, count, child) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications),
                          if (count > 0)
                            Positioned(
                              right: -6,
                              top: -4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 1.2,
                                  ),
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  count > 99 ? '99+' : '$count',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  label: 'Notifications',
                ),
                BottomNavigationBarItem(
                  icon: _buildBadgeIcon(
                    Icons.person,
                    _pendingFriendRequestCount,
                  ),
                  label: 'Profil',
                ),
              ],
            ),
    );
  }
}
