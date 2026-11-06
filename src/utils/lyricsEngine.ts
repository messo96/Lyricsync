export interface LyricWord {
  text: string;
  startMs: number;
  endMs: number;
}

export interface LyricLine {
  id: string;
  startMs: number;
  endMs: number;
  text: string;
  translationIt?: string;
  words: LyricWord[];
}

export interface SyncState {
  activeLineIndex: number;
  activeWordIndex: number;
  lineProgress: number;
  wordProgress: number;
  effectiveTimeMs: number;
  nextLineIndex: number;
}

export interface KineticOrbPhysicsState {
  basePhase: number;
  dynamicPhase: number;
  rippleClock: number;
  smoothVolume: number;
  smoothTransient: number;
  listeningBlend: number;
}

/**
 * Pure delta-time physics step for the Hyper-Fluid Kinetic Microphone Orb.
 * Accumulates phases monotonically (never wraps around to 0), preventing
 * any loop snap or stall even when audio input pauses between chunks.
 */
export function advanceKineticOrbPhysics(
  prev: KineticOrbPhysicsState,
  params: {
    dtSeconds: number;
    isListening: boolean;
    rawVolume: number;
    rawTransient: number;
    msSinceAudio: number;
  }
): KineticOrbPhysicsState {
  const dt = Math.max(0.001, Math.min(0.05, params.dtSeconds));
  const targetBlend = params.isListening ? 1.0 : 0.0;
  const listeningBlend =
    prev.listeningBlend + (targetBlend - prev.listeningBlend) * (1.0 - Math.exp(-dt * 9.0));

  let effectiveTargetVol = Math.max(0, Math.min(1, params.rawVolume));
  let effectiveTargetTrans = Math.max(0, Math.min(1, params.rawTransient));

  if (params.isListening) {
    const carrierWave =
      0.24 +
      0.14 * Math.sin(prev.basePhase * 2.3) +
      0.09 * Math.cos(prev.basePhase * 3.9) +
      0.06 * Math.sin(prev.basePhase * 6.7);

    if (params.msSinceAudio > 140 || effectiveTargetVol < 0.18) {
      effectiveTargetVol = Math.max(
        effectiveTargetVol,
        Math.max(0.15, Math.min(0.52, carrierWave))
      );
    }
    if (params.msSinceAudio > 220 && Math.sin(prev.basePhase * 3.1) > 0.82) {
      effectiveTargetTrans = Math.max(effectiveTargetTrans, 0.38);
    }
  } else {
    effectiveTargetVol = 0.0;
    effectiveTargetTrans = 0.0;
  }

  const volRate = effectiveTargetVol > prev.smoothVolume ? 18.0 : 7.5;
  const smoothVolume =
    prev.smoothVolume +
    (effectiveTargetVol - prev.smoothVolume) * (1.0 - Math.exp(-dt * volRate));

  const transRate = effectiveTargetTrans > prev.smoothTransient ? 22.0 : 8.5;
  const smoothTransient =
    prev.smoothTransient +
    (effectiveTargetTrans - prev.smoothTransient) * (1.0 - Math.exp(-dt * transRate));

  const energyBoost = 1.0 + smoothVolume * 2.1 + smoothTransient * 1.35;
  const basePhase = prev.basePhase + dt * 2.2;
  const dynamicPhase =
    prev.dynamicPhase + dt * (2.6 * (0.45 + 0.55 * listeningBlend) * energyBoost);
  const rippleClock =
    prev.rippleClock + dt * (0.72 + smoothVolume * 0.95 + smoothTransient * 0.65);

  return {
    basePhase,
    dynamicPhase,
    rippleClock,
    smoothVolume,
    smoothTransient,
    listeningBlend,
  };
}

export function formatLrcTimestamp(ms: number): string {
  const clamped = Math.max(0, Math.round(ms));
  const totalSeconds = Math.floor(clamped / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  const hundredths = Math.floor((clamped % 1000) / 10);

  return `[${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}.${String(hundredths).padStart(2, '0')}]`;
}

export function formatDisplayTime(ms: number, includeDeciseconds = false): string {
  const clamped = Math.max(0, Math.round(ms));
  const totalSeconds = Math.floor(clamped / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  const deciseconds = Math.floor((clamped % 1000) / 100);

  const mm = String(minutes).padStart(2, '0');
  const ss = String(seconds).padStart(2, '0');
  return includeDeciseconds ? `${mm}:${ss}.${deciseconds}` : `${mm}:${ss}`;
}

export function generateWordTimings(text: string, startMs: number, endMs: number): LyricWord[] {
  const rawWords = text
    .trim()
    .split(/\s+/)
    .filter((w) => w.length > 0);

  if (rawWords.length === 0) return [];

  const duration = Math.max(400, endMs - startMs);
  const totalWeight = rawWords.reduce((sum, w) => sum + Math.max(2, w.length), 0);

  let cursor = startMs;
  return rawWords.map((word, idx) => {
    const weight = Math.max(2, word.length);
    const wordDuration =
      idx === rawWords.length - 1
        ? Math.max(50, startMs + duration - cursor)
        : Math.round((weight / totalWeight) * duration);
    const wStart = cursor;
    const wEnd = cursor + wordDuration;
    cursor = wEnd;
    return { text: word, startMs: wStart, endMs: wEnd };
  });
}

export function parseLrc(lrcContent: string, totalDurationMs = 240000): LyricLine[] {
  const lines = lrcContent.split(/\r?\n/);
  const parsedRaw: Array<{ startMs: number; text: string; translationIt?: string }> = [];
  const timeRegex = /^\[(\d{1,3}):(\d{2})(?:\.(\d{1,3}))?\]\s*(.*)$/;

  for (const rawLine of lines) {
    const trimmed = rawLine.trim();
    if (!trimmed) continue;
    const match = trimmed.match(timeRegex);
    if (!match) continue;

    const minutes = parseInt(match[1], 10);
    const seconds = parseInt(match[2], 10);
    const fractionStr = match[3] || '0';
    let ms = 0;
    if (fractionStr.length === 1) ms = parseInt(fractionStr, 10) * 100;
    else if (fractionStr.length === 2) ms = parseInt(fractionStr, 10) * 10;
    else ms = parseInt(fractionStr.slice(0, 3), 10);

    const startMs = minutes * 60 * 1000 + seconds * 1000 + ms;
    const payload = match[4].trim();
    if (!payload) continue;

    const parts = payload.split(/\s*\|\s*/);
    const mainText = parts[0].trim();
    const translationIt = parts[1]?.trim();

    if (mainText) {
      parsedRaw.push({ startMs, text: mainText, translationIt });
    }
  }

  parsedRaw.sort((a, b) => a.startMs - b.startMs);

  return parsedRaw.map((item, idx) => {
    const nextStart =
      idx < parsedRaw.length - 1
        ? parsedRaw[idx + 1].startMs
        : Math.max(item.startMs + 5000, totalDurationMs);
    const endMs = Math.max(item.startMs + 800, Math.min(nextStart - 120, item.startMs + 8000));
    return {
      id: `line-${idx}-${item.startMs}`,
      startMs: item.startMs,
      endMs,
      text: item.text,
      translationIt: item.translationIt,
      words: generateWordTimings(item.text, item.startMs, endMs),
    };
  });
}

export function getSyncStateAtTime(
  lines: LyricLine[],
  currentTimeMs: number,
  offsetMs = 0
): SyncState {
  const effectiveTimeMs = Math.max(0, currentTimeMs + offsetMs);

  if (lines.length === 0) {
    return {
      activeLineIndex: -1,
      activeWordIndex: -1,
      lineProgress: 0,
      wordProgress: 0,
      effectiveTimeMs,
      nextLineIndex: -1,
    };
  }

  let activeLineIndex = -1;
  for (let i = 0; i < lines.length; i++) {
    if (effectiveTimeMs >= lines[i].startMs) {
      activeLineIndex = i;
    } else {
      break;
    }
  }

  if (activeLineIndex === -1) {
    return {
      activeLineIndex: -1,
      activeWordIndex: -1,
      lineProgress: 0,
      wordProgress: 0,
      effectiveTimeMs,
      nextLineIndex: 0,
    };
  }

  const line = lines[activeLineIndex];
  const lineDuration = Math.max(1, line.endMs - line.startMs);
  const lineProgress = Math.max(0, Math.min(1, (effectiveTimeMs - line.startMs) / lineDuration));

  let activeWordIndex = -1;
  let wordProgress = 0;

  for (let w = 0; w < line.words.length; w++) {
    const word = line.words[w];
    if (effectiveTimeMs >= word.startMs) {
      activeWordIndex = w;
      const wDur = Math.max(1, word.endMs - word.startMs);
      wordProgress = Math.max(0, Math.min(1, (effectiveTimeMs - word.startMs) / wDur));
    } else {
      break;
    }
  }

  const nextLineIndex = activeLineIndex + 1 < lines.length ? activeLineIndex + 1 : -1;

  return {
    activeLineIndex,
    activeWordIndex,
    lineProgress,
    wordProgress,
    effectiveTimeMs,
    nextLineIndex,
  };
}
