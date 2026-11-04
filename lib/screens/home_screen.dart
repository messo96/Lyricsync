import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/audio_recorder_service.dart';
import '../services/music_recognition_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pulsing_waveform.dart';
import 'lyrics_teleprompter_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AudioRecorderService _audioRecorder = AudioRecorderService();
  final MusicRecognitionService _recognitionService = MusicRecognitionService();

  bool _isListening = false;
  String _statusText = 'Tocca per ascoltare e sincronizzare il testo';
  bool _isAutoPlayEnabled = false;
  bool _hasCustomApiKey = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await _recognitionService.getSavedAudDToken();
    if (mounted) {
      setState(() {
        _isAutoPlayEnabled = prefs.getBool('lyricsync_autoplay_enabled') ?? false;
        _hasCustomApiKey = token != null && token.isNotEmpty;
      });
    }
  }

  Future<void> _toggleAutoPlay(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lyricsync_autoplay_enabled', value);
    if (mounted) {
      setState(() {
        _isAutoPlayEnabled = value;
      });
    }
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  /// Avvia la cattura audio da microfono e il riconoscimento acustico del brano
  Future<void> _startListening() async {
    if (_isListening) return;

    setState(() {
      _isListening = true;
      _statusText = 'Ascolto del concerto in corso (44.1 kHz)...';
    });

    String? samplePath;
    try {
      samplePath = await _audioRecorder.startListening();

      // Registra per 5 secondi per isolare l'impronta musicale
      await Future.delayed(const Duration(milliseconds: 5000));

      if (mounted) {
        setState(() {
          _statusText = 'Identificazione brano in corso...';
        });
      }

      await _audioRecorder.stopListening();
      final recordingEndedAt = DateTime.now();

      if (mounted) {
        setState(() {
          _statusText = 'Cercando testi sincronizzati...';
        });
      }

      // Riconoscimento REALE via AudD con sincronizzazione precisa del timecode
      final syncedSong = await _recognitionService.recognizeFromAudioSample(
        sampleAudioPath: samplePath,
        recordingEndedAt: recordingEndedAt,
      );

      if (mounted) {
        setState(() {
          _isListening = false;
          _statusText = 'Tocca per ascoltare e sincronizzare il testo';
        });

        // Apri il teleprompter sincronizzato
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LyricsTeleprompterScreen(
              song: syncedSong,
              isAutoPlay: _isAutoPlayEnabled,
            ),
          ),
        ).then((_) => _loadPreferences());
      }
    } on AudDRateLimitException catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _statusText = 'Tocca per ascoltare e sincronizzare il testo';
        });
        _showApiKeyDialog(alertMessage: e.message);
      }
    } on SongNotRecognizedException catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _statusText = 'Tocca per ascoltare e sincronizzare il testo';
        });
        _showNotDetectedDialog(e.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _statusText = 'Tocca per ascoltare e sincronizzare il testo';
        });
        _showNotDetectedDialog(
          'Errore durante il rilevamento. Verifica la connessione internet e riprova.',
        );
      }
    }
  }

  Future<void> _showApiKeyDialog({String? alertMessage}) async {
    final currentToken = await _recognitionService.getSavedAudDToken();
    final controller = TextEditingController(text: currentToken ?? '');

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.vpn_key_rounded, color: AppTheme.accentAmber, size: 22),
            SizedBox(width: 10),
            Text(
              'API Token AudD',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (alertMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    alertMessage,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFFCA5A5), height: 1.4),
                  ),
                ),
              ],
              const Text(
                'AudD offre 300 riconoscimenti gratuiti registrandosi senza carta di credito su dashboard.audd.io.\n\nIncolla qui il tuo token per un riconoscimento illimitato e dedicato:',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  hintText: 'Es. abc123xyz456...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.accentAmber),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.open_in_new_rounded, size: 14, color: AppTheme.accentCyan),
                label: const Text(
                  'Ottieni Token Gratis (dashboard.audd.io)',
                  style: TextStyle(fontSize: 12, color: AppTheme.accentCyan, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF334155)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  launchUrl(
                    Uri.parse('https://dashboard.audd.io/'),
                    mode: LaunchMode.externalApplication,
                  );
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Chiudi', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _recognitionService.saveAudDToken(controller.text.trim());
              await _loadPreferences();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      controller.text.trim().isEmpty
                          ? 'Token rimosso (verrà usato il token standard)'
                          : 'API Token AudD salvato con successo!',
                    ),
                    backgroundColor: AppTheme.accentAmber,
                  ),
                );
              }
            },
            child: const Text('Salva Token'),
          ),
        ],
      ),
    );
  }

  void _showNotDetectedDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.music_off_rounded, color: AppTheme.accentAmber, size: 22),
            SizedBox(width: 10),
            Text(
              'Canzone non rilevata',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'OK',
              style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchScreen(recognitionService: _recognitionService),
                ),
              );
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search_rounded, size: 16),
                SizedBox(width: 6),
                Text('Cerca Manualmente'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.accentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.music_note_rounded, color: AppTheme.accentAmber, size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'LyricSync',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: const Text(
                'LIVE CONCERT',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentCyan,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Icona Chiave API con spunta verde se configurata
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                tooltip: _hasCustomApiKey
                    ? 'API Token AudD Configurato (Attivo)'
                    : 'Configura Chiave API AudD',
                icon: Icon(
                  Icons.vpn_key_rounded,
                  color: _hasCustomApiKey ? const Color(0xFF10B981) : AppTheme.accentAmber,
                  size: 21,
                ),
                onPressed: () => _showApiKeyDialog(),
              ),
              if (_hasCustomApiKey)
                Positioned(
                  right: 6,
                  top: 9,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 9,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            tooltip: 'Cerca canzone o testo',
            icon: const Icon(Icons.search_rounded, color: AppTheme.textPrimary, size: 22),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SearchScreen(recognitionService: _recognitionService),
                ),
              );
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Hero radar per cattura microfono (unico elemento centrale)
              Center(
                child: GestureDetector(
                  onTap: _isListening ? null : _startListening,
                  child: PulsingWaveform(
                    isListening: _isListening,
                    amplitudeNotifier: _audioRecorder.amplitudeNotifier,
                    statusText: _statusText,
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Tocca il pulsante per ascoltare e sincronizzare il testo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),

              const Spacer(flex: 2),

              // Switch AutoPlay Concerto
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isAutoPlayEnabled
                        ? AppTheme.accentCyan.withValues(alpha: 0.5)
                        : const Color(0xFF1E293B),
                    width: 1.2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black38,
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _isAutoPlayEnabled
                            ? AppTheme.accentCyan.withValues(alpha: 0.15)
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.autorenew_rounded,
                        color: _isAutoPlayEnabled ? AppTheme.accentCyan : AppTheme.textMuted,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'AutoPlay Concerto',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              if (_isAutoPlayEnabled) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentCyan.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'ATTIVO',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: AppTheme.accentCyan,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Rileva in automatico la canzone successiva al termine',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _isAutoPlayEnabled,
                      activeColor: AppTheme.accentCyan,
                      onChanged: _toggleAutoPlay,
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
