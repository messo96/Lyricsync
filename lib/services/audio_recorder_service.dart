import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Rappresenta lo stato acustico istantaneo rilevato dal microfono:
/// volume effettivo, intensità percettiva, transienti vocali/musicali e spettro
class AcousticState {
  final double currentDb;           // Range [-60.0, 0.0] dB
  final double normalized;          // Range [0.0, 1.0] ampiezza normalizzata
  final double soundIntensity;      // Range [0.0, 1.0] intensità sonora percettiva reattiva a qualsiasi suono
  final bool isSoundActive;         // Suono rilevato chiaramente sopra il rumore di fondo
  final bool isTransientHit;        // Attacco sonoro/musicale dinamico (voce, cassa, accordo, rullante)
  final double transientIntensity;  // Range [0.0, 1.0] intensità del transiente
  final bool isBassHit;             // Retrocompatibilità per transienti a bassa frequenza
  final double bassIntensity;       // Retrocompatibilità intensità bassi
  final double averageEnergy;       // Range [0.0, 1.0] energia media d'ambiente

  const AcousticState({
    this.currentDb = -60.0,
    this.normalized = 0.0,
    this.soundIntensity = 0.0,
    this.isSoundActive = false,
    this.isTransientHit = false,
    this.transientIntensity = 0.0,
    this.isBassHit = false,
    this.bassIntensity = 0.0,
    this.averageEnergy = 0.0,
  });
}

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  /// Notifier di retrocompatibilità
  final ValueNotifier<double> amplitudeNotifier = ValueNotifier<double>(-45.0);

  /// Notifier avanzato in tempo reale per visualizzazione dei bassi e dell'acustica
  final ValueNotifier<AcousticState> acousticNotifier = ValueNotifier<AcousticState>(const AcousticState());

  bool _isRecording = false;
  double _lastDb = -60.0;
  double _runningAvgDb = -50.0;

  bool get isRecording => _isRecording;

  /// Verifica e richiede il permesso per il microfono
  Future<bool> checkAndRequestPermission() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted) return true;

      final result = await Permission.microphone.request();
      if (result.isGranted) return true;

      // Fallback sul recorder interno
      return await _recorder.hasPermission();
    } catch (e) {
      debugPrint('Errore permessi microfono: $e');
      return await _recorder.hasPermission();
    }
  }

  /// Avvia la registrazione audio con campionamento ottimizzato (Mono 44.1 kHz, 128 kbps)
  Future<String?> startListening({int bitRate = 128000}) async {
    if (_isRecording) return null;

    final hasPerm = await checkAndRequestPermission();
    if (!hasPerm) {
      throw Exception('Permesso microfono non concesso. Concedi il permesso nelle impostazioni di sistema.');
    }

    final tempDir = await getTemporaryDirectory();
    final samplePath = '${tempDir.path}/live_concert_sample_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // Configurazione mono a 44.1 kHz per massimizzare la precisione del fingerprint acustico di AudD
    // audioInterruption: none evita di sottrarre il focus audio alle altre app di musica (Spotify, YouTube Music, ecc.)
    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: bitRate,
        sampleRate: 44100,
        numChannels: 1, // Mono: evita cancellazioni di fase acustica e massimizza i picchi armonici
        audioInterruption: AudioInterruptionMode.none,
        androidConfig: const AndroidRecordConfig(
          manageBluetooth: false, // Non attiva SCO bluetooth, preservando la riproduzione A2DP
          muteAudio: false,       // Non silenzia i flussi audio di sistema/musica
          audioSource: AndroidAudioSource.mic,
          audioManagerMode: AudioManagerMode.modeNormal,
        ),
        iosConfig: const IosRecordConfig(
          categoryOptions: [
            IosAudioCategoryOption.mixWithOthers,
            IosAudioCategoryOption.allowBluetooth,
            IosAudioCategoryOption.defaultToSpeaker,
          ],
        ),
      ),
      path: samplePath,
    );
    _isRecording = true;

    _lastDb = -60.0;
    _runningAvgDb = -50.0;

    // Monitoraggio acustico ad alta frequenza (~28-35 FPS) per intercettare qualsiasi suono, voce e musica
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 30))
        .listen((amp) {
      final db = amp.current.isFinite ? amp.current.clamp(-60.0, 0.0) : -60.0;

      // Normalizzazione dinamica calibrata:
      // Consideriamo -48 dB come soglia di silenzio d'ambiente.
      // Da -48 dB a -12 dB copre l'intera gamma espressiva di voci e musica reale.
      final rawNorm = ((db + 48.0) / 36.0).clamp(0.0, 1.0);
      // Risposta acustica percettiva (legge esponenziale) per rendere l'animazione ultra-reattiva ad ogni sfumatura di suono
      final soundIntensity = math.pow(rawNorm, 1.1).toDouble().clamp(0.0, 1.0);

      // Transiente sonoro dinamico: cattura qualsiasi attacco improvviso (voce acuta, accordo, percussione, cassa, rullante)
      final delta = db - _lastDb;
      final isTransientHit = delta > 1.8 && db > -45.0;
      final transientIntensity = isTransientHit ? (delta / 5.0).clamp(0.25, 1.0) : 0.0;

      // Rilevamento specifico dei colpi di cassa / bassi per retrocompatibilità
      final isBassHit = delta > 2.5 && db > -44.0;
      final bassIntensity = isBassHit ? (delta / 5.5).clamp(0.3, 1.0) : (soundIntensity * 0.5);

      final isSoundActive = db > -45.0;

      _runningAvgDb = 0.85 * _runningAvgDb + 0.15 * db;
      _lastDb = db;

      final state = AcousticState(
        currentDb: db,
        normalized: soundIntensity,
        soundIntensity: soundIntensity,
        isSoundActive: isSoundActive,
        isTransientHit: isTransientHit,
        transientIntensity: transientIntensity,
        isBassHit: isBassHit,
        bassIntensity: bassIntensity,
        averageEnergy: ((_runningAvgDb + 48.0) / 36.0).clamp(0.0, 1.0),
      );

      acousticNotifier.value = state;
      amplitudeNotifier.value = db;
    });

    return samplePath;
  }

  /// Ferma la registrazione e restituisce il percorso del file audio campionato
  Future<String?> stopListening({bool resetNotifiers = true}) async {
    if (!_isRecording) return null;

    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _isRecording = false;
    if (resetNotifiers) {
      acousticNotifier.value = const AcousticState();
      amplitudeNotifier.value = -45.0;
    }

    final recordedPath = await _recorder.stop();
    return recordedPath;
  }

  void dispose() {
    _amplitudeSubscription?.cancel();
    acousticNotifier.dispose();
    amplitudeNotifier.dispose();
    _recorder.dispose();
  }
}
