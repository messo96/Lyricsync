import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../models/synced_song.dart';
import '../services/realtime_lyrics_sync_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/concert_glow_banner.dart';
import '../widgets/delay_adjuster_bar.dart';
import '../widgets/teleprompter_line_tile.dart';

class LyricsTeleprompterScreen extends StatefulWidget {
  final SyncedSong song;
  final int initialOffsetMs;

  const LyricsTeleprompterScreen({
    super.key,
    required this.song,
    this.initialOffsetMs = 0,
  });

  @override
  State<LyricsTeleprompterScreen> createState() => _LyricsTeleprompterScreenState();
}

class _LyricsTeleprompterScreenState extends State<LyricsTeleprompterScreen> {
  late final RealtimeLyricsSyncController _controller;
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener = ItemPositionsListener.create();

  int _lastScrolledIndex = -1;
  bool _showTranslation = true;
  bool _isGlowEnabled = false;
  double _fontScale = 1.0;
  bool _isUserScrolling = false;

  @override
  void initState() {
    super.initState();
    _controller = RealtimeLyricsSyncController(
      song: widget.song,
      initialManualOffsetMs: widget.initialOffsetMs,
    );
    _controller.addListener(_onSyncUpdate);

    // Salto istantaneo al punto esatto del brano appena la vista è renderizzata
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeIdx = _controller.activeLineIndex;
      if (activeIdx > 0 && _scrollController.isAttached) {
        _lastScrolledIndex = activeIdx;
        _scrollController.jumpTo(
          index: activeIdx,
          alignment: 0.35,
        );
      }
    });
  }

  void _onSyncUpdate() {
    final activeIdx = _controller.activeLineIndex;
    if (activeIdx != -1 &&
        activeIdx != _lastScrolledIndex &&
        !_isUserScrolling &&
        _scrollController.isAttached) {
      _lastScrolledIndex = activeIdx;
      _scrollController.scrollTo(
        index: activeIdx,
        alignment: 0.35, // Centra il verso a 35% dall'alto per una lettura naturale cantando
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onSyncUpdate);
    _controller.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  widget.song.artist,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                if (widget.song.isLiveConcertVersion) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: AppTheme.accentAmber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accentAmber,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          // Traduzione ON / OFF
          IconButton(
            tooltip: _showTranslation ? 'Nascondi traduzione' : 'Mostra traduzione',
            icon: Icon(
              Icons.translate_rounded,
              color: _showTranslation ? AppTheme.accentCyan : AppTheme.textMuted,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _showTranslation = !_showTranslation;
              });
            },
          ),

          // Scalatura dimensione caratteri
          IconButton(
            tooltip: 'Dimensione testo',
            icon: Icon(
              _fontScale > 1.0 ? Icons.text_increase_rounded : Icons.format_size_rounded,
              color: _fontScale > 1.0 ? AppTheme.accentAmber : AppTheme.textSecondary,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                if (_fontScale >= 1.3) {
                  _fontScale = 0.9;
                } else if (_fontScale >= 1.0) {
                  _fontScale = 1.3;
                } else {
                  _fontScale = 1.0;
                }
              });
            },
          ),

          // Modalità Concert Glow (luce per concerto)
          IconButton(
            tooltip: 'Concert Glowstick Mode',
            icon: Icon(
              Icons.flare_rounded,
              color: _isGlowEnabled ? AppTheme.accentAmber : AppTheme.textMuted,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _isGlowEnabled = !_isGlowEnabled;
              });
            },
          ),

          // Play / Pause
          IconButton(
            tooltip: _controller.isPlaying ? 'Pausa' : 'Riprendi',
            icon: Icon(
              _controller.isPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
              color: AppTheme.accentAmber,
              size: 26,
            ),
            onPressed: () => _controller.togglePlayPause(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner concert glow
            ConcertGlowBanner(
              isEnabled: _isGlowEnabled,
              onToggle: () => setState(() => _isGlowEnabled = !_isGlowEnabled),
            ),

            // Orologio sincronizzato del concerto
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.mic_external_on_rounded, size: 14, color: AppTheme.accentAmber),
                      const SizedBox(width: 6),
                      Text(
                        'Live Teleprompter · Sincronia attiva',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentAmber.withValues(alpha: 0.9),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${_formatDuration(_controller.currentPosition)} / ${_formatDuration(widget.song.duration)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1, color: Color(0xFF1E293B)),

            // Lista principale testi con ScrollablePositionedList
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification) {
                    _isUserScrolling = true;
                  } else if (notification is ScrollEndNotification) {
                    Future.delayed(const Duration(seconds: 3), () {
                      if (mounted) {
                        setState(() {
                          _isUserScrolling = false;
                        });
                      }
                    });
                  }
                  return false;
                },
                child: ScrollablePositionedList.builder(
                  itemScrollController: _scrollController,
                  itemPositionsListener: _positionsListener,
                  initialScrollIndex: _controller.activeLineIndex >= 0 ? _controller.activeLineIndex : 0,
                  initialAlignment: 0.35,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
                  itemCount: widget.song.lyrics.length,
                  itemBuilder: (context, index) {
                    final line = widget.song.lyrics[index];
                    final isActive = index == _controller.activeLineIndex;
                    final isPast = index < _controller.activeLineIndex;

                    return TeleprompterLineTile(
                      line: line,
                      lineIndex: index,
                      isActive: isActive,
                      isPast: isPast,
                      activeLineProgress: isActive ? _controller.activeLineProgress : 0.0,
                      activeWordIndex: isActive ? _controller.activeWordIndex : -1,
                      showTranslation: _showTranslation,
                      fontScale: _fontScale,
                      onTap: () {
                        _controller.jumpToLine(index);
                      },
                    );
                  },
                ),
              ),
            ),

            // Barra di regolazione ritardo palco / eco stadio
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12, top: 4),
              child: DelayAdjusterBar(
                offsetMs: _controller.manualPhaseOffsetMs,
                onAdjust: (delta) => _controller.adjustOffset(delta),
                onReset: () => _controller.resetOffset(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
