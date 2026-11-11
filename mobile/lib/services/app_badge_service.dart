import 'package:app_badge_plus/app_badge_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class AppBadgeService {
  static Future<bool>? _supportFuture;
  static bool _permissionRequestAttempted = false;

  static Future<void> updateCount(int count) async {
    try {
      final supported = await (_supportFuture ??= AppBadgePlus.isSupported());
      if (!supported) {
        debugPrint('Le badge natif n’est pas pris en charge sur cet appareil.');
        return;
      }
      final badgeCount = count < 0 ? 0 : count;
      if (badgeCount > 0) {
        var permission = await Permission.notification.status;
        if (!permission.isGranted &&
            !permission.isProvisional &&
            !_permissionRequestAttempted) {
          _permissionRequestAttempted = true;
          permission = await Permission.notification.request();
        }
        if (!permission.isGranted && !permission.isProvisional) {
          debugPrint('La permission de notification/badge n’est pas accordée.');
          return;
        }
      }
      await AppBadgePlus.updateBadge(badgeCount);
    } on Object catch (error, stackTrace) {
      debugPrint('Mise à jour du badge natif impossible : $error');
      debugPrint('$stackTrace');
    }
  }
}
