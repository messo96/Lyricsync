import 'package:flutter/material.dart';

class ConcertGlowBanner extends StatefulWidget {
  final bool isEnabled;
  final VoidCallback onToggle;

  const ConcertGlowBanner({
    super.key,
    required this.isEnabled,
    required this.onToggle,
  });

  @override
  State<ConcertGlowBanner> createState() => _ConcertGlowBannerState();
}

class _ConcertGlowBannerState extends State<ConcertGlowBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;
  int _colorIndex = 0;

  static const List<Color> _glowColors = [
    Color(0xFFF59E0B), // Amber Gold
    Color(0xFF06B6D4), // Neon Cyan
    Color(0xFFEC4899), // Hot Pink
    Color(0xFF10B981), // Emerald
    Color(0xFF8B5CF6), // Laser Violet
  ];

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _cycleColor() {
    setState(() {
      _colorIndex = (_colorIndex + 1) % _glowColors.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return const SizedBox.shrink();

    final activeColor = _glowColors[_colorIndex];

    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, _) {
        final opacity = 0.25 + (_glowController.value * 0.45);

        return GestureDetector(
          onTap: _cycleColor,
          child: Container(
            height: 48,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  activeColor.withValues(alpha: opacity),
                  activeColor.withValues(alpha: opacity * 0.4),
                  activeColor.withValues(alpha: opacity),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: activeColor.withValues(alpha: 0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.light_mode_rounded, size: 16, color: activeColor),
                const SizedBox(width: 8),
                Text(
                  'Concert Glow Active · Tocca per cambiare colore',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: activeColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

