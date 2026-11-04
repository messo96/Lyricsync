import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/audio_recorder_service.dart';
import '../theme/app_theme.dart';

/// Un granello/quanto acustico orbitante attorno al nucleo sonoro
class _OrbitalParticle {
  final double radiusRatio; // Distanza proporzionale dal centro [0.55, 1.0]
  final double speed;       // Velocità orbitale (rad/s)
  final double initialAngle;// Angolo iniziale
  final double size;        // Raggio particella
  final bool isGold;        // Oro caldo o Menta nordica

  const _OrbitalParticle({
    required this.radiusRatio,
    required this.speed,
    required this.initialAngle,
    required this.size,
    required this.isGold,
  });
}

/// Pulsante Microfono & Visualizzatore "Sonic Nebula":
/// Un nucleo sonoro vivente con onde fluide armoniche, pulviscolo orbitante e lente olografica
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

  // 24 particelle quantiche sonore generate deterministicamente
  static final List<_OrbitalParticle> _particles = List.generate(24, (i) {
    final rng = math.Random(i * 7919 + 101);
    return _OrbitalParticle(
      radiusRatio: 0.58 + (rng.nextDouble() * 0.38),
      speed: (rng.nextBool() ? 1.0 : -1.0) * (0.6 + rng.nextDouble() * 1.2),
      initialAngle: rng.nextDouble() * 2 * math.pi,
      size: 1.8 + rng.nextDouble() * 2.2,
      isGold: rng.nextDouble() > 0.55,
    );
  });

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
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
        final phase = _animController.value * 2 * math.pi;

        // Rinculo elastico fisico sui transienti di cassa/bassi
        final membraneThump = widget.isListening
            ? 1.0 + (isBassHit ? (bassIntensity * 0.18) : (normalized * 0.06))
            : (1.0 + math.sin(phase) * 0.03);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: radarSize,
              height: radarSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Pittore Nebula Acustica (onde fluide armoniche, pulviscolo quantico, shockwave)
                  CustomPaint(
                    size: Size(radarSize, radarSize),
                    painter: _SonicNebulaPainter(
                      phase: phase,
                      normalized: normalized,
                      bassIntensity: bassIntensity,
                      isBassHit: isBassHit,
                      isListening: widget.isListening,
                      particles: _particles,
                    ),
                  ),

                  // 2. Lente Olografica Centrale Frosted Glass
                  Transform.scale(
                    scale: membraneThump,
                    child: Container(
                      width: 108 * scale,
                      height: 108 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.35, -0.4),
                          radius: 0.9,
                          colors: widget.isListening
                              ? (isBassHit
                                  ? const [
                                      Color(0xFF34D399),
                                      Color(0xFF10B981),
                                      Color(0xFF0F2624),
                                    ]
                                  : const [
                                      Color(0xFF2DD4BF),
                                      Color(0xFF0F766E),
                                      Color(0xFF0A1826),
                                    ])
                              : const [
                                  Color(0xFF1E293B),
                                  Color(0xFF111827),
                                  Color(0xFF070B14),
                                ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                        border: Border.all(
                          color: widget.isListening
                              ? (isBassHit
                                  ? AppTheme.accentGold.withValues(alpha: 0.9)
                                  : AppTheme.accentMint.withValues(alpha: 0.75))
                              : const Color(0xFF334155),
                          width: (isBassHit ? 2.5 : 1.8) * scale,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isListening
                                ? (isBassHit
                                    ? AppTheme.accentGold.withValues(alpha: 0.6)
                                    : AppTheme.accentMint.withValues(alpha: 0.45))
                                : Colors.black54,
                            blurRadius: (isBassHit ? 34 : (widget.isListening ? 24 : 10)) * scale,
                            spreadRadius: (isBassHit ? 4 : (widget.isListening ? 2 : 0)) * scale,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Riflesso speculare superiore a cupola
                          Positioned(
                            top: 8 * scale,
                            left: 18 * scale,
                            right: 18 * scale,
                            height: 28 * scale,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: widget.isListening ? 0.35 : 0.15),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Icona / Equalizzatore fluttuante
                          _buildCenterSymbol(scale, isBassHit, normalized, bassIntensity),
                        ],
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
                margin: const EdgeInsets.only(bottom: 6),
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
                          ? 'BASSI DETECTED · ${db.toStringAsFixed(0)} dB'
                          : 'AUDIO ATTIVO · ${db.toStringAsFixed(0)} dB',
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

  /// Icona centrale viva: microfono in riposo, equalizzatore cinetico a 5 bande in ascolto
  Widget _buildCenterSymbol(double scale, bool isBassHit, double norm, double bass) {
    if (!widget.isListening) {
      return Icon(
        Icons.mic_rounded,
        size: (44 * scale).clamp(20.0, 50.0),
        color: AppTheme.textPrimary,
      );
    }

    // Barre equalizzatore cinetiche a 5 frequenze nel centro della lente
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(5, (index) {
        final barHeightRatio = switch (index) {
          0 => (0.35 + norm * 0.45),
          1 => (0.55 + bass * 0.45),
          2 => (0.75 + (isBassHit ? 0.35 : norm * 0.25)),
          3 => (0.55 + bass * 0.45),
          _ => (0.35 + norm * 0.45),
        }.clamp(0.25, 1.1);

        final h = (36 * scale * barHeightRatio).clamp(8.0, 48.0);
        final w = (4.5 * scale).clamp(2.5, 6.0);

        return Container(
          width: w,
          height: h,
          margin: EdgeInsets.symmetric(horizontal: (2.5 * scale).clamp(1.5, 4.0)),
          decoration: BoxDecoration(
            color: isBassHit
                ? (index == 2 ? const Color(0xFFFDE68A) : Colors.white)
                : const Color(0xFF04121E),
            borderRadius: BorderRadius.circular(4),
            boxShadow: isBassHit
                ? [
                    const BoxShadow(color: Colors.white70, blurRadius: 4),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

/// Disegna la "Sonic Nebula": onde fluide parametriche, pulviscolo orbitale e shockwave
class _SonicNebulaPainter extends CustomPainter {
  final double phase;
  final double normalized;
  final double bassIntensity;
  final bool isBassHit;
  final bool isListening;
  final List<_OrbitalParticle> particles;

  _SonicNebulaPainter({
    required this.phase,
    required this.normalized,
    required this.bassIntensity,
    required this.isBassHit,
    required this.isListening,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 260.0;
    final maxR = (size.width / 2) - 2;

    if (!isListening) {
      // In modalità idle: sottile alone polare e cerchio di riposo
      final idlePaint = Paint()
        ..color = AppTheme.accentMint.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * scale;
      canvas.drawCircle(center, 64 * scale, idlePaint);

      final outerIdle = Paint()
        ..color = AppTheme.accentMint.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * scale;
      canvas.drawCircle(center, 80 * scale, outerIdle);
      return;
    }

    // ── LIVELLO 1: Alone Nebula di Sfondo Luminoso ──────────────────────────
    final nebulaRadius = (75.0 + normalized * 32.0 + (isBassHit ? 18.0 : 0.0)) * scale;
    final nebulaPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (isBassHit ? AppTheme.accentGold : AppTheme.accentMint).withValues(alpha: isBassHit ? 0.35 : 0.22),
          AppTheme.accentMint.withValues(alpha: 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: nebulaRadius));
    canvas.drawCircle(center, nebulaRadius, nebulaPaint);

    // ── LIVELLO 2: Onda d'Urto Shockwave su Bass Transients ──────────────────
    if (isBassHit || bassIntensity > 0.4) {
      final shockwaveR = (70.0 + (phase / (2 * math.pi)) * 52.0) * scale;
      final shockAlpha = ((1.0 - (phase / (2 * math.pi))) * 0.6).clamp(0.0, 1.0);
      final shockPaint = Paint()
        ..color = AppTheme.accentGold.withValues(alpha: shockAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * scale;
      canvas.drawCircle(center, shockwaveR.clamp(0.0, maxR), shockPaint);
    }

    // ── LIVELLO 3: Onda Fluida Esterna Armonica (Menta Liquida) ──────────────
    _drawFluidHarmonicWave(
      canvas: canvas,
      center: center,
      baseRadius: 88.0 * scale,
      amplitude1: (6.0 + normalized * 14.0) * scale,
      amplitude2: (4.0 + bassIntensity * 8.0) * scale,
      harmonics1: 3,
      harmonics2: 5,
      phaseOffset: phase,
      strokeColor: AppTheme.accentMint.withValues(alpha: 0.65 + normalized * 0.35),
      fillColor: AppTheme.accentMint.withValues(alpha: 0.04 + normalized * 0.06),
      strokeWidth: 2.0 * scale,
      maxR: maxR,
    );

    // ── LIVELLO 4: Onda Fluida Interna dei Bassi (Oro Caldo e Reattività Beat) ─
    _drawFluidHarmonicWave(
      canvas: canvas,
      center: center,
      baseRadius: 72.0 * scale,
      amplitude1: (4.0 + bassIntensity * 16.0) * scale,
      amplitude2: (3.0 + (isBassHit ? 14.0 : 4.0)) * scale,
      harmonics1: 4,
      harmonics2: 2,
      phaseOffset: -phase * 1.3,
      strokeColor: isBassHit
          ? AppTheme.accentGold.withValues(alpha: 0.95)
          : AppTheme.accentGold.withValues(alpha: 0.45 + bassIntensity * 0.4),
      fillColor: isBassHit
          ? AppTheme.accentGold.withValues(alpha: 0.12)
          : AppTheme.accentGold.withValues(alpha: 0.03),
      strokeWidth: (isBassHit ? 2.6 : 1.5) * scale,
      maxR: maxR,
    );

    // ── LIVELLO 5: Pulviscolo Quantico Sonoro Orbitante ──────────────────────
    final particleMint = Paint()
      ..color = AppTheme.accentMint.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final particleGold = Paint()
      ..color = AppTheme.accentGold.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    for (final p in particles) {
      final angle = p.initialAngle + (phase * p.speed);
      final r = (p.radiusRatio * 96.0 * scale) + (normalized * 22.0 * scale) + (isBassHit ? 12.0 * scale : 0.0);
      final px = center.dx + math.cos(angle) * r;
      final py = center.dy + math.sin(angle) * r;

      final pSize = (p.size * scale * (isBassHit ? 1.4 : (1.0 + normalized * 0.35))).clamp(1.2, 5.0);
      canvas.drawCircle(Offset(px, py), pSize, p.isGold ? particleGold : particleMint);
    }
  }

  /// Traccia una forma fluida armonica chiusa con modulazione sinusoidale continua
  void _drawFluidHarmonicWave({
    required Canvas canvas,
    required Offset center,
    required double baseRadius,
    required double amplitude1,
    required double amplitude2,
    required int harmonics1,
    required int harmonics2,
    required double phaseOffset,
    required Color strokeColor,
    required Color fillColor,
    required double strokeWidth,
    required double maxR,
  }) {
    final path = Path();
    const int steps = 72; // Campionamento fluido a 5 gradi per segmento
    const double stepAngle = (2 * math.pi) / steps;

    for (int i = 0; i <= steps; i++) {
      final theta = i * stepAngle;
      final wave1 = math.sin(theta * harmonics1 + phaseOffset) * amplitude1;
      final wave2 = math.cos(theta * harmonics2 - phaseOffset * 0.8) * amplitude2;
      final r = (baseRadius + wave1 + wave2).clamp(30.0, maxR);

      final x = center.dx + math.cos(theta) * r;
      final y = center.dy + math.sin(theta) * r;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Disegna riempimento translucido
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Disegna bordo fluorescente
    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _SonicNebulaPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.normalized != normalized ||
        oldDelegate.bassIntensity != bassIntensity ||
        oldDelegate.isBassHit != isBassHit ||
        oldDelegate.isListening != isListening;
  }
}
