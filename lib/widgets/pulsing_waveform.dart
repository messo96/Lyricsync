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
      duration: const Duration(milliseconds: 1500),
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
                    ? math.sin(_animController.value * 2 * math.pi) * 0.14 + 0.86
                    : 1.0;
                final dynamicScale = widget.isListening
                    ? (1.0 + (normalized * 0.42)) * pulse
                    : 1.0;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Anello esterno 1 (Onda d'espansione calmo mint)
                    if (widget.isListening)
                      Container(
                        width: 195 * dynamicScale,
                        height: 195 * dynamicScale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentMint.withValues(alpha: 0.06),
                          border: Border.all(
                            color: AppTheme.accentMint.withValues(alpha: 0.22),
                            width: 1.5,
                          ),
                        ),
                      ),

                    // Anello esterno 2 (Onda secondaria oro calmo)
                    if (widget.isListening)
                      Container(
                        width: 155 * dynamicScale,
                        height: 155 * dynamicScale,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.accentGold.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppTheme.accentGold.withValues(alpha: 0.35),
                            width: 1.8,
                          ),
                        ),
                      ),

                    // Pulsante centrale iconico
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: widget.isListening
                              ? const [Color(0xFF2DD4BF), Color(0xFF0EA5E9)] // Mint to Ocean Blue calmo
                              : const [AppTheme.surfaceLight, Color(0xFF141926)],
                        ),
                        border: Border.all(
                          color: widget.isListening
                              ? AppTheme.accentMint
                              : AppTheme.border,
                          width: widget.isListening ? 2 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.isListening
                                ? AppTheme.accentMint.withValues(alpha: 0.38)
                                : Colors.black45,
                            blurRadius: widget.isListening ? 30 : 12,
                            spreadRadius: widget.isListening ? 3 : 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.isListening
                            ? Icons.graphic_eq_rounded
                            : Icons.mic_rounded,
                        size: 46,
                        color: widget.isListening
                            ? const Color(0xFF080B11)
                            : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            widget.statusText,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isListening ? AppTheme.accentMint : AppTheme.textSecondary,
              letterSpacing: 0.1,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
