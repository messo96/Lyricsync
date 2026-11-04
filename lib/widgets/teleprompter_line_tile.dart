import 'package:flutter/material.dart';
import '../models/synced_song.dart';
import '../theme/app_theme.dart';

class TeleprompterLineTile extends StatelessWidget {
  final LyricLine line;
  final int lineIndex;
  final bool isActive;
  final bool isPast;
  final double activeLineProgress;
  final int activeWordIndex;
  final bool showTranslation;
  final double fontScale;
  final VoidCallback onTap;

  const TeleprompterLineTile({
    super.key,
    required this.line,
    required this.lineIndex,
    required this.isActive,
    required this.isPast,
    required this.activeLineProgress,
    required this.activeWordIndex,
    required this.showTranslation,
    required this.fontScale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeFontSize = 26.0 * fontScale;
    final regularFontSize = 19.0 * fontScale;
    final pastFontSize = 17.0 * fontScale;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      splashColor: AppTheme.accentAmber.withValues(alpha: 0.15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        padding: EdgeInsets.symmetric(
          vertical: isActive ? 16 : 8,
          horizontal: isActive ? 16 : 8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isActive
              ? AppTheme.accentAmber.withValues(alpha: 0.12)
              : Colors.transparent,
          border: isActive
              ? Border.all(
                  color: AppTheme.accentAmber.withValues(alpha: 0.4),
                  width: 1.5,
                )
              : Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Testo del verso
            if (isActive && line.words.isNotEmpty)
              _buildKaraokeWordFlow(context, activeFontSize)
            else
              Text(
                line.text,
                style: TextStyle(
                  fontSize: isActive
                      ? activeFontSize
                      : (isPast ? pastFontSize : regularFontSize),
                  fontWeight: isActive
                      ? FontWeight.w800
                      : (isPast ? FontWeight.w400 : FontWeight.w600),
                  color: isActive
                      ? AppTheme.activeLyricGlow
                      : (isPast ? AppTheme.textMuted : AppTheme.textSecondary),
                  height: 1.35,
                  letterSpacing: isActive ? 0.3 : 0.0,
                  shadows: isActive
                      ? [
                          Shadow(
                            color: AppTheme.accentAmber.withValues(alpha: 0.6),
                            blurRadius: 18,
                          ),
                        ]
                      : null,
                ),
              ),

            // Barra di avanzamento per il verso attivo (modalità concerto karaoke)
            if (isActive) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: activeLineProgress,
                  minHeight: 3.5,
                  backgroundColor: AppTheme.surfaceLight,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentAmber),
                ),
              ),
            ],

            // Traduzione italiana opzionale per cantare capendo il significato
            if (showTranslation && line.translation != null && line.translation!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                line.translation!,
                style: TextStyle(
                  fontSize: (isActive ? 15.0 : 13.0) * fontScale,
                  fontStyle: FontStyle.italic,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? AppTheme.accentCyan
                      : AppTheme.textMuted.withValues(alpha: 0.8),
                  height: 1.25,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildKaraokeWordFlow(BuildContext context, double fontSize) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: List.generate(line.words.length, (wIdx) {
        final word = line.words[wIdx];
        final isWordSung = wIdx <= activeWordIndex;
        final isCurrentWord = wIdx == activeWordIndex;

        return Text(
          word.text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: isWordSung ? AppTheme.activeLyricGlow : Colors.white54,
            shadows: isCurrentWord
                ? [
                    Shadow(
                      color: AppTheme.accentAmber.withValues(alpha: 0.9),
                      blurRadius: 16,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

