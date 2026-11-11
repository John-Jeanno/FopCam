import 'package:flutter/material.dart';
import 'package:mobile/models/shop.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/utils/media_url_helper.dart';

Future<void> showStoryAuthorProfile(BuildContext context, User author) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111827),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _StoryAuthorProfileSheet(author: author),
  );
}

class _StoryAuthorProfileSheet extends StatefulWidget {
  const _StoryAuthorProfileSheet({required this.author});

  final User author;

  @override
  State<_StoryAuthorProfileSheet> createState() =>
      _StoryAuthorProfileSheetState();
}

class _StoryAuthorProfileSheetState extends State<_StoryAuthorProfileSheet> {
  late final Future<List<Shop>> _shopsFuture;

  @override
  void initState() {
    super.initState();
    _shopsFuture = ApiService.fetchShops(search: widget.author.username);
  }

  Shop? _shopForAuthor(List<Shop> shops) {
    for (final shop in shops) {
      if (shop.owner?.id == widget.author.id) return shop;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final author = widget.author;
    final fullName = [
      author.firstName,
      author.lastName,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 42,
              backgroundImage: author.profileImage == null
                  ? null
                  : NetworkImage(normalizeMediaUrl(author.profileImage) ?? ''),
              child: author.profileImage == null
                  ? Text(
                      author.username.isEmpty
                          ? 'U'
                          : author.username[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28),
                    )
                  : null,
            ),
            const SizedBox(height: 14),
            if (fullName.isNotEmpty)
              Text(
                fullName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            Text(
              '@${author.username}',
              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 15),
            ),
            const SizedBox(height: 24),
            FutureBuilder<List<Shop>>(
              future: _shopsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  );
                }
                final shop = snapshot.hasData
                    ? _shopForAuthor(snapshot.data!)
                    : null;
                if (shop == null) {
                  return const Text(
                    'Aucune boutique publique associée à ce profil.',
                    style: TextStyle(color: Color(0xFF94A3B8)),
                    textAlign: TextAlign.center,
                  );
                }
                return SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(
                      context,
                    ).pushNamed('/shop', arguments: {'shopId': shop.id}),
                    icon: const Icon(Icons.storefront_outlined),
                    label: Text('Visiter ${shop.name}'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
