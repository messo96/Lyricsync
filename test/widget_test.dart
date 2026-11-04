import 'package:flutter_test/flutter_test.dart';
import 'package:lyricsync/data/concert_setlists.dart';
import 'package:lyricsync/main.dart';
import 'package:lyricsync/models/synced_song.dart';
import 'package:lyricsync/services/realtime_lyrics_sync_controller.dart';

void main() {
  testWidgets('LyricSyncApp smoke test: verifies initial load', (WidgetTester tester) async {
    await tester.pumpWidget(const LyricSyncApp());
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('LyricSync'), findsOneWidget);
    expect(find.text('Setlist & Inni da Stadio'), findsOneWidget);
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
}
