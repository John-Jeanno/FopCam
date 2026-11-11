import 'package:flutter/material.dart';

class DuelActionButton extends StatelessWidget {
  const DuelActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.sports_kabaddi,
    this.backgroundColor = const Color(0xFFFFC107),
    this.foregroundColor = const Color(0xFF2B1600),
    this.disabledBackgroundColor,
    this.disabledForegroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? disabledBackgroundColor;
  final Color? disabledForegroundColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 54,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 27),
      label: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        disabledBackgroundColor: disabledBackgroundColor,
        disabledForegroundColor: disabledForegroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}
