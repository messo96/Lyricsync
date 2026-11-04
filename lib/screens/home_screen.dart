import 'package:flutter/material.dart';
import '../data/concert_setlists.dart';
import '../models/synced_song.dart';
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
  List<SyncedSong> _history = [];
  int _selectedLatencyPresetMs = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final list = await _recognitionService.getHistory();
    if (mounted) {
      setState(() {
        _history = list;
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

    try {
      final samplePath = await _audioRecorder.startListening();

      // Registra per 3.5 secondi per isolare l'impronta musicale dal rumore del pubblico
      await Future.delayed(const Duration(milliseconds: 3500));

      if (mounted) {
        setState(() {
          _statusText = 'Identificazione brano e aggancio testi LRC...';
        });
      }

      await _audioRecorder.stopListening();

      // Riconoscimento e calcolo offset rispetto all'esecuzione sul palco
      final syncedSong = await _recognitionService.recognizeFromAudioSample(
        sampleAudioPath: samplePath,
      );

      if (mounted) {
        setState(() {
          _isListening = false;
          _statusText = 'Tocca per ascoltare e sincronizzare il testo';
        });
        _loadHistory();

        // Apri subito il teleprompter con il testo sincronizzato
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LyricsTeleprompterScreen(
              song: syncedSong,
              initialOffsetMs: _selectedLatencyPresetMs,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _statusText = 'Tocca per ascoltare e sincronizzare il testo';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attenzione: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _openSong(SyncedSong song) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LyricsTeleprompterScreen(
          song: song,
          initialOffsetMs: _selectedLatencyPresetMs,
        ),
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Selettore rapido compensazione acustica dello stadio
              _buildStadiumAcousticSelector(),

              const SizedBox(height: 28),

              // Hero radar per cattura microfono
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

              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Rivolgi il microfono verso il palco per rilevare al volo la canzone',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Sezione: Inni da concerto offline / setlist
              _buildSectionHeader(
                title: 'Setlist & Inni da Stadio',
                subtitle: 'Tocca un brano per cantare con il testo sincronizzato',
                action: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SearchScreen(recognitionService: _recognitionService),
                      ),
                    );
                  },
                  child: const Text(
                    'Cerca brano',
                    style: TextStyle(color: AppTheme.accentAmber, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: ConcertCatalog.stadiumAnthems.length,
                itemBuilder: (context, index) {
                  final song = ConcertCatalog.stadiumAnthems[index];
                  return _buildConcertSongCard(song);
                },
              ),

              // Cronologia se presente
              if (_history.isNotEmpty) ...[
                const SizedBox(height: 28),
                _buildSectionHeader(
                  title: 'Rilevati di Recente',
                  subtitle: 'I brani ascoltati durante le tue serate dal vivo',
                  action: TextButton(
                    onPressed: () async {
                      await _recognitionService.clearHistory();
                      _loadHistory();
                    },
                    child: const Text(
                      'Svuota',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _history.take(4).length,
                  itemBuilder: (context, index) {
                    final song = _history[index];
                    return _buildHistorySongTile(song);
                  },
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStadiumAcousticSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.stadium_rounded, size: 16, color: AppTheme.accentAmber),
              const SizedBox(width: 8),
              const Text(
                'Posizione nello Stadio (Compensazione ritardo acustico)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildPresetChip('Sotto il Palco (0ms)', 0),
              const SizedBox(width: 8),
              _buildPresetChip('Prato (+250ms)', 250),
              const SizedBox(width: 8),
              _buildPresetChip('Gradinata (+500ms)', 500),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, int offsetMs) {
    final isSelected = _selectedLatencyPresetMs == offsetMs;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedLatencyPresetMs = offsetMs;
          });
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentAmber.withValues(alpha: 0.15)
                : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.accentAmber : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.accentAmber : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (action != null) action,
      ],
    );
  }

  Widget _buildConcertSongCard(SyncedSong song) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.3)),
          ),
          child: const Icon(Icons.queue_music_rounded, color: AppTheme.accentAmber, size: 22),
        ),
        title: Text(
          song.title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          '${song.artist} · ${song.musicalKey ?? 'Tonalità Live'} · ${song.bpm} BPM',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentAmber.withValues(alpha: 0.15),
            foregroundColor: AppTheme.accentAmber,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: AppTheme.accentAmber, width: 1),
            ),
            elevation: 0,
          ),
          onPressed: () => _openSong(song),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.mic_rounded, size: 14),
              SizedBox(width: 4),
              Text('Canta', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        onTap: () => _openSong(song),
      ),
    );
  }

  Widget _buildHistorySongTile(SyncedSong song) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: const Icon(Icons.history_rounded, color: AppTheme.accentCyan, size: 20),
        title: Text(
          song.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
        ),
        subtitle: Text(
          song.artist,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
        onTap: () => _openSong(song),
      ),
    );
  }
}
