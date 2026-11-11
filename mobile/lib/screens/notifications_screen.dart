import 'package:flutter/material.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/widgets/chat_window_host.dart';
import 'package:mobile/models/notification.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/auth_service.dart';

class NotificationsScreen extends StatefulWidget {
  final Future<void> Function()? onNotificationRead;

  const NotificationsScreen({super.key, this.onNotificationRead});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<NotificationItem>> _notificationsFuture;
  bool _showUnreadOnly = false;
  bool _isMarkingAllRead = false;
  final Set<int> _handlingFriendRequests = {};

  @override
  void initState() {
    super.initState();
    _notificationsFuture = ApiService.fetchNotifications();
  }

  Future<void> _markRead(int notificationId) async {
    final success = await ApiService.markNotificationRead(notificationId);
    if (success && mounted) {
      setState(() {
        _notificationsFuture = ApiService.fetchNotifications();
      });
      await widget.onNotificationRead?.call();
    }
  }

  Future<void> _markAllRead() async {
    if (_isMarkingAllRead) return;
    setState(() => _isMarkingAllRead = true);
    final success = await ApiService.markAllNotificationsRead();
    if (!mounted) return;
    setState(() {
      _isMarkingAllRead = false;
      if (success) _notificationsFuture = ApiService.fetchNotifications();
    });
    if (success) {
      await widget.onNotificationRead?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de tout marquer comme lu.')),
      );
    }
  }

  Future<void> _openNotification(NotificationItem notification) async {
    if (!notification.isRead) await _markRead(notification.id);
    if (!mounted) return;

    switch (notification.type) {
      case 'message':
        final room = notification.data?['room']?.toString();
        if (room != null && room.isNotEmpty) {
          await ChatWindowHost.openChat(context, roomId: room);
        } else {
          await Navigator.of(context).pushNamed('/messages');
        }
      case 'stock':
        await _openSellerDashboard();
      case 'order':
        if (notification.data?['audience'] == 'seller') {
          await _openSellerDashboard();
        }
      case 'friend_request':
        final data = notification.data;
        final username = data?['requester_username']?.toString();
        final userId = int.tryParse(data?['requester_id']?.toString() ?? '');
        if (username != null && username.isNotEmpty && userId != null) {
          await Navigator.of(context).pushNamed(
            '/user_profile',
            arguments: User(
              id: userId,
              username: username,
              email: '',
              firstName: data?['requester_first_name']?.toString(),
              lastName: data?['requester_last_name']?.toString(),
              role: 'particular',
              connectionStatus: 'pending',
              friendRequestId: int.tryParse(
                data?['friend_request_id']?.toString() ?? '',
              ),
              friendRequestDirection: 'incoming',
            ),
          );
          await _reloadAfterFriendAction();
        } else {
          await Navigator.of(context).pushNamed('/profile');
          await _reloadAfterFriendAction();
        }
      case 'game_challenge':
      case 'game_rematch':
      case 'game_challenge_response':
        await Navigator.of(context).pushNamed('/game/legends');
    }
  }

  Future<void> _openSellerDashboard() async {
    final profile = await AuthService.getProfile();
    if (!mounted) return;
    final user = profile['data'];
    if (profile['success'] == true &&
        user is User &&
        user.role.trim().toLowerCase() == 'boutique') {
      await Navigator.of(context).pushNamed('/producer_dashboard');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Le tableau vendeur est réservé au type de profil Boutique.',
        ),
      ),
    );
  }

  Future<void> _reloadAfterFriendAction() async {
    if (!mounted) return;
    setState(() => _notificationsFuture = ApiService.fetchNotifications());
    await widget.onNotificationRead?.call();
  }

  Future<void> _respondToFriendRequest(
    NotificationItem notification,
    String action,
  ) async {
    final requestId = int.tryParse(
      notification.data?['friend_request_id']?.toString() ?? '',
    );
    if (requestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette demande doit être traitée depuis votre profil.'),
        ),
      );
      await Navigator.of(context).pushNamed('/profile');
      return;
    }
    if (_handlingFriendRequests.contains(requestId)) return;
    setState(() => _handlingFriendRequests.add(requestId));

    final success = await ApiService.handleFriendRequestAction(
      requestId,
      action,
    );
    if (!mounted) return;
    setState(() => _handlingFriendRequests.remove(requestId));
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de traiter cette demande.')),
      );
      return;
    }
    await ApiService.markNotificationRead(notification.id);
    await _reloadAfterFriendAction();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action == 'accept'
              ? 'Demande de connexion acceptée.'
              : 'Demande de connexion rejetée.',
        ),
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
    'message' => 'Message',
    'order' => 'Commande',
    'stock' => 'Stock',
    'friend_request' => 'Demande de contact',
    'payment' => 'Paiement',
    'game_challenge' => 'Défi légendaire',
    'game_rematch' => 'Revanche légendaire',
    'game_challenge_response' => 'Réponse à un défi',
    _ => 'Information',
  };

  IconData _typeIcon(String type) => switch (type) {
    'message' => Icons.chat_bubble_outline,
    'order' => Icons.shopping_bag_outlined,
    'stock' => Icons.inventory_2_outlined,
    'friend_request' => Icons.person_add_alt_1,
    'payment' => Icons.payments_outlined,
    'game_challenge' ||
    'game_rematch' ||
    'game_challenge_response' => Icons.sports_esports,
    _ => Icons.notifications_none,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Tout marquer comme lu',
            onPressed: _isMarkingAllRead ? null : _markAllRead,
            icon: _isMarkingAllRead
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<NotificationItem>>(
            future: _notificationsFuture,
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
                        'Impossible de charger les notifications.',
                        style: TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: () => setState(
                          () => _notificationsFuture =
                              ApiService.fetchNotifications(),
                        ),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                );
              }
              final allNotifications = snapshot.data ?? [];
              final notifications = _showUnreadOnly
                  ? allNotifications.where((item) => !item.isRead).toList()
                  : allNotifications;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Toutes'),
                          selected: !_showUnreadOnly,
                          onSelected: (_) =>
                              setState(() => _showUnreadOnly = false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(
                            'Non lues (${allNotifications.where((item) => !item.isRead).length})',
                          ),
                          selected: _showUnreadOnly,
                          onSelected: (_) =>
                              setState(() => _showUnreadOnly = true),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: notifications.isEmpty
                        ? Center(
                            child: Text(
                              _showUnreadOnly
                                  ? 'Vous êtes à jour : aucune notification non lue.'
                                  : 'Aucune notification pour le moment.',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              setState(
                                () => _notificationsFuture =
                                    ApiService.fetchNotifications(),
                              );
                              await _notificationsFuture;
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: notifications.length,
                              separatorBuilder: (context, index) =>
                                  const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final notification = notifications[index];
                                return InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: () => _openNotification(notification),
                                  child: Container(
                                    padding: const EdgeInsets.all(18),
                                    decoration: BoxDecoration(
                                      color: notification.isRead
                                          ? const Color(0xFF111827)
                                          : const Color(0xFF2B1220),
                                      borderRadius: BorderRadius.circular(22),
                                      border: Border.all(
                                        color: notification.isRead
                                            ? const Color.fromRGBO(
                                                255,
                                                255,
                                                255,
                                                0.08,
                                              )
                                            : const Color(0xFF7F1D1D),
                                        width: notification.isRead ? 1 : 1.5,
                                      ),
                                      boxShadow: [
                                        if (!notification.isRead)
                                          const BoxShadow(
                                            color: Color.fromRGBO(
                                              248,
                                              24,
                                              24,
                                              0.18,
                                            ),
                                            blurRadius: 16,
                                            offset: Offset(0, 6),
                                          ),
                                      ],
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: const Color(
                                            0xFF1F2937,
                                          ),
                                          child: Icon(
                                            _typeIcon(notification.type),
                                            color: const Color(0xFFFCA5A5),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      notification.title,
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                      ),
                                                    ),
                                                  ),
                                                  if (!notification.isRead)
                                                    const Icon(
                                                      Icons.circle,
                                                      size: 9,
                                                      color: Color(0xFFB91C1C),
                                                    ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                notification.message,
                                                style: const TextStyle(
                                                  color: Color(0xFFCBD5E1),
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              if (notification.type ==
                                                      'friend_request' &&
                                                  !{
                                                    'accepted',
                                                    'declined',
                                                  }.contains(
                                                    notification
                                                        .data?['status'],
                                                  ))
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 14,
                                                      ),
                                                  child: Wrap(
                                                    spacing: 8,
                                                    runSpacing: 6,
                                                    children: [
                                                      FilledButton(
                                                        onPressed:
                                                            _handlingFriendRequests
                                                                .contains(
                                                                  int.tryParse(
                                                                    notification
                                                                            .data?['friend_request_id']
                                                                            ?.toString() ??
                                                                        '',
                                                                  ),
                                                                )
                                                            ? null
                                                            : () =>
                                                                  _respondToFriendRequest(
                                                                    notification,
                                                                    'accept',
                                                                  ),
                                                        child: const Text(
                                                          'Accepter',
                                                        ),
                                                      ),
                                                      OutlinedButton(
                                                        onPressed:
                                                            _handlingFriendRequests
                                                                .contains(
                                                                  int.tryParse(
                                                                    notification
                                                                            .data?['friend_request_id']
                                                                            ?.toString() ??
                                                                        '',
                                                                  ),
                                                                )
                                                            ? null
                                                            : () =>
                                                                  _respondToFriendRequest(
                                                                    notification,
                                                                    'decline',
                                                                  ),
                                                        child: const Text(
                                                          'Rejeter',
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            _openNotification(
                                                              notification,
                                                            ),
                                                        child: const Text(
                                                          'Voir le profil',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    _typeLabel(
                                                      notification.type,
                                                    ),
                                                    style: const TextStyle(
                                                      color: Color(0xFF9CA3AF),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  Text(
                                                    notification.createdAt
                                                        .toLocal()
                                                        .toString()
                                                        .split('.')
                                                        .first,
                                                    style: const TextStyle(
                                                      color: Color(0xFF9CA3AF),
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
