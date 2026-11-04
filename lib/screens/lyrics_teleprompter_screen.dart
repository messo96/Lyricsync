import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/synced_song.dart';
import '../services/music_recognition_service.dart';
import '../services/realtime_lyrics_sync_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/concert_glow_banner.dart';
import '../widgets/delay_adjuster_bar.dart';
import '../widgets/spotify_icon_button.dart';
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
  final MusicRecognitionService _recognitionService = MusicRecognitionService();

  int _lastScrolledIndex = -1;
  bool _showTranslation = true;
  bool _isGlowEnabled = false;
  double _fontScale = 1.0;
  bool _isUserScrolling = false;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _controller = RealtimeLyricsSyncController(
      song: widget.song,
      initialManualOffsetMs: widget.initialOffsetMs,
    );
    _controller.addListener(_onSyncUpdate);
    _checkFavorite();

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

  Future<void> _checkFavorite() async {
    final fav = await _recognitionService.isFavorite(widget.song.title, widget.song.artist);
    if (mounted) {
      setState(() {
        _isFavorite = fav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final nowFav = await _recognitionService.toggleFavorite(widget.song);
    if (mounted) {
      setState(() {
        _isFavorite = nowFav;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nowFav ? '❤️ "${widget.song.title}" salvata nei preferiti!' : 'Canzone rimossa dai preferiti',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: nowFav ? const Color(0xFFEF4444) : AppTheme.surfaceLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _openSpotify() async {
    final target = widget.song.spotifyUrl != null && widget.song.spotifyUrl!.isNotEmpty
        ? widget.song.spotifyUrl!
        : 'https://open.spotify.com/search/${Uri.encodeComponent('${widget.song.artist} ${widget.song.title}')}';
    final uri = Uri.parse(target);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Errore apertura Spotify: $e');
    }
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
        title: const Text('Live Teleprompter'),
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
            // ── TOP HEADER CARD: Copertina, Titolo, Cantanti, Preferito (Cuore) e Spotify ──
            _buildSongHeaderCard(),

            // Banner concert glow
            ConcertGlowBanner(
              isEnabled: _isGlowEnabled,
              onToggle: () => setState(() => _isGlowEnabled = !_isGlowEnabled),
            ),

            const Divider(height: 1, color: Color(0xFF1E293B)),

            // ── AREA CENTRALE: Lista testi con auto-scroll a 60fps ─────────────────
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
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
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

            // ── SOTTO IL TESTO: Pannello di Sincronizzazione Manuale ─────────────
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12, top: 4),
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

  Widget _buildSongHeaderCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Copertina del brano (o placeholder musicale)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: widget.song.coverArtUrl != null && widget.song.coverArtUrl!.isNotEmpty
                ? Image.network(
                    widget.song.coverArtUrl!,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildArtworkPlaceholder(),
                  )
                : _buildArtworkPlaceholder(),
          ),

          const SizedBox(width: 12),

          // Titolo, Cantanti & Minutaggio
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: AppTheme.accentAmber),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatDuration(_controller.currentPosition)} / ${_formatDuration(widget.song.duration)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Pulsante Cuore (Salva nei Preferiti)
          IconButton(
            tooltip: _isFavorite ? 'Rimuovi dai preferiti' : 'Salva nei preferiti',
            icon: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? const Color(0xFFEF4444) : AppTheme.textSecondary,
              size: 24,
            ),
            onPressed: _toggleFavorite,
          ),

          // Icona Spotify (Apre il brano direttamente su Spotify)
          SpotifyIconButton(
            onTap: _openSpotify,
            size: 36,
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkPlaceholder() {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
      ),
      child: const Icon(
        Icons.album_rounded,
        color: AppTheme.accentAmber,
        size: 28,
      ),
    );
  }
}
