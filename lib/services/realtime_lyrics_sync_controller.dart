import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/synced_song.dart';

class RealtimeLyricsSyncController extends ChangeNotifier {
  final SyncedSong song;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _tickerTimer;

  bool _isPlaying = true;
  int _manualPhaseOffsetMs = 0;
  Duration _currentPosition = Duration.zero;
  int _activeLineIndex = -1;
  int _activeWordIndex = -1;
  double _activeLineProgress = 0.0;

  // Getters
  bool get isPlaying => _isPlaying;
  int get manualPhaseOffsetMs => _manualPhaseOffsetMs;
  Duration get currentPosition => _currentPosition;
  int get activeLineIndex => _activeLineIndex;
  int get activeWordIndex => _activeWordIndex;
  double get activeLineProgress => _activeLineProgress;

  RealtimeLyricsSyncController({
    required this.song,
    int initialManualOffsetMs = 0,
  }) {
    _manualPhaseOffsetMs = initialManualOffsetMs;
    _stopwatch.start();
    _startTicker();
    _computeCurrentState();
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_isPlaying) {
        _computeCurrentState();
      }
    });
  }

  void _computeCurrentState() {
    final elapsedMs = _stopwatch.elapsedMilliseconds;
    final totalMs = song.detectedPlayOffset.inMilliseconds + elapsedMs + _manualPhaseOffsetMs;

    // Loop al termine per permettere sessioni di canto continue
    final clampedMs = song.duration.inMilliseconds > 0
        ? totalMs % song.duration.inMilliseconds
        : totalMs;

    _currentPosition = Duration(milliseconds: clampedMs);

    int newLineIdx = -1;
    int newWordIdx = -1;
    double progress = 0.0;

    for (int i = 0; i < song.lyrics.length; i++) {
      if (_currentPosition >= song.lyrics[i].timestamp) {
        newLineIdx = i;
      } else {
        break;
      }
    }

    if (newLineIdx != -1) {
      final currentLine = song.lyrics[newLineIdx];
      final lineDuration = currentLine.endTimestamp - currentLine.timestamp;
      final lineElapsed = _currentPosition - currentLine.timestamp;

      if (lineDuration.inMilliseconds > 0) {
        progress = (lineElapsed.inMilliseconds / lineDuration.inMilliseconds).clamp(0.0, 1.0);
      }

      for (int w = 0; w < currentLine.words.length; w++) {
        if (_currentPosition >= currentLine.words[w].start) {
          newWordIdx = w;
        } else {
          break;
        }
      }
    }

    _activeLineIndex = newLineIdx;
    _activeWordIndex = newWordIdx;
    _activeLineProgress = progress;

    notifyListeners();
  }

  /// Regola la fase temporale (es. +100ms / -100ms / +500ms per compensare la distanza dagli altoparlanti)
  void adjustOffset(int deltaMs) {
    _manualPhaseOffsetMs += deltaMs;
    _computeCurrentState();
  }

  /// Reimposta l'offset di latenza a zero
  void resetOffset() {
    _manualPhaseOffsetMs = 0;
    _computeCurrentState();
  }

  /// Salta direttamente a una posizione o verso specifico
  void seekTo(Duration target) {
    final diffMs = target.inMilliseconds - (song.detectedPlayOffset.inMilliseconds + _manualPhaseOffsetMs);
    _stopwatch.reset();
    _manualPhaseOffsetMs = diffMs;
    _stopwatch.start();
    _computeCurrentState();
  }

  /// Salta alla riga per indice
  void jumpToLine(int lineIndex) {
    if (lineIndex >= 0 && lineIndex < song.lyrics.length) {
      seekTo(song.lyrics[lineIndex].timestamp);
    }
  }

  /// Play / Pausa del teleprompter
  void togglePlayPause() {
    _isPlaying = !_isPlaying;
    if (_isPlaying) {
      _stopwatch.start();
    } else {
      _stopwatch.stop();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _stopwatch.stop();
    super.dispose();
  }
}
