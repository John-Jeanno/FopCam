import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mobile/models/notification.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationSoundService {
  static final FlutterTts _speech = FlutterTts();
  static final AudioPlayer _soundPlayer = AudioPlayer();
  static const String webAlertAsset = 'sounds/score.wav';
  static const Map<String, String> categoryLabels = {
    'messages': 'Messages',
    'games': 'Défis et jeux',
    'social': 'Activité sociale',
    'orders': 'Commandes et paiements',
    'other': 'Autres notifications',
  };
  static const Map<String, String> soundLabels = {
    'system': 'Son système',
    'soft': 'Douce',
    'alert': 'Sifflet',
    'festive': 'Festive',
  };
  static const Map<String, String> _soundAssets = {
    'soft': 'sounds/score.wav',
    'alert': 'sounds/whistle.wav',
    'festive': 'sounds/bonus.wav',
  };

  static Map<String, String> _preferences = {
    for (final category in categoryLabels.keys) category: 'system',
  };

  static Map<String, String> get preferences =>
      Map<String, String>.unmodifiable(_preferences);

  static String categoryForType(String type) => switch (type) {
    'message' => 'messages',
    'game_challenge' || 'game_rematch' || 'game_tournament' => 'games',
    'order' || 'payment' || 'stock' => 'orders',
    'friend_request' ||
    'follow' ||
    'like' ||
    'comment' ||
    'group_invite' => 'social',
    _ => 'other',
  };

  static Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _preferences = {
      for (final category in categoryLabels.keys)
        category: _validSound(prefs.getString(_keyFor(category)))
            ? prefs.getString(_keyFor(category))!
            : 'system',
    };
  }

  static Future<void> applyServerPreferences(
    Map<String, String> serverPreferences,
  ) async {
    if (serverPreferences.isEmpty) return;
    final merged = {
      for (final category in categoryLabels.keys)
        category: _validSound(serverPreferences[category])
            ? serverPreferences[category]!
            : 'system',
    };
    await savePreferences(merged);
  }

  static Future<void> savePreferences(
    Map<String, String> preferences,
  ) async {
    final validated = <String, String>{
      for (final category in categoryLabels.keys)
        category: _validSound(preferences[category])
            ? preferences[category]!
            : 'system',
    };
    final prefs = await SharedPreferences.getInstance();
    for (final entry in validated.entries) {
      await prefs.setString(_keyFor(entry.key), entry.value);
    }
    _preferences = validated;
  }

  static String _keyFor(String category) => 'notification_sound_$category';

  static bool _validSound(String? sound) => soundLabels.containsKey(sound);

  static Future<void> preview(String sound) async {
    if (sound == 'system') {
      await _playSystemAlert();
      return;
    }
    await _playAsset(_soundAssets[sound], fallbackToSystem: true);
  }

  static Future<void> play(NotificationItem notification) async {
    final category = categoryForType(notification.type);
    final sound = _preferences[category] ?? 'system';
    if (sound != 'system') {
      await _playAsset(_soundAssets[sound], fallbackToSystem: true);
      return;
    }

    final announcement = announcementFor(notification);
    if (announcement != null) {
      try {
        await _speech.awaitSpeakCompletion(true);
        await _speech.setLanguage('fr-FR');
        await _speech.setSpeechRate(0.48);
        await _speech.setVolume(1);
        await _speech.speak(announcement);
        return;
      } on Object catch (error, stackTrace) {
        debugPrint('Lecture audio de notification impossible: $error');
        debugPrint('$stackTrace');
      }
    }

    if (kIsWeb) {
      await _playAsset(webAlertAsset, fallbackToSystem: true);
      return;
    }
    await _playSystemAlert();
  }

  static String? announcementFor(NotificationItem notification) =>
      switch (notification.type) {
        'game_challenge' =>
          'Nouveau défi de légende en attente. ${notification.message}',
        'game_rematch' =>
          'Nouvelle demande de revanche en attente. ${notification.message}',
        _ => null,
      };

  static Future<void> _playAsset(
    String? asset, {
    required bool fallbackToSystem,
  }) async {
    if (asset == null) {
      if (fallbackToSystem) await _playSystemAlert();
      return;
    }
    try {
      await _soundPlayer.stop();
      await _soundPlayer.play(AssetSource(asset));
    } on Object catch (error, stackTrace) {
      debugPrint('Son personnalisé de notification impossible: $error');
      debugPrint('$stackTrace');
      if (fallbackToSystem) await _playSystemAlert();
    }
  }

  static Future<void> _playSystemAlert() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } on Object catch (error, stackTrace) {
      debugPrint('Son système de notification indisponible: $error');
      debugPrint('$stackTrace');
    }
  }
}
