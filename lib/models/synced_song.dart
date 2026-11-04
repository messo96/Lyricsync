class LyricWord {
  final String text;
  final Duration start;
  final Duration end;

  const LyricWord({
    required this.text,
    required this.start,
    required this.end,
  });

  Map<String, dynamic> toJson() => {
        'text': text,
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
      };

  factory LyricWord.fromJson(Map<String, dynamic> json) => LyricWord(
        text: json['text'] as String? ?? '',
        start: Duration(milliseconds: json['startMs'] as int? ?? 0),
        end: Duration(milliseconds: json['endMs'] as int? ?? 0),
      );
}

class LyricLine {
  final Duration timestamp;
  final Duration endTimestamp;
  final String text;
  final String? translation;
  final List<LyricWord> words;

  const LyricLine({
    required this.timestamp,
    required this.endTimestamp,
    required this.text,
    this.translation,
    required this.words,
  });

  Map<String, dynamic> toJson() => {
        'timestampMs': timestamp.inMilliseconds,
        'endTimestampMs': endTimestamp.inMilliseconds,
        'text': text,
        'translation': translation,
        'words': words.map((w) => w.toJson()).toList(),
      };

  factory LyricLine.fromJson(Map<String, dynamic> json) => LyricLine(
        timestamp: Duration(milliseconds: json['timestampMs'] as int? ?? 0),
        endTimestamp: Duration(milliseconds: json['endTimestampMs'] as int? ?? 0),
        text: json['text'] as String? ?? '',
        translation: json['translation'] as String?,
        words: (json['words'] as List<dynamic>?)
                ?.map((w) => LyricWord.fromJson(w as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class SyncedSong {
  final String id;
  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final Duration detectedPlayOffset;
  final DateTime matchedAt;
  final int bpm;
  final String? musicalKey;
  final bool isLiveConcertVersion;
  final String? coverArtUrl;
  final String rawLrc;
  final List<LyricLine> lyrics;

  const SyncedSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.detectedPlayOffset,
    required this.matchedAt,
    this.bpm = 120,
    this.musicalKey,
    this.isLiveConcertVersion = true,
    this.coverArtUrl,
    required this.rawLrc,
    required this.lyrics,
  });

  /// Parser robusto per LRC standard `[mm:ss.xx]`.
  /// Se il testo non contiene tag timestamp, attiva automaticamente il sincronizzatore intelligente da testo piano.
  static List<LyricLine> parseLrc(String rawLrc, Duration totalDuration) {
    if (rawLrc.trim().isEmpty) return [];

    // Se non ci sono timestamp LRC tipo [00:15.20], passa al parser per testo piano
    final hasLrcTimestamps = RegExp(r'\[\d{1,2}:\d{2}').hasMatch(rawLrc);
    if (!hasLrcTimestamps) {
      return parsePlainLyrics(rawLrc, totalDuration);
    }

    final regex = RegExp(r'^\[(\d{1,2}):(\d{2})(?:\.(\d{2,3}))?\]\s*(.*)$');
    final parsedRaw = <({Duration start, String lineContent})>[];

    final lines = rawLrc.split('\n');
    for (final rawLine in lines) {
      final trimmed = rawLine.trim();
      if (trimmed.isEmpty) continue;

      final match = regex.firstMatch(trimmed);
      if (match == null) continue;

      final min = int.tryParse(match.group(1) ?? '0') ?? 0;
      final sec = int.tryParse(match.group(2) ?? '0') ?? 0;
      final fracStr = match.group(3) ?? '00';
      final ms = fracStr.length == 2
          ? (int.tryParse(fracStr) ?? 0) * 10
          : (int.tryParse(fracStr) ?? 0);

      final lineContent = match.group(4)?.trim() ?? '';
      if (lineContent.isEmpty) continue;

      parsedRaw.add((
        start: Duration(minutes: min, seconds: sec, milliseconds: ms),
        lineContent: lineContent,
      ));
    }

    parsedRaw.sort((a, b) => a.start.compareTo(b.start));
    if (parsedRaw.isEmpty) {
      return parsePlainLyrics(rawLrc, totalDuration);
    }

    final result = <LyricLine>[];

    for (int i = 0; i < parsedRaw.length; i++) {
      final current = parsedRaw[i];
      final nextStart = i + 1 < parsedRaw.length
          ? parsedRaw[i + 1].start
          : (totalDuration > current.start
              ? totalDuration
              : current.start + const Duration(seconds: 4));

      // Gestione traduzione opzionale: "Verso originale | Traduzione italiana"
      String text = current.lineContent;
      String? translation;
      if (text.contains(' | ')) {
        final parts = text.split(' | ');
        text = parts[0].trim();
        translation = parts[1].trim();
      }

      final lineDuration = nextStart - current.start;
      final tokens = text.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();

      final words = <LyricWord>[];
      if (tokens.isNotEmpty && lineDuration.inMilliseconds > 0) {
        final wordStepMs = (lineDuration.inMilliseconds / tokens.length).round();
        for (int wIdx = 0; wIdx < tokens.length; wIdx++) {
          final wStart = current.start + Duration(milliseconds: wordStepMs * wIdx);
          final wEnd = wIdx == tokens.length - 1
              ? nextStart
              : current.start + Duration(milliseconds: wordStepMs * (wIdx + 1));
          words.add(LyricWord(
            text: tokens[wIdx],
            start: wStart,
            end: wEnd,
          ));
        }
      }

      result.add(LyricLine(
        timestamp: current.start,
        endTimestamp: nextStart,
        text: text,
        translation: translation,
        words: words,
      ));
    }

    return result;
  }

  /// Converte testo piano in versi con sincronizzazione stimata su tutta la durata
  static List<LyricLine> parsePlainLyrics(String plainText, Duration totalDuration) {
    if (plainText.trim().isEmpty) return [];

    final rawLines = plainText
        .split('\n')
        .map((l) => l.trim())
        // Rimuove intestazioni tipo [Chorus], [Verse 1], [Intro]
        .where((l) => l.isNotEmpty && !(l.startsWith('[') && l.endsWith(']')))
        .toList();

    if (rawLines.isEmpty) return [];

    final effectiveDuration = totalDuration.inSeconds > 30
        ? totalDuration
        : Duration(seconds: rawLines.length * 5);

    // Intro e outro buffer
    final introMs = (effectiveDuration.inMilliseconds * 0.06).clamp(5000.0, 16000.0).round();
    final outroMs = (effectiveDuration.inMilliseconds * 0.05).clamp(4000.0, 14000.0).round();
    final availableMs = (effectiveDuration.inMilliseconds - introMs - outroMs).clamp(20000, 600000);

    // Calcolo pesi proporzionali in base alla lunghezza dei versi
    int totalWeight = 0;
    final weights = <int>[];
    for (final line in rawLines) {
      final w = (line.length + line.split(' ').length * 4).clamp(10, 140);
      weights.add(w);
      totalWeight += w;
    }

    final result = <LyricLine>[];
    int currentMs = introMs;

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i];
      final lineDurationMs = totalWeight > 0
          ? ((weights[i] / totalWeight) * availableMs).round().clamp(1900, 8500)
          : (availableMs ~/ rawLines.length);

      final start = Duration(milliseconds: currentMs);
      final end = Duration(milliseconds: currentMs + lineDurationMs);
      currentMs += lineDurationMs;

      final tokens = line.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
      final words = <LyricWord>[];
      if (tokens.isNotEmpty && lineDurationMs > 0) {
        final wordStepMs = (lineDurationMs / tokens.length).round();
        for (int wIdx = 0; wIdx < tokens.length; wIdx++) {
          final wStart = start + Duration(milliseconds: wordStepMs * wIdx);
          final wEnd = wIdx == tokens.length - 1
              ? end
              : start + Duration(milliseconds: wordStepMs * (wIdx + 1));
          words.add(LyricWord(
            text: tokens[wIdx],
            start: wStart,
            end: wEnd,
          ));
        }
      }

      result.add(LyricLine(
        timestamp: start,
        endTimestamp: end,
        text: line,
        words: words,
      ));
    }

    return result;
  }

  /// Converte una lista di LyricLine in stringa LRC standard
  static String toLrcString(List<LyricLine> lines) {
    final buffer = StringBuffer();
    for (final line in lines) {
      final totalSec = line.timestamp.inSeconds;
      final min = (totalSec ~/ 60).toString().padLeft(2, '0');
      final sec = (totalSec % 60).toString().padLeft(2, '0');
      final frac = ((line.timestamp.inMilliseconds % 1000) ~/ 10).toString().padLeft(2, '0');
      buffer.writeln('[$min:$sec.$frac] ${line.text}');
    }
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': duration.inMilliseconds,
        'detectedPlayOffsetMs': detectedPlayOffset.inMilliseconds,
        'matchedAt': matchedAt.toIso8601String(),
        'bpm': bpm,
        'musicalKey': musicalKey,
        'isLiveConcertVersion': isLiveConcertVersion,
        'coverArtUrl': coverArtUrl,
        'rawLrc': rawLrc,
        'lyrics': lyrics.map((l) => l.toJson()).toList(),
      };

  factory SyncedSong.fromJson(Map<String, dynamic> json) {
    final rawLrc = json['rawLrc'] as String? ?? '';
    final durationMs = json['durationMs'] as int? ?? 180000;
    final duration = Duration(milliseconds: durationMs);

    List<LyricLine> lyricsList = [];
    if (json['lyrics'] != null) {
      lyricsList = (json['lyrics'] as List<dynamic>)
          .map((l) => LyricLine.fromJson(l as Map<String, dynamic>))
          .toList();
    }
    if (lyricsList.isEmpty && rawLrc.isNotEmpty) {
      lyricsList = SyncedSong.parseLrc(rawLrc, duration);
    }

    return SyncedSong(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Sconosciuto',
      artist: json['artist'] as String? ?? 'Artista sconosciuto',
      album: json['album'] as String? ?? 'Live Concert',
      duration: duration,
      detectedPlayOffset: Duration(
          milliseconds: json['detectedPlayOffsetMs'] as int? ?? 0),
      matchedAt: json['matchedAt'] != null
          ? DateTime.tryParse(json['matchedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      bpm: json['bpm'] as int? ?? 120,
      musicalKey: json['musicalKey'] as String?,
      isLiveConcertVersion: json['isLiveConcertVersion'] as bool? ?? true,
      coverArtUrl: json['coverArtUrl'] as String?,
      rawLrc: rawLrc,
      lyrics: lyricsList,
    );
  }
}
