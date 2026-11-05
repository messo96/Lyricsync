import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Rappresenta lo stato acustico istantaneo rilevato dal microfono (decibel, bassi, ampiezza)
class AcousticState {
  final double currentDb;      // Range [-60.0, 0.0] dB
  final double normalized;     // Range [0.0, 1.0] ampiezza normalizzata
  final bool isBassHit;        // Rilevamento colpo di cassa / transiente percussivo
  final double bassIntensity;  // Range [0.0, 1.0] intensità dell'onda di basso
  final double averageEnergy;  // Range [0.0, 1.0] energia media d'ambiente

  const AcousticState({
    this.currentDb = -60.0,
    this.normalized = 0.0,
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

    // Monitoraggio acustico ad alta frequenza (~28 FPS) per intercettare i colpi di cassa (kick drum/bassi)
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 35))
        .listen((amp) {
      final db = amp.current.clamp(-60.0, 0.0);
      final normalized = ((db + 60.0) / 60.0).clamp(0.0, 1.0);

      // Rilevamento transiente di basso / colpo di cassa (brusco incremento di dB)
      final delta = db - _lastDb;
      final isBassHit = delta > 2.4 && db > -46.0;
      final bassIntensity = isBassHit ? (delta / 6.0).clamp(0.3, 1.0) : (normalized * 0.4);

      _runningAvgDb = 0.85 * _runningAvgDb + 0.15 * db;
      _lastDb = db;

      final state = AcousticState(
        currentDb: db,
        normalized: normalized,
        isBassHit: isBassHit,
        bassIntensity: bassIntensity,
        averageEnergy: ((_runningAvgDb + 60.0) / 60.0).clamp(0.0, 1.0),
      );

      acousticNotifier.value = state;
      amplitudeNotifier.value = db;
    });

    return samplePath;
  }

  /// Ferma la registrazione e restituisce il percorso del file audio campionato
  Future<String?> stopListening() async {
    if (!_isRecording) return null;

    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _isRecording = false;
    acousticNotifier.value = const AcousticState();
    amplitudeNotifier.value = -45.0;

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
