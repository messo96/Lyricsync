import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class DelayAdjusterBar extends StatelessWidget {
  final int offsetMs;
  final Function(int deltaMs) onAdjust;
  final VoidCallback onReset;

  const DelayAdjusterBar({
    super.key,
    required this.offsetMs,
    required this.onAdjust,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final offsetSec = (offsetMs / 1000.0).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: offsetMs != 0
              ? AppTheme.accentAmber.withValues(alpha: 0.5)
              : const Color(0xFF1E293B),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Riga Intestazione con stato offset e Reset
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_rounded, size: 14, color: AppTheme.accentAmber),
                  const SizedBox(width: 6),
                  const Text(
                    'Sincronizzazione Manuale',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: offsetMs != 0 ? onReset : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: offsetMs != 0
                        ? AppTheme.accentAmber.withValues(alpha: 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        offsetMs == 0 ? 'Sync: 0.0s' : 'Offset: ${offsetMs > 0 ? "+" : ""}${offsetSec}s',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: offsetMs != 0 ? AppTheme.accentAmber : AppTheme.textMuted,
                        ),
                      ),
                      if (offsetMs != 0) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.restart_alt_rounded, size: 13, color: AppTheme.accentAmber),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Pulsanti di regolazione rapida
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Ritarda testo (quando il testo è troppo avanti rispetto alla voce)
              _buildAdjustChip(
                label: '-1.0s',
                sublabel: 'Ritarda',
                isNegative: true,
                onTap: () => onAdjust(-1000),
              ),
              _buildAdjustChip(
                label: '-0.5s',
                sublabel: null,
                isNegative: true,
                onTap: () => onAdjust(-500),
              ),
              _buildAdjustChip(
                label: '-0.2s',
                sublabel: null,
                isNegative: true,
                onTap: () => onAdjust(-200),
              ),

              Container(width: 1, height: 24, color: const Color(0xFF1E293B)),

              // Anticipa testo (quando il testo è troppo indietro rispetto alla voce)
              _buildAdjustChip(
                label: '+0.2s',
                sublabel: null,
                isNegative: false,
                onTap: () => onAdjust(200),
              ),
              _buildAdjustChip(
                label: '+0.5s',
                sublabel: null,
                isNegative: false,
                onTap: () => onAdjust(500),
              ),
              _buildAdjustChip(
                label: '+1.0s',
                sublabel: 'Anticipa',
                isNegative: false,
                onTap: () => onAdjust(1000),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Guida visiva
          const Text(
            '◀ Ritarda se il testo è avanti · Anticipa se è indietro ▶',
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustChip({
    required String label,
    required String? sublabel,
    required bool isNegative,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isNegative
                ? const Color(0xFF334155)
                : const Color(0xFF334155),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isNegative ? const Color(0xFF38BDF8) : AppTheme.accentAmber,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
