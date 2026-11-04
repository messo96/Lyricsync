import test from 'node:test';
import assert from 'node:assert/strict';
import {
  formatLrcTimestamp,
  formatDisplayTime,
  parseLrc,
  serializeToLrc,
  getSyncStateAtTime,
  computeEnvironmentSyncPosition,
} from './lyricsEngine';

test('formatLrcTimestamp and formatDisplayTime format milliseconds accurately', () => {
  assert.equal(formatLrcTimestamp(0), '[00:00.00]');
  assert.equal(formatLrcTimestamp(65430), '[01:05.43]');
  assert.equal(formatDisplayTime(65430, false), '01:05');
  assert.equal(formatDisplayTime(65430, true), '01:05.4');
});

test('parseLrc parses timestamps, lyrics, translations, and generates word timings', () => {
  const sampleLrc = `
[00:04.00] Luci riflesse sull'asfalto bagnato | Lights reflected on the wet asphalt
[00:08.50] Il basso vibra dietro la vetrina | The bass vibrates behind the shop window
[00:13.00] Cerco la tua voce dentro il rumore | I search for your voice inside the noise
  `.trim();

  const lines = parseLrc(sampleLrc, 60000);
  assert.equal(lines.length, 3);
  assert.equal(lines[0].startMs, 4000);
  assert.equal(lines[0].text, "Luci riflesse sull'asfalto bagnato");
  assert.equal(lines[0].translationIt, 'Lights reflected on the wet asphalt');
  assert.equal(lines[0].words.length, 4);
  assert.equal(lines[0].words[0].startMs, 4000);
  assert.ok(lines[0].endMs <= 8500);
});

test('getSyncStateAtTime identifies active line, active word, and applies manual offset', () => {
  const sampleLrc = `
[00:05.00] Prima riga del brano
[00:10.00] Seconda riga sincronizzata
[00:15.00] Terza riga finale
  `.trim();

  const lines = parseLrc(sampleLrc, 30000);

  // Before first lyric line
  const beforeState = getSyncStateAtTime(lines, 2000, 0);
  assert.equal(beforeState.activeLineIndex, -1);
  assert.equal(beforeState.nextLineIndex, 0);

  // Middle of first lyric line
  const firstState = getSyncStateAtTime(lines, 6500, 0);
  assert.equal(firstState.activeLineIndex, 0);
  assert.ok(firstState.activeWordIndex >= 0);
  assert.ok(firstState.lineProgress > 0 && firstState.lineProgress < 1);

  // With +4000ms offset at 6500ms -> effective time is 10500ms (line index 1)
  const offsetState = getSyncStateAtTime(lines, 6500, 4000);
  assert.equal(offsetState.activeLineIndex, 1);
  assert.equal(offsetState.effectiveTimeMs, 10500);
});

test('computeEnvironmentSyncPosition compensates for room offset and network latency', () => {
  const syncedMs = computeEnvironmentSyncPosition({
    detectedSongPositionMs: 34200,
    networkLatencyMs: 380,
    elapsedSinceMatchMs: 1420,
    manualPhaseOffsetMs: -100,
    totalDurationMs: 180000,
  });

  assert.equal(syncedMs, 35900);
});

test('serializeToLrc round-trips lines and metadata', () => {
  const lines = parseLrc('[00:12.50] Onde di vetro sul mare | Waves of glass on the sea', 60000);
  const serialized = serializeToLrc(lines, {
    title: 'Onde di Vetro',
    artist: 'Nu Genea & Serena',
  });

  assert.ok(serialized.includes('[ti:Onde di Vetro]'));
  assert.ok(serialized.includes('[00:12.50] Onde di vetro sul mare | Waves of glass on the sea'));
});
