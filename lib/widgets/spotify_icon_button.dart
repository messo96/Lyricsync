import 'dart:math' as math;
import 'package:flutter/material.dart';

class SpotifyIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const SpotifyIconButton({
    super.key,
    required this.onTap,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size / 2),
      child: Tooltip(
        message: 'Apri su Spotify',
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: Color(0xFF1DB954), // Spotify Green
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x661DB954),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: Size(size * 0.62, size * 0.62),
              painter: _SpotifyLogoPainter(),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpotifyLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF121212)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width * 0.44;
    final cy = size.height * 0.58;

    // Onda superiore
    paint.strokeWidth = size.width * 0.14;
    final rect1 = Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.58);
    canvas.drawArc(rect1, -1.35 * math.pi, 0.68 * math.pi, false, paint);

    // Onda centrale
    paint.strokeWidth = size.width * 0.125;
    final rect2 = Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.43);
    canvas.drawArc(rect2, -1.35 * math.pi, 0.65 * math.pi, false, paint);

    // Onda inferiore
    paint.strokeWidth = size.width * 0.11;
    final rect3 = Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.28);
    canvas.drawArc(rect3, -1.35 * math.pi, 0.62 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

