export interface FlutterCodeFile {
  id: string;
  filename: string;
  path: string;
  language: 'yaml' | 'dart';
  description: string;
  linesOfCode: number;
  content: string;
}

export const FLUTTER_PROJECT_FILES: FlutterCodeFile[] = [
  {
    id: 'pubspec',
    filename: 'pubspec.yaml',
    path: 'pubspec.yaml',
    language: 'yaml',
    description: 'Dipendenze Flutter per cattura audio PCM da microfono, fingerprinting ACRCloud/AudD, LRCLIB e lista testi auto-scroll.',
    linesOfCode: 38,
    content: `name: aurasync_flutter
description: Rilevamento musicale ambientale con testi sincronizzati in tempo reale (LRC).
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.4.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  # Cattura stream audio PCM/AAC dal microfono per fingerprinting
  record: ^5.1.2
  # Richieste HTTP verso ACRCloud / AudD e LRCLIB (database testi LRC)
  dio: ^5.7.0
  # Calcolo firma HMAC-SHA1 per autenticazione API ACRCloud
  crypto: ^3.0.5
  # Gestione permessi microfono su iOS e Android
  permission_handler: ^11.3.1
  # Auto-scroll fluido alla riga attiva del testo
  scrollable_positioned_list: ^0.3.8
  # Animazioni fluide ad alte prestazioni (60/120 fps)
  flutter_animate: ^4.5.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^4.0.0

flutter:
  uses-material-design: true`,
  },
  {
    id: 'models',
    filename: 'synced_song.dart',
    path: 'lib/models/synced_song.dart',
    language: 'dart',
    description: 'Modello dati per la canzone rilevata, l’offset temporale nell’ambiente esterno e il parser nativo per file .LRC.',
    linesOfCode: 92,
    content: `class LyricWord {
  final String text;
  final Duration start;
  final Duration end;

  const LyricWord({
    required this.text,
    required this.start,
    required this.end,
  });
}

class LyricLine {
  final Duration timestamp;
  final Duration endTimestamp;
  final String text;
  final List<LyricWord> words;

  const LyricLine({
    required this.timestamp,
    required this.endTimestamp,
    required this.text,
    required this.words,
  });
}

class SyncedSong {
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  /// Posizione esatta del brano nell'ambiente esterno al momento del match
  final Duration detectedPlayOffset;
  /// Timestamp di sistema in cui il server ha restituito il match
  final DateTime matchedAt;
  final List<LyricLine> lyrics;

  const SyncedSong({
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.detectedPlayOffset,
    required this.matchedAt,
    required this.lyrics,
  });

  /// Parser nativo per formato standard LRC: [mm:ss.xx] Testo della riga
  static List<LyricLine> parseLrc(String rawLrc, Duration totalDuration) {
    final regex = RegExp(r'^\\[(\\d{2}):(\\d{2})\\.(\\d{2,3})\\]\\s*(.*)\$');
    final temp = <({Duration start, String text})>[];

    for (final rawLine in rawLrc.split('\\n')) {
      final match = regex.firstMatch(rawLine.trim());
      if (match == null) continue;

      final min = int.parse(match.group(1)!);
      final sec = int.parse(match.group(2)!);
      final frac = match.group(3)!;
      final ms = frac.length == 2 ? int.parse(frac) * 10 : int.parse(frac);
      final text = match.group(4)!.trim();
      if (text.isEmpty) continue;

      temp.add((
        start: Duration(minutes: min, seconds: sec, milliseconds: ms),
        text: text,
      ));
    }

    temp.sort((a, b) => a.start.compareTo(b.start));

    return List.generate(temp.length, (i) {
      final current = temp[i];
      final nextStart = i + 1 < temp.length ? temp[i + 1].start : totalDuration;
      final lineDuration = nextStart - current.start;
      final tokens = current.text.split(RegExp(r'\\s+'));
      final wordStep = Duration(
        milliseconds: (lineDuration.inMilliseconds / tokens.length).round(),
      );

      final words = List.generate(tokens.length, (wIdx) {
        final wStart = current.start + (wordStep * wIdx);
        return LyricWord(
          text: tokens[wIdx],
          start: wStart,
          end: wStart + wordStep,
        );
      });

      return LyricLine(
        timestamp: current.start,
        endTimestamp: nextStart,
        text: current.text,
        words: words,
      );
    });
  }
}`,
  },
  {
    id: 'recognition_service',
    filename: 'ambient_recognition_service.dart',
    path: 'lib/services/ambient_recognition_service.dart',
    language: 'dart',
    description: 'Servizio che registra 4 secondi di audio dall’ambiente esterno, ottiene titolo/artista + play_offset_ms da ACRCloud/AudD e scarica il testo sincronizzato da LRCLIB.',
    linesOfCode: 108,
    content: `import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../models/synced_song.dart';

class AmbientRecognitionService {
  final AudioRecorder _recorder = AudioRecorder();
  final Dio _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));

  final String acrHost;
  final String acrAccessKey;
  final String acrSecretKey;

  AmbientRecognitionService({
    required this.acrHost,
    required this.acrAccessKey,
    required this.acrSecretKey,
  });

  /// 1. Registra un campione ambientale di 4 secondi e calcola la compensazione di latenza
  Future<SyncedSong?> recognizeFromEnvironment() async {
    if (!await _recorder.hasPermission()) {
      throw Exception('Permesso microfono negato');
    }

    final tempDir = await getTemporaryDirectory();
    final samplePath = '\${tempDir.path}/ambient_sample.m4a';
    final recordStartedAt = DateTime.now();

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: samplePath,
    );

    // 4 secondi di ascolto ambientale per un'impronta acustica robusta al rumore
    await Future.delayed(const Duration(seconds: 4));
    final path = await _recorder.stop();
    if (path == null) return null;

    final requestStartedAt = DateTime.now();
    final bytes = await File(path).readAsBytes();

    // 2. Invia il campione ad ACRCloud / AudD per ottenere titolo, artista e play_offset_ms
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final stringToSign = 'POST\\n/v1/identify\\n\$acrAccessKey\\naudio\\n1\\n\$timestamp';
    final hmacSha1 = Hmac(sha1, utf8.encode(acrSecretKey));
    final signature = base64.encode(hmacSha1.convert(utf8.encode(stringToSign)).bytes);

    final formData = FormData.fromMap({
      'sample': MultipartFile.fromBytes(bytes, filename: 'sample.m4a'),
      'access_key': acrAccessKey,
      'data_type': 'audio',
      'signature_version': '1',
      'signature': signature,
      'sample_bytes': bytes.length.toString(),
      'timestamp': timestamp,
    });

    final response = await _dio.post('https://\$acrHost/v1/identify', data: formData);
    final networkLatency = DateTime.now().difference(requestStartedAt);

    final musicList = response.data['metadata']?['music'] as List?;
    if (musicList == null || musicList.isEmpty) return null;

    final match = musicList.first;
    final String title = match['title'] ?? 'Sconosciuto';
    final String artist = (match['artists'] as List?)?.first?['name'] ?? 'Artista';
    final String album = match['album']?['name'] ?? '';
    final int durationMs = match['duration_ms'] ?? 180000;
    // play_offset_ms indica a che punto del brano è finito il campione registrato
    final int playOffsetMs = match['play_offset_ms'] ?? 0;

    // 3. Scarica i testi sincronizzati (.LRC) da LRCLIB API gratuita
    final lrcResponse = await _dio.get(
      'https://lrclib.net/api/get',
      queryParameters: {
        'track_name': title,
        'artist_name': artist,
        'album_name': album,
      },
    );

    final String syncedLyricsRaw = lrcResponse.data['syncedLyrics'] ?? '';
    final totalDuration = Duration(milliseconds: durationMs);
    final parsedLines = SyncedSong.parseLrc(syncedLyricsRaw, totalDuration);

    // Sommiamo play_offset_ms + latenza di rete per allineamento istantaneo col mondo esterno
    return SyncedSong(
      title: title,
      artist: artist,
      album: album,
      duration: totalDuration,
      detectedPlayOffset: Duration(milliseconds: playOffsetMs) + networkLatency,
      matchedAt: DateTime.now(),
      lyrics: parsedLines,
    );
  }
}`,
  },
  {
    id: 'sync_controller',
    filename: 'realtime_lyrics_controller.dart',
    path: 'lib/services/realtime_lyrics_controller.dart',
    language: 'dart',
    description: 'Motore di sincronizzazione ad alta precisione basato su Stopwatch + Ticker a 60fps per mantenere i testi agganciati alla musica nella stanza.',
    linesOfCode: 76,
    content: `import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/synced_song.dart';

class RealtimeLyricsController extends ChangeNotifier {
  final SyncedSong song;
  late final Ticker _ticker;
  final Stopwatch _stopwatch = Stopwatch();

  /// Offset manuale (in millisecondi) per micro-calibrazione dell'utente (+/- 100ms)
  int manualPhaseOffsetMs = 0;

  Duration _currentPosition = Duration.zero;
  int _activeLineIndex = -1;
  int _activeWordIndex = -1;

  Duration get currentPosition => _currentPosition;
  int get activeLineIndex => _activeLineIndex;
  int get activeWordIndex => _activeWordIndex;

  RealtimeLyricsController({
    required this.song,
    required TickerProvider vsync,
  }) {
    _stopwatch.start();
    _ticker = vsync.createTicker(_onTick)..start();
  }

  void _onTick(Duration _) {
    // Posizione reale = Offset rilevato nella stanza + tempo trascorso dal match + calibrazione utente
    final elapsedMs = _stopwatch.elapsedMilliseconds;
    final totalMs = song.detectedPlayOffset.inMilliseconds + elapsedMs + manualPhaseOffsetMs;
    _currentPosition = Duration(milliseconds: totalMs.clamp(0, song.duration.inMilliseconds));

    int newLineIdx = -1;
    int newWordIdx = -1;

    for (int i = 0; i < song.lyrics.length; i++) {
      if (_currentPosition >= song.lyrics[i].timestamp) {
        newLineIdx = i;
      } else {
        break;
      }
    }

    if (newLineIdx != -1) {
      final words = song.lyrics[newLineIdx].words;
      for (int w = 0; w < words.length; w++) {
        if (_currentPosition >= words[w].start) {
          newWordIdx = w;
        } else {
          break;
        }
      }
    }

    if (newLineIdx != _activeLineIndex || newWordIdx != _activeWordIndex) {
      _activeLineIndex = newLineIdx;
      _activeWordIndex = newWordIdx;
    }
    notifyListeners();
  }

  /// Permette di anticipare o ritardare il testo (es. +100ms o -100ms)
  void adjustPhaseOffset(int deltaMs) {
    manualPhaseOffsetMs += deltaMs;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _stopwatch.stop();
    super.dispose();
  }
}`,
  },
  {
    id: 'lyrics_screen',
    filename: 'lyrics_sync_screen.dart',
    path: 'lib/screens/lyrics_sync_screen.dart',
    language: 'dart',
    description: 'Schermata principale Flutter con ScrollablePositionedList che centra automaticamente il verso cantato in quel preciso istante e controlli di fase.',
    linesOfCode: 112,
    content: `import 'package:flutter/material.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import '../models/synced_song.dart';
import '../services/realtime_lyrics_controller.dart';

class LyricsSyncScreen extends StatefulWidget {
  final SyncedSong song;
  const LyricsSyncScreen({super.key, required this.song});

  @override
  State<LyricsSyncScreen> createState() => _LyricsSyncScreenState();
}

class _LyricsSyncScreenState extends State<LyricsSyncScreen>
    with SingleTickerProviderStateMixin {
  late final RealtimeLyricsController _controller;
  final ItemScrollController _scrollController = ItemScrollController();
  int _lastScrolledLine = -1;

  @override
  void initState() {
    super.initState();
    _controller = RealtimeLyricsController(song: widget.song, vsync: this);
    _controller.addListener(_handleSyncUpdate);
  }

  void _handleSyncUpdate() {
    final lineIdx = _controller.activeLineIndex;
    if (lineIdx != -1 && lineIdx != _lastScrolledLine && _scrollController.isAttached) {
      _lastScrolledLine = lineIdx;
      _scrollController.scrollTo(
        index: lineIdx,
        alignment: 0.38, // Mantiene il verso attivo nella zona centrale di lettura
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_handleSyncUpdate);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.song.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(widget.song.artist, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Anticipa testo (-100ms)',
            onPressed: () => _controller.adjustPhaseOffset(-100),
            icon: const Icon(Icons.fast_rewind_rounded),
          ),
          IconButton(
            tooltip: 'Ritarda testo (+100ms)',
            onPressed: () => _controller.adjustPhaseOffset(100),
            icon: const Icon(Icons.fast_forward_rounded),
          ),
        ],
      ),
      body: ScrollablePositionedList.builder(
        itemScrollController: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        itemCount: widget.song.lyrics.length,
        itemBuilder: (context, index) {
          final line = widget.song.lyrics[index];
          final isActive = index == _controller.activeLineIndex;
          final isPast = index < _controller.activeLineIndex;

          return AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 220),
            style: TextStyle(
              fontSize: isActive ? 26 : 19,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? const Color(0xFFFBBF24)
                  : (isPast ? Colors.white38 : Colors.white60),
              height: 1.45,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(line.text),
            ),
          );
        },
      ),
    );
  }
}`,
  },
];
