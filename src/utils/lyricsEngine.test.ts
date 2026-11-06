import test from 'node:test';
import assert from 'node:assert/strict';
import {
  formatLrcTimestamp,
  formatDisplayTime,
  parseLrc,
  getSyncStateAtTime,
  advanceKineticOrbPhysics,
  KineticOrbPhysicsState,
} from './lyricsEngine';

test('formatLrcTimestamp and formatDisplayTime format milliseconds accurately', () => {
  assert.equal(formatLrcTimestamp(0), '[00:00.00]');
  assert.equal(formatLrcTimestamp(65430), '[01:05.43]');
  assert.equal(formatDisplayTime(65430, false), '01:05');
  assert.equal(formatDisplayTime(65430, true), '01:05.4');
});

test('parseLrc parses timestamps, lyrics, translations, and generates word timings', () => {
  const sampleLrc = `
[00:14.20] When you try your best, but you don't succeed | Quando fai del tuo meglio, ma non ci riesci
[00:21.00] When you get what you want, but not what you need | Quando ottieni ciò che vuoi, ma non ciò di cui hai bisogno
  `.trim();

  const lines = parseLrc(sampleLrc, 120000);
  assert.equal(lines.length, 2);
  assert.equal(lines[0].startMs, 14200);
  assert.equal(lines[0].translationIt, 'Quando fai del tuo meglio, ma non ci riesci');
  assert.ok(lines[0].words.length >= 8);
});

test('getSyncStateAtTime identifies active line, active word, and applies manual offset', () => {
  const sampleLrc = `
[00:05.00] Prima riga del brano
[00:10.00] Seconda riga sincronizzata
  `.trim();

  const lines = parseLrc(sampleLrc, 30000);
  const firstState = getSyncStateAtTime(lines, 6500, 0);
  assert.equal(firstState.activeLineIndex, 0);

  const offsetState = getSyncStateAtTime(lines, 6500, 4000);
  assert.equal(offsetState.activeLineIndex, 1);
});

test('advanceKineticOrbPhysics advances monotonically without freezing or loop snaps during network intervals', () => {
  let state: KineticOrbPhysicsState = {
    basePhase: 0,
    dynamicPhase: 0,
    rippleClock: 0,
    smoothVolume: 0,
    smoothTransient: 0,
    listeningBlend: 0,
  };

  // Simulate 5 seconds (300 frames at 60 FPS) of listening even with 0 raw mic input (network chunk transition)
  for (let frame = 0; frame < 300; frame++) {
    const next = advanceKineticOrbPhysics(state, {
      dtSeconds: 1 / 60,
      isListening: true,
      rawVolume: 0,
      rawTransient: 0,
      msSinceAudio: 500,
    });

    // Phases must strictly increase on every frame and never wrap around to 0
    assert.ok(next.basePhase > state.basePhase);
    assert.ok(next.dynamicPhase > state.dynamicPhase);
    assert.ok(next.rippleClock > state.rippleClock);
    state = next;
  }

  // Carrier wave ensures smoothVolume never freezes at 0 while listening
  assert.ok(state.smoothVolume > 0.14);
  assert.ok(state.listeningBlend > 0.99);
});
