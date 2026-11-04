import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/listening_environment.dart';
import '../models/synced_song.dart';
import '../services/audio_recorder_service.dart';
import '../services/music_recognition_service.dart';
import '../services/realtime_lyrics_sync_controller.dart';
import '../services/system_service.dart';
import '../theme/app_theme.dart';
import '../widgets/concert_glow_banner.dart';
import '../widgets/delay_adjuster_bar.dart';
import '../widgets/pulsing_waveform.dart';
import '../widgets/spotify_icon_button.dart';
import '../widgets/teleprompter_line_tile.dart';

class LyricsTeleprompterScreen extends StatefulWidget {
  final SyncedSong song;
  final int initialOffsetMs;
  final bool isAutoPlay;
  final ListeningEnvironment environment;

  const LyricsTeleprompterScreen({
    super.key,
    required this.song,
    this.initialOffsetMs = 0,
    this.isAutoPlay = false,
    this.environment = ListeningEnvironment.concerto,
  });

  @override
  State<LyricsTeleprompterScreen> createState() => _LyricsTeleprompterScreenState();
}

class _LyricsTeleprompterScreenState extends State<LyricsTeleprompterScreen> {
  late SyncedSong _currentSong;
  late RealtimeLyricsSyncController _controller;
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener = ItemPositionsListener.create();
  final MusicRecognitionService _recognitionService = MusicRecognitionService();
  final AudioRecorderService _audioRecorder = AudioRecorderService();

  int _lastScrolledIndex = -1;
  bool _showTranslation = true;
  bool _isGlowEnabled = false;
  double _fontScale = 1.0;
  bool _isUserScrolling = false;
  bool _isFavorite = false;

  // Stato visibilità HUD (menu superiore e barra sync inferiore)
  bool _showOverlay = true;

  // AutoPlay: ascolto automatico del brano successivo
  bool _isAutoDetectingNext = false;
  String _autoDetectStatus = '';

  @override
  void initState() {
    super.initState();
    _currentSong = widget.song;

    // Mantieni lo schermo sempre attivo durante la visualizzazione dei testi
    SystemService.keepScreenOn(true);
    // Configura Picture-in-Picture automatico al cambio applicazione
    SystemService.setAutoPip(true);
    SystemService.isPipModeNotifier.addListener(_onPipModeChanged);

    // ── ORIZZONTALE DI DEFAULT: Apri subito in landscape ──
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _initController(widget.initialOffsetMs);
    _checkFavorite();
  }

  void _onPipModeChanged() {
    if (mounted) setState(() {});
  }

  void _initController([int initialOffsetMs = 0]) {
    _controller = RealtimeLyricsSyncController(
      song: _currentSong,
      initialManualOffsetMs: initialOffsetMs,
      onSongFinished: _onSongEnded,
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

  void _onSongEnded() {
    if (!mounted) return;
    if (widget.isAutoPlay && !_isAutoDetectingNext) {
      _listenAndSwitchToNextSong();
    }
  }

  /// Cattura dal microfono e rileva il brano successivo senza tornare indietro (max 30s)
  Future<void> _listenAndSwitchToNextSong() async {
    if (_isAutoDetectingNext) return;

    setState(() {
      _isAutoDetectingNext = true;
      _autoDetectStatus = 'Ascolto brano successivo (${widget.environment.label})...';
    });

    final deadline = DateTime.now().add(const Duration(seconds: 30));
    SyncedSong? nextSong;

    while (mounted && _isAutoDetectingNext && DateTime.now().isBefore(deadline)) {
      final remainingSec = deadline.difference(DateTime.now()).inSeconds;
      if (remainingSec < 3) break;

      final chunkMs = widget.environment.sampleDurationMs.clamp(3500, remainingSec * 1000);

      setState(() {
        _autoDetectStatus = 'Ascolto continuo (${remainingSec}s)... In attesa di musica';
      });

      String? samplePath;
      DateTime? recordingEndedAt;

      try {
        samplePath = await _audioRecorder.startListening();
        await Future.delayed(Duration(milliseconds: chunkMs));

        if (!mounted || !_isAutoDetectingNext) {
          await _audioRecorder.stopListening();
          break;
        }

        recordingEndedAt = DateTime.now();
        await _audioRecorder.stopListening();

        if (samplePath == null) continue;

        setState(() {
          _autoDetectStatus = 'Identificazione del nuovo brano...';
        });

        try {
          final song = await _recognitionService.recognizeFromAudioSample(
            sampleAudioPath: samplePath,
            recordingEndedAt: recordingEndedAt,
            environment: widget.environment,
          );
          nextSong = song;
          break; // TROVATO!
        } on SongNotRecognizedException {
          debugPrint('AutoDetect: nessun match ancora, continuo ascolto...');
        }
      } catch (e) {
        debugPrint('AutoDetect error: $e');
        await _audioRecorder.stopListening();
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    await _audioRecorder.stopListening();

    if (!mounted) return;

    if (nextSong != null) {
      _controller.removeListener(_onSyncUpdate);
      _controller.dispose();

      setState(() {
        _currentSong = nextSong!;
        _isAutoDetectingNext = false;
        _lastScrolledIndex = -1;
      });

      _initController(0);
      _checkFavorite();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '🎵 Nuovo brano rilevato: "${nextSong.title}" di ${nextSong.artist}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppTheme.accentCyan,
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (_isAutoDetectingNext) {
      setState(() {
        _isAutoDetectingNext = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun brano successivo riconosciuto dopo 30s.'),
          backgroundColor: AppTheme.surfaceLight,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _cancelAutoDetect() {
    _audioRecorder.stopListening();
    if (mounted) {
      setState(() {
        _isAutoDetectingNext = false;
      });
    }
  }

  void _toggleOverlay() {
    setState(() {
      _showOverlay = !_showOverlay;
    });
  }

  Future<void> _checkFavorite() async {
    final fav = await _recognitionService.isFavorite(_currentSong.title, _currentSong.artist);
    if (mounted) {
      setState(() {
        _isFavorite = fav;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final nowFav = await _recognitionService.toggleFavorite(_currentSong);
    if (mounted) {
      setState(() {
        _isFavorite = nowFav;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            nowFav ? '❤️ "${_currentSong.title}" salvata nei preferiti!' : 'Canzone rimossa dai preferiti',
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
    final target = _currentSong.spotifyUrl != null && _currentSong.spotifyUrl!.isNotEmpty
        ? _currentSong.spotifyUrl!
        : 'https://open.spotify.com/search/${Uri.encodeComponent('${_currentSong.artist} ${_currentSong.title}')}';
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
    SystemService.isPipModeNotifier.removeListener(_onPipModeChanged);
    SystemService.keepScreenOn(false);
    SystemService.setAutoPip(false);
    _audioRecorder.dispose();
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
    if (SystemService.isPipMode) {
      return _buildPipView();
    }

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
                    itemCount: _currentSong.lyrics.length,
                    itemBuilder: (context, index) {
                      final line = _currentSong.lyrics[index];
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

            // ── LIVELLO 4: Overlay AutoPlay Rilevamento Brano Successivo (Anti-Overflow) ──────────
            if (_isAutoDetectingNext)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.88),
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      child: Container(
                        constraints: BoxConstraints(
                          maxWidth: isLandscape ? 560 : 360,
                        ),
                        padding: EdgeInsets.symmetric(
                          horizontal: isLandscape ? 20 : 18,
                          vertical: isLandscape ? 14 : 18,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: AppTheme.accentCyan.withValues(alpha: 0.5),
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(color: Colors.black87, blurRadius: 20, offset: Offset(0, 6)),
                          ],
                        ),
                        child: isLandscape
                            ? _buildAutoPlayLandscapeContent()
                            : _buildAutoPlayPortraitContent(),
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

  /// Layout orizzontale compatto per il popup AutoPlay: evita qualsiasi overflow in landscape
  Widget _buildAutoPlayLandscapeContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PulsingWaveform(
          isListening: true,
          size: 110,
          acousticNotifier: _audioRecorder.acousticNotifier,
          amplitudeNotifier: _audioRecorder.amplitudeNotifier,
          statusText: '',
          showStatusText: false,
          showBadge: false,
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.autorenew_rounded, color: AppTheme.accentCyan, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AutoPlay Concerto',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                _autoDetectStatus,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.accentCyan,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.close_rounded, size: 15, color: AppTheme.textSecondary),
                label: const Text(
                  'Annulla AutoPlay',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  side: const BorderSide(color: Color(0xFF334155)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: _cancelAutoDetect,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Layout verticale per il popup AutoPlay
  Widget _buildAutoPlayPortraitContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.autorenew_rounded, color: AppTheme.accentCyan, size: 18),
            ),
            const SizedBox(width: 8),
            const Text(
              'AutoPlay Concerto',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PulsingWaveform(
          isListening: true,
          size: 150,
          acousticNotifier: _audioRecorder.acousticNotifier,
          amplitudeNotifier: _audioRecorder.amplitudeNotifier,
          statusText: _autoDetectStatus,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
          label: const Text('Annulla AutoPlay', style: TextStyle(color: AppTheme.textSecondary)),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF334155)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _cancelAutoDetect,
        ),
      ],
    );
  }

  /// Vista ultra-compatta e ad alto contrasto per Picture-in-Picture (finestra fluttuante sopra altre app)
  Widget _buildPipView() {
    final activeIndex = _controller.activeLineIndex;
    final currentLine = (activeIndex >= 0 && activeIndex < _currentSong.lyrics.length)
        ? _currentSong.lyrics[activeIndex]
        : null;
    final nextLine = (activeIndex + 1 >= 0 && activeIndex + 1 < _currentSong.lyrics.length)
        ? _currentSong.lyrics[activeIndex + 1]
        : null;

    final progress = _currentSong.duration.inMilliseconds > 0
        ? (_controller.currentPosition.inMilliseconds / _currentSong.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF070A0F),
            border: Border.all(
              color: AppTheme.accentCyan.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              // Mini barra di avanzamento del brano
              LinearProgressIndicator(
                value: progress,
                minHeight: 2.5,
                backgroundColor: const Color(0xFF1E293B),
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
              ),

              // Contenuto compatto PiP
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Header PiP con artista, titolo e minutaggio
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.music_note_rounded, size: 11, color: AppTheme.accentCyan),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '${_currentSong.artist} • ${_currentSong.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _formatDuration(_controller.currentPosition),
                            style: const TextStyle(
                              fontSize: 9,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentAmber,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Verso attivo in grande evidenza con Nordic Mint
                      Text(
                        currentLine?.text.isNotEmpty == true ? currentLine!.text : '♪ ${_currentSong.title} ♪',
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.accentCyan,
                          height: 1.25,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 4),
                          ],
                        ),
                      ),

                      // Traduzione se presente e attiva
                      if (currentLine?.translation != null && _showTranslation) ...[
                        const SizedBox(height: 2),
                        Text(
                          currentLine!.translation!,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentAmber,
                          ),
                        ),
                      ],

                      // Verso successivo in anteprima morbida
                      if (nextLine != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          nextLine.text,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                      const Spacer(),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
            child: _currentSong.coverArtUrl != null && _currentSong.coverArtUrl!.isNotEmpty
                ? Image.network(
                    _currentSong.coverArtUrl!,
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
                  _currentSong.title,
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
                        _currentSong.artist,
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
                      '${_formatDuration(_controller.currentPosition)} / ${_formatDuration(_currentSong.duration)}',
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
          const SizedBox(width: 6),

          // Traduzione ON/OFF
          IconButton(
            tooltip: _showTranslation ? 'Nascondi traduzione' : 'Mostra traduzione',
            padding: const EdgeInsets.symmetric(horizontal: 5),
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
            padding: const EdgeInsets.symmetric(horizontal: 5),
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

          // Finestra Fluttuante (PiP sopra altre app)
          IconButton(
            tooltip: 'Finestra fluttuante (PiP)',
            padding: const EdgeInsets.symmetric(horizontal: 5),
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.picture_in_picture_alt_rounded,
              color: AppTheme.accentCyan,
              size: 20,
            ),
            onPressed: () => SystemService.enterPip(),
          ),

          // Rotazione Verticale / Orizzontale
          IconButton(
            tooltip: 'Torna in verticale',
            padding: const EdgeInsets.symmetric(horizontal: 5),
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.screen_lock_portrait_rounded,
              color: AppTheme.accentAmber,
              size: 20,
            ),
            onPressed: _toggleOrientation,
          ),

          // Tasto Rileva Brano Successivo (Auto-Riconoscimento o Salto)
          IconButton(
            tooltip: 'Rileva brano successivo dal microfono',
            padding: const EdgeInsets.symmetric(horizontal: 5),
            constraints: const BoxConstraints(),
            icon: const Icon(
              Icons.skip_next_rounded,
              color: AppTheme.accentCyan,
              size: 26,
            ),
            onPressed: _listenAndSwitchToNextSong,
          ),

          // Play / Pausa
          IconButton(
            tooltip: _controller.isPlaying ? 'Pausa' : 'Riprendi',
            padding: const EdgeInsets.symmetric(horizontal: 5),
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
            padding: const EdgeInsets.symmetric(horizontal: 5),
            constraints: const BoxConstraints(),
            icon: Icon(
              _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: _isFavorite ? const Color(0xFFEF4444) : AppTheme.textSecondary,
              size: 21,
            ),
            onPressed: _toggleFavorite,
          ),

          const SizedBox(width: 6),

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
              tooltip: 'Rileva brano successivo',
              icon: const Icon(
                Icons.skip_next_rounded,
                color: AppTheme.accentCyan,
                size: 24,
              ),
              onPressed: _listenAndSwitchToNextSong,
            ),
            IconButton(
              tooltip: 'Finestra fluttuante (PiP)',
              icon: const Icon(
                Icons.picture_in_picture_alt_rounded,
                color: AppTheme.accentCyan,
                size: 22,
              ),
              onPressed: () => SystemService.enterPip(),
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
            child: _currentSong.coverArtUrl != null && _currentSong.coverArtUrl!.isNotEmpty
                ? Image.network(
                    _currentSong.coverArtUrl!,
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
                  _currentSong.title,
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
                        _currentSong.artist,
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
                      '${_formatDuration(_controller.currentPosition)} / ${_formatDuration(_currentSong.duration)}',
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
