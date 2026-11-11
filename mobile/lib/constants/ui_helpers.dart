import 'package:flutter/material.dart';
import 'package:mobile/constants/app_colors.dart';

BoxDecoration buildPanelDecoration() {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.08)),
  );
}

BoxDecoration buildActiveBadgeDecoration() {
  return BoxDecoration(
    gradient: const LinearGradient(
      colors: [AppColors.primary, AppColors.primaryDark],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    boxShadow: const [
      BoxShadow(
        color: Color.fromRGBO(153, 27, 27, 0.28),
        blurRadius: 18,
        offset: Offset(0, 10),
      ),
    ],
  );
}

BoxDecoration buildGhostPanelDecoration() {
  return BoxDecoration(
    color: const Color(0xFF111827),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.08)),
  );
}
