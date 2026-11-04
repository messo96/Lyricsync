import 'package:flutter/material.dart';
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
            ),
          ),
        );
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

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }
}
