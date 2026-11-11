import 'package:flutter/material.dart';
import 'package:mobile/constants/app_colors.dart';

class SectionScreen extends StatelessWidget {
  final String title;
  final List<String> items;

  const SectionScreen({super.key, required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(item, style: const TextStyle(color: Colors.white)),
            );
          },
        ),
      ),
    );
  }
}
