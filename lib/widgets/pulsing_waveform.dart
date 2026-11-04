import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/audio_recorder_service.dart';
import '../theme/app_theme.dart';

/// Particella sonora orbitante
class _SoundSpark {
  final double orbitRatio;
  final double speed;
  final double angleOffset;
  final double size;
  final bool isGold;

  const _SoundSpark({
    required this.orbitRatio,
    required this.speed,
    required this.angleOffset,
    required this.size,
    required this.isGold,
  });
}

/// Pulsante Microfono & Visualizzatore "Fluid Sonic Nebula":
/// Estremamente fluido (120 FPS con smoothing esponenziale a zero jitter),
/// iper-reattivo ai transienti sonori e con lente centrale in vetro olografico.
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
  late final AnimationController _ticker;

  // Variabili di interpolazione per fluidità a 60/120 FPS senza scatti
  double _smoothVolume = 0.0;
  double _smoothBass = 0.0;
  double _kickIntensity = 0.0;

  double _targetVolume = 0.0;
  double _targetBass = 0.0;
  bool _kickTriggered = false;
  double _currentDb = -60.0;

  // 18 scintille sonore con orbite armoniche
  static final List<_SoundSpark> _sparks = List.generate(18, (i) {
    final rng = math.Random(i * 3571 + 97);
    return _SoundSpark(
      orbitRatio: 0.62 + (rng.nextDouble() * 0.32),
      speed: (rng.nextBool() ? 1.0 : -1.0) * (0.5 + rng.nextDouble() * 0.8),
      angleOffset: rng.nextDouble() * 2 * math.pi,
      size: 1.6 + rng.nextDouble() * 1.8,
      isGold: rng.nextDouble() > 0.5,
    );
  });

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _setupListeners();
  }

  void _setupListeners() {
    widget.acousticNotifier?.addListener(_onAcousticUpdate);
    widget.amplitudeNotifier?.addListener(_onAmplitudeUpdate);
  }

  void _removeListeners() {
    widget.acousticNotifier?.removeListener(_onAcousticUpdate);
    widget.amplitudeNotifier?.removeListener(_onAmplitudeUpdate);
  }

  @override
  void didUpdateWidget(covariant PulsingWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.acousticNotifier != widget.acousticNotifier ||
        oldWidget.amplitudeNotifier != widget.amplitudeNotifier) {
      oldWidget.acousticNotifier?.removeListener(_onAcousticUpdate);
      oldWidget.amplitudeNotifier?.removeListener(_onAmplitudeUpdate);
      _setupListeners();
    }
  }

  void _onAcousticUpdate() {
    final state = widget.acousticNotifier?.value;
    if (state != null) {
      _targetVolume = state.normalized.clamp(0.0, 1.0);
      _targetBass = state.bassIntensity.clamp(0.0, 1.0);
      _currentDb = state.currentDb;
      if (state.isBassHit) {
        _kickTriggered = true;
      }
    }
  }

  void _onAmplitudeUpdate() {
    final amp = widget.amplitudeNotifier?.value ?? -60.0;
    _currentDb = amp;
    final norm = ((amp + 60.0) / 60.0).clamp(0.0, 1.0);
    _targetVolume = norm;
    _targetBass = norm * 0.6;
    if (norm > 0.45) _kickTriggered = true;
  }

  @override
  void dispose() {
    _removeListeners();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radarSize = widget.size ?? 260.0;
    final scale = radarSize / 260.0;

    return AnimatedBuilder(
      animation: _ticker,
      builder: (context, _) {
        // Smoothing esponenziale dinamico: attacco rapido (<16ms) e decadimento setoso
        final attackNorm = _targetVolume > _smoothVolume ? 0.32 : 0.12;
        _smoothVolume += (_targetVolume - _smoothVolume) * attackNorm;

        final attackBass = _targetBass > _smoothBass ? 0.38 : 0.15;
        _smoothBass += (_targetBass - _smoothBass) * attackBass;

        if (_kickTriggered) {
          _kickIntensity = 1.0;
          _kickTriggered = false;
        } else {
          _kickIntensity *= 0.88; // Decadimento morbido a 60/120Hz
        }

        final phase = _ticker.value * 2 * math.pi;

        // Rinculo elastico fisico della lente su transienti di cassa
        final membraneThump = widget.isListening
            ? 1.0 + (_kickIntensity * 0.15) + (_smoothVolume * 0.05)
            : (1.0 + math.sin(phase) * 0.025);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: radarSize,
              height: radarSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // 1. Rendering GPU ad alta efficienza: Onde fluide, aloni e pulviscolo
                  CustomPaint(
                    size: Size(radarSize, radarSize),
                    painter: _FluidSonicPainter(
                      phase: phase,
                      volume: _smoothVolume,
                      bass: _smoothBass,
                      kick: _kickIntensity,
                      isListening: widget.isListening,
                      sparks: _sparks,
                    ),
                  ),

                  // 2. Lente Olografica Centrale con Riflesso Speculare 3D
                  Transform.scale(
                    scale: membraneThump,
                    child: Container(
                      width: 106 * scale,
                      height: 106 * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          center: const Alignment(-0.35, -0.38),
                          radius: 0.9,
                          colors: widget.isListening
                              ? (_kickIntensity > 0.4
                                  ? const [
                                      Color(0xFF34D399),
                                      Color(0xFF0D9488),
                                      Color(0xFF041D1D),
                                    ]
                                  : const [
                                      Color(0xFF2DD4BF),
                                      Color(0xFF0F766E),
                                      Color(0xFF071B26),
                                    ])
                              : const [
                                  Color(0xFF1E293B),
                                  Color(0xFF0F172A),
                                  Color(0xFF050811),
                                ],
                          stops: const [0.0, 0.58, 1.0],
                        ),
                        border: Border.all(
                          color: widget.isListening
                              ? (_kickIntensity > 0.3
                                  ? AppTheme.accentGold.withValues(alpha: 0.95)
                                  : AppTheme.accentMint.withValues(alpha: 0.75))
                              : const Color(0xFF334155),
                          width: (_kickIntensity > 0.3 ? 2.4 : 1.8) * scale,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isListening
                                ? (_kickIntensity > 0.3
                                    ? AppTheme.accentGold.withValues(alpha: 0.55)
                                    : AppTheme.accentMint.withValues(alpha: 0.4))
                                : Colors.black45,
                            blurRadius: (_kickIntensity > 0.3 ? 32 : (widget.isListening ? 22 : 10)) * scale,
                            spreadRadius: (_kickIntensity > 0.3 ? 3 : (widget.isListening ? 1.5 : 0)) * scale,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Riflesso speculare a cupola in vetro satinato
                          Positioned(
                            top: 8 * scale,
                            left: 18 * scale,
                            right: 18 * scale,
                            height: 26 * scale,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.white.withValues(alpha: widget.isListening ? 0.32 : 0.15),
                                    Colors.white.withValues(alpha: 0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Equalizzatore fluido cinetico a 5 barre dipinto direttamente a GPU
                          if (widget.isListening)
                            CustomPaint(
                              size: Size(54 * scale, 38 * scale),
                              painter: _CoreEqualizerPainter(
                                volume: _smoothVolume,
                                bass: _smoothBass,
                                kick: _kickIntensity,
                                phase: phase,
                              ),
                            )
                          else
                            Icon(
                              Icons.mic_rounded,
                              size: (44 * scale).clamp(20.0, 50.0),
                              color: AppTheme.textPrimary,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (widget.showBadge && widget.isListening) ...[
              const SizedBox(height: 10),
              // Badge di feedback acustico in tempo reale
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: _kickIntensity > 0.35
                      ? AppTheme.accentGold.withValues(alpha: 0.15)
                      : AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _kickIntensity > 0.35
                        ? AppTheme.accentGold.withValues(alpha: 0.5)
                        : AppTheme.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _kickIntensity > 0.35 ? Icons.speaker_rounded : Icons.graphic_eq_rounded,
                      size: 12,
                      color: _kickIntensity > 0.35 ? AppTheme.accentGold : AppTheme.accentMint,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _kickIntensity > 0.35
                          ? 'BASSI DETECTED · ${_currentDb.toStringAsFixed(0)} dB'
                          : 'AUDIO ATTIVO · ${_currentDb.toStringAsFixed(0)} dB',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                        color: _kickIntensity > 0.35 ? AppTheme.accentGold : AppTheme.accentMint,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (widget.showStatusText && widget.statusText.isNotEmpty) ...[
              const SizedBox(height: 6),
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

/// Disegna l'equalizzatore a barre fluide all'interno della lente di vetro
class _CoreEqualizerPainter extends CustomPainter {
  final double volume;
  final double bass;
  final double kick;
  final double phase;

  _CoreEqualizerPainter({
    required this.volume,
    required this.bass,
    required this.kick,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int barCount = 5;
    final barWidth = size.width / (barCount * 1.8);
    final gap = barWidth * 0.8;
    final totalWidth = (barCount * barWidth) + ((barCount - 1) * gap);
    final startX = (size.width - totalWidth) / 2;

    final paintDark = Paint()
      ..color = const Color(0xFF03101C)
      ..style = PaintingStyle.fill;

    final paintKick = Paint()
      ..color = const Color(0xFFFDE68A)
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      // Modulazione organica per ciascuna banda di frequenza
      final harmonic = math.sin(phase * 1.5 + (i * 0.7)).abs() * 0.25;
      final ratio = switch (i) {
        0 => (0.35 + volume * 0.45 + harmonic),
        1 => (0.55 + bass * 0.45 + harmonic),
        2 => (0.75 + (kick * 0.35) + volume * 0.2 + harmonic),
        3 => (0.55 + bass * 0.45 + harmonic),
        _ => (0.35 + volume * 0.45 + harmonic),
      }.clamp(0.2, 1.0);

      final barH = size.height * ratio;
      final x = startX + i * (barWidth + gap);
      final y = (size.height - barH) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barH),
        Radius.circular(barWidth / 2),
      );

      final useKickGlow = kick > 0.4 && (i == 1 || i == 2 || i == 3);
      canvas.drawRRect(rect, useKickGlow ? paintKick : paintDark);
    }
  }

  @override
  bool shouldRepaint(covariant _CoreEqualizerPainter oldDelegate) => true;
}

/// Disegna le onde fluide armoniche e le particelle orbitanti con smoothing a 120 FPS
class _FluidSonicPainter extends CustomPainter {
  final double phase;
  final double volume;
  final double bass;
  final double kick;
  final bool isListening;
  final List<_SoundSpark> sparks;

  _FluidSonicPainter({
    required this.phase,
    required this.volume,
    required this.bass,
    required this.kick,
    required this.isListening,
    required this.sparks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 260.0;
    final maxR = (size.width / 2) - 2;

    if (!isListening) {
      // In modalità riposo: sottili anelli di respiro sereno
      final idle1 = Paint()
        ..color = AppTheme.accentMint.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * scale;
      canvas.drawCircle(center, 64 * scale, idle1);

      final idle2 = Paint()
        ..color = AppTheme.accentMint.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0 * scale;
      canvas.drawCircle(center, 80 * scale, idle2);
      return;
    }

    // ── 1. Alone Magnetico di Sfondo ─────────────────────────────────────────
    final auraR = (74.0 + volume * 30.0 + (kick * 16.0)) * scale;
    final auraPaint = Paint()
      ..color = (kick > 0.35 ? AppTheme.accentGold : AppTheme.accentMint)
          .withValues(alpha: (0.16 + volume * 0.14).clamp(0.0, 0.4))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 * scale);
    canvas.drawCircle(center, auraR, auraPaint);

    // ── 2. Onda Shockwave sui Kick Transients ────────────────────────────────
    if (kick > 0.08) {
      final shockR = (68.0 + (1.0 - kick) * 52.0) * scale;
      final shockAlpha = (kick * 0.65).clamp(0.0, 1.0);
      final shockPaint = Paint()
        ..color = AppTheme.accentGold.withValues(alpha: shockAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * scale;
      canvas.drawCircle(center, shockR.clamp(0.0, maxR), shockPaint);
    }

    // ── 3. Onda Fluida Esterna Armonica (Menta Liquida) ───────────────────────
    _drawSmoothFluidWave(
      canvas: canvas,
      center: center,
      baseRadius: 86.0 * scale,
      amp1: (5.0 + volume * 14.0) * scale,
      amp2: (3.5 + bass * 8.0) * scale,
      harmonics1: 3,
      harmonics2: 5,
      phaseOffset: phase,
      strokeColor: AppTheme.accentMint.withValues(alpha: 0.6 + volume * 0.35),
      fillColor: AppTheme.accentMint.withValues(alpha: 0.04 + volume * 0.06),
      strokeWidth: 2.0 * scale,
      maxR: maxR,
    );

    // ── 4. Onda Fluida Interna dei Bassi (Oro Caldo Reattivo) ─────────────────
    _drawSmoothFluidWave(
      canvas: canvas,
      center: center,
      baseRadius: 72.0 * scale,
      amp1: (4.0 + bass * 15.0) * scale,
      amp2: (3.0 + kick * 14.0) * scale,
      harmonics1: 4,
      harmonics2: 2,
      phaseOffset: -phase * 1.25,
      strokeColor: kick > 0.3
          ? AppTheme.accentGold.withValues(alpha: 0.95)
          : AppTheme.accentGold.withValues(alpha: 0.45 + bass * 0.4),
      fillColor: kick > 0.3
          ? AppTheme.accentGold.withValues(alpha: 0.12)
          : AppTheme.accentGold.withValues(alpha: 0.03),
      strokeWidth: (kick > 0.3 ? 2.5 : 1.5) * scale,
      maxR: maxR,
    );

    // ── 5. Scintille Quantiche Sonore Orbitanti ──────────────────────────────
    final sparkMint = Paint()
      ..color = AppTheme.accentMint.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final sparkGold = Paint()
      ..color = AppTheme.accentGold.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    for (final s in sparks) {
      final angle = s.angleOffset + (phase * s.speed);
      final r = (s.orbitRatio * 94.0 * scale) + (volume * 20.0 * scale) + (kick * 10.0 * scale);
      final px = center.dx + math.cos(angle) * r;
      final py = center.dy + math.sin(angle) * r;

      final sSize = (s.size * scale * (kick > 0.3 ? 1.4 : (1.0 + volume * 0.3))).clamp(1.2, 4.5);
      canvas.drawCircle(Offset(px, py), sSize, s.isGold ? sparkGold : sparkMint);
    }
  }

  void _drawSmoothFluidWave({
    required Canvas canvas,
    required Offset center,
    required double baseRadius,
    required double amp1,
    required double amp2,
    required int harmonics1,
    required int harmonics2,
    required double phaseOffset,
    required Color strokeColor,
    required Color fillColor,
    required double strokeWidth,
    required double maxR,
  }) {
    final path = Path();
    const int steps = 48; // Ottimizzato per 120 FPS senza sovraccaricare la GPU
    const double stepAngle = (2 * math.pi) / steps;

    for (int i = 0; i <= steps; i++) {
      final theta = i * stepAngle;
      final wave1 = math.sin(theta * harmonics1 + phaseOffset) * amp1;
      final wave2 = math.cos(theta * harmonics2 - phaseOffset * 0.8) * amp2;
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

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _FluidSonicPainter oldDelegate) => true;
}
