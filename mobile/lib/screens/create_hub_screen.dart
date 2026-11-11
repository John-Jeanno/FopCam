import 'package:flutter/material.dart';
import 'package:mobile/constants/app_colors.dart';
import 'package:mobile/constants/ui_helpers.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/services/auth_service.dart';

class CreateHubScreen extends StatelessWidget {
  const CreateHubScreen({super.key, this.onStoryCreated});

  final VoidCallback? onStoryCreated;

  Future<void> _createStory(BuildContext context) async {
    if (!await AuthService.isLoggedIn()) {
      if (!context.mounted) return;
      await Navigator.of(context, rootNavigator: true).pushNamed('/login');
      if (!context.mounted) return;
      final loggedInAfterLogin = await AuthService.isLoggedIn();
      if (!context.mounted || !loggedInAfterLogin) return;
    }
    if (!context.mounted) return;
    final created = await Navigator.of(
      context,
      rootNavigator: true,
    ).pushNamed<bool>('/create_story');
    if (created == true) onStoryCreated?.call();
  }

  Future<void> _createShop(BuildContext context) async {
    if (!await AuthService.isLoggedIn()) {
      if (!context.mounted) return;
      await Navigator.of(context, rootNavigator: true).pushNamed('/login');
      if (!context.mounted || !await AuthService.isLoggedIn()) return;
    }

    final profile = await AuthService.getProfile();
    if (!context.mounted) return;
    final user = profile['data'];
    if (profile['success'] != true || user is! User) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de vérifier votre type de profil : '
            '${profile['error'] ?? 'veuillez réessayer.'}',
          ),
        ),
      );
      return;
    }
    if (user.role != 'boutique') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Passez au type de profil Boutique dans Profil > Mes paramètres '
            'pour créer une boutique.',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).pushNamed('/create_shop');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Créer'), elevation: 0),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF020617), Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionTitle(
                'Créer du contenu',
                'Publiez un produit, un statut ou du contenu pour la communauté.',
              ),
              const SizedBox(height: 18),
              _buildCreateCard(
                context,
                icon: Icons.add_shopping_cart,
                title: 'Publier un produit',
                subtitle: 'Partagez vos nouveautés avec la communauté.',
                onTap: () {
                  Navigator.of(context).pushNamed('/create_product');
                },
              ),
              const SizedBox(height: 14),
              _buildCreateCard(
                context,
                icon: Icons.add_business,
                title: 'Créer une boutique',
                subtitle:
                    'Réservé au type de profil Boutique. '
                    'Choisissez ce type dans Profil > Mes paramètres.',
                onTap: () => _createShop(context),
              ),
              const SizedBox(height: 14),
              _buildCreateCard(
                context,
                icon: Icons.add_photo_alternate,
                title: 'Publier un statut',
                subtitle: 'Partagez un moment, visible pendant 24 heures.',
                onTap: () => _createStory(context),
              ),
              const SizedBox(height: 14),
              _buildCreateCard(
                context,
                icon: Icons.video_call,
                title: 'Publier un clip',
                subtitle: 'Ajoutez un thème et un effet vidéo à votre clip.',
                onTap: () {
                  Navigator.of(context).pushNamed('/create_reel');
                },
              ),
              const SizedBox(height: 14),
              _buildCreateCard(
                context,
                icon: Icons.wifi_tethering,
                title: 'Lancer un direct',
                subtitle: 'Diffusez en direct et échangez avec la communauté.',
                onTap: () {
                  Navigator.of(context).pushNamed('/live');
                },
              ),
              const SizedBox(height: 14),
              _buildCreateCard(
                context,
                icon: Icons.camera,
                title: 'Effets photo',
                subtitle:
                    'Ajoutez des effets et autocollants à une photo, puis publiez-la.',
                onTap: () {
                  Navigator.of(context).pushNamed('/ar_effects');
                },
              ),
              const SizedBox(height: 14),
              _buildCreateCard(
                context,
                icon: Icons.map,
                title: 'Carte sociale',
                subtitle: 'Repérez les boutiques locales et leur emplacement.',
                onTap: () {
                  Navigator.of(context).pushNamed('/map');
                },
              ),
              const SizedBox(height: 14),
              _buildCreateCard(
                context,
                icon: Icons.group,
                title: 'Collaborer',
                subtitle:
                    'Trouvez un partenaire local et contactez-le pour votre projet.',
                onTap: () {
                  Navigator.of(context).pushNamed('/collaboration');
                },
              ),
              const SizedBox(height: 14),
              _buildCreateCard(
                context,
                icon: Icons.event,
                title: 'Créer un événement',
                subtitle: 'Annoncer une rencontre, un atelier ou une promo.',
                onTap: () {
                  Navigator.of(context).pushNamed('/create_event');
                },
              ),
              const SizedBox(height: 14),
              _buildCreateCard(
                context,
                icon: Icons.work,
                title: 'Publier une offre d’emploi',
                subtitle: 'Recrutez ou trouvez une mission locale.',
                onTap: () {
                  Navigator.of(context).pushNamed('/create_job');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildCreateCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: buildPanelDecoration(),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(14),
              child: Icon(icon, color: AppColors.primaryLight, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
