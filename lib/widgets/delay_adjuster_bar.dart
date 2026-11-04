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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1E293B),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildAdjustButton(
            label: '-500',
            onTap: () => onAdjust(-500),
          ),
          const SizedBox(width: 4),
          _buildAdjustButton(
            label: '-100',
            onTap: () => onAdjust(-100),
          ),
          const SizedBox(width: 8),

          // Badge centrale con stato offset
          GestureDetector(
            onTap: onReset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: offsetMs != 0
                    ? AppTheme.accentAmber.withValues(alpha: 0.2)
                    : AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: offsetMs != 0
                      ? AppTheme.accentAmber.withValues(alpha: 0.5)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.speed_rounded,
                    size: 14,
                    color: offsetMs != 0 ? AppTheme.accentAmber : AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    offsetMs == 0
                        ? 'Sync 0ms'
                        : '${offsetMs > 0 ? "+" : ""}${offsetMs}ms',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: offsetMs != 0
                          ? AppTheme.accentAmber
                          : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 8),
          _buildAdjustButton(
            label: '+100',
            onTap: () => onAdjust(100),
          ),
          const SizedBox(width: 4),
          _buildAdjustButton(
            label: '+500',
            onTap: () => onAdjust(500),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}

