import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lyricsync/data/concert_setlists.dart';
import 'package:lyricsync/main.dart';
import 'package:lyricsync/models/synced_song.dart';
import 'package:lyricsync/services/audio_recorder_service.dart';
import 'package:lyricsync/services/music_recognition_service.dart';
import 'package:lyricsync/services/realtime_lyrics_sync_controller.dart';
import 'package:lyricsync/widgets/pulsing_waveform.dart';

void main() {
  testWidgets('LyricSyncApp smoke test: verifies initial load', (WidgetTester tester) async {
    await tester.pumpWidget(const LyricSyncApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('LyricSync'), findsOneWidget);
    expect(find.text('Tocca per ascoltare e sincronizzare il testo'), findsOneWidget);
  });

  test('SyncedSong.parseLrc parses timestamps and translations accurately', () {
    const rawLrc = '''
[00:05.50] Hello world | Ciao mondo
[00:12.00] Singing in the stadium | Cantando nello stadio
''';
    final lines = SyncedSong.parseLrc(rawLrc, const Duration(seconds: 30));
    expect(lines.length, 2);
    expect(lines[0].timestamp, const Duration(seconds: 5, milliseconds: 500));
    expect(lines[0].text, 'Hello world');
    expect(lines[0].translation, 'Ciao mondo');
    expect(lines[0].words.length, 2);

    expect(lines[1].timestamp, const Duration(seconds: 12));
    expect(lines[1].text, 'Singing in the stadium');
    expect(lines[1].translation, 'Cantando nello stadio');
  });

  test('RealtimeLyricsSyncController manages phase offset correctly', () {
    final song = ConcertCatalog.stadiumAnthems.first;
    final controller = RealtimeLyricsSyncController(song: song);

    expect(controller.manualPhaseOffsetMs, 0);

    controller.adjustOffset(250);
    expect(controller.manualPhaseOffsetMs, 250);

    controller.adjustOffset(-100);
    expect(controller.manualPhaseOffsetMs, 150);

    controller.resetOffset();
    expect(controller.manualPhaseOffsetMs, 0);

    controller.dispose();
  });

  test('MusicRecognitionService.parseTimecode parses various timecode formats', () {
    // MM:SS
    expect(MusicRecognitionService.parseTimecode('01:24'), const Duration(minutes: 1, seconds: 24));
    expect(MusicRecognitionService.parseTimecode('00:45.30'), const Duration(seconds: 45, milliseconds: 300));
    // HH:MM:SS
    expect(MusicRecognitionService.parseTimecode('01:02:03'), const Duration(hours: 1, minutes: 2, seconds: 3));
    // Numbers
    expect(MusicRecognitionService.parseTimecode(95), const Duration(seconds: 95));
    expect(MusicRecognitionService.parseTimecode(95000), const Duration(milliseconds: 95000));
    // Null / Empty
    expect(MusicRecognitionService.parseTimecode(null), Duration.zero);
    expect(MusicRecognitionService.parseTimecode(''), Duration.zero);
  });

  testWidgets('PulsingWaveform animates continuously without stalling across frames', (WidgetTester tester) async {
    final acousticNotifier = ValueNotifier<AcousticState>(const AcousticState());
    final amplitudeNotifier = ValueNotifier<double>(-45.0);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PulsingWaveform(
            isListening: true,
            acousticNotifier: acousticNotifier,
            amplitudeNotifier: amplitudeNotifier,
            statusText: 'Ascolto (28s)... Rilevamento in corso',
          ),
        ),
      ),
    );

    // Pump several frames to verify delta-time ticker advances smoothly
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Trigger a dynamic sound peak / transient hit
    acousticNotifier.value = const AcousticState(
      currentDb: -16.0,
      normalized: 0.85,
      soundIntensity: 0.88,
      isSoundActive: true,
      isTransientHit: true,
      transientIntensity: 0.92,
    );

    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.textContaining('RITMO RILEVATO'), findsOneWidget);

    acousticNotifier.dispose();
    amplitudeNotifier.dispose();
  });
}
