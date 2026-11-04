import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/concert_setlists.dart';
import '../models/listening_environment.dart';
import '../models/synced_song.dart';

/// Eccezione lanciata quando il fingerprinting audio non trova nessuna corrispondenza
class SongNotRecognizedException implements Exception {
  final String message;
  const SongNotRecognizedException([this.message = 'Canzone non rilevata']);
  @override
  String toString() => message;
}

/// Eccezione lanciata quando il limite di richieste AudD è stato raggiunto
class AudDRateLimitException implements Exception {
  final String message;
  const AudDRateLimitException([this.message = 'Limite richieste AudD raggiunto']);
  @override
  String toString() => message;
}

class MusicRecognitionService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
    headers: {
      'User-Agent': 'LyricSync/1.0 (Concert Live Lyrics Teleprompter)',
    },
  ));

  static const String _historyKey = 'lyricsync_history_v1';
  static const String _prefKeyAudDToken = 'lyricsync_audd_api_token';

  Future<String?> getSavedAudDToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_prefKeyAudDToken);
    return (token != null && token.trim().isNotEmpty) ? token.trim() : null;
  }

  Future<void> saveAudDToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null || token.trim().isEmpty) {
      await prefs.remove(_prefKeyAudDToken);
    } else {
      await prefs.setString(_prefKeyAudDToken, token.trim());
    }
  }

  /// Converte qualsiasi formato timecode (MM:SS, HH:MM:SS, secondi, millisecondi) in Duration
  static Duration parseTimecode(dynamic raw) {
    if (raw == null) return Duration.zero;

    if (raw is num) {
      if (raw > 10000) {
        return Duration(milliseconds: raw.round());
      } else {
        return Duration(milliseconds: (raw * 1000).round());
      }
    }

    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return Duration.zero;

      final asNum = num.tryParse(s);
      if (asNum != null) {
        return parseTimecode(asNum);
      }

      final parts = s.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final secPart = double.tryParse(parts[1]) ?? 0.0;
        return Duration(milliseconds: (m * 60000 + secPart * 1000).round());
      } else if (parts.length == 3) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final secPart = double.tryParse(parts[2]) ?? 0.0;
        return Duration(milliseconds: (h * 3600000 + m * 60000 + secPart * 1000).round());
      }
    }

    return Duration.zero;
  }

  /// Pulisce il titolo rimuovendo suffissi tipici (Remastered, Live, feat., ecc.)
  static String cleanTitle(String raw) {
    var s = raw;
    s = s.replaceAll(RegExp(r'\s*-\s*(Remaster(ed)?(\s*\d+)?|Live.*|Radio Edit|Single).*', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\(.*(feat|with|live|remaster|deluxe|version|edit|audio|video).*\)', caseSensitive: false), '');
    s = s.replaceAll(RegExp(r'\s*\[.*(feat|with|live|remaster|deluxe|version|edit|audio|video).*\]', caseSensitive: false), '');
    return s.trim();
  }

  /// Pulisce il nome dell'artista
  static String cleanArtist(String raw) {
    var s = raw;
    s = s.replaceAll(RegExp(r'\s*(feat\.|featuring|with|&).+', caseSensitive: false), '');
    return s.trim();
  }

  /// Riconoscimento reale tramite AudD API + Recupero Testi Multi-Provider (LRCLIB, Lyrics.ovh, AudD Lyrics, Offline)
  Future<SyncedSong> recognizeFromAudioSample({
    required String? sampleAudioPath,
    DateTime? recordingEndedAt,
    ListeningEnvironment? environment,
  }) async {
    if (sampleAudioPath == null) {
      throw const SongNotRecognizedException('Nessun campione audio registrato.');
    }

    final file = File(sampleAudioPath);
    if (!file.existsSync()) {
      throw const SongNotRecognizedException('File audio del campione non trovato.');
    }

    // ── 1. Fingerprinting con AudD (gratuito) ────────────────────────────────
    String? rawTitle;
    String? rawArtist;
    String? rawAlbum;
    String? auddLyrics;
    String? coverArtUrl;
    String? spotifyUrl;
    int durationSec = 180;
    Duration detectedPlayOffset = Duration.zero;

    final savedToken = await getSavedAudDToken();
    final apiToken = savedToken ?? 'test';

    try {
      final formData = FormData.fromMap({
        'api_token': apiToken,
        'return': 'lyrics,apple_music,spotify',
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
          receiveTimeout: const Duration(seconds: 14),
          sendTimeout: const Duration(seconds: 14),
        ),
      );

      debugPrint('AudD response: ${audDResponse.data}');

      Map<String, dynamic>? resultObj;
      Map<String, dynamic>? errorObj;
      final responseData = audDResponse.data;
      if (responseData is String) {
        final decoded = jsonDecode(responseData) as Map<String, dynamic>;
        resultObj = decoded['result'] as Map<String, dynamic>?;
        errorObj = decoded['error'] as Map<String, dynamic>?;
      } else if (responseData is Map<String, dynamic>) {
        resultObj = responseData['result'] as Map<String, dynamic>?;
        errorObj = responseData['error'] as Map<String, dynamic>?;
      }

      if (errorObj != null) {
        final errorCode = errorObj['error_code'];
        final errorMsg = errorObj['error_message']?.toString() ?? '';
        debugPrint('AudD API returned error: $errorCode - $errorMsg');
        if (errorCode == 901 || errorCode == 900) {
          throw const AudDRateLimitException(
            'Limite di richieste gratuite AudD raggiunto.\n\nPer continuare, inserisci un API Token gratuito di AudD (300 richieste gratis su dashboard.audd.io).',
          );
        }
      }

      if (resultObj != null) {
        rawTitle = resultObj['title'] as String?;
        rawArtist = resultObj['artist'] as String?;
        rawAlbum = resultObj['album'] as String?;

        // Calcolo timecode calibrato: compensa solo la latenza di rete post-registrazione
        final rawTimecode = resultObj['timecode'] ??
            resultObj['play_offset_ms'] ??
            resultObj['offset'];
        if (rawTimecode != null) {
          final sampleOffset = parseTimecode(rawTimecode);
          final networkDelay = recordingEndedAt != null
              ? DateTime.now().difference(recordingEndedAt)
              : const Duration(milliseconds: 1200);

          final envOffset = environment != null
              ? Duration(milliseconds: environment.latencyOffsetMs)
              : Duration.zero;

          // Calibrazione: il timecode indica la posizione del campione;
          // aggiungiamo il ritardo di rete e l'offset acustico ambientale selezionato
          detectedPlayOffset = sampleOffset + networkDelay + envOffset;
          if (detectedPlayOffset < Duration.zero) detectedPlayOffset = Duration.zero;
          debugPrint('Sincronia Calibrata: timecode=$rawTimecode ($sampleOffset) + netDelay=$networkDelay + envOffset=$envOffset => offset=$detectedPlayOffset');
        }

        // Durata e copertina da metadata Spotify / Apple Music
        final appleMusic = resultObj['apple_music'] as Map<String, dynamic>?;
        final spotify = resultObj['spotify'] as Map<String, dynamic>?;

        if (spotify != null) {
          if (spotify['duration_ms'] != null) {
            durationSec = ((spotify['duration_ms'] as num) / 1000).round();
          }
          final albumObj = spotify['album'] as Map<String, dynamic>?;
          final images = albumObj?['images'] as List?;
          if (images != null && images.isNotEmpty) {
            coverArtUrl = images[0]['url'] as String?;
          }
          final externalUrls = spotify['external_urls'] as Map<String, dynamic>?;
          spotifyUrl = externalUrls?['spotify'] as String?;
        } else if (appleMusic?['durationInMillis'] != null) {
          durationSec = ((appleMusic!['durationInMillis'] as num) / 1000).round();
        }

        if (coverArtUrl == null && appleMusic != null) {
          final artwork = appleMusic['artwork'] as Map<String, dynamic>?;
          final rawArtUrl = artwork?['url'] as String?;
          if (rawArtUrl != null) {
            coverArtUrl = rawArtUrl.replaceAll('{w}', '300').replaceAll('{h}', '300');
          }
        }

        // Fallback link Spotify per apertura diretta app o web
        spotifyUrl ??= 'https://open.spotify.com/search/${Uri.encodeComponent('$rawArtist $rawTitle')}';

        // Testo restituito direttamente da AudD (se presente)
        final lyricsObj = resultObj['lyrics'] as Map<String, dynamic>?;
        if (lyricsObj != null && lyricsObj['lyrics'] is String) {
          auddLyrics = lyricsObj['lyrics'] as String;
        }
      }
    } on AudDRateLimitException {
      rethrow;
    } catch (e) {
      debugPrint('AudD API error: $e');
      throw const SongNotRecognizedException(
        'Impossibile contattare il servizio di riconoscimento. Verifica la connessione internet e riprova.',
      );
    }

    if (rawTitle == null || rawTitle.trim().isEmpty || rawArtist == null || rawArtist.trim().isEmpty) {
      throw const SongNotRecognizedException(
        'Nessuna canzone rilevata nel microfono. Avvicina il telefono agli altoparlanti e riprova.',
      );
    }

    final cleanedTitle = cleanTitle(rawTitle);
    final cleanedArtist = cleanArtist(rawArtist);
    debugPrint('Canzone riconosciuta: "$rawTitle" ($cleanedTitle) di "$rawArtist" ($cleanedArtist) @ offset $detectedPlayOffset');

    // ── 2. Recupero Testi & Sincronia con Fallback Multi-Fonte ───────────────
    final totalDuration = Duration(seconds: durationSec);
    final lyricsData = await _fetchLyricsMultiSource(
      rawTitle: rawTitle,
      cleanTitle: cleanedTitle,
      rawArtist: rawArtist,
      cleanArtist: cleanedArtist,
      auddLyrics: auddLyrics,
      duration: totalDuration,
    );

    if (lyricsData == null || lyricsData.lines.isEmpty) {
      throw SongNotRecognizedException(
        '"$rawTitle" di $rawArtist rilevata con successo, ma il testo non è al momento disponibile nei database gratuiti.\nPuoi cercarla manualmente con l\'icona 🔍.',
      );
    }

    final syncedSong = SyncedSong(
      id: 'mic-${DateTime.now().millisecondsSinceEpoch}',
      title: rawTitle,
      artist: rawArtist,
      album: rawAlbum ?? 'Riconoscimento Live',
      duration: totalDuration,
      detectedPlayOffset: detectedPlayOffset,
      matchedAt: DateTime.now(),
      isLiveConcertVersion: true,
      coverArtUrl: coverArtUrl,
      spotifyUrl: spotifyUrl,
      rawLrc: lyricsData.rawLrc,
      lyrics: lyricsData.lines,
    );

    await saveSongToHistory(syncedSong);
    return syncedSong;
  }

  /// Motore multi-provider per testi sincronizzati e testo piano
  Future<({String rawLrc, List<LyricLine> lines})?> _fetchLyricsMultiSource({
    required String rawTitle,
    required String cleanTitle,
    required String rawArtist,
    required String cleanArtist,
    required String? auddLyrics,
    required Duration duration,
  }) async {
    // Fonte 0: Controlla catalogo inni da concerto offline (Coldplay, Oasis, Queen, Maneskin, ecc.)
    final offlineMatch = ConcertCatalog.stadiumAnthems.where((s) {
      final sTitle = s.title.toLowerCase();
      final sArtist = s.artist.toLowerCase();
      final cTitle = cleanTitle.toLowerCase();
      final cArtist = cleanArtist.toLowerCase();
      return (sTitle.contains(cTitle) || cTitle.contains(sTitle.split(' ').first)) &&
          (sArtist.contains(cArtist) || cArtist.contains(sArtist));
    }).firstOrNull;

    if (offlineMatch != null) {
      debugPrint('Testo trovato nel catalogo inni offline!');
      return (rawLrc: offlineMatch.rawLrc, lines: offlineMatch.lyrics);
    }

    String? foundSyncedLrc;
    String? foundPlainText;

    // Fonte 1: LRCLIB (Testi sincronizzati al millisecondo)
    try {
      // 1.A: Tentativo con titolo e artista puliti (senza album per evitare 404)
      final lrc1 = await _queryLrclibGet(cleanTitle, cleanArtist);
      if (lrc1 != null) {
        if (lrc1.synced != null && lrc1.synced!.isNotEmpty) {
          foundSyncedLrc = lrc1.synced;
        } else if (lrc1.plain != null && lrc1.plain!.isNotEmpty) {
          foundPlainText = lrc1.plain;
        }
      }

      // 1.B: Se nullo, tentativo con titolo e artista originali
      if (foundSyncedLrc == null && foundPlainText == null && rawTitle != cleanTitle) {
        final lrc2 = await _queryLrclibGet(rawTitle, rawArtist);
        if (lrc2 != null) {
          if (lrc2.synced != null && lrc2.synced!.isNotEmpty) {
            foundSyncedLrc = lrc2.synced;
          } else if (lrc2.plain != null && lrc2.plain!.isNotEmpty) {
            foundPlainText = lrc2.plain;
          }
        }
      }

      // 1.C: Se ancora nullo, ricerca per query libera su LRCLIB
      if (foundSyncedLrc == null && foundPlainText == null) {
        final searchResult = await _queryLrclibSearch('$cleanArtist $cleanTitle');
        if (searchResult != null) {
          if (searchResult.synced != null && searchResult.synced!.isNotEmpty) {
            foundSyncedLrc = searchResult.synced;
          } else if (searchResult.plain != null && searchResult.plain!.isNotEmpty) {
            foundPlainText = searchResult.plain;
          }
        }
      }
    } catch (e) {
      debugPrint('LRCLIB fallback err: $e');
    }

    // Se abbiamo trovato i testi sincronizzati da LRCLIB, li usiamo subito!
    if (foundSyncedLrc != null && foundSyncedLrc.trim().isNotEmpty) {
      final parsed = SyncedSong.parseLrc(foundSyncedLrc, duration);
      if (parsed.isNotEmpty) {
        return (rawLrc: foundSyncedLrc, lines: parsed);
      }
    }

    // Fonte 2: Lyrics.ovh (API gratuita, enorme catalogo di testi italiani e internazionali)
    if (foundPlainText == null || foundPlainText.trim().isEmpty) {
      try {
        final ovhResp = await _dio.get(
          'https://api.lyrics.ovh/v1/$cleanArtist/$cleanTitle',
          options: Options(receiveTimeout: const Duration(seconds: 4)),
        );
        if (ovhResp.statusCode == 200 && ovhResp.data is Map) {
          final lyrics = ovhResp.data['lyrics'] as String?;
          if (lyrics != null && lyrics.trim().isNotEmpty) {
            foundPlainText = lyrics;
            debugPrint('Testo trovato su Lyrics.ovh!');
          }
        }
      } catch (e) {
        debugPrint('Lyrics.ovh fallback err: $e');
      }
    }

    // Fonte 3: Testo restituito da AudD
    if ((foundPlainText == null || foundPlainText.trim().isEmpty) && auddLyrics != null && auddLyrics.trim().isNotEmpty) {
      foundPlainText = auddLyrics;
      debugPrint('Testo utilizzato da AudD response!');
    }

    // Se abbiamo testo piano (da LRCLIB plain, da Lyrics.ovh o da AudD), attiviamo l'Auto-Sync intelligente
    if (foundPlainText != null && foundPlainText.trim().isNotEmpty) {
      final autoSyncedLines = SyncedSong.parsePlainLyrics(foundPlainText, duration);
      if (autoSyncedLines.isNotEmpty) {
        final generatedLrc = SyncedSong.toLrcString(autoSyncedLines);
        return (rawLrc: generatedLrc, lines: autoSyncedLines);
      }
    }

    return null;
  }

  Future<({String? synced, String? plain})?> _queryLrclibGet(String title, String artist) async {
    try {
      final res = await _dio.get(
        'https://lrclib.net/api/get',
        queryParameters: {
          'track_name': title,
          'artist_name': artist,
        },
        options: Options(receiveTimeout: const Duration(seconds: 4)),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map<String, dynamic>;
        return (
          synced: data['syncedLyrics'] as String?,
          plain: data['plainLyrics'] as String?,
        );
      }
    } catch (_) {}
    return null;
  }

  Future<({String? synced, String? plain})?> _queryLrclibSearch(String query) async {
    try {
      final res = await _dio.get(
        'https://lrclib.net/api/search',
        queryParameters: {'q': query},
        options: Options(receiveTimeout: const Duration(seconds: 4)),
      );
      if (res.statusCode == 200 && res.data is List) {
        final list = res.data as List;
        String? firstPlain;
        for (final item in list) {
          final synced = item['syncedLyrics'] as String?;
          if (synced != null && synced.trim().isNotEmpty) {
            return (synced: synced, plain: item['plainLyrics'] as String?);
          }
          firstPlain ??= item['plainLyrics'] as String?;
        }
        if (firstPlain != null) {
          return (synced: null, plain: firstPlain);
        }
      }
    } catch (_) {}
    return null;
  }

  /// Ricerca manuale su LRCLIB e Lyrics.ovh
  Future<List<SyncedSong>> searchLrclib(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    final results = <SyncedSong>[];

    try {
      final response = await _dio.get(
        'https://lrclib.net/api/search',
        queryParameters: {'q': clean},
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );

      if (response.statusCode == 200 && response.data is List) {
        final list = response.data as List;
        for (final item in list) {
          final syncedLyrics = item['syncedLyrics'] as String?;
          final plainLyrics = item['plainLyrics'] as String?;
          final trackName = item['trackName'] as String? ?? 'Sconosciuto';
          final artistName = item['artistName'] as String? ?? 'Artista';
          final albumName = item['albumName'] as String? ?? 'Album';
          final durationSec = (item['duration'] as num?)?.round() ?? 180;
          final totalDuration = Duration(seconds: durationSec);

          if (syncedLyrics != null && syncedLyrics.trim().isNotEmpty) {
            final parsed = SyncedSong.parseLrc(syncedLyrics, totalDuration);
            if (parsed.isNotEmpty) {
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
                lyrics: parsed,
              ));
            }
          } else if (plainLyrics != null && plainLyrics.trim().isNotEmpty) {
            final autoSynced = SyncedSong.parsePlainLyrics(plainLyrics, totalDuration);
            if (autoSynced.isNotEmpty) {
              results.add(SyncedSong(
                id: 'lrclib-${item['id'] ?? DateTime.now().millisecondsSinceEpoch}',
                title: trackName,
                artist: artistName,
                album: albumName,
                duration: totalDuration,
                detectedPlayOffset: Duration.zero,
                matchedAt: DateTime.now(),
                isLiveConcertVersion: false,
                rawLrc: SyncedSong.toLrcString(autoSynced),
                lyrics: autoSynced,
              ));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Search error: $e');
    }

    // Se pochi risultati, cerca anche nel catalogo offline
    final queryLower = clean.toLowerCase();
    for (final song in ConcertCatalog.stadiumAnthems) {
      if (song.title.toLowerCase().contains(queryLower) ||
          song.artist.toLowerCase().contains(queryLower) ||
          song.lyrics.any((l) => l.text.toLowerCase().contains(queryLower))) {
        if (!results.any((r) => r.title == song.title)) {
          results.add(song);
        }
      }
    }

    return results;
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

  // ── GESTIONE PREFERITI (CUORE) ──────────────────────────────────────────
  static const String _favoritesKey = 'lyricsync_favorites_v1';

  /// Controlla se la canzone è nei preferiti
  Future<bool> isFavorite(String title, String artist) async {
    final favs = await getFavorites();
    return favs.any((s) =>
        s.title.trim().toLowerCase() == title.trim().toLowerCase() &&
        s.artist.trim().toLowerCase() == artist.trim().toLowerCase());
  }

  /// Aggiunge o rimuove dai preferiti, restituisce true se ora è preferita
  Future<bool> toggleFavorite(SyncedSong song) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favs = await getFavorites();
      final index = favs.indexWhere((s) =>
          s.title.trim().toLowerCase() == song.title.trim().toLowerCase() &&
          s.artist.trim().toLowerCase() == song.artist.trim().toLowerCase());

      bool nowFavorite;
      if (index >= 0) {
        favs.removeAt(index);
        nowFavorite = false;
      } else {
        favs.insert(0, song);
        nowFavorite = true;
      }

      final jsonList = favs.map((s) => s.toJson()).toList();
      await prefs.setString(_favoritesKey, jsonEncode(jsonList));
      return nowFavorite;
    } catch (e) {
      debugPrint('Errore toggle preferiti: $e');
      return false;
    }
  }

  /// Recupera l'elenco dei brani preferiti
  Future<List<SyncedSong>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_favoritesKey);
      if (raw == null || raw.isEmpty) return [];

      final decoded = jsonDecode(raw) as List;
      return decoded.map((item) => SyncedSong.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Errore caricamento preferiti: $e');
      return [];
    }
  }
}
