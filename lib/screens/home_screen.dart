import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/listening_environment.dart';
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
  bool _isAutoPlayEnabled = false;
  bool _hasCustomApiKey = false;
  ListeningEnvironment _selectedEnvironment = ListeningEnvironment.concerto;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final token = await _recognitionService.getSavedAudDToken();
    final envId = prefs.getString('lyricsync_environment');
    if (mounted) {
      setState(() {
        _isAutoPlayEnabled = prefs.getBool('lyricsync_autoplay_enabled') ?? false;
        _hasCustomApiKey = token != null && token.isNotEmpty;
        _selectedEnvironment = ListeningEnvironment.fromId(envId);
      });
    }
  }

  Future<void> _setEnvironment(ListeningEnvironment env) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lyricsync_environment', env.id);
    if (mounted) {
      setState(() {
        _selectedEnvironment = env;
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
    _countdownTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _safeDeleteFile(String path) {
    unawaited(
      Future(() async {
        try {
          final f = File(path);
          if (await f.exists()) {
            await f.delete();
          }
        } catch (_) {}
      }),
    );
  }

  /// Interrompe manualmente l'ascolto continuo su richiesta dell'utente
  void _cancelListening() {
    _countdownTimer?.cancel();
    _audioRecorder.stopListening(resetNotifiers: true);
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusText = 'Tocca per ascoltare e sincronizzare il testo';
      });
    }
  }

  /// Avvia la cattura audio continua da microfono finché non trova un brano (timeout max 30s)
  /// Usa una pipeline sovrapposta: mentre invia il campione N al riconoscimento di rete,
  /// il microfono continua immediatamente ad ascoltare il campione N+1 senza mai fermare l'animazione.
  Future<void> _startListening() async {
    if (_isListening) return;

    final hasPerm = await _audioRecorder.checkAndRequestPermission();
    if (!hasPerm) {
      if (mounted) {
        _showNotDetectedDialog(
          'Permesso microfono non concesso. Concedi il permesso nelle impostazioni per usare LyricSync.',
        );
      }
      return;
    }

    setState(() {
      _isListening = true;
      _statusText = 'Ascolto continuo (30s)... In attesa della musica';
    });

    final deadline = DateTime.now().add(const Duration(seconds: 30));
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || !_isListening) {
        timer.cancel();
        return;
      }
      final remaining = deadline.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
      } else {
        setState(() {
          _statusText = 'Ascolto (${remaining}s)... Rilevamento in corso';
        });
      }
    });

    int attempt = 0;
    SyncedSong? recognizedSong;
    String? lastErrorMsg;
    bool rateLimitHit = false;
    String? rateLimitMessage;
    Future<void>? pendingRecognitionTask;

    try {
      // Avvia subito il primo ciclo di ascolto microfono
      String? activeSamplePath = await _audioRecorder.startListening();

      while (mounted && _isListening && recognizedSong == null && !rateLimitHit && DateTime.now().isBefore(deadline)) {
        attempt++;
        final remainingMs = deadline.difference(DateTime.now()).inMilliseconds;
        if (remainingMs < 2500) {
          break;
        }

        final chunkDurationMs = _selectedEnvironment.sampleDurationMs.clamp(3200, remainingMs);

        if (activeSamplePath == null) {
          activeSamplePath = await _audioRecorder.startListening();
        }

        // Attendi la finestra di campionamento lasciando scorrere il microfono in tempo reale
        await Future.delayed(Duration(milliseconds: chunkDurationMs));

        if (!mounted || !_isListening || recognizedSong != null || rateLimitHit) {
          break;
        }

        final recordingEndedAt = DateTime.now();
        final completedPath = await _audioRecorder.stopListening(resetNotifiers: false);
        activeSamplePath = null;

        // Riavvia IMMEDIATAMENTE il microfono per il blocco successivo così non c'è mai pausa!
        if (mounted && _isListening && deadline.difference(DateTime.now()).inMilliseconds >= 2500) {
          try {
            activeSamplePath = await _audioRecorder.startListening();
          } catch (_) {}
        }

        if (completedPath == null) continue;

        // Attendi eventuale analisi precedente prima di lanciare la nuova in background
        if (pendingRecognitionTask != null) {
          await pendingRecognitionTask;
          if (recognizedSong != null || rateLimitHit || !mounted || !_isListening) {
            _safeDeleteFile(completedPath);
            break;
          }
        }

        final currentAttempt = attempt;
        pendingRecognitionTask = () async {
          try {
            final song = await _recognitionService.recognizeFromAudioSample(
              sampleAudioPath: completedPath,
              recordingEndedAt: recordingEndedAt,
              environment: _selectedEnvironment,
            );
            recognizedSong = song;
            _safeDeleteFile(completedPath);
          } on SongNotRecognizedException catch (e) {
            lastErrorMsg = e.message;
            _safeDeleteFile(completedPath);
            debugPrint('Tentativo $currentAttempt non riuscito: ${e.message}. Continuo ascolto...');
          } on AudDRateLimitException catch (e) {
            rateLimitHit = true;
            rateLimitMessage = e.message;
            _safeDeleteFile(completedPath);
          } catch (e) {
            debugPrint('Errore durante analisi tentativo $currentAttempt: $e');
            _safeDeleteFile(completedPath);
          }
        }();
      }

      // Se l'ultimo task di riconoscimento è ancora in volo, attendilo mentre il microfono resta animato
      if (pendingRecognitionTask != null && recognizedSong == null && !rateLimitHit && _isListening) {
        await pendingRecognitionTask;
      }

      if (activeSamplePath != null) {
        final leftover = await _audioRecorder.stopListening(resetNotifiers: true);
        if (leftover != null) _safeDeleteFile(leftover);
      }
    } catch (e) {
      debugPrint('Errore ciclo ascolto: $e');
    }

    _countdownTimer?.cancel();
    await _audioRecorder.stopListening(resetNotifiers: true);

    if (rateLimitHit && mounted) {
      setState(() {
        _isListening = false;
        _statusText = 'Tocca per ascoltare e sincronizzare il testo';
      });
      _showApiKeyDialog(alertMessage: rateLimitMessage);
      return;
    }

    if (!mounted) return;

    if (recognizedSong != null) {
      setState(() {
        _isListening = false;
        _statusText = 'Tocca per ascoltare e sincronizzare il testo';
      });

      // Apri il teleprompter sincronizzato
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LyricsTeleprompterScreen(
            song: recognizedSong!,
            isAutoPlay: _isAutoPlayEnabled,
            environment: _selectedEnvironment,
          ),
        ),
      ).then((_) => _loadPreferences());
    } else if (_isListening) {
      // Scaduti i 30 secondi senza aver individuato il brano
      setState(() {
        _isListening = false;
        _statusText = 'Tocca per ascoltare e sincronizzare il testo';
      });

      _showNotDetectedDialog(
        lastErrorMsg ??
            'Nessun brano riconosciuto dopo 30 secondi di ascolto continuo.\nAvvicina il telefono alla sorgente audio e riprova.',
      );
    }
  }

  void _showEnvironmentModal() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(Icons.tune_rounded, color: AppTheme.accentMint, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Ambiente di Ascolto',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Calibra tempo di registrazione, filtri acustici e latenza del microfono:',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                ...ListeningEnvironment.values.map((env) {
                  final isSelected = env == _selectedEnvironment;
                  return InkWell(
                    onTap: () {
                      _setEnvironment(env);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? env.badgeColor.withValues(alpha: 0.12)
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? env.badgeColor.withValues(alpha: 0.6)
                              : AppTheme.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: env.badgeColor.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(env.icon, color: env.badgeColor, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      env.label,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: env.badgeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        '${(env.sampleDurationMs / 1000).toStringAsFixed(1)}s',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: env.badgeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  env.description,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textMuted,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Icon(Icons.check_circle_rounded, color: env.badgeColor, size: 20),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
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
            InkWell(
              onTap: _showEnvironmentModal,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _selectedEnvironment.badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedEnvironment.badgeColor.withValues(alpha: 0.45),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _selectedEnvironment.icon,
                      size: 12,
                      color: _selectedEnvironment.badgeColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _selectedEnvironment.shortLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: _selectedEnvironment.badgeColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 13,
                      color: _selectedEnvironment.badgeColor,
                    ),
                  ],
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
                  onTap: _isListening ? _cancelListening : _startListening,
                  child: PulsingWaveform(
                    isListening: _isListening,
                    acousticNotifier: _audioRecorder.acousticNotifier,
                    amplitudeNotifier: _audioRecorder.amplitudeNotifier,
                    statusText: _statusText,
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  _isListening
                      ? 'Ascolto continuo attivo (max 30s) · Tocca per fermare'
                      : 'Tocca il pulsante per ascoltare e sincronizzare il testo',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: _isListening ? AppTheme.accentCyan : AppTheme.textMuted,
                    fontWeight: _isListening ? FontWeight.w600 : FontWeight.w400,
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
