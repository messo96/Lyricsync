import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  // Stato visibilità HUD (menu superiore e barra sync inferiore)
  bool _showOverlay = true;

  @override
  void initState() {
    super.initState();

    // ── ORIZZONTALE DI DEFAULT: Apri subito in landscape ──
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

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

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
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
    // Ripristina l'orientamento verticale standard quando si esce
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _toggleOrientation() async {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ]);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: Stack(
          children: [
            // ── LIVELLO 1: Lista Testi a Schermo Intero ───────────────────────
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleOverlay,
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
                    padding: EdgeInsets.only(
                      left: isLandscape ? 32 : 18,
                      right: isLandscape ? 32 : 18,
                      top: isLandscape ? 72 : 140,
                      bottom: isLandscape ? 68 : 96,
                    ),
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
                        onTap: _toggleOverlay, // Cliccare sul testo mostra/nasconde i menu senza alterare il brano
                      );
                    },
                  ),
                ),
              ),
            ),

            // ── LIVELLO 2: Menu Superiore Flottante (Animato con Fade & Slide) ────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                offset: _showOverlay ? Offset.zero : const Offset(0, -1.2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _showOverlay ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showOverlay,
                    child: SafeArea(
                      bottom: false,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.95),
                              Colors.black.withValues(alpha: 0.82),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.7, 1.0],
                          ),
                        ),
                        padding: EdgeInsets.fromLTRB(12, 4, 12, isLandscape ? 8 : 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isLandscape)
                              _buildLandscapeUnifiedHeader()
                            else
                              _buildPortraitHeader(),
                            if (_isGlowEnabled)
                              ConcertGlowBanner(
                                isEnabled: _isGlowEnabled,
                                onToggle: () => setState(() => _isGlowEnabled = !_isGlowEnabled),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── LIVELLO 3: Menu Inferiore Delay Flottante (Animato con Fade & Slide) ──
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                offset: _showOverlay ? Offset.zero : const Offset(0, 1.2),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 220),
                  opacity: _showOverlay ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_showOverlay,
                    child: SafeArea(
                      top: false,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.95),
                              Colors.black.withValues(alpha: 0.8),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.75, 1.0],
                          ),
                        ),
                        padding: EdgeInsets.only(
                          left: 14,
                          right: 14,
                          bottom: isLandscape ? 6 : 12,
                          top: 14,
                        ),
                        child: DelayAdjusterBar(
                          offsetMs: _controller.manualPhaseOffsetMs,
                          onAdjust: (delta) => _controller.adjustOffset(delta),
                          onReset: () => _controller.resetOffset(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Header orizzontale unificato: una singola riga ultra-compatta con tutti i controlli
  Widget _buildLandscapeUnifiedHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black87,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Tasto Indietro
          IconButton(
            tooltip: 'Indietro',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 22),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 10),

          // Artwork brano
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: widget.song.coverArtUrl != null && widget.song.coverArtUrl!.isNotEmpty
                ? Image.network(
                    widget.song.coverArtUrl!,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildArtworkPlaceholder(size: 36),
                  )
                : _buildArtworkPlaceholder(size: 36),
          ),
          const SizedBox(width: 10),

          // Titolo, Cantante & Minutaggio
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
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 1),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.timer_outlined, size: 11, color: AppTheme.accentAmber),
                    const SizedBox(width: 3),
                    Text(
                      '${_formatDuration(_controller.currentPosition)} / ${_formatDuration(widget.song.duration)}',
                      style: const TextStyle(
                        fontSize: 10,
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

          // Traduzione ON/OFF
          IconButton(
            tooltip: _showTranslation ? 'Nascondi traduzione' : 'Mostra traduzione',
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.translate_rounded,
              color: _showTranslation ? AppTheme.accentCyan : AppTheme.textMuted,
              size: 20,
            ),
            onPressed: () => setState(() => _showTranslation = !_showTranslation),
          ),

          // Dimensione testo
          IconButton(
            tooltip: 'Dimensione testo',
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints(),
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

          // Rotazione Verticale / Orizzontale
          IconButton(
            tooltip: 'Torna in verticale',
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.screen_lock_portrait_rounded,
              color: AppTheme.accentAmber,
              size: 20,
            ),
            onPressed: _toggleOrientation,
          ),

          // Concert Glowstick Mode
          IconButton(
            tooltip: 'Concert Glowstick Mode',
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints(),
            icon: Icon(
              Icons.flare_rounded,
              color: _isGlowEnabled ? AppTheme.accentAmber : AppTheme.textMuted,
              size: 20,
            ),
            onPressed: () => setState(() => _isGlowEnabled = !_isGlowEnabled),
          ),

          // Play / Pausa
          IconButton(
            tooltip: _controller.isPlaying ? 'Pausa' : 'Riprendi',
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints(),
            icon: Icon(
              _controller.isPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
              color: AppTheme.accentAmber,
              size: 24,
            ),
            onPressed: () => _controller.togglePlayPause(),
          ),

          const SizedBox(width: 4),

          // Cuore (Salva nei Preferiti)
          IconButton(
            tooltip: _isFavorite ? 'Rimuovi dai preferiti' : 'Salva nei preferiti',
            padding: const EdgeInsets.symmetric(horizontal: 6),
            constraints: const BoxConstraints(),
            icon: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? const Color(0xFFEF4444) : AppTheme.textSecondary,
              size: 21,
            ),
            onPressed: _toggleFavorite,
          ),

          const SizedBox(width: 8),

          // Pulsante Spotify (con logo 3D ufficiale caricato dall'utente)
          SpotifyIconButton(
            onTap: _openSpotify,
            size: 32,
          ),
        ],
      ),
    );
  }

  /// Header verticale standard
  Widget _buildPortraitHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(width: 4),
            const Text(
              'Live Teleprompter',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            IconButton(
              tooltip: _showTranslation ? 'Nascondi traduzione' : 'Mostra traduzione',
              icon: Icon(
                Icons.translate_rounded,
                color: _showTranslation ? AppTheme.accentCyan : AppTheme.textMuted,
                size: 20,
              ),
              onPressed: () => setState(() => _showTranslation = !_showTranslation),
            ),
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
            IconButton(
              tooltip: 'Gira lo schermo in orizzontale',
              icon: const Icon(
                Icons.screen_rotation_rounded,
                color: AppTheme.textSecondary,
                size: 22,
              ),
              onPressed: _toggleOrientation,
            ),
            IconButton(
              tooltip: _controller.isPlaying ? 'Pausa' : 'Riprendi',
              icon: Icon(
                _controller.isPlaying ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                color: AppTheme.accentAmber,
                size: 26,
              ),
              onPressed: () => _controller.togglePlayPause(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildSongHeaderCard(isLandscape: false),
      ],
    );
  }

  Widget _buildSongHeaderCard({required bool isLandscape}) {
    final artworkSize = isLandscape ? 38.0 : 54.0;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: 14,
        vertical: isLandscape ? 3 : 6,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: isLandscape ? 6 : 10,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(isLandscape ? 14 : 18),
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
            borderRadius: BorderRadius.circular(isLandscape ? 8 : 12),
            child: widget.song.coverArtUrl != null && widget.song.coverArtUrl!.isNotEmpty
                ? Image.network(
                    widget.song.coverArtUrl!,
                    width: artworkSize,
                    height: artworkSize,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildArtworkPlaceholder(size: artworkSize),
                  )
                : _buildArtworkPlaceholder(size: artworkSize),
          ),

          const SizedBox(width: 10),

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
                  style: TextStyle(
                    fontSize: isLandscape ? 13 : 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: isLandscape ? 1 : 3),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: isLandscape ? 11 : 12,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.timer_outlined, size: 11, color: AppTheme.accentAmber),
                    const SizedBox(width: 3),
                    Text(
                      '${_formatDuration(_controller.currentPosition)} / ${_formatDuration(widget.song.duration)}',
                      style: TextStyle(
                        fontSize: isLandscape ? 10 : 11,
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
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? const Color(0xFFEF4444) : AppTheme.textSecondary,
              size: isLandscape ? 20 : 24,
            ),
            onPressed: _toggleFavorite,
          ),

          const SizedBox(width: 10),

          // Icona Spotify (Apre il brano direttamente su Spotify con logo 3D)
          SpotifyIconButton(
            onTap: _openSpotify,
            size: isLandscape ? 30 : 36,
          ),
        ],
      ),
    );
  }

  Widget _buildArtworkPlaceholder({double size = 54}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size > 40 ? 12 : 8),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
      ),
      child: Icon(
        Icons.album_rounded,
        color: AppTheme.accentAmber,
        size: size * 0.52,
      ),
    );
  }
}
