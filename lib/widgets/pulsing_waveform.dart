import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../services/audio_recorder_service.dart';
import '../theme/app_theme.dart';

/// Configurazione di ogni petalo di seta liquida 3D (stile Siri / Shazam Morph)
class _SilkPetalSpec {
  final Color primaryColor;
  final Color secondaryColor;
  final double speedMultiplier;
  final double phaseOffset;
  final int lobeCount;
  final double baseScale;

  const _SilkPetalSpec({
    required this.primaryColor,
    required this.secondaryColor,
    required this.speedMultiplier,
    required this.phaseOffset,
    required this.lobeCount,
    required this.baseScale,
  });
}

/// Nuova Animazione Pulsante Microfono "Siri / Shazam Liquid Silk & Sonic Ripples":
/// Completamente diversa dall'equalizzatore a barre:
/// 1. L'icona del microfono resta sempre al centro, levitando e pulsando in 3D col battito.
/// 2. 4 Petali di Seta Liquida Translucent (Ciano, Indaco, Oro, Corallo) si aprono e ruotano
///    morbidezza 120 FPS attorno al pulsante centrale quando ascolta.
/// 3. Anelli d'onda d'urto concentrici perfetti (stile Shazam) si espandono verso l'esterno
///    accompagnati da una scia radar a cometa.
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
  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;

  // Fasi continue accumulate con delta-time (dt) per fluidità assoluta a 120 FPS
  double _time = 0.0;
  double _flowPhase = 0.0;
  double _pulseCycle = 0.0;

  double _smoothVolume = 0.0;
  double _smoothTransient = 0.0;
  double _listeningBlend = 0.0;

  double _targetVolume = 0.0;
  double _targetTransient = 0.0;
  bool _transientImpulse = false;
  double _currentDb = -60.0;
  bool _isSoundActive = false;
  DateTime _lastAudioEventAt = DateTime.fromMillisecondsSinceEpoch(0);

  static const List<_SilkPetalSpec> _petals = [
    _SilkPetalSpec(
      primaryColor: Color(0xFF00F5D4),
      secondaryColor: Color(0xFF0EA5E9),
      speedMultiplier: 1.15,
      phaseOffset: 0.0,
      lobeCount: 3,
      baseScale: 1.04,
    ),
    _SilkPetalSpec(
      primaryColor: Color(0xFF6366F1),
      secondaryColor: Color(0xFFA855F7),
      speedMultiplier: -0.92,
      phaseOffset: 1.57,
      lobeCount: 3,
      baseScale: 1.00,
    ),
    _SilkPetalSpec(
      primaryColor: Color(0xFFF59E0B),
      secondaryColor: Color(0xFFF43F5E),
      speedMultiplier: 1.38,
      phaseOffset: 3.14,
      lobeCount: 2,
      baseScale: 0.96,
    ),
    _SilkPetalSpec(
      primaryColor: Color(0xFF2DD4BF),
      secondaryColor: Color(0xFF38BDF8),
      speedMultiplier: -1.24,
      phaseOffset: 4.71,
      lobeCount: 4,
      baseScale: 0.92,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _listeningBlend = widget.isListening ? 1.0 : 0.0;
    _setupListeners();
    _ticker = createTicker(_onTick)..start();
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
    if (!oldWidget.isListening && widget.isListening) {
      _transientImpulse = true;
      _smoothTransient = 0.9;
    }
  }

  void _onAcousticUpdate() {
    final state = widget.acousticNotifier?.value;
    if (state != null) {
      _lastAudioEventAt = DateTime.now();
      _targetVolume = state.soundIntensity.clamp(0.0, 1.0);
      _targetTransient = (state.transientIntensity > 0
              ? state.transientIntensity
              : (state.isTransientHit ? 0.8 : 0.0))
          .clamp(0.0, 1.0);
      _currentDb = state.currentDb;
      _isSoundActive = state.isSoundActive;
      if (state.isTransientHit || state.isBassHit) {
        _transientImpulse = true;
      }
    }
  }

  void _onAmplitudeUpdate() {
    final amp = widget.amplitudeNotifier?.value ?? -60.0;
    _lastAudioEventAt = DateTime.now();
    _currentDb = amp;
    final norm = ((amp + 48.0) / 36.0).clamp(0.0, 1.0);
    _targetVolume = math.pow(norm, 1.08).toDouble();
    _isSoundActive = amp > -45.0;
    if (norm > 0.38) _transientImpulse = true;
  }

  void _onTick(Duration elapsed) {
    final rawDt = (_lastElapsed == Duration.zero)
        ? 0.016
        : (elapsed - _lastElapsed).inMicroseconds / 1000000.0;
    _lastElapsed = elapsed;

    final dt = rawDt.clamp(0.001, 0.050);

    final targetBlend = widget.isListening ? 1.0 : 0.0;
    _listeningBlend += (targetBlend - _listeningBlend) * (1.0 - math.exp(-dt * 8.5));

    final msSinceAudio = DateTime.now().difference(_lastAudioEventAt).inMilliseconds;
    double effectiveVol = _targetVolume;
    double effectiveTrans = _targetTransient;

    if (widget.isListening) {
      // Battito cardiaco musicale fluido anche durante il silenzio o l'invio di rete
      final syntheticBeat = math.pow(math.max(0.0, math.sin(_time * 3.8)), 4).toDouble();
      final breathWave = 0.28 + 0.16 * math.sin(_time * 2.1) + syntheticBeat * 0.26;
      if (msSinceAudio > 140 || effectiveVol < 0.20) {
        effectiveVol = math.max(effectiveVol, breathWave.clamp(0.20, 0.68));
      }
      if (msSinceAudio > 200 && syntheticBeat > 0.72) {
        effectiveTrans = math.max(effectiveTrans, 0.55);
      }
    } else {
      effectiveVol = 0.0;
      effectiveTrans = 0.0;
    }

    final volRate = effectiveVol > _smoothVolume ? 16.0 : 6.5;
    _smoothVolume += (effectiveVol - _smoothVolume) * (1.0 - math.exp(-dt * volRate));

    if (_transientImpulse) {
      _smoothTransient = math.max(_smoothTransient, 0.95);
      _transientImpulse = false;
    } else {
      final transRate = effectiveTrans > _smoothTransient ? 20.0 : 7.5;
      _smoothTransient += (effectiveTrans - _smoothTransient) * (1.0 - math.exp(-dt * transRate));
    }

    final speedFactor = 1.0 + (_smoothVolume * 1.85) + (_smoothTransient * 1.25);
    _time += dt;
    _flowPhase += dt * 1.9 * (0.35 + 0.65 * _listeningBlend) * speedFactor;
    _pulseCycle += dt * (0.58 + _smoothVolume * 0.75 + _smoothTransient * 0.50);

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _removeListeners();
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canvasSize = widget.size ?? 276.0;
    final scale = canvasSize / 276.0;

    final energy = (_smoothVolume * 0.7 + _smoothTransient * 0.45).clamp(0.0, 1.0);

    // Rimbalzo elastico stile Shazam del pulsante centrale
    final idleScale = 1.0 + math.sin(_time * 2.0) * 0.028;
    final listeningScale = 1.0 +
        math.sin(_flowPhase * 1.5) * 0.04 +
        (_smoothVolume * 0.13) +
        (_smoothTransient * 0.11);
    final buttonScale = idleScale * (1.0 - _listeningBlend) + listeningScale * _listeningBlend;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: canvasSize,
          height: canvasSize,
          child: RepaintBoundary(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 1. Pittore Custom: Anelli d'urto Shazam + Petali di Seta Liquida 3D + Cometa Radar
                CustomPaint(
                  size: Size(canvasSize, canvasSize),
                  painter: _SiriShazamSilkPainter(
                    time: _time,
                    flowPhase: _flowPhase,
                    pulseCycle: _pulseCycle,
                    volume: _smoothVolume,
                    transient: _smoothTransient,
                    listeningBlend: _listeningBlend,
                    petals: _petals,
                  ),
                ),

                // 2. Bottone Centrale a Capsula Magnetica con Icona Microfono Sempre Visibile
                Transform.scale(
                  scale: buttonScale,
                  child: Container(
                    width: 96 * scale,
                    height: 96 * scale,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color.lerp(
                            const Color(0xFF1E293B),
                            Color.lerp(
                              const Color(0xFF00F5D4),
                              const Color(0xFF6366F1),
                              0.5 + 0.5 * math.sin(_flowPhase * 0.7),
                            )!,
                            _listeningBlend,
                          )!,
                          Color.lerp(
                            const Color(0xFF0F172A),
                            const Color(0xFF0F172A),
                            _listeningBlend,
                          )!,
                        ],
                      ),
                      border: Border.all(
                        color: Color.lerp(
                          Colors.white.withValues(alpha: 0.18),
                           Colors.white.withValues(alpha: 0.65 + energy * 0.35),
                          _listeningBlend,
                        )!,
                        width: (1.6 + energy * 1.2) * scale,
                      ),
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: 1.0 + (_smoothTransient * 0.16 * _listeningBlend),
                        child: Icon(
                          Icons.mic_rounded,
                          size: (42 * scale).clamp(22.0, 50.0),
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (widget.showBadge && widget.isListening) ...[
          const SizedBox(height: 10),
          Builder(
            builder: (context) {
              final isLively = energy > 0.36;
              final isDetected = _isSoundActive || _smoothVolume > 0.22;

              final label = isDetected
                  ? (_smoothTransient > 0.42
                      ? 'RITMO RILEVATO · ${_currentDb.toStringAsFixed(0)} dB'
                      : 'ONDA SONORA ATTIVA · ${_currentDb.toStringAsFixed(0)} dB')
                  : 'ASCOLTO AMBIENTALE ATTIVO';

              final badgeColor = isLively
                  ? AppTheme.accentGold
                  : (isDetected ? AppTheme.accentMint : const Color(0xFF818CF8));

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: badgeColor.withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDetected ? Icons.waves_rounded : Icons.radar_rounded,
                      size: 13,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
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
  }
}

class _SiriShazamSilkPainter extends CustomPainter {
  final double time;
  final double flowPhase;
  final double pulseCycle;
  final double volume;
  final double transient;
  final double listeningBlend;
  final List<_SilkPetalSpec> petals;

  _SiriShazamSilkPainter({
    required this.time,
    required this.flowPhase,
    required this.pulseCycle,
    required this.volume,
    required this.transient,
    required this.listeningBlend,
    required this.petals,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 276.0;
    final maxR = (size.width / 2) - 4.0;

    // 1. Halo Atmosferico Multicolore
    final haloR = (68.0 +
            math.sin(time * 2.0) * 6.0 +
            (volume * 44.0 + transient * 22.0) * listeningBlend) *
        scale;
    final haloShader = RadialGradient(
      colors: [
        const Color(0xFF00F5D4).withValues(alpha: 0.16 + listeningBlend * 0.22),
        const Color(0xFF6366F1).withValues(alpha: 0.10 + listeningBlend * 0.16),
        Colors.transparent,
      ],
      stops: const [0.0, 0.55, 1.0],
    ).createShader(Rect.fromCircle(center: center, radius: haloR.clamp(20.0, maxR)));

    canvas.drawCircle(center, haloR.clamp(20.0, maxR), Paint()..shader = haloShader);

    // 2. Anelli Sottili di Riposo (Idle)
    if (listeningBlend < 0.99) {
      final idleAlpha = (1.0 - listeningBlend).clamp(0.0, 1.0);
      for (int i = 0; i < 3; i++) {
        final waveR = (58.0 + i * 16.0 + math.sin(time * 1.8 - i * 0.9) * 3.5) * scale;
        final idlePaint = Paint()
          ..color = const Color(0xFF38BDF8).withValues(alpha: (0.20 - i * 0.05) * idleAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * scale;
        canvas.drawCircle(center, waveR, idlePaint);
      }
      if (listeningBlend <= 0.01) return;
    }

    // 3. Onde d'Urto Concentriche Perfette (Stile Shazam Pulse)
    const int ringCount = 4;
    for (int i = 0; i < ringCount; i++) {
      final prog = (pulseCycle + (i / ringCount)) % 1.0;
      final eased = 1.0 - math.pow(1.0 - prog, 2.6).toDouble();
      final r = (48.0 * scale) + (maxR - 48.0 * scale) * eased;
      final ringAlpha = ((1.0 - prog) * (0.48 + volume * 0.38) * listeningBlend).clamp(0.0, 0.85);

      final ringColor = Color.lerp(
        const Color(0xFF00F5D4),
        const Color(0xFF6366F1),
        prog,
      )!.withValues(alpha: ringAlpha);

      final ringPaint = Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = (2.8 * (1.0 - prog * 0.65)) * scale;

      canvas.drawCircle(center, r, ringPaint);
    }

    // 4. Petali di Seta Liquida 3D (Siri Morphing Blobs)
    for (final petal in petals) {
      _drawSilkPetal(
        canvas: canvas,
        center: center,
        scale: scale,
        maxR: maxR,
        spec: petal,
      );
    }

    // 5. Scia Radar a Cometa Rotante sul Perimetro Esterno
    final sweepRadius = (108.0 + volume * 10.0) * scale;
    final sweepAngle = flowPhase * 1.35;
    final arcRect = Rect.fromCircle(center: center, radius: sweepRadius.clamp(30.0, maxR));
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        transform: GradientRotation(sweepAngle),
        colors: [
          Colors.transparent,
          const Color(0xFF00F5D4).withValues(alpha: 0.15 * listeningBlend),
          const Color(0xFFF6C974).withValues(alpha: 0.85 * listeningBlend),
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(arcRect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.4 * scale;

    canvas.drawArc(arcRect, sweepAngle + math.pi * 0.8, math.pi * 1.15, false, sweepPaint);
  }

  void _drawSilkPetal({
    required Canvas canvas,
    required Offset center,
    required double scale,
    required double maxR,
    required _SilkPetalSpec spec,
  }) {
    final path = Path();
    const int steps = 72;
    const double stepAngle = (2 * math.pi) / steps;

    final baseR = (54.0 * spec.baseScale + volume * 22.0 + transient * 12.0) * scale;
    final lobeAmp = (8.0 + volume * 18.0 + transient * 14.0) * scale * listeningBlend;
    final secondaryAmp = (4.0 + volume * 9.0) * scale * listeningBlend;
    final rotation = flowPhase * spec.speedMultiplier + spec.phaseOffset;

    for (int i = 0; i <= steps; i++) {
      final idx = i % steps;
      final theta = idx * stepAngle;

      final lobe = math.sin(theta * spec.lobeCount + rotation) * lobeAmp;
      final twist = math.cos(theta * (spec.lobeCount + 1) - rotation * 1.3) * secondaryAmp;
      final r = (baseR + lobe + twist).clamp(32.0 * scale, maxR - 6.0 * scale);

      final x = center.dx + math.cos(theta) * r;
      final y = center.dy + math.sin(theta) * r;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    final rect = Rect.fromCircle(center: center, radius: baseR + lobeAmp);
    final fillGradient = LinearGradient(
      begin: Alignment(math.cos(rotation), math.sin(rotation)),
      end: Alignment(-math.cos(rotation), -math.sin(rotation)),
      colors: [
        spec.primaryColor.withValues(alpha: (0.28 + volume * 0.24) * listeningBlend),
        spec.secondaryColor.withValues(alpha: (0.14 + transient * 0.20) * listeningBlend),
      ],
    );

    final fillPaint = Paint()
      ..shader = fillGradient.createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final borderPaint = Paint()
      ..color = spec.primaryColor.withValues(alpha: (0.68 + volume * 0.28) * listeningBlend)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8 * scale;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SiriShazamSilkPainter oldDelegate) => true;
}
