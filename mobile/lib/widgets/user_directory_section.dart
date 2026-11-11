import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/screens/user_profile_screen.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/utils/media_url_helper.dart';

class UserDirectorySection extends StatefulWidget {
  const UserDirectorySection({super.key});

  @override
  State<UserDirectorySection> createState() => _UserDirectorySectionState();
}

class _UserDirectorySectionState extends State<UserDirectorySection> {
  static const double _itemExtent = 178;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  late Future<List<User>> _usersFuture;
  Timer? _scrollTimer;
  Timer? _searchDebounce;
  bool _onlineOnly = false;
  int? _positionedUserCount;
  final Set<int> _sendingRequests = {};

  @override
  void initState() {
    super.initState();
    _usersFuture = ApiService.fetchUserDirectory();
    _scrollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _advanceCarousel(),
    );
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _searchDebounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _loadUsers({bool? onlineOnly, String? search}) {
    if (onlineOnly != null) _onlineOnly = onlineOnly;
    setState(() {
      _positionedUserCount = null;
      _usersFuture = ApiService.fetchUserDirectory(
        onlineOnly: _onlineOnly,
        search: search ?? _searchController.text,
      );
    });
  }

  void _scheduleSearch(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => _loadUsers(),
    );
  }

  void _advanceCarousel() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.maxScrollExtent <= 0) return;

    final copyExtent = _positionedUserCount == null
        ? 0.0
        : _positionedUserCount! * _itemExtent;
    var target = position.pixels + _itemExtent * 0.75;
    if (copyExtent > 0 &&
        (target >= copyExtent * 2 || target > position.maxScrollExtent)) {
      var wrapped = target - copyExtent;
      if (wrapped < 0) wrapped += copyExtent;
      _scrollController.jumpTo(wrapped.clamp(0, position.maxScrollExtent));
      return;
    }
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _openProfile(User user) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => UserProfileScreen(user: user)),
    );
    if (mounted) _loadUsers(onlineOnly: _onlineOnly);
  }

  Future<void> _sendRequest(User user) async {
    if (_sendingRequests.contains(user.id)) return;
    setState(() => _sendingRequests.add(user.id));
    final result = await ApiService.sendFriendRequestWithResult(user.id);
    if (!mounted) return;
    setState(() => _sendingRequests.remove(user.id));

    if (result['success'] == true) {
      _loadUsers(onlineOnly: _onlineOnly);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Demande envoyée à @${user.username}.')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result['error']?.toString() ??
              'Impossible d’envoyer cette demande de connexion.',
        ),
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final imageUrl = normalizeMediaUrl(user.profileImage);
    final requestPending = user.connectionStatus == 'pending';
    final incomingRequest =
        requestPending && user.friendRequestDirection == 'incoming';
    final connected = user.connectionStatus == 'accepted';

    return SizedBox(
      width: _itemExtent - 10,
      child: InkWell(
        onTap: () => _openProfile(user),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceAlt,
                      shape: BoxShape.circle,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl == null
                        ? _fallbackAvatar(user)
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _fallbackAvatar(user),
                          ),
                  ),
                  if (user.isOnline)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                user.firstName?.trim().isNotEmpty == true
                    ? user.firstName!
                    : '@${user.username}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              SizedBox(
                height: 28,
                child: connected
                    ? const Text(
                        'Ami',
                        style: TextStyle(
                          color: Color(0xFF86EFAC),
                          fontSize: 11,
                        ),
                      )
                    : requestPending
                    ? Text(
                        incomingRequest ? 'Demande reçue' : 'En attente',
                        style: const TextStyle(
                          color: Color(0xFFFDE68A),
                          fontSize: 11,
                        ),
                      )
                    : TextButton.icon(
                        onPressed: _sendingRequests.contains(user.id)
                            ? null
                            : () => _sendRequest(user),
                        icon: _sendingRequests.contains(user.id)
                            ? const SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                ),
                              )
                            : const Icon(Icons.person_add_alt_1, size: 14),
                        label: const Text('Rejoindre'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 10),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackAvatar(User user) => Center(
    child: Text(
      user.username.isEmpty ? '?' : user.username[0].toUpperCase(),
      style: const TextStyle(color: Colors.white, fontSize: 24),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Utilisateurs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              FilterChip(
                label: const Text('En ligne'),
                selected: _onlineOnly,
                onSelected: (selected) => _loadUsers(onlineOnly: selected),
                avatar: const Icon(Icons.circle, size: 10),
              ),
              IconButton(
                tooltip: 'Actualiser les utilisateurs',
                onPressed: () => _loadUsers(onlineOnly: _onlineOnly),
                icon: const Icon(Icons.refresh, color: Colors.white70),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Découvrez des profils, consultez leur page et envoyez une demande de connexion.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: _scheduleSearch,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) {
              _searchDebounce?.cancel();
              _loadUsers();
            },
            decoration: InputDecoration(
              hintText: 'Rechercher un utilisateur',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Effacer la recherche',
                      onPressed: () {
                        _searchController.clear();
                        _loadUsers();
                      },
                      icon: const Icon(Icons.clear),
                    ),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          FutureBuilder<List<User>>(
            future: _usersFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 118,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return SizedBox(
                  height: 118,
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () => _loadUsers(onlineOnly: _onlineOnly),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Impossible de charger. Réessayer'),
                    ),
                  ),
                );
              }
              final users = snapshot.data ?? const <User>[];
              if (users.isEmpty) {
                return SizedBox(
                  height: 118,
                  child: Center(
                    child: Text(
                      _onlineOnly
                          ? 'Aucun utilisateur en ligne actuellement.'
                          : _searchController.text.trim().isNotEmpty
                          ? 'Aucun utilisateur trouvé.'
                          : 'Aucun autre utilisateur inscrit pour le moment.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }
              if (_positionedUserCount != users.length) {
                _positionedUserCount = users.length;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.jumpTo(users.length * _itemExtent);
                  }
                });
              }
              return SizedBox(
                height: 136,
                child: ListView.builder(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemExtent: _itemExtent,
                  itemCount: users.length > 1 ? users.length * 3 : users.length,
                  itemBuilder: (context, index) =>
                      _buildUserCard(users[index % users.length]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
