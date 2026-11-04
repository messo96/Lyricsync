import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/audio_recorder_service.dart';
import '../theme/app_theme.dart';

class PulsingWaveform extends StatefulWidget {
  final bool isListening;
  final ValueNotifier<double>? amplitudeNotifier;
  final ValueNotifier<AcousticState>? acousticNotifier;
  final String statusText;
  final double? size;
  final bool showStatusText;
  final bool showBadge;

  const PulsingWaveform({
    super.key,
    required this.isListening,
    this.amplitudeNotifier,
    this.acousticNotifier,
    required this.statusText,
    this.size,
    this.showStatusText = true,
    this.showBadge = true,
  });

  @override
  State<PulsingWaveform> createState() => _PulsingWaveformState();
}

class _PulsingWaveformState extends State<PulsingWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.acousticNotifier != null) {
      return ValueListenableBuilder<AcousticState>(
        valueListenable: widget.acousticNotifier!,
        builder: (context, acoustic, child) {
          return _buildContent(
            context,
            normalized: acoustic.normalized,
            db: acoustic.currentDb,
            isBassHit: acoustic.isBassHit,
            bassIntensity: acoustic.bassIntensity,
          );
        },
      );
    }

    if (widget.amplitudeNotifier != null) {
      return ValueListenableBuilder<double>(
        valueListenable: widget.amplitudeNotifier!,
        builder: (context, amplitude, child) {
          final norm = ((amplitude + 60.0) / 60.0).clamp(0.0, 1.0);
          final isBass = norm > 0.45;
          return _buildContent(
            context,
            normalized: norm,
            db: amplitude,
            isBassHit: isBass,
            bassIntensity: norm * 0.6,
          );
        },
      );
    }

    return _buildContent(
      context,
      normalized: 0.0,
      db: -60.0,
      isBassHit: false,
      bassIntensity: 0.0,
    );
  }

  Widget _buildContent(
    BuildContext context, {
    required double normalized,
    required double db,
    required bool isBassHit,
    required double bassIntensity,
  }) {
    final radarSize = widget.size ?? 260.0;
    final scale = radarSize / 260.0;

    return AnimatedBuilder(
      animation: _animController,
      builder: (context, _) {
        final animVal = _animController.value;

        // Effetto membrana subwoofer: espansione elastica sui colpi di basso
        final membraneThump = widget.isListening
            ? 1.0 + (isBassHit ? (bassIntensity * 0.16) : (normalized * 0.07))
            : 1.0;

        // Onde concentriche d'espansione
        final wavePulse1 = widget.isListening
            ? (math.sin(animVal * 2 * math.pi) * 0.12 + 0.88) * (1.0 + normalized * 0.35)
            : 1.0;

        final wavePulse2 = widget.isListening
            ? (math.cos(animVal * 2 * math.pi) * 0.15 + 0.85) * (1.0 + bassIntensity * 0.45)
            : 1.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: radarSize,
              height: radarSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Anello esterno 1: Onda acustica d'ambiente (Mint calmo)
                  if (widget.isListening)
                    Container(
                      width: 230 * wavePulse1 * scale,
                      height: 230 * wavePulse1 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentMint.withValues(
                          alpha: 0.03 + (normalized * 0.05),
                        ),
                        border: Border.all(
                          color: AppTheme.accentMint.withValues(
                            alpha: 0.15 + (normalized * 0.25),
                          ),
                          width: 1.2 * scale,
                        ),
                      ),
                    ),

                  // Anello esterno 2: Onda d'urto dei bassi (Oro champagne caldo)
                  if (widget.isListening)
                    Container(
                      width: 180 * wavePulse2 * scale,
                      height: 180 * wavePulse2 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentGold.withValues(
                          alpha: 0.04 + (bassIntensity * 0.08),
                        ),
                        border: Border.all(
                          color: isBassHit
                              ? AppTheme.accentGold.withValues(alpha: 0.65)
                              : AppTheme.accentGold.withValues(alpha: 0.2),
                          width: (isBassHit ? 2.0 : 1.2) * scale,
                        ),
                      ),
                    ),

                  // Corona radiale di barre equalizzatore reattive all'audio e ai bassi
                  if (widget.isListening)
                    CustomPaint(
                      size: Size(radarSize, radarSize),
                      painter: _RadialEqualizerPainter(
                        normalized: normalized,
                        bassIntensity: bassIntensity,
                        isBassHit: isBassHit,
                        animPhase: animVal * 2 * math.pi,
                      ),
                    ),

                  // Cono centrale subwoofer (con microfono) con reattività fisica
                  Transform.scale(
                    scale: membraneThump,
                    child: Container(
                      width: 116 * scale,
                      height: 116 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.isListening
                              ? (isBassHit
                                  ? const [Color(0xFF34D399), Color(0xFFF6C974)] // Lampo cassa / beat
                                  : const [Color(0xFF2DD4BF), Color(0xFF0EA5E9)]) // Menta e oceano
                              : const [AppTheme.surfaceLight, Color(0xFF131926)],
                        ),
                        border: Border.all(
                          color: widget.isListening
                              ? (isBassHit ? AppTheme.accentGold : AppTheme.accentMint)
                              : AppTheme.border,
                          width: (isBassHit ? 2.5 : 1.5) * scale,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isListening
                                ? (isBassHit
                                    ? AppTheme.accentGold.withValues(alpha: 0.55)
                                    : AppTheme.accentMint.withValues(alpha: 0.4))
                                : Colors.black45,
                            blurRadius: (isBassHit ? 36 : (widget.isListening ? 26 : 12)) * scale,
                            spreadRadius: (isBassHit ? 4 : (widget.isListening ? 2 : 0)) * scale,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.isListening
                            ? (isBassHit ? Icons.equalizer_rounded : Icons.graphic_eq_rounded)
                            : Icons.mic_rounded,
                        size: (46 * scale).clamp(20.0, 50.0),
                        color: widget.isListening
                            ? const Color(0xFF070A10)
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (widget.showBadge && widget.isListening) ...[
              const SizedBox(height: 10),
              // Badge di feedback acustico in tempo reale (dB e Bassi)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isBassHit
                      ? AppTheme.accentGold.withValues(alpha: 0.15)
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isBassHit
                        ? AppTheme.accentGold.withValues(alpha: 0.45)
                        : AppTheme.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isBassHit ? Icons.speaker_rounded : Icons.graphic_eq_rounded,
                      size: 12,
                      color: isBassHit ? AppTheme.accentGold : AppTheme.accentMint,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isBassHit
                          ? 'BASSI · ${db.toStringAsFixed(0)} dB'
                          : 'AUDIO · ${db.toStringAsFixed(0)} dB',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: isBassHit ? AppTheme.accentGold : AppTheme.accentMint,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (widget.showStatusText && widget.statusText.isNotEmpty) ...[
              const SizedBox(height: 6),
              // Testo di stato principale
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  widget.statusText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: widget.isListening ? AppTheme.accentMint : AppTheme.textSecondary,
                    letterSpacing: 0.1,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Disegna la corona radiale di 32 barre equalizzatore che ballano e reagiscono ai bassi
class _RadialEqualizerPainter extends CustomPainter {
  final double normalized;
  final double bassIntensity;
  final bool isBassHit;
  final double animPhase;

  _RadialEqualizerPainter({
    required this.normalized,
    required this.bassIntensity,
    required this.isBassHit,
    required this.animPhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 260.0;
    const int barCount = 32;
    final double innerRadius = 66.0 * scale;

    final paintMint = Paint()
      ..color = AppTheme.accentMint.withValues(alpha: 0.75)
      ..strokeWidth = 2.6 * scale
      ..strokeCap = StrokeCap.round;

    final paintGold = Paint()
      ..color = AppTheme.accentGold.withValues(alpha: 0.85)
      ..strokeWidth = 3.0 * scale
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < barCount; i++) {
      final angle = (i * 2 * math.pi) / barCount;
      // Le barre in basso (tra 1/4 e 3/4 di pi greco) reagiscono maggiormente ai bassi
      final isBottomBassZone = math.sin(angle) > 0.1;

      final harmonicWobble = math.sin(animPhase + (i * 0.35)).abs() * 4.0;
      final bassBoost = isBottomBassZone
          ? (bassIntensity * (isBassHit ? 28.0 : 16.0))
          : (bassIntensity * 8.0);
      final ambientBoost = normalized * 18.0;

      final barLength = (5.0 + ambientBoost + bassBoost + harmonicWobble) * scale;

      final startX = center.dx + math.cos(angle) * innerRadius;
      final startY = center.dy + math.sin(angle) * innerRadius;
      final endX = center.dx + math.cos(angle) * (innerRadius + barLength);
      final endY = center.dy + math.sin(angle) * (innerRadius + barLength);

      final useGold = isBottomBassZone && (isBassHit || bassIntensity > 0.35);
      canvas.drawLine(
        Offset(startX, startY),
        Offset(endX, endY),
        useGold ? paintGold : paintMint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadialEqualizerPainter oldDelegate) {
    return oldDelegate.normalized != normalized ||
        oldDelegate.bassIntensity != bassIntensity ||
        oldDelegate.isBassHit != isBassHit ||
        oldDelegate.animPhase != animPhase;
  }
}
