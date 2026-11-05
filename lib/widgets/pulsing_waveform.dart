import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/audio_recorder_service.dart';
import '../theme/app_theme.dart';

/// Particella sonora orbitante nel campo acustico
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
/// iper-reattivo a qualsiasi suono (voci, melodie, accordi, percussioni e bassi)
/// con equalizzatore cinetico integrato e lente centrale in vetro olografico.
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
  double _smoothTransient = 0.0;

  double _targetVolume = 0.0;
  double _targetTransient = 0.0;
  bool _transientTriggered = false;
  double _currentDb = -60.0;
  bool _isSoundActive = false;

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
      _targetVolume = state.soundIntensity.clamp(0.0, 1.0);
      _targetTransient = (state.transientIntensity > 0
              ? state.transientIntensity
              : (state.isTransientHit ? 0.7 : 0.0))
          .clamp(0.0, 1.0);
      _currentDb = state.currentDb;
      _isSoundActive = state.isSoundActive;
      if (state.isTransientHit || state.isBassHit) {
        _transientTriggered = true;
      }
    }
  }

  void _onAmplitudeUpdate() {
    final amp = widget.amplitudeNotifier?.value ?? -60.0;
    _currentDb = amp;
    final norm = ((amp + 48.0) / 36.0).clamp(0.0, 1.0);
    _targetVolume = math.pow(norm, 1.1).toDouble();
    _isSoundActive = amp > -45.0;
    if (norm > 0.4) _transientTriggered = true;
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
        // Smoothing esponenziale dinamico: reattività immediata a qualsiasi suono
        final attackVolume = _targetVolume > _smoothVolume ? 0.36 : 0.14;
        _smoothVolume += (_targetVolume - _smoothVolume) * attackVolume;

        final attackTransient = _targetTransient > _smoothTransient ? 0.45 : 0.18;
        _smoothTransient += (_targetTransient - _smoothTransient) * attackTransient;

        if (_transientTriggered) {
          _smoothTransient = 1.0;
          _transientTriggered = false;
        } else {
          _smoothTransient *= 0.86; // Decadimento morbido a 60/120Hz
        }

        final phase = _ticker.value * 2 * math.pi;

        // Livello sonoro complessivo combinato per la modulazione estetica
        final soundActivity = (_smoothVolume * 0.75 + _smoothTransient * 0.35).clamp(0.0, 1.0);

        // Espansione e respiro reattivo del pulsante centrale a OGNI suono
        final membraneThump = widget.isListening
            ? 1.0 + (_smoothVolume * 0.15) + (_smoothTransient * 0.10)
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
                  // 1. Rendering GPU ad alta efficienza: Onde fluide reattive a ogni suono
                  CustomPaint(
                    size: Size(radarSize, radarSize),
                    painter: _FluidSonicPainter(
                      phase: phase,
                      volume: _smoothVolume,
                      transient: _smoothTransient,
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
                              ? [
                                  Color.lerp(
                                    const Color(0xFF2DD4BF),
                                    const Color(0xFF34D399),
                                    soundActivity,
                                  )!,
                                  Color.lerp(
                                    const Color(0xFF0F766E),
                                    const Color(0xFF0D9488),
                                    soundActivity,
                                  )!,
                                  const Color(0xFF041D1D),
                                ]
                              : const [
                                  Color(0xFF1E293B),
                                  Color(0xFF0F172A),
                                  Color(0xFF050811),
                                ],
                          stops: const [0.0, 0.58, 1.0],
                        ),
                        border: Border.all(
                          color: widget.isListening
                              ? Color.lerp(
                                  AppTheme.accentMint.withValues(alpha: 0.75),
                                  AppTheme.accentGold.withValues(alpha: 0.95),
                                  soundActivity,
                                )!
                              : const Color(0xFF334155),
                          width: (1.8 + soundActivity * 0.8) * scale,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isListening
                                ? Color.lerp(
                                    AppTheme.accentMint.withValues(alpha: 0.35 + soundActivity * 0.25),
                                    AppTheme.accentGold.withValues(alpha: 0.6),
                                    soundActivity,
                                  )!
                                : Colors.black45,
                            blurRadius: (14.0 + soundActivity * 22.0) * scale,
                            spreadRadius: (1.0 + soundActivity * 3.0) * scale,
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

                          // Equalizzatore fluido cinetico a 5 bande: danza con ogni frequenza sonora
                          if (widget.isListening)
                            CustomPaint(
                              size: Size(54 * scale, 38 * scale),
                              painter: _CoreEqualizerPainter(
                                volume: _smoothVolume,
                                transient: _smoothTransient,
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
              // Badge di feedback acustico in tempo reale per qualsiasi suono
              Builder(
                builder: (context) {
                  final isLively = soundActivity > 0.35;
                  final isDetected = _isSoundActive || _smoothVolume > 0.12;

                  final label = isDetected
                      ? (_smoothTransient > 0.4
                          ? 'DINAMICA / RITMO · ${_currentDb.toStringAsFixed(0)} dB'
                          : 'SUONO RILEVATO · ${_currentDb.toStringAsFixed(0)} dB')
                      : 'IN ASCOLTO · ${_currentDb.toStringAsFixed(0)} dB';

                  final badgeColor = isLively
                      ? AppTheme.accentGold
                      : (isDetected ? AppTheme.accentMint : AppTheme.textMuted);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: isLively
                          ? AppTheme.accentGold.withValues(alpha: 0.15)
                          : AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isLively
                            ? AppTheme.accentGold.withValues(alpha: 0.5)
                            : AppTheme.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isDetected ? Icons.graphic_eq_rounded : Icons.mic_rounded,
                          size: 12,
                          color: badgeColor,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                            color: badgeColor,
                          ),
                        ),
                      ],
                    ),
                  );
                },
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

/// Disegna l'equalizzatore a 5 barre fluide all'interno della lente, animato da qualsiasi suono rilevato
class _CoreEqualizerPainter extends CustomPainter {
  final double volume;
  final double transient;
  final double phase;

  _CoreEqualizerPainter({
    required this.volume,
    required this.transient,
    required this.phase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const int barCount = 5;
    final barWidth = size.width / (barCount * 1.85);
    final gap = barWidth * 0.75;
    final totalWidth = (barCount * barWidth) + ((barCount - 1) * gap);
    final startX = (size.width - totalWidth) / 2;

    for (int i = 0; i < barCount; i++) {
      // Ciascuna barra risponde armonicamente alla presenza di suono/voce/strumenti
      final harmonic = math.sin(phase * 2.2 + (i * 1.15)).abs() * (0.08 + volume * 0.26);
      final bandWeight = switch (i) {
        0 => 0.85, // Bassi / ritmica
        1 => 1.05, // Medi bassi (chitarre / corpo musicale)
        2 => 1.25, // Voce / melodia solista (barra centrale prominente)
        3 => 1.05, // Medi alti (presenza vocale / ottoni)
        _ => 0.85, // Alti / brillantezza
      };

      // In assenza di suono, le barre restano in elegante riposo compatto (~15%)
      final baseRest = 0.14 + (math.sin(phase + i) * 0.02);
      final soundRaise = (volume * bandWeight * 0.66) + (transient * 0.22 * (i == 2 ? 1.0 : 0.7));
      final ratio = (baseRest + soundRaise + harmonic).clamp(0.12, 1.0);

      final barH = size.height * ratio;
      final x = startX + i * (barWidth + gap);
      final y = (size.height - barH) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barH),
        Radius.circular(barWidth / 2),
      );

      final barActivity = (volume * 0.75 + transient * 0.35).clamp(0.0, 1.0);
      final barColor = Color.lerp(
        const Color(0xFF03101C),
        (i == 2 ? const Color(0xFFFDE68A) : const Color(0xFF2DD4BF)),
        (0.25 + barActivity * 0.75).clamp(0.0, 1.0),
      )!;

      final paint = Paint()
        ..color = barColor
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoreEqualizerPainter oldDelegate) => true;
}

/// Disegna le onde fluide armoniche e le particelle orbitanti con smoothing a 120 FPS
class _FluidSonicPainter extends CustomPainter {
  final double phase;
  final double volume;
  final double transient;
  final bool isListening;
  final List<_SoundSpark> sparks;

  _FluidSonicPainter({
    required this.phase,
    required this.volume,
    required this.transient,
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

    // ── 1. Alone Magnetico di Sfondo che respira col volume sonoro ────────────
    final auraR = (72.0 + volume * 36.0 + (transient * 16.0)) * scale;
    final auraPaint = Paint()
      ..color = (transient > 0.4 ? AppTheme.accentGold : AppTheme.accentMint)
          .withValues(alpha: (0.14 + volume * 0.22).clamp(0.0, 0.45))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 18 * scale);
    canvas.drawCircle(center, auraR, auraPaint);

    // ── 2. Onda Shockwave sui Picchi Sonori e Dinamici ────────────────────────
    if (transient > 0.06 || volume > 0.45) {
      final intensity = math.max(transient, volume * 0.7);
      final shockR = (66.0 + (1.0 - intensity) * 54.0) * scale;
      final shockAlpha = (intensity * 0.65).clamp(0.0, 0.95);
      final shockPaint = Paint()
        ..color = (transient > 0.35 ? AppTheme.accentGold : AppTheme.accentMint)
            .withValues(alpha: shockAlpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8 * scale;
      canvas.drawCircle(center, shockR.clamp(0.0, maxR), shockPaint);
    }

    // ── 3. Onda Fluida Esterna Armonica (Menta Liquida Reattiva al Suono) ──────
    _drawSmoothFluidWave(
      canvas: canvas,
      center: center,
      baseRadius: (82.0 + volume * 10.0) * scale,
      amp1: (4.5 + volume * 18.0) * scale,
      amp2: (3.0 + volume * 12.0 + transient * 6.0) * scale,
      harmonics1: 3,
      harmonics2: 5,
      phaseOffset: phase,
      strokeColor: AppTheme.accentMint.withValues(alpha: 0.55 + volume * 0.4),
      fillColor: AppTheme.accentMint.withValues(alpha: 0.03 + volume * 0.07),
      strokeWidth: 2.0 * scale,
      maxR: maxR,
    );

    // ── 4. Onda Fluida Interna Dinamica (Oro Caldo / Turchese) ────────────────
    _drawSmoothFluidWave(
      canvas: canvas,
      center: center,
      baseRadius: (70.0 + volume * 6.0) * scale,
      amp1: (3.5 + volume * 15.0) * scale,
      amp2: (2.5 + transient * 14.0) * scale,
      harmonics1: 4,
      harmonics2: 2,
      phaseOffset: -phase * 1.25,
      strokeColor: transient > 0.35
          ? AppTheme.accentGold.withValues(alpha: 0.95)
          : AppTheme.accentGold.withValues(alpha: 0.35 + volume * 0.5),
      fillColor: transient > 0.35
          ? AppTheme.accentGold.withValues(alpha: 0.12)
          : AppTheme.accentGold.withValues(alpha: 0.03),
      strokeWidth: (transient > 0.35 ? 2.5 : 1.5) * scale,
      maxR: maxR,
    );

    // ── 5. Scintille Quantiche Sonore Orbitanti con Velocità Dinamica ──────────
    final sparkMint = Paint()
      ..color = AppTheme.accentMint.withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    final sparkGold = Paint()
      ..color = AppTheme.accentGold.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;

    for (final s in sparks) {
      final speedBoost = 1.0 + (volume * 1.2);
      final angle = s.angleOffset + (phase * s.speed * speedBoost);
      final r = (s.orbitRatio * 92.0 * scale) + (volume * 24.0 * scale) + (transient * 10.0 * scale);
      final px = center.dx + math.cos(angle) * r;
      final py = center.dy + math.sin(angle) * r;

      final sSize = (s.size * scale * (1.0 + volume * 0.5 + transient * 0.3)).clamp(1.2, 4.6);
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
