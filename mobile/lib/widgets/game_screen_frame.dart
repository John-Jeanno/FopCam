import 'package:flutter/material.dart';

class GameScreenFrame extends StatelessWidget {
  const GameScreenFrame({
    super.key,
    required this.child,
    this.maxWidth = 1120,
    this.maxHeight = 900,
    this.breakpoint = 1000,
  });

  final Widget child;
  final double maxWidth;
  final double maxHeight;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < breakpoint) return child;
        return ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Center(
            child: SizedBox(
              width: constraints.maxWidth.clamp(0, maxWidth),
              height: constraints.maxHeight.clamp(0, maxHeight),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
