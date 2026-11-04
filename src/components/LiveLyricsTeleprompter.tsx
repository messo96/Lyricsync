import React, { useEffect, useRef, useState } from 'react';
import {
  Play,
  Pause,
  RotateCcw,
  Languages,
  Download,
  SlidersHorizontal,
  Edit3,
  Check,
  X,
} from 'lucide-react';
import {
  LyricLine,
  SyncState,
  formatDisplayTime,
  formatLrcTimestamp,
  serializeToLrc,
} from '../utils/lyricsEngine';
import { AmbientSong } from '../data/songsCatalog';
import { AlbumArtwork } from './AlbumArtwork';

interface LiveLyricsTeleprompterProps {
  song: AmbientSong;
  currentTimeMs: number;
  syncState: SyncState;
  isPlaying: boolean;
  manualOffsetMs: number;
  showTranslation: boolean;
  onTogglePlay: () => void;
  onSeekToMs: (ms: number) => void;
  onAdjustOffset: (deltaMs: number) => void;
  onResetOffset: () => void;
  onToggleTranslation: () => void;
  onUpdateCustomLrc: (newLrcRaw: string) => void;
  onJumpToRoomOffset: () => void;
}

export const LiveLyricsTeleprompter: React.FC<LiveLyricsTeleprompterProps> = ({
  song,
  currentTimeMs,
  syncState,
  isPlaying,
  manualOffsetMs,
  showTranslation,
  onTogglePlay,
  onSeekToMs,
  onAdjustOffset,
  onResetOffset,
  onToggleTranslation,
  onUpdateCustomLrc,
  onJumpToRoomOffset,
}) => {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const lineRefs = useRef<Record<number, HTMLButtonElement | null>>({});
  const [isEditingLrc, setIsEditingLrc] = useState(false);
  const [draftLrc, setDraftLrc] = useState(song.lrcRaw);

  useEffect(() => {
    setDraftLrc(song.lrcRaw);
  }, [song.id, song.lrcRaw]);

  // Smooth auto-scroll inside the lyrics container when activeLineIndex changes
  useEffect(() => {
    const activeIdx = syncState.activeLineIndex;
    if (activeIdx < 0 || !containerRef.current) return;
    const activeEl = lineRefs.current[activeIdx];
    if (!activeEl) return;

    const container = containerRef.current;
    const targetScrollTop =
      activeEl.offsetTop - container.clientHeight * 0.36 + activeEl.clientHeight * 0.5;

    container.scrollTo({
      top: Math.max(0, targetScrollTop),
      behavior: 'smooth',
    });
  }, [syncState.activeLineIndex]);

  const handleDownloadLrc = () => {
    const lrcContent = serializeToLrc(song.lines, {
      title: song.title,
      artist: song.artist,
      album: song.album,
      offsetMs: manualOffsetMs,
    });
    const blob = new Blob([lrcContent], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${song.title.toLowerCase().replace(/\s+/g, '_')}.lrc`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  const handleSaveCustomLrc = (e: React.FormEvent) => {
    e.preventDefault();
    if (!draftLrc.trim()) return;
    onUpdateCustomLrc(draftLrc);
    setIsEditingLrc(false);
  };

  return (
    <div className="rounded-2xl bg-slate-900/95 border border-slate-800 flex flex-col h-full overflow-hidden">
      {/* Track Header & Live Sync Clock */}
      <div className="p-5 border-b border-slate-800/90 flex flex-col gap-4">
        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="flex items-center gap-4 min-w-0">
            <AlbumArtwork
              motif={song.coverPalette.motif}
              title={song.title}
              artist={song.artist}
              accentColor={song.coverPalette.accent}
              className="w-16 h-16"
            />
            <div className="min-w-0">
              <div className="flex items-center gap-2 text-xs text-amber-400 font-medium whitespace-nowrap">
                <span>Sincronizzazione Live Attiva</span>
                <span aria-hidden="true">·</span>
                <span className="font-mono tabular-nums">Confidenza {song.confidenceScore}%</span>
              </div>
              <h1
                className="text-xl sm:text-2xl font-bold text-slate-50 truncate mt-0.5"
                data-testid="detected-song-title"
              >
                {song.title}
              </h1>
              <p className="text-sm text-slate-300 truncate" data-testid="detected-song-artist">
                {song.artist} <span aria-hidden="true" className="text-slate-600">·</span>{' '}
                <span className="text-slate-400">{song.album} ({song.releaseYear})</span>
              </p>
            </div>
          </div>

          {/* Transport & Quick Actions */}
          <div className="flex items-center gap-2 flex-wrap sm:flex-nowrap shrink-0">
            <button
              type="button"
              onClick={onTogglePlay}
              aria-label={isPlaying ? 'Metti in pausa sincronizzazione' : 'Avvia sincronizzazione'}
              className="min-h-[40px] px-4 py-2 rounded-xl bg-amber-500 hover:bg-amber-400 text-slate-950 font-semibold text-xs flex items-center gap-2 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
            >
              {isPlaying ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
              <span>{isPlaying ? 'In Sincro' : 'Riprendi'}</span>
            </button>

            <button
              type="button"
              onClick={onJumpToRoomOffset}
              title="Riallinea al punto corrente rilevato nella stanza"
              className="min-h-[40px] px-3 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700/80 text-xs font-medium flex items-center gap-1.5 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
            >
              <RotateCcw className="w-3.5 h-3.5 text-sky-400" />
              <span>Offset Stanza ({formatDisplayTime(song.defaultRoomOffsetMs)})</span>
            </button>

            <button
              type="button"
              onClick={onToggleTranslation}
              aria-pressed={showTranslation}
              className={`min-h-[40px] px-3 py-2 rounded-xl border text-xs font-medium flex items-center gap-1.5 transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                showTranslation
                  ? 'bg-sky-500/15 border-sky-500/50 text-sky-300'
                  : 'bg-slate-800/80 border-slate-700/80 text-slate-300 hover:text-white'
              }`}
            >
              <Languages className="w-3.5 h-3.5" />
              <span>Traduzione</span>
            </button>
          </div>
        </div>
      </div>

      {/* Phase / Offset Calibration Bar */}
      <div className="px-5 py-2.5 bg-slate-950/70 border-b border-slate-800/80 flex flex-wrap items-center justify-between gap-3 text-xs">
        <div className="flex items-center gap-2 text-slate-300">
          <SlidersHorizontal className="w-3.5 h-3.5 text-amber-400 shrink-0" />
          <span>Calibrazione Fase LRC:</span>
          <span
            className="font-mono tabular-nums font-semibold text-amber-300"
            data-testid="phase-offset-value"
          >
            {manualOffsetMs >= 0 ? `+${manualOffsetMs} ms` : `${manualOffsetMs} ms`}
          </span>
        </div>

        <div className="flex items-center gap-1.5 flex-wrap">
          <button
            type="button"
            onClick={() => onAdjustOffset(-500)}
            className="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 font-mono text-xs transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            -500ms
          </button>
          <button
            type="button"
            onClick={() => onAdjustOffset(-100)}
            className="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 font-mono text-xs transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            -100ms
          </button>
          <button
            type="button"
            onClick={onResetOffset}
            className="px-2.5 py-1 rounded-lg bg-slate-800/60 hover:bg-slate-700 text-slate-400 hover:text-slate-200 text-xs transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            Reset 0ms
          </button>
          <button
            type="button"
            onClick={() => onAdjustOffset(100)}
            className="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 font-mono text-xs transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            +100ms
          </button>
          <button
            type="button"
            onClick={() => onAdjustOffset(500)}
            className="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 font-mono text-xs transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            +500ms
          </button>

          <span aria-hidden="true" className="text-slate-700 mx-1">|</span>

          <button
            type="button"
            onClick={() => setIsEditingLrc(!isEditingLrc)}
            className="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 flex items-center gap-1 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            <Edit3 className="w-3 h-3" />
            <span>{isEditingLrc ? 'Chiudi Editor LRC' : 'Modifica LRC'}</span>
          </button>

          <button
            type="button"
            onClick={handleDownloadLrc}
            className="px-2.5 py-1 rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-200 flex items-center gap-1 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            <Download className="w-3 h-3" />
            <span>Esporta .LRC</span>
          </button>
        </div>
      </div>

      {/* Interactive LRC Editor Drawer or Live Synchronized Lyrics Teleprompter */}
      {isEditingLrc ? (
        <form onSubmit={handleSaveCustomLrc} className="p-5 flex-1 flex flex-col gap-3">
          <div className="flex items-center justify-between">
            <label htmlFor="lrc-editor-textarea" className="text-xs font-semibold text-slate-200">
              Editor Sorgente .LRC ([mm:ss.xx] Testo | Traduzione opzionale)
            </label>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setIsEditingLrc(false)}
                className="px-3 py-1.5 rounded-lg bg-slate-800 text-slate-300 text-xs flex items-center gap-1 cursor-pointer"
              >
                <X className="w-3.5 h-3.5" />
                <span>Annulla</span>
              </button>
              <button
                type="submit"
                className="px-3 py-1.5 rounded-lg bg-amber-500 text-slate-950 font-semibold text-xs flex items-center gap-1 cursor-pointer"
              >
                <Check className="w-3.5 h-3.5" />
                <span>Applica Sincronia</span>
              </button>
            </div>
          </div>
          <textarea
            id="lrc-editor-textarea"
            value={draftLrc}
            onChange={(e) => setDraftLrc(e.target.value)}
            rows={12}
            className="w-full flex-1 rounded-xl bg-slate-950 border border-slate-800 p-4 font-mono text-xs text-slate-200 focus:outline-none focus:border-amber-500"
          />
        </form>
      ) : (
        <div
          ref={containerRef}
          className="relative flex-1 overflow-y-auto px-6 py-8 space-y-3 max-h-[460px] min-h-[360px]"
          data-testid="lyrics-teleprompter"
        >
          {song.lines.map((line: LyricLine, idx: number) => {
            const isActive = idx === syncState.activeLineIndex;
            const isPast = idx < syncState.activeLineIndex;

            return (
              <button
                key={line.id}
                ref={(el) => {
                  lineRefs.current[idx] = el;
                }}
                type="button"
                onClick={() => onSeekToMs(line.startMs)}
                data-active={isActive ? 'true' : 'false'}
                className={`w-full text-left group rounded-2xl px-4 py-3.5 transition-all duration-200 cursor-pointer flex items-start gap-4 ${
                  isActive
                    ? 'bg-slate-800/90 border border-amber-500/40 shadow-sm'
                    : 'hover:bg-slate-800/40 border border-transparent'
                }`}
              >
                {/* Timestamp column */}
                <span
                  className={`font-mono tabular-nums text-xs mt-1.5 shrink-0 ${
                    isActive
                      ? 'text-amber-400 font-semibold'
                      : 'text-slate-500 group-hover:text-slate-300'
                  }`}
                >
                  {formatLrcTimestamp(line.startMs).replace(/[\[\]]/g, '')}
                </span>

                {/* Lyric Words + Translation + Progress */}
                <div className="flex-1 min-w-0">
                  <div
                    className={`leading-snug transition-colors duration-150 flex flex-wrap gap-x-2 gap-y-1 ${
                      isActive
                        ? 'text-xl sm:text-2xl font-bold text-slate-50'
                        : isPast
                        ? 'text-base sm:text-lg font-medium text-slate-500'
                        : 'text-base sm:text-lg font-medium text-slate-300'
                    }`}
                  >
                    {line.words.map((word, wIdx) => {
                      const isWordSung =
                        isActive && wIdx <= syncState.activeWordIndex;
                      const isCurrentWord =
                        isActive && wIdx === syncState.activeWordIndex;

                      return (
                        <span
                          key={`${line.id}-w-${wIdx}`}
                          className={`transition-colors duration-100 ${
                            isActive
                              ? isCurrentWord
                                ? 'text-amber-300 underline decoration-amber-400/70 decoration-2 underline-offset-4'
                                : isWordSung
                                ? 'text-amber-400'
                                : 'text-slate-200'
                              : ''
                          }`}
                        >
                          {word.text}
                        </span>
                      );
                    })}
                  </div>

                  {showTranslation && line.translationIt && (
                    <p
                      className={`mt-1.5 text-xs sm:text-sm ${
                        isActive ? 'text-slate-300' : 'text-slate-500'
                      }`}
                    >
                      {line.translationIt}
                    </p>
                  )}

                  {/* Active Line Syllabic Progress Bar */}
                  {isActive && (
                    <div className="mt-2.5 w-full h-1 bg-slate-950 rounded-full overflow-hidden">
                      <div
                        className="h-full bg-amber-400 transition-all duration-75"
                        style={{
                          width: `${Math.round(syncState.lineProgress * 100)}%`,
                        }}
                      />
                    </div>
                  )}
                </div>
              </button>
            );
          })}
        </div>
      )}

      {/* Interactive Timeline Scrubber Footer */}
      <div className="px-5 py-3.5 bg-slate-950 border-t border-slate-800/90 flex items-center gap-4">
        <span
          className="font-mono tabular-nums text-xs text-amber-400 font-medium w-14 shrink-0"
          data-testid="current-sync-clock"
        >
          {formatDisplayTime(syncState.effectiveTimeMs, true)}
        </span>

        <div className="flex-1 flex items-center">
          <input
            type="range"
            aria-label="Posizione temporale del brano sincronizzato"
            min={0}
            max={song.durationMs}
            step={100}
            value={Math.min(song.durationMs, Math.max(0, currentTimeMs))}
            onChange={(e) => onSeekToMs(Number(e.target.value))}
            className="w-full accent-amber-400 h-1.5 bg-slate-800 rounded-lg cursor-pointer"
          />
        </div>

        <span className="font-mono tabular-nums text-xs text-slate-400 w-12 text-right shrink-0">
          {formatDisplayTime(song.durationMs, false)}
        </span>
      </div>
    </div>
  );
};
