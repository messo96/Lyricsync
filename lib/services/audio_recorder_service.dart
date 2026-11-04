import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSubscription;
  final ValueNotifier<double> amplitudeNotifier = ValueNotifier<double>(-45.0);
  bool _isRecording = false;

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

  /// Avvia la registrazione audio ambientale e attiva lo stream dei dB per il visualizzatore
  Future<String?> startListening({Duration duration = const Duration(seconds: 4)}) async {
    if (_isRecording) return null;

    final hasPerm = await checkAndRequestPermission();
    if (!hasPerm) {
      throw Exception('Permesso microfono non concesso. Concedi il permesso nelle impostazioni di sistema.');
    }

    final tempDir = await getTemporaryDirectory();
    final samplePath = '${tempDir.path}/live_concert_sample_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: samplePath,
    );
    _isRecording = true;

    // Monitoraggio ampiezza in tempo reale per le onde grafiche sullo schermo
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 60))
        .listen((amp) {
      amplitudeNotifier.value = amp.current.clamp(-60.0, 0.0);
    });

    return samplePath;
  }

  /// Ferma la registrazione e restituisce il percorso del file audio campionato
  Future<String?> stopListening() async {
    if (!_isRecording) return null;

    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    _isRecording = false;
    amplitudeNotifier.value = -45.0;

    final recordedPath = await _recorder.stop();
    return recordedPath;
  }

  void dispose() {
    _amplitudeSubscription?.cancel();
    amplitudeNotifier.dispose();
    _recorder.dispose();
  }
}

