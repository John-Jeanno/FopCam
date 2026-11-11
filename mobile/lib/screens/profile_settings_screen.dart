import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/screens/password_reset_screen.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/app_locale_service.dart';
import 'package:mobile/services/app_theme_service.dart';
import 'package:mobile/services/notification_sound_service.dart';
import 'package:mobile/widgets/profile_analytics_section.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late Future<Map<String, dynamic>> _profileFuture;
  String _profileVisibility = 'public';
  String _phoneVisibility = 'private';
  String _preferredLanguage = 'fr';
  Map<String, String> _notificationSounds =
      NotificationSoundService.preferences;
  bool _isSaving = false;
  bool _settingsInitialized = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = AuthService.getProfile();
  }

  Future<void> _saveSettings() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final result = await ApiService.updateProfile({
      'profile_visibility': _profileVisibility,
      'phone_visibility': _phoneVisibility,
      'preferred_language': _preferredLanguage,
      'notification_sounds': _notificationSounds,
    });
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (result['success'] == true) {
      await NotificationSoundService.savePreferences(_notificationSounds);
      if (!mounted) return;
      await AppLocaleService.setLanguage(_preferredLanguage);
      if (!mounted) return;
      final message = result['pending_sync'] == true
          ? 'Paramètres conservés hors ligne et en attente de synchronisation.'
          : 'Paramètres du profil enregistrés.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Impossible d’enregistrer les paramètres : ${result['error']}',
        ),
      ),
    );
  }

  Future<void> _openPasswordRecovery({
    required User user,
    required String channel,
    required String identifier,
  }) async {
    if (identifier.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            channel == 'email'
                ? 'Aucune adresse email n’est enregistrée dans votre profil.'
                : 'Aucun numéro de téléphone n’est enregistré dans votre profil.',
          ),
        ),
      );
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PasswordResetScreen(
          initialChannel: channel,
          initialIdentifier: identifier,
        ),
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }

  Color _textColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  Color _mutedTextColor(BuildContext context) =>
      _textColor(context).withValues(alpha: 0.72);

  Widget _visibilityField({
    required String title,
    required String helper,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _textColor(context),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(helper, style: TextStyle(color: _mutedTextColor(context))),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: value,
          dropdownColor: Theme.of(context).colorScheme.surface,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: const [
            DropdownMenuItem(value: 'public', child: Text('Public')),
            DropdownMenuItem(value: 'private', child: Text('Privé')),
          ],
          onChanged: _isSaving ? null : onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
                ? const [
                    Color(0xFF020617),
                    Color(0xFF0F172A),
                    Color(0xFF1E293B),
                  ]
                : const [
                    Color(0xFFF8FAFC),
                    Color(0xFFF1F5F9),
                    Color(0xFFE2E8F0),
                  ],
          ),
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError ||
                snapshot.data?['success'] != true ||
                snapshot.data?['data'] is! User) {
              return Center(
                child: Text(
                  'Impossible de charger les paramètres du compte.',
                  style: TextStyle(color: _textColor(context)),
                  textAlign: TextAlign.center,
                ),
              );
            }
            final user = snapshot.data!['data'] as User;
            if (!_settingsInitialized) {
              _profileVisibility = user.profileVisibility;
              _phoneVisibility = user.phoneVisibility;
              _preferredLanguage =
                  AppLocaleService.isSupported(user.preferredLanguage)
                  ? user.preferredLanguage
                  : AppLocaleService.languageForCountry(user.countryCode) ??
                        AppLocaleService.localeTag(
                          AppLocaleService.locale.value,
                        );
              if (user.notificationSounds.isNotEmpty) {
                _notificationSounds = {
                  ...NotificationSoundService.preferences,
                  ...user.notificationSounds,
                };
                unawaited(
                  NotificationSoundService.applyServerPreferences(
                    user.notificationSounds,
                  ),
                );
              }
              _settingsInitialized = true;
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionCard(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: AppThemeService.isDarkMode,
                    builder: (context, isDarkMode, _) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        isDarkMode ? Icons.dark_mode : Icons.light_mode,
                        color: _textColor(context),
                      ),
                      title: Text(
                        'Thème jour / nuit',
                        style: TextStyle(
                          color: _textColor(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        isDarkMode
                            ? 'Thème nuit actif (thème par défaut)'
                            : 'Thème jour actif',
                        style: TextStyle(color: _mutedTextColor(context)),
                      ),
                      value: isDarkMode,
                      onChanged: AppThemeService.setDarkMode,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sonneries des notifications',
                        style: TextStyle(
                          color: _textColor(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choisissez un son différent pour chaque type de notification reçue lorsque l’application est ouverte. Touchez une sonnerie pour l’écouter, puis enregistrez vos paramètres.',
                        style: TextStyle(color: _mutedTextColor(context)),
                      ),
                      const SizedBox(height: 16),
                      ...NotificationSoundService.categoryLabels.entries.map(
                        (category) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                category.value,
                                style: TextStyle(
                                  color: _textColor(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 7),
                              DropdownButtonFormField<String>(
                                initialValue:
                                    _notificationSounds[category.key] ??
                                    'system',
                                dropdownColor:
                                    Theme.of(context).colorScheme.surface,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                ),
                                items: NotificationSoundService.soundLabels
                                    .entries
                                    .map(
                                      (sound) => DropdownMenuItem(
                                        value: sound.key,
                                        child: Text(sound.value),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _isSaving
                                    ? null
                                    : (sound) {
                                        if (sound == null) return;
                                        setState(
                                          () => _notificationSounds = {
                                            ..._notificationSounds,
                                            category.key: sound,
                                          },
                                        );
                                        unawaited(
                                          NotificationSoundService.preview(
                                            sound,
                                          ),
                                        );
                                      },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Confidentialité',
                        style: TextStyle(
                          color: _textColor(context),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choisissez les informations visibles par les autres utilisateurs.',
                        style: TextStyle(color: _mutedTextColor(context)),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Langue de l’application',
                        style: TextStyle(
                          color: _textColor(context),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _preferredLanguage,
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        items: AppLocaleService.languages
                            .map(
                              (language) => DropdownMenuItem(
                                value: language.code,
                                child: Text(language.name),
                              ),
                            )
                            .toList(),
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value != null) {
                                  setState(() => _preferredLanguage = value);
                                }
                              },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'La langue est enregistrée sur votre compte et sera appliquée progressivement aux écrans de l’application.',
                        style: TextStyle(color: _mutedTextColor(context)),
                      ),
                      const SizedBox(height: 20),
                      _visibilityField(
                        title: 'Visibilité du profil',
                        helper:
                            'Un profil privé est visible uniquement par vos amis.',
                        value: _profileVisibility,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _profileVisibility = value);
                          }
                        },
                      ),
                      const SizedBox(height: 20),
                      _visibilityField(
                        title: 'Visibilité du numéro de téléphone',
                        helper:
                            'En mode privé, votre numéro reste visible uniquement par vous.',
                        value: _phoneVisibility,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _phoneVisibility = value);
                          }
                        },
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _saveSettings,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving ? 'Enregistrement...' : 'Enregistrer',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const ProfileAnalyticsSection(),
                const SizedBox(height: 14),
                _sectionCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sécurité et récupération du compte',
                        style: TextStyle(
                          color: _textColor(context),
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Utilisez vos coordonnées enregistrées pour recevoir un code de réinitialisation du mot de passe.',
                        style: TextStyle(color: _mutedTextColor(context)),
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.email_outlined,
                          color: _mutedTextColor(context),
                        ),
                        title: Text(
                          'Récupération par email',
                          style: TextStyle(color: _textColor(context)),
                        ),
                        subtitle: Text(
                          user.email.isEmpty
                              ? 'Aucune adresse enregistrée'
                              : user.email,
                          style: TextStyle(color: _mutedTextColor(context)),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: _mutedTextColor(context),
                        ),
                        onTap: () => _openPasswordRecovery(
                          user: user,
                          channel: 'email',
                          identifier: user.email,
                        ),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          Icons.chat_outlined,
                          color: _mutedTextColor(context),
                        ),
                        title: Text(
                          'Récupération par WhatsApp',
                          style: TextStyle(color: _textColor(context)),
                        ),
                        subtitle: Text(
                          user.phone?.isNotEmpty == true
                              ? user.phone!
                              : 'Aucun numéro enregistré',
                          style: TextStyle(
                            color: _mutedTextColor(
                              context,
                            ).withValues(alpha: 0.82),
                          ),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: _mutedTextColor(context),
                        ),
                        onTap: () => _openPasswordRecovery(
                          user: user,
                          channel: 'whatsapp',
                          identifier: user.phone ?? '',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Après validation du code, vous pourrez choisir un nouveau mot de passe.',
                        style: TextStyle(
                          color: _mutedTextColor(
                            context,
                          ).withValues(alpha: 0.82),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
