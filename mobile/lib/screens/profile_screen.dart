// ignore_for_file: library_private_types_in_public_api

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/widgets/profile_portfolio_editor.dart';
import 'login_screen.dart';
import 'package:mobile/utils/media_url_helper.dart';

class ProfileScreen extends StatefulWidget {
  final Future<void> Function()? onFriendRequestsChanged;

  const ProfileScreen({super.key, this.onFriendRequestsChanged});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _FriendRequestTile extends StatelessWidget {
  const _FriendRequestTile({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final Map<String, dynamic> request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final requester = request['requester'];
    final name = requester is Map
        ? (requester['first_name']?.toString().trim().isNotEmpty == true
              ? requester['first_name'].toString()
              : requester['username']?.toString() ?? 'Utilisateur')
        : 'Utilisateur';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(color: Colors.white)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(onPressed: onAccept, child: const Text('Accepter')),
              OutlinedButton(
                onPressed: onDecline,
                child: const Text('Rejeter'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;
  XFile? _profileImage;
  XFile? _coverImage;
  Uint8List? _profileImageBytes;
  Uint8List? _coverImageBytes;
  bool _isUpdatingImages = false;
  bool _isUpdatingRole = false;
  late Future<List<Map<String, dynamic>>> _friendRequestsFuture;
  late Future<Map<String, dynamic>> _roleQuotaFuture;

  static const _profileRoles = {
    'particular': 'Particulier',
    'producer': 'Producteur',
    'boutique': 'Boutique',
    'prestataire': 'Prestataire',
    'enterprise': 'Entreprise',
    'influencer': 'Influenceur',
    'community_lead': 'Responsable communautaire',
    'driver': 'Livreur',
  };

  @override
  void initState() {
    super.initState();
    _profileFuture = _getProfile();
    _friendRequestsFuture = ApiService.fetchFriendRequests();
    _roleQuotaFuture = ApiService.fetchProfileRoleChangeQuota();
  }

  Future<Map<String, dynamic>> _getProfile() async {
    return await AuthService.getProfile();
  }

  Future<void> _changeProfileRole(User user, String role) async {
    if (role == user.role || _isUpdatingRole) return;
    setState(() => _isUpdatingRole = true);
    try {
      final quota = await ApiService.changeProfileRole(role);
      final profileResult = await AuthService.getProfile();
      if (!mounted) return;
      if (profileResult['success'] != true || profileResult['data'] is! User) {
        throw StateError('Le nouveau type de profil n’a pas été confirmé.');
      }
      setState(() {
        _profileFuture = Future.value(profileResult);
        _roleQuotaFuture = Future.value(quota);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Type de profil modifié : ${_profileRoles[role] ?? role}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _roleQuotaFuture = ApiService.fetchProfileRoleChangeQuota();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Modification impossible : $error')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingRole = false);
    }
  }

  Widget _buildRoleSettings(User user) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _roleQuotaFuture,
      builder: (context, snapshot) {
        final remaining = snapshot.data?['remaining_changes'];
        final resetAt = DateTime.tryParse(
          snapshot.data?['resets_at']?.toString() ?? '',
        )?.toLocal();
        final currentRole = _profileRoles[user.role] ?? user.role;
        return Card(
          color: const Color(0xFF172033),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Type de profil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Gérez votre type de profil et ses options.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Type de profil',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  snapshot.hasError
                      ? 'Impossible de charger la limite : ${snapshot.error}'
                      : snapshot.connectionState == ConnectionState.waiting
                      ? 'Type actuel : $currentRole'
                      : 'Type actuel : $currentRole · '
                            '${remaining ?? 0} changement(s) restant(s) ce mois-ci'
                            '${resetAt == null ? '' : ' · réinitialisation le ${resetAt.day}/${resetAt.month}/${resetAt.year}'}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _profileRoles.containsKey(user.role)
                      ? user.role
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Changer de type',
                    border: OutlineInputBorder(),
                  ),
                  dropdownColor: const Color(0xFF172033),
                  items: _profileRoles.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      )
                      .toList(),
                  onChanged:
                      _isUpdatingRole ||
                          snapshot.connectionState == ConnectionState.waiting ||
                          snapshot.hasError ||
                          remaining == 0
                      ? null
                      : (role) {
                          if (role != null) {
                            _changeProfileRole(user, role);
                          }
                        },
                ),
                if (_isUpdatingRole)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _respondToFriendRequest(int requestId, String action) async {
    final succeeded = await ApiService.handleFriendRequestAction(
      requestId,
      action,
    );
    if (!mounted) return;
    if (!succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'accept'
                ? 'Impossible d’accepter cette demande.'
                : 'Impossible de rejeter cette demande.',
          ),
        ),
      );
      return;
    }
    setState(() {
      _friendRequestsFuture = ApiService.fetchFriendRequests();
    });
    await widget.onFriendRequestsChanged?.call();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          action == 'accept'
              ? 'Demande d’ami acceptée.'
              : 'Demande d’ami rejetée.',
        ),
      ),
    );
  }

  Widget _buildFriendRequests(int userId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _friendRequestsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            child: ListTile(
              title: const Text('Demandes d’amis'),
              subtitle: Text(
                'Impossible de charger les demandes : ${snapshot.error}',
              ),
              trailing: IconButton(
                tooltip: 'Réessayer',
                icon: const Icon(Icons.refresh),
                onPressed: () => setState(
                  () =>
                      _friendRequestsFuture = ApiService.fetchFriendRequests(),
                ),
              ),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Card(
            child: ListTile(
              title: Text('Demandes d’amis'),
              trailing: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final incoming = snapshot.data!.where((request) {
          final receiver = request['receiver'];
          return request['status'] == 'pending' &&
              receiver is Map &&
              receiver['id'] == userId;
        }).toList();
        if (incoming.isEmpty) return const SizedBox.shrink();

        return Card(
          color: const Color(0xFF2B1220),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0xFF7F1D1D)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demandes d’amis reçues (${incoming.length})',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                for (final request in incoming)
                  _FriendRequestTile(
                    request: request,
                    onAccept: () =>
                        _respondToFriendRequest(request['id'] as int, 'accept'),
                    onDecline: () => _respondToFriendRequest(
                      request['id'] as int,
                      'decline',
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(bool isCover) async {
    try {
      final picker = ImagePicker();
      final result = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 80,
      );

      if (result != null) {
        final bytes = await result.readAsBytes();
        if (!mounted) return;
        setState(() {
          if (isCover) {
            _coverImage = result;
            _coverImageBytes = bytes;
          } else {
            _profileImage = result;
            _profileImageBytes = bytes;
          }
        });
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible de sélectionner la photo : $error'),
          ),
        );
      }
    }
  }

  Future<void> _uploadImages() async {
    if (_profileImage == null && _coverImage == null) {
      return;
    }

    final uploadingProfileImage = _profileImage != null;
    final uploadingCoverImage = _coverImage != null;
    if (!mounted) return;
    setState(() {
      _isUpdatingImages = true;
    });

    final result = await ApiService.updateProfileImages(
      profileImage: _profileImage,
      coverImage: _coverImage,
    );

    if (result['success'] == true) {
      final profileResult = await AuthService.getProfile();
      if (!mounted) return;
      final updatedUser = profileResult['data'];
      final imagesConfirmed =
          profileResult['success'] == true &&
          updatedUser is User &&
          (!uploadingProfileImage || updatedUser.profileImage != null) &&
          (!uploadingCoverImage || updatedUser.coverImage != null);
      if (!imagesConfirmed) {
        setState(() => _isUpdatingImages = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'L’envoi a réussi, mais le serveur ne confirme pas encore '
              'les photos. Elles restent sélectionnées : réessayez.',
            ),
          ),
        );
        return;
      }
      setState(() {
        _isUpdatingImages = false;
        _profileFuture = Future.value(profileResult);
        _profileImage = null;
        _coverImage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Images de profil mises à jour.')),
      );
    } else {
      if (mounted) setState(() => _isUpdatingImages = false);
      if (!mounted) return;
      final error = result['error'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Erreur lors de l’envoi des images : ${error ?? 'Veuillez réessayer.'}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Mon Profil'),
        backgroundColor: const Color(0xFF111827),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || !snapshot.data!['success']) {
              return Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color.fromRGBO(255, 255, 255, 0.08),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color.fromRGBO(255, 255, 255, 0.12),
                    ),
                  ),
                  child: const Text(
                    'Impossible de charger le profil',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              );
            }

            final user = snapshot.data!['data'];
            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFriendRequests(user.id),
                    const SizedBox(height: 14),
                    _buildRoleSettings(user),
                    const SizedBox(height: 14),
                    Card(
                      color: const Color(0xFF172033),
                      child: ListTile(
                        leading: const Icon(
                          Icons.settings_outlined,
                          color: Colors.white,
                        ),
                        title: const Text(
                          'Paramètres',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          'Confidentialité, sécurité et récupération du compte',
                          style: TextStyle(color: Colors.white70),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white70,
                        ),
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed('/profile/settings'),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: double.infinity,
                          height: 220,
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(28),
                            image: DecorationImage(
                              image: _coverImageBytes != null
                                  ? MemoryImage(_coverImageBytes!)
                                  : user.coverImage != null
                                  ? NetworkImage(
                                      normalizeMediaUrl(user.coverImage) ?? '',
                                    )
                                  : const AssetImage(
                                      'assets/images/fopcam-logo.png',
                                    ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 16,
                          right: 16,
                          child: IconButton.filledTonal(
                            tooltip: 'Modifier la photo de couverture',
                            onPressed: _isUpdatingImages
                                ? null
                                : () => _pickImage(true),
                            icon: const Icon(Icons.camera_alt),
                            style: IconButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: const Color.fromRGBO(
                                0,
                                0,
                                0,
                                0.5,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -52,
                          left: 20,
                          child: Stack(
                            children: [
                              Container(
                                width: 116,
                                height: 116,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 10,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _profileImageBytes != null
                                      ? Image.memory(
                                          _profileImageBytes!,
                                          fit: BoxFit.cover,
                                        )
                                      : user.profileImage != null
                                      ? Image.network(
                                          normalizeMediaUrl(
                                                user.profileImage,
                                              ) ??
                                              '',
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: const Color(0xFF1F2937),
                                          child: Center(
                                            child: Text(
                                              user.username.isNotEmpty
                                                  ? user.username[0]
                                                        .toUpperCase()
                                                  : 'U',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 28,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 2,
                                right: 2,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                  child: IconButton(
                                    tooltip: 'Modifier la photo de profil',
                                    onPressed: _isUpdatingImages
                                        ? null
                                        : () => _pickImage(false),
                                    icon: const Icon(
                                      Icons.camera_alt,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                    constraints: const BoxConstraints.tightFor(
                                      width: 36,
                                      height: 36,
                                    ),
                                    padding: EdgeInsets.zero,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 68),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        key: const ValueKey('change-profile-photo'),
                        onPressed: _isUpdatingImages
                            ? null
                            : () => _pickImage(false),
                        icon: const Icon(Icons.account_circle_outlined),
                        label: const Text('Changer la photo de profil'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.08),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.12),
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.22),
                            blurRadius: 24,
                            offset: Offset(0, 14),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.username ?? '-',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user.email ?? '-',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildBadge('Vérifié'),
                              const SizedBox(width: 10),
                              if (user.role.trim().toLowerCase() == 'boutique')
                                _buildBadge('Boutique'),
                              const SizedBox(width: 10),
                              _buildBadge('Top créateur'),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'À la une',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildHighlightCard(
                                  'Histoire produit',
                                  'Nouveautés locales',
                                ),
                                const SizedBox(width: 12),
                                _buildHighlightCard(
                                  'Shopping en direct',
                                  'Prochain direct',
                                ),
                                const SizedBox(width: 12),
                                _buildHighlightCard(
                                  'Clip tendance',
                                  'Recette express',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Détails du profil',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (user.role.contains('producer') ||
                              user.role.contains('shop_owner'))
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(
                                    context,
                                  ).pushNamed('/producer_dashboard');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: const Text(
                                  'Tableau vendeur',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(
                                  context,
                                ).pushNamed('/edit_profile').then((refresh) {
                                  if (refresh == true) {
                                    setState(() {
                                      _profileFuture = _getProfile();
                                    });
                                  }
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryLight,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'Modifier le profil',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final fieldWidth = constraints.maxWidth >= 900
                            ? (constraints.maxWidth - 16) / 2
                            : constraints.maxWidth;
                        return Wrap(
                          spacing: 16,
                          children: [
                            SizedBox(
                              width: fieldWidth,
                              child: _buildProfileField(
                                'Utilisateur',
                                user.username,
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _buildProfileField('Email', user.email),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _buildProfileField(
                                'Prénom',
                                user.firstName ?? '-',
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _buildProfileField(
                                'Nom',
                                user.lastName ?? '-',
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _buildProfileField(
                                'Rôle',
                                user.role.replaceAll('_', ' '),
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _buildProfileField('Bio', user.bio ?? '-'),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _buildProfileField(
                                'Téléphone',
                                user.phone ?? '-',
                              ),
                            ),
                            SizedBox(
                              width: fieldWidth,
                              child: _buildProfileField(
                                'Ville',
                                user.city ?? '-',
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    ProfilePortfolioEditor(user: user),
                    if (_profileImage != null || _coverImage != null) ...[
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isUpdatingImages ? null : _uploadImages,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: _isUpdatingImages
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Enregistrer les photos de profil et de couverture',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF991B1B), Color(0xFF7F1D1D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(153, 27, 27, 0.35),
                              blurRadius: 18,
                              offset: Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () async {
                            final navigator = Navigator.of(context);
                            await AuthService.logout();
                            if (!mounted) return;
                            navigator.pushReplacement(
                              MaterialPageRoute(
                                builder: (ctx) => const LoginScreen(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'Déconnexion',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildProfileField(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1f2937),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF94a3b8),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHighlightCard(String title, String subtitle) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
