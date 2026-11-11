import 'package:flutter/material.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/widgets/chat_window_host.dart';

class MessagesScreen extends StatefulWidget {
  final Future<void> Function()? onMessagesRead;

  const MessagesScreen({super.key, this.onMessagesRead});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late Future<_MessageData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
  }

  Future<_MessageData> _loadData() async {
    final results = await Future.wait([
      AuthService.getProfile(),
      ApiService.fetchConversations(),
    ]);
    final profile = results[0] as Map<String, dynamic>;
    if (profile['success'] != true || profile['data'] is! User) {
      throw StateError('Connectez-vous pour consulter vos discussions.');
    }
    final user = profile['data'] as User;
    return _MessageData(
      conversations:
          (results[1] as List<Map<String, dynamic>>)
              .where((conversation) {
                final profile = conversation['profile'];
                return conversation['room_id'] is String &&
                    profile is Map &&
                    profile['id'] is int &&
                    profile['id'] != user.id;
              })
              .map((conversation) {
                final unreadCount = conversation['unread_count'];
                final updatedAt = conversation['updated_at']?.toString();
                return _Conversation(
                  roomId: conversation['room_id'] as String,
                  user: User.fromJson(
                    Map<String, dynamic>.from(conversation['profile'] as Map),
                  ),
                  preview: conversation['last_message']?.toString() ?? '',
                  unreadCount: unreadCount is int ? unreadCount : 0,
                  updatedAt: DateTime.tryParse(updatedAt ?? ''),
                );
              })
              .toList()
            ..sort(
              (a, b) => (b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                  .compareTo(
                    a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
                  ),
            ),
    );
  }

  Future<void> _openConversation(_Conversation conversation) async {
    await ChatWindowHost.openChat(
      context,
      roomId: conversation.roomId,
      title: _displayName(conversation.user),
    );
    if (!mounted) return;
    await widget.onMessagesRead?.call();
    setState(() => _dataFuture = _loadData());
  }

  Future<void> _deleteConversation(_Conversation conversation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cette discussion ?'),
        content: const Text(
          'Tous les messages seront supprimés pour les deux personnes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ApiService.deleteConversation(conversation.roomId);
      if (!mounted) return;
      setState(() => _dataFuture = _loadData());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Discussion supprimée pour les deux personnes.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Suppression impossible : $error')),
      );
    }
  }

  String _displayName(User user) {
    final name = '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();
    return name.isEmpty ? user.username : name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () async {
            if (!await Navigator.of(context).maybePop() && context.mounted) {
              Navigator.of(context).pushReplacementNamed('/home');
            }
          },
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: FutureBuilder<_MessageData>(
          future: _dataFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Impossible de charger les discussions : '
                        '${snapshot.error}',
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            setState(() => _dataFuture = _loadData()),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              );
            }
            final data = snapshot.data!;
            return RefreshIndicator(
              onRefresh: () async {
                final future = _loadData();
                setState(() => _dataFuture = future);
                await future;
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Discussions privées',
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  if (data.conversations.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        'Vos discussions privées apparaîtront ici.',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                  for (final conversation in data.conversations)
                    MessageConversationTile(
                      user: conversation.user,
                      preview: conversation.preview,
                      unreadCount: conversation.unreadCount,
                      onTap: () => _openConversation(conversation),
                      onDelete: () => _deleteConversation(conversation),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class MessageConversationTile extends StatelessWidget {
  const MessageConversationTile({
    super.key,
    required this.user,
    required this.preview,
    required this.unreadCount,
    required this.onTap,
    required this.onDelete,
  });

  final User user;
  final String preview;
  final int unreadCount;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  String get _displayName {
    final name = '${user.firstName ?? ''} ${user.lastName ?? ''}'.trim();
    return name.isEmpty ? user.username : name;
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = unreadCount > 0;
    return Card(
      color: hasUnread ? const Color(0xFF1B1B2A) : const Color(0xFF111827),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: hasUnread ? AppColors.primaryDark : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          foregroundImage: user.profileImage == null
              ? null
              : NetworkImage(user.profileImage!),
          child: user.profileImage == null ? const Icon(Icons.person) : null,
        ),
        title: Text(
          _displayName,
          style: TextStyle(
            color: Colors.white,
            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          preview,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: hasUnread ? Colors.white : AppColors.textSecondary,
            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasUnread)
              Semantics(
                label: '$unreadCount messages non lus',
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryDark,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (hasUnread) const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Options de la discussion',
              onSelected: (value) {
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Supprimer pour tous'),
                ),
              ],
              icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _MessageData {
  const _MessageData({required this.conversations});

  final List<_Conversation> conversations;
}

class _Conversation {
  const _Conversation({
    required this.roomId,
    required this.user,
    required this.preview,
    required this.unreadCount,
    required this.updatedAt,
  });

  final String roomId;
  final User user;
  final String preview;
  final int unreadCount;
  final DateTime? updatedAt;
}
