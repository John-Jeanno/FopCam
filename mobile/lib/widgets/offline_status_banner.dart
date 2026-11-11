import 'package:flutter/material.dart';
import 'package:mobile/services/offline_data_service.dart';

class OfflineStatusBanner extends StatelessWidget {
  const OfflineStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: OfflineDataService.isOnline,
      builder: (context, isOnline, _) => ValueListenableBuilder<int>(
        valueListenable: OfflineDataService.pendingChanges,
        builder: (context, pending, _) {
          if (isOnline && pending == 0) return const SizedBox.shrink();
          final message = !isOnline
              ? 'Hors ligne — les données consultables proviennent du cache.'
              : 'Synchronisation : $pending modification'
                    '${pending == 1 ? '' : 's'} en attente.';
          return SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              color: isOnline
                  ? const Color(0xFF713F12)
                  : const Color(0xFF7F1D1D),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Row(
                children: [
                  Icon(
                    isOnline ? Icons.sync : Icons.cloud_off,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
