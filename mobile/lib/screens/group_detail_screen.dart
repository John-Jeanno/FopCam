import 'package:flutter/material.dart';
import 'package:mobile/constants/api_endpoints.dart';
import 'package:mobile/models/group.dart';
import 'package:mobile/services/api_service.dart';

class GroupDetailScreen extends StatefulWidget {
  final Group group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  bool _isJoining = false;
  late Group _group;
  List<Map<String, dynamic>> _pending = [];
  bool _loadingPending = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _loadPending();
  }

  Future<void> _loadPending() async {
    setState(() => _loadingPending = true);
    final list = await ApiService.fetchPendingMembers(_group.id);
    if (!mounted) return;
    setState(() {
      _pending = list;
      _loadingPending = false;
    });
  }

  Future<void> _approve(int memberId) async {
    final ok = await ApiService.approveMember(_group.id, memberId);
    if (ok) {
      await _loadPending();
      setState(() {
        _group = _group.copyWith(memberCount: _group.memberCount + 1);
      });
    }
  }

  Future<void> _reject(int memberId) async {
    final ok = await ApiService.rejectMember(_group.id, memberId);
    if (ok) await _loadPending();
  }

  Future<void> _joinGroup() async {
    setState(() => _isJoining = true);
    final success = await ApiService.joinGroup(_group.id);
    if (!mounted) return;
    setState(() {
      _isJoining = false;
      if (success) {
        _group = _group.copyWith(isMember: true, memberStatus: 'approved');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(_group.name),
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_group.coverImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.network(
                      _resolveMediaUrl(_group.coverImage!),
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: 180,
                        color: const Color(0xFF111827),
                        child: const Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                Text(
                  _group.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Créé par ${_group.creator.username}',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  _group.description,
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildBadge('Type', _group.groupType),
                    const SizedBox(width: 10),
                    _buildBadge('Membres', '${_group.memberCount}'),
                  ],
                ),
                const SizedBox(height: 22),
                if (!_group.isMember)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isJoining ? null : _joinGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        _isJoining ? 'Rejoindre...' : 'Rejoindre le groupe',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 18,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F766E),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.check, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Vous êtes membre',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 26),
                // Pending members (for moderators/admins)
                Text(
                  'Règles du groupe',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                if (_loadingPending)
                  const Center(child: CircularProgressIndicator())
                else if (_pending.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'Demandes en attente',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._pending.map((m) {
                        final id = m['id'];
                        final user = m['user'] ?? {};
                        final username = user['username'] ?? 'Utilisateur';
                        return Card(
                          color: const Color(0xFF111827),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  username,
                                  style: const TextStyle(color: Colors.white),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () => _approve(id),
                                      child: const Text('Approuver'),
                                    ),
                                    TextButton(
                                      onPressed: () => _reject(id),
                                      child: const Text(
                                        'Rejeter',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                    ],
                  )
                else
                  const SizedBox.shrink(),
                const SizedBox(height: 12),
                Text(
                  _group.rules ?? 'Aucune règle affichée.',
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        '$label : $value',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
    );
  }

  String _resolveMediaUrl(String value) {
    if (value.startsWith('http')) {
      return value;
    }
    return '${ApiEndpoints.baseUrl}$value';
  }
}
