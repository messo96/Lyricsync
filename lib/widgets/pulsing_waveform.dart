import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PulsingWaveform extends StatefulWidget {
  final bool isListening;
  final ValueNotifier<double> amplitudeNotifier;
  final String statusText;

  const PulsingWaveform({
    super.key,
    required this.isListening,
    required this.amplitudeNotifier,
    required this.statusText,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: widget.amplitudeNotifier,
          builder: (context, amplitude, child) {
            // Normalizza l'ampiezza da [-60 dB, 0 dB] a un range 0.0 -> 1.0
            final normalized = ((amplitude + 60) / 60).clamp(0.05, 1.0);

            return AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                final pulse = widget.isListening
                    ? math.sin(_animController.value * 2 * math.pi) * 0.15 + 0.85
                    : 1.0;
                final dynamicScale = widget.isListening
                    ? (1.0 + (normalized * 0.45)) * pulse
                    : 1.0;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Anello esterno 1
                    if (widget.isListening)
                      Container(
                        width: 190 * dynamicScale,
                        height: 190 * dynamicScale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentAmber.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppTheme.accentAmber.withValues(alpha: 0.25),
                            width: 1.5,
                          ),
                        ),
                      ),

                    // Anello esterno 2
                    if (widget.isListening)
                      Container(
                        width: 150 * dynamicScale,
                        height: 150 * dynamicScale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentCyan.withValues(alpha: 0.12),
                          border: Border.all(
                            color: AppTheme.accentCyan.withValues(alpha: 0.4),
                            width: 2,
                          ),
                        ),
                      ),

                    // Pulsante centrale
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.isListening
                              ? [AppTheme.accentAmber, const Color(0xFFF97316)]
                              : [AppTheme.surfaceLight, const Color(0xFF1E293B)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isListening
                                ? AppTheme.accentAmber.withValues(alpha: 0.45)
                                : Colors.black45,
                            blurRadius: widget.isListening ? 28 : 12,
                            spreadRadius: widget.isListening ? 4 : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.isListening
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_rounded,
                        size: 46,
                        color: widget.isListening
                            ? const Color(0xFF0F172A)
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          widget.statusText,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: widget.isListening ? AppTheme.accentAmber : AppTheme.textSecondary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

