import 'package:flutter/material.dart';

class StoryOptionsBottomSheet extends StatefulWidget {
  final Function(String? backgroundColor, String? textColor, double fontSize)
  onOptionsSelected;

  const StoryOptionsBottomSheet({super.key, required this.onOptionsSelected});

  @override
  State<StoryOptionsBottomSheet> createState() =>
      _StoryOptionsBottomSheetState();
}

class _StoryOptionsBottomSheetState extends State<StoryOptionsBottomSheet> {
  String? _selectedBgColor;
  String? _selectedTextColor;
  double _fontSize = 24;

  final List<String> _backgroundColors = [
    '#1F2937', // Dark gray
    '#DC2626', // Red
    '#EA580C', // Orange
    '#EAAC02', // Yellow
    '#16A34A', // Green
    '#0284C7', // Blue
    '#7C3AED', // Purple
    '#DB2777', // Pink
    '#000000', // Black
    '#FFFFFF', // White
  ];

  final List<String> _textColors = [
    '#FFFFFF', // White
    '#000000', // Black
    '#FFD700', // Gold
    '#FF69B4', // Hot Pink
    '#00CED1', // Dark Turquoise
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111827),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Couleur de fond',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _backgroundColors.map((color) {
                final isSelected = _selectedBgColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedBgColor = color);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _parseColor(color),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? Border.all(color: Colors.white, width: 3)
                          : null,
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(Icons.check, color: Colors.white),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Couleur du texte',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _textColors.map((color) {
                final isSelected = _selectedTextColor == color;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedTextColor = color);
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _parseColor(color),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white30, width: 1),
                    ),
                    child: isSelected
                        ? const Center(
                            child: Icon(Icons.check, color: Colors.black),
                          )
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text(
              'Taille de police',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Slider(
              value: _fontSize,
              min: 12,
              max: 48,
              divisions: 9,
              label: _fontSize.toStringAsFixed(0),
              activeColor: const Color(0xFF2563EB),
              inactiveColor: Colors.white30,
              onChanged: (value) {
                setState(() => _fontSize = value);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  widget.onOptionsSelected(
                    _selectedBgColor,
                    _selectedTextColor,
                    _fontSize,
                  );
                  Navigator.pop(context);
                },
                child: const Text(
                  'Appliquer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xff')));
    } catch (e) {
      return Colors.black;
    }
  }
}
