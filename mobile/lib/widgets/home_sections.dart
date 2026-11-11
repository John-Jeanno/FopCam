import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/widgets/chat_window_host.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/models/story.dart';
import 'package:mobile/models/product.dart';
import 'package:mobile/models/post.dart';
import 'package:mobile/models/shop.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/screens/create_story_screen.dart';
import 'package:mobile/screens/section_screen.dart';
import 'package:mobile/screens/story_viewer_screen.dart';
import 'package:mobile/utils/media_url_helper.dart';
import 'package:mobile/widgets/story_preview.dart';
import 'package:mobile/widgets/post_image_viewer.dart';
import 'package:mobile/widgets/product_price_label.dart';
import 'package:mobile/services/story_offline_service.dart';

class HomeSections extends StatefulWidget {
  const HomeSections({super.key});

  @override
  State<HomeSections> createState() => _HomeSectionsState();
}

class _HomeSectionsState extends State<HomeSections> {
  List<Story> _stories = [];
  List<Product> _products = [];
  List<Post> _posts = [];
  List<Shop> _shops = [];
  final List<Product> _exampleProducts = Product.mockProducts();
  static const List<String> _exampleSellerPortraits = [
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=160&q=80',
    'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=160&q=80',
    'https://images.unsplash.com/photo-1531123897727-8f129e1688ce?auto=format&fit=crop&w=160&q=80',
    'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=160&q=80',
  ];

  final Set<int> _sendingFriendRequests = {};
  final Set<int> _sentFriendRequests = {};
  final Set<int> _openingChats = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    StoryOfflineService.pendingCount.addListener(_onPendingStoriesChanged);
    _loadAll();
  }

  @override
  void dispose() {
    StoryOfflineService.pendingCount.removeListener(_onPendingStoriesChanged);
    super.dispose();
  }

  void _onPendingStoriesChanged() {
    if (mounted) _loadAll();
  }

  Future<void> _loadAll() async {
    if (_stories.isEmpty &&
        _products.isEmpty &&
        _posts.isEmpty &&
        _shops.isEmpty) {
      setState(() => _loading = true);
    }
    final results = await Future.wait<Object>([
      ApiService.fetchStories(),
      ApiService.fetchProducts(pageSize: 8),
      ApiService.fetchPosts(pageSize: 3),
      ApiService.fetchShops(),
    ]);
    if (!mounted) return;
    setState(() {
      _stories = results[0] as List<Story>;
      _products = results[1] as List<Product>;
      _posts = results[2] as List<Post>;
      _shops = results[3] as List<Shop>;
      _loading = false;
    });
  }

  Future<void> _createStory() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    if (!isLoggedIn) {
      await Navigator.of(context, rootNavigator: true).pushNamed('/login');
      if (!mounted) return;
      final loggedInAfterLogin = await AuthService.isLoggedIn();
      if (!mounted || !loggedInAfterLogin) return;
    }

    final choice = await StoryCreationOptionsSheet.show(
      context,
      onMediaActionSelected: _pickStoryMedia,
    );
    if (choice == null || !mounted) return;

    XFile? selectedMedia;
    if (choice.mediaFuture != null) {
      try {
        selectedMedia = await choice.mediaFuture!;
      } catch (error) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’ouvrir le sélecteur : $error')),
        );
        return;
      }
      if (!mounted || selectedMedia == null) return;
    }

    final created = await Navigator.of(context, rootNavigator: true)
        .pushNamed<bool>(
          '/create_story',
          arguments: StoryMediaSelection(
            action: choice.action,
            file: selectedMedia,
          ),
        );
    if (created == true && mounted) await _loadAll();
  }

  Future<XFile?> _pickStoryMedia(StoryMediaAction action) {
    final picker = ImagePicker();
    return switch (action) {
      StoryMediaAction.galleryImage => picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
      ),
      StoryMediaAction.cameraImage => picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
      ),
      StoryMediaAction.galleryVideo => picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      ),
      StoryMediaAction.cameraVideo => picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      ),
      StoryMediaAction.textOnly => Future.value(null),
    };
  }

  Future<void> _openEmployment(int tab) async {
    if (!await AuthService.isLoggedIn()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connectez-vous pour accéder aux offres d’emploi.'),
        ),
      );
      await Navigator.of(context, rootNavigator: true).pushNamed('/login');
      return;
    }
    if (!mounted) return;
    await Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamed('/create_job', arguments: tab);
  }

  String _productImageUrl(Product product, int index) =>
      normalizeMediaUrl(product.image) ??
      _exampleProducts[index % _exampleProducts.length].image!;

  String _sellerPortraitUrl(Shop shop, int index) =>
      normalizeMediaUrl(shop.owner?.profileImage) ??
      _exampleSellerPortraits[index % _exampleSellerPortraits.length];

  Future<void> _sendFriendRequest(int receiverId, int shopId) async {
    if (_sendingFriendRequests.contains(shopId)) return;
    setState(() => _sendingFriendRequests.add(shopId));

    final result = await ApiService.sendFriendRequestWithResult(receiverId);
    final success = result['success'] == true;
    if (!mounted) return;

    setState(() {
      _sendingFriendRequests.remove(shopId);
      if (success) {
        _sentFriendRequests.add(shopId);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Demande d’ami envoyée au vendeur.'
              : result['already_exists'] == true
              ? 'Une demande est déjà en attente ou vous êtes déjà amis.'
              : 'Impossible d’envoyer la demande d’ami : '
                    '${result['error'] ?? 'réessayez plus tard.'}',
        ),
      ),
    );
  }

  Future<void> _showSellerProfileImage(
    String imageUrl,
    String sellerName,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.person, color: Colors.white, size: 96),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              right: 56,
              child: Text(
                sellerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                tooltip: 'Fermer',
                onPressed: () => Navigator.of(dialogContext).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openVendorChat(Shop shop) async {
    final owner = shop.owner;
    if (owner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d’identifier le propriétaire de la boutique.',
          ),
        ),
      );
      return;
    }
    if (_openingChats.contains(shop.id)) return;
    setState(() => _openingChats.add(shop.id));
    final conversation = await ApiService.startConversation(owner.id);
    if (!mounted) return;
    setState(() => _openingChats.remove(shop.id));
    final roomId = conversation?['room_id']?.toString();
    if (roomId == null || roomId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d’ouvrir la discussion avec ce vendeur.'),
        ),
      );
      return;
    }
    ChatWindowHost.openChat(
      context,
      roomId: roomId,
      title: ChatWindowHost.titleForUser(
        username: owner.username,
        firstName: owner.firstName,
        lastName: owner.lastName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          ValueListenableBuilder<int>(
            valueListenable: StoryOfflineService.pendingCount,
            builder: (context, pendingCount, _) => pendingCount == 0
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Material(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      child: ListTile(
                        leading: const Icon(
                          Icons.cloud_upload_outlined,
                          color: Color(0xFFFBBF24),
                        ),
                        title: Text(
                          '$pendingCount statut${pendingCount > 1 ? 's' : ''} '
                          'en attente de synchronisation',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: IconButton(
                          tooltip: 'Synchroniser maintenant',
                          icon: const Icon(Icons.sync, color: Colors.white),
                          onPressed: () => StoryOfflineService.syncPending(),
                        ),
                      ),
                    ),
                  ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Statuts',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _stories.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Semantics(
                      button: true,
                      label: 'Ajouter un statut',
                      child: InkWell(
                        onTap: _createStory,
                        borderRadius: BorderRadius.circular(35),
                        child: Column(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1B2436),
                                border: Border.all(
                                  color: const Color(0xFFB91C1C),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 34,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const SizedBox(
                              width: 68,
                              child: Text(
                                'Ajouter',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                final storyIndex = index - 1;
                final story = _stories[storyIndex];
                final author = story.author;
                final displayName = _authorDisplayName(author);
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => StoryViewerScreen(
                            stories: _stories,
                            initialIndex: storyIndex,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: !story.isViewed
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFB91C1C),
                                      Color(0xFF7F1D1D),
                                    ],
                                  )
                                : const LinearGradient(
                                    colors: [Colors.grey, Colors.grey],
                                  ),
                          ),
                          child: StoryPreview(story: story),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 68,
                          child: Text(
                            displayName,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildEmploymentSection(),
          const SizedBox(height: 12),
          _buildHeroBanner(),
          const SizedBox(height: 12),
          _buildAdvancedSearchCard(context),
          const SizedBox(height: 12),
          _buildPremiumBanner(),
          const SizedBox(height: 12),
          _buildFeatureTiles(),
          const SizedBox(height: 12),
          _buildNewArrivalsSection(context),
          const SizedBox(height: 12),
          _buildPostsSection(context),
          const SizedBox(height: 12),
          _buildSectionWithItems(
            context,
            title: '🌟 Produit en vedette',
            items: _products.map((p) => p.title).toList(),
            onSeeAll: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SectionScreen(
                    title: 'Produit en vedette',
                    items: _products.map((p) => p.title).toList(),
                  ),
                ),
              );
            },
            content: SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  final product = _products[index];
                  return Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () => Navigator.of(
                        context,
                      ).pushNamed('/product', arguments: product.id),
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                _productImageUrl(product, index),
                                fit: BoxFit.cover,
                                width: double.infinity,
                                errorBuilder: (_, _, _) => Container(
                                  color: AppColors.surfaceAlt,
                                  child: const Icon(
                                    Icons.shopping_bag_outlined,
                                    color: Colors.white54,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                product.title,
                                style: const TextStyle(color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
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
          ),
          _buildVendorsSection(context),
        ],
      ),
    );
  }

  Widget _buildEmploymentSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Text(
          'Emploi',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(
              child: Card(
                color: const Color(0xFF172033),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openEmployment(0),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.person_search, color: Colors.amber),
                        SizedBox(height: 8),
                        Text(
                          'Recherche d’emploi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Publier ou consulter',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                color: const Color(0xFF172033),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openEmployment(1),
                  child: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.work_outline, color: Colors.lightBlue),
                        SizedBox(height: 8),
                        Text(
                          'Offres d’emploi',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Publier ou postuler',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  String _authorDisplayName(dynamic author) {
    final hasName =
        (author.firstName != null && author.firstName!.isNotEmpty) ||
        (author.lastName != null && author.lastName!.isNotEmpty);
    if (hasName) {
      final first = author.firstName ?? '';
      final last = author.lastName ?? '';
      return '$first $last'.trim();
    }
    return author.username;
  }

  Widget _buildPremiumBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF7F1D1D), Color(0xFF3F1111)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Marché du jour',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Produits frais, artisans locaux et offres exclusives à découvrir dès maintenant.',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront,
                color: Colors.white,
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF1F2937), Color(0xFF111827)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Hors ligne',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Achetez directement des vendeurs locaux',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Découvrez les boutiques, produits et services de votre région en quelques tapotements.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSearchCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: GestureDetector(
        onTap: () => Navigator.of(context).pushNamed('/advanced_search'),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border, width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF7F1D1D),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '🔎 Recherche avancée',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Trouvez des catégories, produits ou vendeurs en explorant l’application.',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewArrivalsSection(BuildContext context) {
    final newestProducts = _products.take(6).toList();
    if (newestProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return _buildSectionWithItems(
      context,
      title: '🆕 Nouveautés',
      items: newestProducts.map((p) => p.title).toList(),
      onSeeAll: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SectionScreen(
              title: 'Nouveautés',
              items: newestProducts.map((p) => p.title).toList(),
            ),
          ),
        );
      },
      content: SizedBox(
        height: 180,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: newestProducts.length,
          itemBuilder: (context, index) {
            final product = newestProducts[index];
            return Container(
              width: 180,
              height: 180,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: InkWell(
                onTap: () => Navigator.of(
                  context,
                ).pushNamed('/shop', arguments: {'shopId': product.shopId}),
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          _productImageUrl(product, index),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColors.surfaceAlt,
                            child: const Icon(
                              Icons.shopping_bag_outlined,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                product.title,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            ProductPriceLabel(
                              product: product,
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ],
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

  Widget _buildVendorsSection(BuildContext context) {
    return _buildSectionWithItems(
      context,
      title: 'Vendeurs',
      items: _shops.map((s) => s.name).toList(),
      onSeeAll: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SectionScreen(
              title: 'Vendeurs',
              items: _shops.map((s) => s.name).toList(),
            ),
          ),
        );
      },
      content: SizedBox(
        height: 420,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _shops.length,
          itemBuilder: (context, index) {
            final shop = _shops[index];
            final owner = shop.owner;
            final shopLogo = normalizeMediaUrl(shop.logo);
            final ownerName = owner == null
                ? ''
                : [owner.firstName, owner.lastName]
                      .whereType<String>()
                      .where((name) => name.trim().isNotEmpty)
                      .join(' ')
                      .trim();
            final isSending = _sendingFriendRequests.contains(shop.id);
            final isSent = _sentFriendRequests.contains(shop.id);
            return Container(
              width: 220,
              height: 380,
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: shopLogo != null
                        ? Image.network(
                            shopLogo,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 90,
                            errorBuilder: (_, _, _) => Container(
                              height: 90,
                              color: Colors.white10,
                              child: const Icon(
                                Icons.storefront,
                                color: Colors.white30,
                                size: 36,
                              ),
                            ),
                          )
                        : Container(
                            height: 90,
                            color: Colors.white10,
                            child: const Center(
                              child: Icon(
                                Icons.storefront,
                                color: Colors.white30,
                                size: 36,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    shop.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _showSellerProfileImage(
                          _sellerPortraitUrl(shop, index),
                          ownerName.isEmpty
                              ? owner?.username ?? 'Vendeur local'
                              : ownerName,
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.surfaceAlt,
                          child: ClipOval(
                            child: Image.network(
                              _sellerPortraitUrl(shop, index),
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Icon(
                                Icons.person,
                                color: Colors.white70,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          ownerName.isEmpty
                              ? owner?.username ?? 'Vendeur local'
                              : ownerName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed(
                              '/shop',
                              arguments: {'shopId': shop.id},
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7F1D1D),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: const Text('Voir la boutique'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: owner == null || isSent || isSending
                              ? null
                              : () => _sendFriendRequest(owner.id, shop.id),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: isSent
                                  ? const Color(0xFF10B981)
                                  : Colors.white24,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(
                            isSending
                                ? 'Envoi...'
                                : isSent
                                ? 'Demandé'
                                : 'Devenir ami',
                            style: TextStyle(
                              color: isSent
                                  ? const Color(0xFF10B981)
                                  : Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _openingChats.contains(shop.id)
                              ? null
                              : () => _openVendorChat(shop),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          child: Text(
                            _openingChats.contains(shop.id)
                                ? 'Ouverture...'
                                : 'Discuter',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPostsSection(BuildContext context) {
    if (_posts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'Publications du moment',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'à suivre',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _posts.length,
            itemBuilder: (context, index) {
              final post = _posts[index];
              return Container(
                width: 220,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B1616),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border, width: 1.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(14),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: post.image != null && post.image!.isNotEmpty
                            ? GestureDetector(
                                onTap: () => showPostImageViewer(
                                  context,
                                  post.image!,
                                  title: post.author.username,
                                ),
                                child: Image.network(
                                  post.image!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                ),
                              )
                            : Container(color: Colors.white10),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppColors.background,
                                  backgroundImage:
                                      post.author.profileImage != null &&
                                          post.author.profileImage!.isNotEmpty
                                      ? NetworkImage(
                                          normalizeMediaUrl(
                                                post.author.profileImage,
                                              ) ??
                                              '',
                                        )
                                      : null,
                                  child:
                                      post.author.profileImage == null ||
                                          post.author.profileImage!.isEmpty
                                      ? Text(
                                          post.author.username.isNotEmpty
                                              ? post.author.username[0]
                                                    .toUpperCase()
                                              : 'U',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    post.author.username,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Text(
                                post.content,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${post.likesCount} ♥  •  ${post.commentsCount} 💬',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
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
  }

  Widget _buildFeatureTiles() {
    final features = [
      {
        'title': 'Livraison rapide',
        'desc': 'Recevez vos produits frais en quelques heures.',
        'icon': Icons.local_shipping_outlined,
      },
      {
        'title': 'Qualité garantie',
        'desc': 'Vendeurs vérifiés et produits de confiance.',
        'icon': Icons.verified_outlined,
      },
      {
        'title': 'Communauté locale',
        'desc': 'Soutenez les fermes et artisans de votre quartier.',
        'icon': Icons.people_alt_outlined,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Row(
        children: features.map((f) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3F1111),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1.2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF7F1D1D),
                    child: Icon(
                      f['icon'] as IconData,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (f['title'] as String),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (f['desc'] as String),
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    List<String> items,
    VoidCallback onSeeAll,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          TextButton(
            onPressed: onSeeAll,
            child: const Text(
              'Voir tout',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionWithItems(
    BuildContext context, {
    required String title,
    required List<String> items,
    required VoidCallback onSeeAll,
    required Widget content,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader(context, title, items, onSeeAll),
        content,
        const SizedBox(height: 12),
      ],
    );
  }
}

class StoryCreationOptionsSheet extends StatelessWidget {
  const StoryCreationOptionsSheet({
    super.key,
    required this.onMediaActionSelected,
  });

  static Future<StoryMediaChoice?> show(
    BuildContext context, {
    required Future<XFile?> Function(StoryMediaAction) onMediaActionSelected,
  }) {
    return showModalBottomSheet<StoryMediaChoice>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111827),
      showDragHandle: true,
      builder: (_) => StoryCreationOptionsSheet(
        onMediaActionSelected: onMediaActionSelected,
      ),
    );
  }

  final Future<XFile?> Function(StoryMediaAction) onMediaActionSelected;

  @override
  Widget build(BuildContext context) {
    const options = [
      (
        Icons.photo_library_outlined,
        'Photo depuis la galerie',
        StoryMediaAction.galleryImage,
      ),
      (
        Icons.photo_camera_outlined,
        'Prendre une photo',
        StoryMediaAction.cameraImage,
      ),
      (
        Icons.video_library_outlined,
        'Vidéo depuis la galerie',
        StoryMediaAction.galleryVideo,
      ),
      (
        Icons.videocam_outlined,
        'Enregistrer une vidéo',
        StoryMediaAction.cameraVideo,
      ),
      (Icons.text_fields, 'Créer un statut texte', StoryMediaAction.textOnly),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ajouter un statut',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            for (final (icon, title, action) in options)
              ListTile(
                leading: Icon(icon, color: const Color(0xFFF87171)),
                title: Text(title, style: const TextStyle(color: Colors.white)),
                onTap: () {
                  final mediaFuture = action == StoryMediaAction.textOnly
                      ? null
                      : onMediaActionSelected(action);
                  Navigator.of(
                    context,
                  ).pop(StoryMediaChoice(action, mediaFuture));
                },
              ),
          ],
        ),
      ),
    );
  }
}

@immutable
class StoryMediaChoice {
  const StoryMediaChoice(this.action, this.mediaFuture);

  final StoryMediaAction action;
  final Future<XFile?>? mediaFuture;
}
