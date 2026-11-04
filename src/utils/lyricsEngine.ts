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
  chords?: string;
  words: LyricWord[];
}

export interface SyncState {
  activeLineIndex: number;
  activeWordIndex: number;
  lineProgress: number; // 0 to 1
  wordProgress: number; // 0 to 1
  effectiveTimeMs: number;
  nextLineIndex: number;
}

/**
 * Formats milliseconds into standard LRC timestamp [mm:ss.xx]
 */
export function formatLrcTimestamp(ms: number): string {
  const clamped = Math.max(0, Math.round(ms));
  const totalSeconds = Math.floor(clamped / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  const hundredths = Math.floor((clamped % 1000) / 10);

  const mm = String(minutes).padStart(2, '0');
  const ss = String(seconds).padStart(2, '0');
  const xx = String(hundredths).padStart(2, '0');
  return `[${mm}:${ss}.${xx}]`;
}

/**
 * Formats milliseconds into human-readable player clock mm:ss.d
 */
export function formatDisplayTime(ms: number, includeDeciseconds = false): string {
  const clamped = Math.max(0, Math.round(ms));
  const totalSeconds = Math.floor(clamped / 1000);
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  const deciseconds = Math.floor((clamped % 1000) / 100);

  const mm = String(minutes).padStart(2, '0');
  const ss = String(seconds).padStart(2, '0');
  if (includeDeciseconds) {
    return `${mm}:${ss}.${deciseconds}`;
  }
  return `${mm}:${ss}`;
}

/**
 * Splits a lyric line text into evenly-timed words (or weighted by character length)
 * across [startMs, endMs] so every line supports smooth word-by-word karaoke highlighting.
 */
export function generateWordTimings(text: string, startMs: number, endMs: number): LyricWord[] {
  const rawWords = text
    .trim()
    .split(/\s+/)
    .filter((w) => w.length > 0);

  if (rawWords.length === 0) {
    return [];
  }

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
    return {
      text: word,
      startMs: wStart,
      endMs: wEnd,
    };
  });
}

/**
 * Parses a standard or enhanced LRC string into structured LyricLine objects.
 * Supports [mm:ss.xx] or [mm:ss.xxx] and optional Italian translation separated by " | "
 */
export function parseLrc(lrcContent: string, totalDurationMs = 180000): LyricLine[] {
  const lines = lrcContent.split(/\r?\n/);
  const parsedRaw: Array<{
    startMs: number;
    text: string;
    translationIt?: string;
  }> = [];

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
      parsedRaw.push({
        startMs,
        text: mainText,
        translationIt,
      });
    }
  }

  parsedRaw.sort((a, b) => a.startMs - b.startMs);

  return parsedRaw.map((item, idx) => {
    const nextStart =
      idx < parsedRaw.length - 1
        ? parsedRaw[idx + 1].startMs
        : Math.max(item.startMs + 4000, totalDurationMs);
    const endMs = Math.max(item.startMs + 800, Math.min(nextStart - 120, item.startMs + 6500));
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

/**
 * Serializes structured LyricLine[] back into standard .lrc format
 */
export function serializeToLrc(
  lines: LyricLine[],
  metadata?: { title?: string; artist?: string; album?: string; offsetMs?: number }
): string {
  const header: string[] = [];
  if (metadata?.title) header.push(`[ti:${metadata.title}]`);
  if (metadata?.artist) header.push(`[ar:${metadata.artist}]`);
  if (metadata?.album) header.push(`[al:${metadata.album}]`);
  if (typeof metadata?.offsetMs === 'number' && metadata.offsetMs !== 0) {
    header.push(`[offset:${metadata.offsetMs}]`);
  }
  header.push('[by:AuraSync Flutter LRC Engine]');

  const body = lines.map((line) => {
    const ts = formatLrcTimestamp(line.startMs);
    const suffix = line.translationIt ? ` | ${line.translationIt}` : '';
    return `${ts} ${line.text}${suffix}`;
  });

  return [...header, '', ...body].join('\n');
}

/**
 * Computes the exact active line, active word, and interpolation progress
 * for a given playback time and user calibration offset.
 */
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
  const lineProgress = Math.max(
    0,
    Math.min(1, (effectiveTimeMs - line.startMs) / lineDuration)
  );

  let activeWordIndex = -1;
  let wordProgress = 0;

  if (line.words && line.words.length > 0) {
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
  }

  const nextLineIndex =
    activeLineIndex + 1 < lines.length ? activeLineIndex + 1 : -1;

  return {
    activeLineIndex,
    activeWordIndex,
    lineProgress,
    wordProgress,
    effectiveTimeMs,
    nextLineIndex,
  };
}

/**
 * Calculates the real-time song position when locking onto an external room source.
 * When ACRCloud / AudD / Gemini identifies a track playing in the environment at
 * `detectedSongPositionMs` and the recognition took `networkLatencyMs`, the live
 * clock immediately jumps to `detectedSongPositionMs + networkLatencyMs + elapsedSinceMatchMs`.
 */
export function computeEnvironmentSyncPosition(params: {
  detectedSongPositionMs: number;
  networkLatencyMs: number;
  elapsedSinceMatchMs: number;
  manualPhaseOffsetMs: number;
  totalDurationMs: number;
}): number {
  const raw =
    params.detectedSongPositionMs +
    params.networkLatencyMs +
    params.elapsedSinceMatchMs +
    params.manualPhaseOffsetMs;

  if (params.totalDurationMs <= 0) return Math.max(0, raw);
  return Math.max(0, Math.min(params.totalDurationMs, raw));
}
