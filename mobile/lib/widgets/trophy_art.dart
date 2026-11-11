import 'dart:math' as math;

import 'package:flutter/material.dart';

class TrophyArtwork extends StatelessWidget {
  const TrophyArtwork({
    super.key,
    required this.medal,
    this.width = 150,
    this.height = 180,
  });

  final String medal;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, height),
    painter: _TrophyArtworkPainter(medal),
  );
}

class TrophyCelebration extends StatefulWidget {
  const TrophyCelebration({
    super.key,
    this.medal = 'cup',
    this.width = 150,
    this.height = 180,
  });

  final String medal;
  final double width;
  final double height;

  @override
  State<TrophyCelebration> createState() => _TrophyCelebrationState();
}

class _TrophyCelebrationState extends State<TrophyCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: widget.width,
    height: widget.height,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          width: math.min(widget.width, widget.height) * 0.88,
          height: math.min(widget.width, widget.height) * 0.88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              center: Alignment(-0.35, -0.4),
              radius: 0.9,
              colors: [Color(0xFFFFF4BF), Color(0xFFFFD95A), Color(0xFFB97716)],
              stops: [0, 0.48, 1],
            ),
            border: Border.all(color: const Color(0xFFFFE9A1), width: 2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66502A00),
                blurRadius: 12,
                offset: Offset(0, 5),
              ),
            ],
          ),
        ),
        TrophyArtwork(
          medal: widget.medal,
          width: widget.width * (widget.medal == 'cup_pro' ? 0.86 : 0.72),
          height: widget.height * (widget.medal == 'cup_pro' ? 0.87 : 0.76),
        ),
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              size: Size(widget.width, widget.height),
              painter: _TrophyConfettiPainter(_controller.value),
            ),
          ),
        ),
      ],
    ),
  );
}

class _TrophyConfettiPainter extends CustomPainter {
  const _TrophyConfettiPainter(this.progress);

  final double progress;
  static const colors = [
    Color(0xFFFFD54F),
    Color(0xFFEF476F),
    Color(0xFF06D6A0),
    Color(0xFF4CC9F0),
    Color(0xFFB388FF),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (var index = 0; index < 28; index++) {
      final seed = index * 37;
      final xProgress = ((seed * 17) % 100) / 100;
      final speed = 0.6 + (seed % 11) / 12;
      final yProgress = (progress * speed + ((seed * 7) % 100) / 100) % 1;
      final sway = math.sin(progress * math.pi * 2 + seed) * size.width * 0.06;
      final x = xProgress * size.width + sway;
      final y = yProgress * size.height;
      final paint = Paint()..color = colors[index % colors.length];
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(progress * math.pi * 4 + seed)
        ..drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: math.max(2, size.width * 0.035),
            height: math.max(3, size.height * 0.035),
          ),
          paint,
        )
        ..restore();
    }
  }

  @override
  bool shouldRepaint(_TrophyConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _TrophyArtworkPainter extends CustomPainter {
  const _TrophyArtworkPainter(this.medal);

  final String medal;

  Color get _metal => switch (medal) {
    'bronze' => const Color(0xFFCD7F32),
    'silver' => const Color(0xFFC6D0D9),
    'gold' => const Color(0xFFFFD54F),
    _ => const Color(0xFFFFD36A),
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (medal != 'cup' && medal != 'cup_pro') {
      _paintMedal(canvas, size);
      return;
    }

    final isPro = medal == 'cup_pro';
    final scale = size.width / (isPro ? 164 : 180);
    canvas.save();
    canvas.scale(scale, size.height / 180);
    final gold = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFF2B0),
          Color(0xFFD89A24),
          Color(0xFFFFD95A),
          Color(0xFF9C5B0A),
        ],
        stops: [0, 0.3, 0.62, 1],
      ).createShader(const Rect.fromLTWH(28, 16, 124, 150));
    final darkGold = Paint()..color = const Color(0xFF8A4E05);
    final highlight = Paint()
      ..color = const Color(0xFFFFF5C1).withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.38)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final bowl = Path()
      ..moveTo(43, 23)
      ..lineTo(137, 23)
      ..lineTo(128, 75)
      ..cubicTo(124, 98, 109, 111, 90, 116)
      ..cubicTo(71, 111, 56, 98, 52, 75)
      ..close();
    canvas.drawPath(bowl.shift(const Offset(3, 6)), shadow);

    final leftHandle = Path()
      ..moveTo(47, 37)
      ..cubicTo(23, 29, 20, 48, 30, 69)
      ..cubicTo(36, 82, 45, 87, 57, 87);
    final rightHandle = Path()
      ..moveTo(133, 37)
      ..cubicTo(157, 29, 160, 48, 150, 69)
      ..cubicTo(144, 82, 135, 87, 123, 87);
    canvas
      ..drawPath(
        leftHandle,
        Paint()
          ..color = const Color(0xFFB97716)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12,
      )
      ..drawPath(
        leftHandle,
        Paint()
          ..color = const Color(0xFFFFD75B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      )
      ..drawPath(
        rightHandle,
        Paint()
          ..color = const Color(0xFFB97716)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12,
      )
      ..drawPath(
        rightHandle,
        Paint()
          ..color = const Color(0xFFFFD75B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6,
      )
      ..drawPath(bowl, gold);

    final rim = RRect.fromRectAndRadius(
      const Rect.fromLTWH(39, 17, 102, 15),
      const Radius.circular(7),
    );
    canvas
      ..drawRRect(rim, darkGold)
      ..drawRRect(
        rim.deflate(2.5),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFFFF4B5), Color(0xFFBE7915)],
          ).createShader(rim.outerRect),
      );

    final innerCup = Path()
      ..moveTo(60, 39)
      ..cubicTo(64, 76, 70, 94, 90, 101)
      ..cubicTo(110, 94, 116, 76, 120, 39);
    canvas.drawPath(innerCup, highlight);
    canvas.drawLine(
      const Offset(89, 111),
      const Offset(89, 136),
      gold..strokeWidth = 16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(73, 132, 34, 10),
        const Radius.circular(4),
      ),
      gold,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(58, 143, 64, 15),
        const Radius.circular(5),
      ),
      gold,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(52, 157, 76, 10),
        const Radius.circular(4),
      ),
      darkGold,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(55, 157, 70, 6),
        const Radius.circular(3),
      ),
      gold,
    );

    final star = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final radius = i.isEven ? 15.0 : 7.0;
      final point = Offset(
        90 + math.cos(angle) * radius,
        62 + math.sin(angle) * radius,
      );
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas
      ..drawPath(star, Paint()..color = const Color(0xFFFFF2B0))
      ..drawCircle(
        const Offset(90, 62),
        2.6,
        Paint()..color = const Color(0xFFFFD95A),
      );
    if (isPro) {
      const ribbonColors = [
        Color(0xFFE53935),
        Color(0xFFFFD54F),
        Color(0xFF06A85F),
        Color(0xFF2878E0),
        Color(0xFF9B59B6),
      ];
      for (var index = 0; index < ribbonColors.length; index++) {
        final x = 34.0 + index * 28;
        final tail = Path()
          ..moveTo(x, 72)
          ..lineTo(x + 8, 82)
          ..lineTo(x + 5, 104)
          ..lineTo(x - 2, 98)
          ..lineTo(x - 7, 105)
          ..lineTo(x - 5, 81)
          ..close();
        canvas.drawPath(tail, Paint()..color = ribbonColors[index]);
      }
    }
    canvas.restore();
  }

  void _paintMedal(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.58);
    final radius = size.width * 0.38;
    final ribbon = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFB71C1C), Color(0xFFE53935), Color(0xFF7F0000)],
      ).createShader(Offset.zero & size);
    final ribbonPath = Path()
      ..moveTo(size.width * 0.32, size.height * 0.03)
      ..lineTo(size.width * 0.68, size.height * 0.03)
      ..lineTo(size.width * 0.62, size.height * 0.35)
      ..lineTo(size.width * 0.5, size.height * 0.29)
      ..lineTo(size.width * 0.38, size.height * 0.35)
      ..close();
    canvas
      ..drawPath(ribbonPath, ribbon)
      ..drawCircle(center, radius, Paint()..color = _metal)
      ..drawCircle(
        center,
        radius * 0.82,
        Paint()
          ..color = Color.lerp(_metal, Colors.white, 0.38)!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    final star = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final pointRadius = radius * (i.isEven ? 0.48 : 0.22);
      final point =
          center +
          Offset(math.cos(angle) * pointRadius, math.sin(angle) * pointRadius);
      if (i == 0) {
        star.moveTo(point.dx, point.dy);
      } else {
        star.lineTo(point.dx, point.dy);
      }
    }
    star.close();
    canvas.drawPath(star, Paint()..color = const Color(0xFFFFF3BF));
  }

  @override
  bool shouldRepaint(_TrophyArtworkPainter oldDelegate) =>
      oldDelegate.medal != medal;
}
