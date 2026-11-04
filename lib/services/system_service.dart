import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servizio di sistema per gestione Picture-in-Picture (PiP) nativo e WakeLock dello schermo
class SystemService {
  static const MethodChannel _channel = MethodChannel('com.messo.lyricsync/system');

  static final ValueNotifier<bool> isPipModeNotifier = ValueNotifier<bool>(false);
  static bool get isPipMode => isPipModeNotifier.value;

  static bool _initialized = false;

  /// Inizializza i listener per gli eventi dal sistema Android (es. ingresso/uscita PiP)
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPipModeChanged') {
        final inPip = call.arguments is Map ? (call.arguments['inPip'] as bool? ?? false) : false;
        debugPrint('[SystemService] onPipModeChanged: $inPip');
        isPipModeNotifier.value = inPip;
      }
    });
  }

  /// Mantiene lo schermo sempre acceso (o ripristina il timeout normale)
  static Future<bool> keepScreenOn(bool enable) async {
    try {
      final res = await _channel.invokeMethod<bool>('keepScreenOn', {'enable': enable});
      debugPrint('[SystemService] keepScreenOn($enable) -> $res');
      return res ?? false;
    } catch (e) {
      debugPrint('[SystemService] Error keepScreenOn: $e');
      return false;
    }
  }

  /// Forza l'ingresso immediato in modalità Picture-in-Picture (finestra fluttuante)
  static Future<bool> enterPip() async {
    try {
      final res = await _channel.invokeMethod<bool>('enterPip');
      return res ?? false;
    } catch (e) {
      debugPrint('[SystemService] Error enterPip: $e');
      return false;
    }
  }

  /// Configura l'auto-PiP: quando l'utente lascia l'app o torna alla home/Spotify,
  /// Android riduce automaticamente l'app a finestra fluttuante.
  static Future<bool> setAutoPip(bool enable) async {
    try {
      final res = await _channel.invokeMethod<bool>('setAutoPip', {'enable': enable});
      return res ?? false;
    } catch (e) {
      debugPrint('[SystemService] Error setAutoPip: $e');
      return false;
    }
  }

  /// Verifica se il dispositivo supporta Picture-in-Picture
  static Future<bool> isPipSupported() async {
    try {
      final res = await _channel.invokeMethod<bool>('isPipSupported');
      return res ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Verifica se l'app è attualmente in PiP
  static Future<bool> isPipActive() async {
    try {
      final res = await _channel.invokeMethod<bool>('isPipActive');
      final active = res ?? false;
      isPipModeNotifier.value = active;
      return active;
    } catch (e) {
      return false;
    }
  }
}
