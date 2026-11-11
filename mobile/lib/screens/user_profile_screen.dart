import 'package:flutter/material.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/widgets/chat_window_host.dart';
import 'package:mobile/utils/media_url_helper.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key, required this.user});

  final User user;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<User> _profileFuture;
  bool _connectionActionInProgress = false;
  bool _openingConversation = false;
  String? _connectionStatus;
  String? _requestDirection;
  int? _friendRequestId;

  @override
  void initState() {
    super.initState();
    _connectionStatus = widget.user.connectionStatus;
    _requestDirection = widget.user.friendRequestDirection;
    _friendRequestId = widget.user.friendRequestId;
    _profileFuture = ApiService.fetchPublicUser(widget.user.username);
  }

  Future<void> _sendConnectionRequest() async {
    if (_connectionActionInProgress) return;
    setState(() => _connectionActionInProgress = true);
    final result = await ApiService.sendFriendRequestWithResult(widget.user.id);
    if (!mounted) return;
    setState(() {
      _connectionActionInProgress = false;
      if (result['success'] == true) {
        _connectionStatus = 'pending';
        _requestDirection = 'outgoing';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['success'] == true
              ? 'Demande de connexion envoyée.'
              : result['error']?.toString() ??
                    'Impossible d’envoyer la demande.',
        ),
      ),
    );
  }

  Future<void> _respondToRequest(String action, {int? requestId}) async {
    requestId ??= _friendRequestId;
    if (requestId == null || _connectionActionInProgress) return;
    setState(() => _connectionActionInProgress = true);
    final success = await ApiService.handleFriendRequestAction(
      requestId,
      action,
    );
    if (!mounted) return;
    setState(() {
      _connectionActionInProgress = false;
      if (success) {
        _connectionStatus = action == 'accept' ? 'accepted' : null;
        _requestDirection = null;
        _friendRequestId = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? action == 'accept'
                    ? 'Demande acceptée.'
                    : 'Demande rejetée.'
              : 'Impossible de traiter cette demande.',
        ),
      ),
    );
  }

  Future<void> _openPrivateConversation() async {
    if (_openingConversation) return;
    setState(() => _openingConversation = true);
    final conversation = await ApiService.startConversation(widget.user.id);
    if (!mounted) return;
    setState(() => _openingConversation = false);
    final roomId = conversation?['room_id'];
    if (roomId is! String || roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir la discussion privée.'),
        ),
      );
      return;
    }
    await ChatWindowHost.openChat(
      context,
      roomId: roomId,
      title: ChatWindowHost.titleForUser(
        username: widget.user.username,
        firstName: widget.user.firstName,
        lastName: widget.user.lastName,
      ),
    );
  }

  Widget _connectionButton({
    required String? connectionStatus,
    required String? requestDirection,
    required int? friendRequestId,
  }) {
    if (connectionStatus == 'accepted') {
      return Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Chip(
            avatar: Icon(Icons.check_circle, color: Color(0xFF86EFAC)),
            label: Text('Ami'),
          ),
          OutlinedButton.icon(
            onPressed: _openingConversation ? null : _openPrivateConversation,
            icon: _openingConversation
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chat_outlined),
            label: const Text('Message privé'),
          ),
        ],
      );
    }
    if (connectionStatus == 'pending' &&
        requestDirection == 'incoming' &&
        friendRequestId != null) {
      return Wrap(
        spacing: 10,
        children: [
          FilledButton(
            onPressed: _connectionActionInProgress
                ? null
                : () => _respondToRequest('accept', requestId: friendRequestId),
            child: const Text('Accepter'),
          ),
          OutlinedButton(
            onPressed: _connectionActionInProgress
                ? null
                : () =>
                      _respondToRequest('decline', requestId: friendRequestId),
            child: const Text('Rejeter'),
          ),
        ],
      );
    }
    if (connectionStatus == 'pending') {
      return const Chip(
        avatar: Icon(Icons.hourglass_top, color: Color(0xFFFDE68A)),
        label: Text('Demande en attente'),
      );
    }
    return FilledButton.icon(
      onPressed: _connectionActionInProgress ? null : _sendConnectionRequest,
      icon: _connectionActionInProgress
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.person_add_alt_1),
      label: const Text('Rejoindre'),
    );
  }

  Widget _profileItemsSection({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> items,
    required String secondaryField,
  }) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Aucune information renseignée pour le moment.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            for (final item in items) ...[
              const SizedBox(height: 12),
              Text(
                item['title']?.toString() ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item[secondaryField]?.toString().trim().isNotEmpty == true)
                Text(
                  item[secondaryField].toString(),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              if (item['start_date']?.toString().trim().isNotEmpty == true ||
                  item['end_date']?.toString().trim().isNotEmpty == true)
                Text(
                  [item['start_date']?.toString(), item['end_date']?.toString()]
                      .where((date) => date?.trim().isNotEmpty == true)
                      .join(' – '),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              if (item['description']?.toString().trim().isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    item['description'].toString(),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _servicesSection(List<Map<String, dynamic>> services) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.handyman_outlined, color: Colors.white70),
                SizedBox(width: 8),
                Text(
                  'Mes services',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (services.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Aucune information renseignée pour le moment.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            for (final service in services) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          service['title']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (service['description']
                                ?.toString()
                                .trim()
                                .isNotEmpty ==
                            true)
                          Text(
                            service['description'].toString(),
                            style: const TextStyle(color: Colors.white70),
                          ),
                      ],
                    ),
                  ),
                  if (service['price'] != null)
                    Text(
                      '${service['price']} ${service['currency'] ?? 'FCFA'}',
                      style: const TextStyle(
                        color: Color(0xFF86EFAC),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profil utilisateur')),
      body: FutureBuilder<User>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: TextButton.icon(
                onPressed: () => setState(
                  () => _profileFuture = ApiService.fetchPublicUser(
                    widget.user.username,
                  ),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Profil indisponible. Réessayer'),
              ),
            );
          }

          final user = snapshot.data!;
          final connectionStatus = _connectionStatus ?? user.connectionStatus;
          final requestDirection =
              _requestDirection ?? user.friendRequestDirection;
          final friendRequestId = _friendRequestId ?? user.friendRequestId;
          final cover = normalizeMediaUrl(user.coverImage);
          final avatar = normalizeMediaUrl(user.profileImage);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: SizedBox(
                  height: 180,
                  child: cover == null
                      ? const ColoredBox(color: AppColors.surfaceAlt)
                      : Image.network(
                          cover,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) =>
                              const ColoredBox(color: AppColors.surfaceAlt),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              CircleAvatar(
                radius: 42,
                backgroundColor: AppColors.surfaceAlt,
                backgroundImage: avatar == null ? null : NetworkImage(avatar),
                child: avatar == null
                    ? Text(
                        user.username.isEmpty
                            ? '?'
                            : user.username[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 14),
              Text(
                '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim().isEmpty
                    ? '@${user.username}'
                    : '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '@${user.username} · ${user.role}',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              if (user.city?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text(
                  user.city!,
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              if (user.bio?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 16),
                Text(user.bio!, style: const TextStyle(color: Colors.white)),
              ],
              _profileItemsSection(
                title: 'Expériences et parcours',
                icon: Icons.work_history_outlined,
                items: user.experienceAndJourney,
                secondaryField: 'organization',
              ),
              _profileItemsSection(
                title: 'Profil et formations',
                icon: Icons.school_outlined,
                items: user.educationAndTraining,
                secondaryField: 'institution',
              ),
              _profileItemsSection(
                title: 'Mes compétences',
                icon: Icons.stars_outlined,
                items: user.skills,
                secondaryField: 'level',
              ),
              _servicesSection(user.services),
              const SizedBox(height: 20),
              _connectionButton(
                connectionStatus: connectionStatus,
                requestDirection: requestDirection,
                friendRequestId: friendRequestId,
              ),
            ],
          );
        },
      ),
    );
  }
}
