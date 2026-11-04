import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/synced_song.dart';

/// Eccezione lanciata quando il fingerprinting audio non trova nessuna corrispondenza
class SongNotRecognizedException implements Exception {
  final String message;
  const SongNotRecognizedException([this.message = 'Canzone non rilevata']);
  @override
  String toString() => message;
}

class MusicRecognitionService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'LyricSync/1.0 (Concert lyrics app)',
    },
  ));

  static const String _historyKey = 'lyricsync_history_v1';

  /// Riconoscimento reale tramite AudD API (free, no key) + testi da LRCLIB.
  /// Lancia [SongNotRecognizedException] se il brano non viene rilevato.
  Future<SyncedSong> recognizeFromAudioSample({
    required String? sampleAudioPath,
  }) async {
    if (sampleAudioPath == null) {
      throw const SongNotRecognizedException('Nessun campione audio disponibile.');
    }

    final file = File(sampleAudioPath);
    if (!file.existsSync()) {
      throw const SongNotRecognizedException('File audio del campione non trovato.');
    }

    // ── 1. Fingerprinting con AudD (gratuito, no API key) ───────────────────
    String? title;
    String? artist;
    String? album;
    int? durationSec;

    try {
      final formData = FormData.fromMap({
        'return': 'apple_music,spotify',
        'file': await MultipartFile.fromFile(
          sampleAudioPath,
          filename: 'sample.m4a',
          contentType: DioMediaType('audio', 'm4a'),
        ),
      });

      final audDResponse = await _dio.post(
        'https://api.audd.io/',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      debugPrint('AudD response: ${audDResponse.data}');

      final responseData = audDResponse.data;
      if (responseData is String) {
        final decoded = jsonDecode(responseData) as Map<String, dynamic>;
        final result = decoded['result'] as Map<String, dynamic>?;
        if (result != null) {
          title = result['title'] as String?;
          artist = result['artist'] as String?;
          album = result['album'] as String?;
        }
      } else if (responseData is Map<String, dynamic>) {
        final result = responseData['result'] as Map<String, dynamic>?;
        if (result != null) {
          title = result['title'] as String?;
          artist = result['artist'] as String?;
          album = result['album'] as String?;
        }
      }
    } catch (e) {
      debugPrint('AudD API error: $e');
      // Se l'API è irraggiungibile, lanciamo l'eccezione invece di fallback
      throw const SongNotRecognizedException(
        'Impossibile connettersi al servizio di riconoscimento musicale. Verifica la connessione internet.',
      );
    }

    // Se AudD non ha trovato nulla, non apriamo niente
    if (title == null || title.trim().isEmpty || artist == null || artist.trim().isEmpty) {
      throw const SongNotRecognizedException(
        'Nessuna canzone rilevata. Avvicina il telefono alla fonte audio e riprova.',
      );
    }

    debugPrint('AudD rilevato: "$title" di "$artist"');

    // ── 2. Cerca i testi sincronizzati (.LRC) su LRCLIB ──────────────────────
    String rawLrc = '';
    int actualDurationSec = durationSec ?? 180;

    try {
      final lrcResponse = await _dio.get(
        'https://lrclib.net/api/get',
        queryParameters: {
          'track_name': title,
          'artist_name': artist,
          if (album != null && album.isNotEmpty) 'album_name': album,
        },
      );

      if (lrcResponse.statusCode == 200 && lrcResponse.data is Map) {
        final data = lrcResponse.data as Map<String, dynamic>;
        rawLrc = data['syncedLyrics'] as String? ?? data['plainLyrics'] as String? ?? '';
        final dur = data['duration'];
        if (dur != null) {
          actualDurationSec = (dur as num).round();
        }
      }
    } catch (e) {
      debugPrint('LRCLIB get error: $e — provo con search');
    }

    // Se get esatto fallisce, proviamo la ricerca generica su LRCLIB
    if (rawLrc.isEmpty) {
      try {
        final searchResp = await _dio.get(
          'https://lrclib.net/api/search',
          queryParameters: {'q': '$artist $title'},
        );

        if (searchResp.statusCode == 200 && searchResp.data is List) {
          final list = searchResp.data as List;
          for (final item in list) {
            final synced = item['syncedLyrics'] as String?;
            if (synced != null && synced.trim().isNotEmpty) {
              rawLrc = synced;
              final dur = item['duration'];
              if (dur != null) actualDurationSec = (dur as num).round();
              break;
            }
          }
        }
      } catch (e) {
        debugPrint('LRCLIB search error: $e');
      }
    }

    // Se non abbiamo testi LRC non ha senso aprire il teleprompter vuoto
    if (rawLrc.isEmpty) {
      throw SongNotRecognizedException(
        '"$title" di $artist rilevata, ma nessun testo sincronizzato disponibile su LRCLIB.\nProva a cercarla manualmente con il tasto 🔍.',
      );
    }

    final totalDuration = Duration(seconds: actualDurationSec);
    final parsedLyrics = SyncedSong.parseLrc(rawLrc, totalDuration);

    if (parsedLyrics.isEmpty) {
      throw SongNotRecognizedException(
        '"$title" trovata ma il formato LRC non è valido. Prova la ricerca manuale.',
      );
    }

    final syncedSong = SyncedSong(
      id: 'mic-${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      artist: artist,
      album: album ?? 'Live Detection',
      duration: totalDuration,
      detectedPlayOffset: Duration.zero, // offset reale non calcolabile senza ACRCloud
      matchedAt: DateTime.now(),
      isLiveConcertVersion: true,
      rawLrc: rawLrc,
      lyrics: parsedLyrics,
    );

    await saveSongToHistory(syncedSong);
    return syncedSong;
  }

  /// Ricerca online gratuita su LRCLIB API per qualsiasi canzone o frammento di testo
  Future<List<SyncedSong>> searchLrclib(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    try {
      final response = await _dio.get(
        'https://lrclib.net/api/search',
        queryParameters: {'q': clean},
      );

      if (response.statusCode == 200 && response.data is List) {
        final List list = response.data as List;
        final results = <SyncedSong>[];

        for (final item in list) {
          final syncedLyrics = item['syncedLyrics'] as String?;
          final trackName = item['trackName'] as String? ?? 'Sconosciuto';
          final artistName = item['artistName'] as String? ?? 'Artista';
          final albumName = item['albumName'] as String? ?? 'Album';
          final durationSec = (item['duration'] as num?)?.round() ?? 180;
          final totalDuration = Duration(seconds: durationSec);

          if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
            final parsedLyrics = SyncedSong.parseLrc(syncedLyrics, totalDuration);
            if (parsedLyrics.isNotEmpty) {
              results.add(SyncedSong(
                id: 'lrclib-${item['id'] ?? DateTime.now().millisecondsSinceEpoch}',
                title: trackName,
                artist: artistName,
                album: albumName,
                duration: totalDuration,
                detectedPlayOffset: Duration.zero,
                matchedAt: DateTime.now(),
                isLiveConcertVersion: false,
                rawLrc: syncedLyrics,
                lyrics: parsedLyrics,
              ));
            }
          }
        }

        return results;
      }
    } catch (e) {
      debugPrint('LRCLIB search error: $e');
    }

    return [];
  }

  /// Salva il brano nella cronologia recente dell'utente
  Future<void> saveSongToHistory(SyncedSong song) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyList = await getHistory();

      historyList.removeWhere((item) =>
          item.title.toLowerCase() == song.title.toLowerCase() &&
          item.artist.toLowerCase() == song.artist.toLowerCase());

      historyList.insert(0, song);
      final limited = historyList.take(20).toList();

      final jsonList = limited.map((s) => s.toJson()).toList();
      await prefs.setString(_historyKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Errore salvataggio cronologia: $e');
    }
  }

  /// Recupera la cronologia dei brani sincronizzati
  Future<List<SyncedSong>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw) as List;
      return decoded.map((item) => SyncedSong.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Errore caricamento cronologia: $e');
      return [];
    }
  }

  /// Svuota la cronologia
  Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_historyKey);
    } catch (e) {
      debugPrint('Errore svuotamento cronologia: $e');
    }
  }
}
