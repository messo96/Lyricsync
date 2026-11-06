import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  Music,
  Search,
  KeyRound,
  ChevronDown,
  RefreshCw,
  ArrowLeft,
  Languages,
  Play,
  Pause,
  SkipForward,
  Heart,
  Code2,
  Check,
  Copy,
  Sliders,
} from 'lucide-react';
import {
  CONCERT_SONGS,
  ConcertSong,
  LISTENING_ENVIRONMENTS,
  ListeningEnvOption,
} from './data/concertCatalog';
import { formatDisplayTime, getSyncStateAtTime } from './utils/lyricsEngine';
import { PulsingWaveformCanvas } from './components/PulsingWaveformCanvas';

interface FlutterSourceFile {
  id: string;
  path: string;
  title: string;
  content: string;
}

export default function App() {
  const [selectedEnv, setSelectedEnv] = useState<ListeningEnvOption>(
    LISTENING_ENVIRONMENTS[2] // Live Concert default
  );
  const [isListening, setIsListening] = useState<boolean>(false);
  const [countdownSec, setCountdownSec] = useState<number>(30);
  const [isAutoPlayEnabled, setIsAutoPlayEnabled] = useState<boolean>(false);
  const [showEnvModal, setShowEnvModal] = useState<boolean>(false);
  const [showSearchModal, setShowSearchModal] = useState<boolean>(false);
  const [showCodeDrawer, setShowCodeDrawer] = useState<boolean>(false);

  // Active Screen: 'home' | 'teleprompter'
  const [screen, setScreen] = useState<'home' | 'teleprompter'>('home');
  const [activeSongIndex, setActiveSongIndex] = useState<number>(0);
  const [currentTimeMs, setCurrentTimeMs] = useState<number>(
    CONCERT_SONGS[0].detectedPlayOffsetMs
  );
  const [manualOffsetMs, setManualOffsetMs] = useState<number>(0);
  const [isPlaying, setIsPlaying] = useState<boolean>(true);
  const [showTranslation, setShowTranslation] = useState<boolean>(true);
  const [isFavorite, setIsFavorite] = useState<boolean>(false);
  const [searchFilter, setSearchFilter] = useState<string>('');

  // Live Flutter source files from /lib
  const [flutterFiles, setFlutterFiles] = useState<FlutterSourceFile[]>([]);
  const [selectedFlutterFileId, setSelectedFlutterFileId] = useState<string>('pulsing_waveform');
  const [copiedFile, setCopiedFile] = useState<boolean>(false);

  const activeSong: ConcertSong = CONCERT_SONGS[activeSongIndex] || CONCERT_SONGS[0];

  useEffect(() => {
    fetch('/api/flutter-files')
      .then((r) => r.json())
      .then((data) => {
        if (Array.isArray(data.files)) {
          setFlutterFiles(data.files);
        }
      })
      .catch(() => {});
  }, []);

  // Continuous listening countdown & automatic song match after 3.6 seconds
  useEffect(() => {
    if (!isListening) {
      setCountdownSec(30);
      return;
    }

    const countdownInterval = window.setInterval(() => {
      setCountdownSec((prev) => (prev > 1 ? prev - 1 : 1));
    }, 1000);

    // Automatically match and open the synchronized teleprompter after a realistic 3.6s scan
    const matchTimeout = window.setTimeout(() => {
      setIsListening(false);
      setCurrentTimeMs(activeSong.detectedPlayOffsetMs);
      setManualOffsetMs(0);
      setIsPlaying(true);
      setScreen('teleprompter');
    }, 3600);

    return () => {
      clearInterval(countdownInterval);
      clearTimeout(matchTimeout);
    };
  }, [isListening, activeSong.detectedPlayOffsetMs]);

  // Real-time lyrics teleprompter clock
  const lastFrameRef = useRef<number>(performance.now());
  useEffect(() => {
    if (screen !== 'teleprompter' || !isPlaying) return;

    lastFrameRef.current = performance.now();
    const timer = window.setInterval(() => {
      const now = performance.now();
      const dt = now - lastFrameRef.current;
      lastFrameRef.current = now;
      setCurrentTimeMs((prev) => {
        const next = prev + dt;
        return next >= activeSong.durationMs ? 0 : next;
      });
    }, 50);

    return () => clearInterval(timer);
  }, [screen, isPlaying, activeSong.durationMs]);

  const syncState = useMemo(() => {
    return getSyncStateAtTime(activeSong.lines, currentTimeMs, manualOffsetMs);
  }, [activeSong.lines, currentTimeMs, manualOffsetMs]);

  const statusText = isListening
    ? `Ascolto (${countdownSec}s)... Rilevamento in corso`
    : 'Tocca per ascoltare e sincronizzare il testo';

  const filteredSongs = useMemo(() => {
    const q = searchFilter.trim().toLowerCase();
    if (!q) return CONCERT_SONGS;
    return CONCERT_SONGS.filter(
      (s) =>
        s.title.toLowerCase().includes(q) ||
        s.artist.toLowerCase().includes(q) ||
        s.rawLrc.toLowerCase().includes(q)
    );
  }, [searchFilter]);

  const activeFlutterFile =
    flutterFiles.find((f) => f.id === selectedFlutterFileId) || flutterFiles[0];

  const handleCopyFlutterCode = async () => {
    if (!activeFlutterFile) return;
    try {
      await navigator.clipboard.writeText(activeFlutterFile.content);
      setCopiedFile(true);
      setTimeout(() => setCopiedFile(false), 2000);
    } catch {
      // Ignore clipboard error
    }
  };

  return (
    <div className="min-h-screen bg-[#090C13] text-[#F8FAFC] flex flex-col">
      {/* Top AppBar matching lib/screens/home_screen.dart */}
      <header className="px-5 py-3.5 flex items-center justify-between border-b border-[#212B3E]/70 bg-[#090C13]/90 backdrop-blur-md sticky top-0 z-30">
        <div className="flex items-center gap-2.5">
          <div className="p-2 rounded-xl bg-[#F6C974]/15 text-[#F6C974]">
            <Music className="w-5 h-5" />
          </div>
          <span className="text-xl font-extrabold tracking-tight text-[#F8FAFC]">
            LyricSync
          </span>

          <button
            type="button"
            onClick={() => setShowEnvModal(true)}
            aria-label={`Ambiente di ascolto attuale: ${selectedEnv.label}. Tocca per cambiare`}
            className="ml-1 px-2.5 py-1 rounded-lg border text-[11px] font-extrabold tracking-wider flex items-center gap-1.5 transition-colors cursor-pointer"
            style={{
              backgroundColor: `${selectedEnv.badgeColor}1F`,
              borderColor: `${selectedEnv.badgeColor}73`,
              color: selectedEnv.badgeColor,
            }}
          >
            <span>{selectedEnv.shortLabel}</span>
            <ChevronDown className="w-3.5 h-3.5" />
          </button>
        </div>

        <div className="flex items-center gap-2">
          <button
            type="button"
            onClick={() => setShowCodeDrawer((v) => !v)}
            className="min-h-[40px] px-3 py-1.5 rounded-xl bg-[#111622] hover:bg-[#182030] border border-[#212B3E] text-xs font-bold text-[#2DD4BF] flex items-center gap-1.5 transition-colors cursor-pointer"
          >
            <Code2 className="w-4 h-4" />
            <span>Codice Flutter Aggiornato</span>
          </button>

          <button
            type="button"
            onClick={() => setShowSearchModal(true)}
            aria-label="Cerca canzone o testo"
            className="min-h-[40px] min-w-[40px] rounded-xl hover:bg-[#182030] flex items-center justify-center text-[#F8FAFC] transition-colors cursor-pointer"
          >
            <Search className="w-5 h-5" />
          </button>
        </div>
      </header>

      {/* Main Content */}
      {screen === 'home' ? (
        <main className="flex-1 max-w-5xl w-full mx-auto px-6 py-8 flex flex-col justify-between items-center">
          <div className="flex-1 flex flex-col items-center justify-center w-full py-6">
            {/* Upgraded Hyper-Fluid Kinetic Orb Microphone Button */}
            <PulsingWaveformCanvas
              isListening={isListening}
              statusText={statusText}
              onToggleListening={() => setIsListening((v) => !v)}
              size={276}
            />

            <p className="mt-3 text-center text-[13px] font-medium text-[#64748B]">
              {isListening
                ? 'Ascolto continuo attivo (pipeline anti-blocco 120 FPS) · Tocca per fermare'
                : 'Tocca il pulsante per ascoltare e sincronizzare il testo'}
            </p>

            {/* Quick Demo Trigger to jump straight into Teleprompter */}
            <div className="mt-6 flex flex-wrap items-center justify-center gap-2">
              {CONCERT_SONGS.map((song, idx) => (
                <button
                  key={song.id}
                  type="button"
                  onClick={() => {
                    setActiveSongIndex(idx);
                    setCurrentTimeMs(song.detectedPlayOffsetMs);
                    setManualOffsetMs(0);
                    setIsPlaying(true);
                    setScreen('teleprompter');
                  }}
                  className="px-3.5 py-2 rounded-xl bg-[#111622] hover:bg-[#182030] border border-[#212B3E] text-xs font-semibold text-[#94A3B8] hover:text-[#F8FAFC] transition-colors cursor-pointer"
                >
                  Simula Match: {song.artist} – {song.title.split(' (')[0]}
                </button>
              ))}
            </div>
          </div>

          {/* Bottom AutoPlay Concerto Card matching lib/screens/home_screen.dart */}
          <div
            className={`w-full max-w-lg rounded-2xl bg-[#111622] p-4 border transition-colors flex items-center justify-between gap-4 ${
              isAutoPlayEnabled ? 'border-[#2DD4BF]/50' : 'border-[#1E293B]'
            }`}
          >
            <div className="flex items-center gap-3.5">
              <div
                className={`p-2.5 rounded-xl ${
                  isAutoPlayEnabled
                    ? 'bg-[#2DD4BF]/15 text-[#2DD4BF]'
                    : 'bg-[#182030] text-[#64748B]'
                }`}
              >
                <RefreshCw className="w-5 h-5" />
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-sm font-bold text-[#F8FAFC]">
                    AutoPlay Concerto
                  </span>
                  {isAutoPlayEnabled && (
                    <span className="text-[10px] font-extrabold text-[#2DD4BF] tracking-wider">
                      ATTIVO
                    </span>
                  )}
                </div>
                <p className="text-xs text-[#94A3B8] mt-0.5">
                  Rileva in automatico la canzone successiva al termine
                </p>
              </div>
            </div>

            <button
              type="button"
              role="switch"
              aria-checked={isAutoPlayEnabled}
              aria-label="Attiva AutoPlay Concerto"
              onClick={() => setIsAutoPlayEnabled((v) => !v)}
              className={`w-12 h-7 rounded-full p-1 transition-colors cursor-pointer ${
                isAutoPlayEnabled ? 'bg-[#2DD4BF]' : 'bg-[#182030]'
              }`}
            >
              <div
                className={`w-5 h-5 rounded-full bg-[#090C13] transition-transform ${
                  isAutoPlayEnabled ? 'translate-x-5' : 'translate-x-0'
                }`}
              />
            </button>
          </div>
        </main>
      ) : (
        /* Live Synchronized Lyrics Teleprompter Screen */
        <main className="flex-1 max-w-5xl w-full mx-auto px-4 sm:px-6 py-5 flex flex-col gap-4">
          <div className="rounded-2xl bg-[#111622] border border-[#212B3E] p-4 flex flex-wrap items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <button
                type="button"
                onClick={() => setScreen('home')}
                aria-label="Torna alla schermata di ascolto microfono"
                className="min-h-[40px] min-w-[40px] rounded-xl bg-[#182030] hover:bg-[#212B3E] flex items-center justify-center text-[#F8FAFC] cursor-pointer"
              >
                <ArrowLeft className="w-5 h-5" />
              </button>
              <div>
                <h1 className="text-lg font-extrabold text-[#F8FAFC]">
                  {activeSong.title}
                </h1>
                <p className="text-xs text-[#94A3B8]">
                  {activeSong.artist} · {activeSong.album} ·{' '}
                  <span className="font-mono tabular-nums text-[#F6C974]">
                    {formatDisplayTime(syncState.effectiveTimeMs)} /{' '}
                    {formatDisplayTime(activeSong.durationMs)}
                  </span>
                </p>
              </div>
            </div>

            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => setShowTranslation((v) => !v)}
                aria-label="Mostra o nascondi traduzione italiana"
                className={`min-h-[40px] px-3 py-1.5 rounded-xl border text-xs font-bold flex items-center gap-1.5 cursor-pointer ${
                  showTranslation
                    ? 'bg-[#2DD4BF]/15 border-[#2DD4BF]/50 text-[#2DD4BF]'
                    : 'bg-[#182030] border-[#212B3E] text-[#94A3B8]'
                }`}
              >
                <Languages className="w-4 h-4" />
                <span>Traduzione IT</span>
              </button>

              <button
                type="button"
                onClick={() => setIsPlaying((p) => !p)}
                aria-label={isPlaying ? 'Pausa' : 'Riprendi'}
                className="min-h-[40px] px-3.5 py-1.5 rounded-xl bg-[#F6C974] text-[#090C13] text-xs font-extrabold flex items-center gap-1.5 cursor-pointer"
              >
                {isPlaying ? <Pause className="w-4 h-4" /> : <Play className="w-4 h-4" />}
                <span>{isPlaying ? 'In Sincro' : 'Pausa'}</span>
              </button>

              <button
                type="button"
                onClick={() =>
                  setActiveSongIndex((i) => (i + 1) % CONCERT_SONGS.length)
                }
                aria-label="Brano successivo"
                className="min-h-[40px] min-w-[40px] rounded-xl bg-[#182030] hover:bg-[#212B3E] text-[#2DD4BF] flex items-center justify-center cursor-pointer"
              >
                <SkipForward className="w-4 h-4" />
              </button>

              <button
                type="button"
                onClick={() => setIsFavorite((f) => !f)}
                aria-label="Salva nei preferiti"
                className="min-h-[40px] min-w-[40px] rounded-xl bg-[#182030] hover:bg-[#212B3E] flex items-center justify-center cursor-pointer"
              >
                <Heart
                  className={`w-4 h-4 ${
                    isFavorite ? 'fill-rose-500 text-rose-500' : 'text-[#94A3B8]'
                  }`}
                />
              </button>
            </div>
          </div>

          {/* Synchronized Lyrics List */}
          <div className="flex-1 rounded-2xl bg-[#111622]/90 border border-[#212B3E] p-6 space-y-4 overflow-y-auto max-h-[520px]">
            {activeSong.lines.map((line, idx) => {
              const isActive = idx === syncState.activeLineIndex;
              const isPast = idx < syncState.activeLineIndex;

              return (
                <button
                  key={line.id}
                  type="button"
                  onClick={() => setCurrentTimeMs(line.startMs)}
                  className={`w-full text-left p-4 rounded-2xl transition-all cursor-pointer ${
                    isActive
                      ? 'bg-[#182030] border border-[#2DD4BF]/45'
                      : 'hover:bg-[#182030]/40 border border-transparent'
                  }`}
                >
                  <div
                    className={`flex flex-wrap gap-x-2 gap-y-1 leading-snug ${
                      isActive
                        ? 'text-2xl font-extrabold text-[#FFFBEB]'
                        : isPast
                        ? 'text-lg font-semibold text-[#64748B]'
                        : 'text-lg font-semibold text-[#94A3B8]'
                    }`}
                  >
                    {line.words.map((w, wIdx) => {
                      const isWordSung = isActive && wIdx <= syncState.activeWordIndex;
                      return (
                        <span
                          key={`${line.id}-${wIdx}`}
                          className={isWordSung ? 'text-[#2DD4BF]' : ''}
                        >
                          {w.text}
                        </span>
                      );
                    })}
                  </div>
                  {showTranslation && line.translationIt && (
                    <p
                      className={`mt-1.5 text-sm font-medium ${
                        isActive ? 'text-[#F6C974]' : 'text-[#64748B]'
                      }`}
                    >
                      {line.translationIt}
                    </p>
                  )}
                </button>
              );
            })}
          </div>

          {/* Bottom Delay Adjuster Bar matching lib/widgets/delay_adjuster_bar.dart */}
          <div className="rounded-2xl bg-[#111622] border border-[#212B3E] px-4 py-3 flex flex-wrap items-center justify-between gap-3 text-xs">
            <div className="flex items-center gap-2 text-[#94A3B8]">
              <Sliders className="w-4 h-4 text-[#2DD4BF]" />
              <span>Calibrazione Sincronia Palco:</span>
              <span className="font-mono tabular-nums font-bold text-[#F6C974]">
                {manualOffsetMs >= 0 ? `+${manualOffsetMs} ms` : `${manualOffsetMs} ms`}
              </span>
            </div>
            <div className="flex items-center gap-1.5">
              <button
                type="button"
                onClick={() => setManualOffsetMs((o) => o - 250)}
                className="px-3 py-1.5 rounded-lg bg-[#182030] hover:bg-[#212B3E] font-mono text-[#F8FAFC] cursor-pointer"
              >
                -250ms
              </button>
              <button
                type="button"
                onClick={() => setManualOffsetMs(0)}
                className="px-3 py-1.5 rounded-lg bg-[#182030] hover:bg-[#212B3E] text-[#94A3B8] cursor-pointer"
              >
                Reset
              </button>
              <button
                type="button"
                onClick={() => setManualOffsetMs((o) => o + 250)}
                className="px-3 py-1.5 rounded-lg bg-[#182030] hover:bg-[#212B3E] font-mono text-[#F8FAFC] cursor-pointer"
              >
                +250ms
              </button>
            </div>
          </div>
        </main>
      )}

      {/* Flutter Source Code Drawer */}
      {showCodeDrawer && (
        <section
          aria-label="Codice sorgente Flutter aggiornato"
          className="max-w-5xl w-full mx-auto px-6 pb-10"
        >
          <div className="rounded-2xl bg-[#111622] border border-[#212B3E] overflow-hidden">
            <div className="p-4 border-b border-[#212B3E] flex flex-wrap items-center justify-between gap-3">
              <div className="flex flex-wrap items-center gap-2">
                {flutterFiles.map((f) => (
                  <button
                    key={f.id}
                    type="button"
                    onClick={() => setSelectedFlutterFileId(f.id)}
                    className={`px-3 py-1.5 rounded-lg text-xs font-mono font-semibold cursor-pointer ${
                      selectedFlutterFileId === f.id
                        ? 'bg-[#2DD4BF] text-[#090C13]'
                        : 'bg-[#182030] text-[#94A3B8] hover:text-white'
                    }`}
                  >
                    {f.path}
                  </button>
                ))}
              </div>
              <button
                type="button"
                onClick={handleCopyFlutterCode}
                className="px-3 py-1.5 rounded-lg bg-[#182030] hover:bg-[#212B3E] text-xs font-semibold text-[#F8FAFC] flex items-center gap-1.5 cursor-pointer"
              >
                {copiedFile ? (
                  <>
                    <Check className="w-3.5 h-3.5 text-[#10B981]" />
                    <span>Copiato</span>
                  </>
                ) : (
                  <>
                    <Copy className="w-3.5 h-3.5" />
                    <span>Copia Codice Dart</span>
                  </>
                )}
              </button>
            </div>
            <pre className="p-4 bg-[#090C13] font-mono text-xs text-[#E2E8F0] overflow-x-auto max-h-[420px]">
              <code>{activeFlutterFile?.content || '// Caricamento file Dart...'}</code>
            </pre>
          </div>
        </section>
      )}

      {/* Environment Selection Bottom Sheet Modal */}
      {showEnvModal && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="Ambiente di Ascolto"
          className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-end sm:items-center justify-center p-4"
        >
          <div className="w-full max-w-md rounded-3xl bg-[#111622] border border-[#212B3E] p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-extrabold text-[#F8FAFC]">
                Ambiente di Ascolto
              </h2>
              <button
                type="button"
                onClick={() => setShowEnvModal(false)}
                className="text-xs text-[#94A3B8] hover:text-white cursor-pointer"
              >
                Chiudi
              </button>
            </div>
            <p className="text-xs text-[#94A3B8]">
              Calibra tempo di registrazione, filtri acustici e latenza del microfono:
            </p>
            <div className="space-y-2.5">
              {LISTENING_ENVIRONMENTS.map((env) => {
                const isSelected = env.id === selectedEnv.id;
                return (
                  <button
                    key={env.id}
                    type="button"
                    onClick={() => {
                      setSelectedEnv(env);
                      setShowEnvModal(false);
                    }}
                    className={`w-full text-left p-3.5 rounded-2xl border transition-colors cursor-pointer ${
                      isSelected
                        ? 'bg-[#182030] border-[#2DD4BF]'
                        : 'bg-[#182030]/60 border-[#212B3E]'
                    }`}
                  >
                    <div className="flex items-center justify-between">
                      <span className="text-sm font-bold text-[#F8FAFC]">
                        {env.label}
                      </span>
                      <span
                        className="text-[11px] font-mono font-bold"
                        style={{ color: env.badgeColor }}
                      >
                        {(env.sampleDurationMs / 1000).toFixed(1)}s
                      </span>
                    </div>
                    <p className="text-xs text-[#64748B] mt-1">{env.description}</p>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      )}

      {/* Search Modal */}
      {showSearchModal && (
        <div
          role="dialog"
          aria-modal="true"
          aria-label="Cerca canzone manualmente"
          className="fixed inset-0 z-50 bg-black/70 backdrop-blur-sm flex items-center justify-center p-4"
        >
          <div className="w-full max-w-lg rounded-3xl bg-[#111622] border border-[#212B3E] p-6 space-y-4">
            <div className="flex items-center justify-between">
              <h2 className="text-lg font-extrabold text-[#F8FAFC]">
                Cerca Canzone o Scaletta Concerto
              </h2>
              <button
                type="button"
                onClick={() => setShowSearchModal(false)}
                className="text-xs text-[#94A3B8] hover:text-white cursor-pointer"
              >
                Chiudi
              </button>
            </div>
            <input
              type="text"
              value={searchFilter}
              onChange={(e) => setSearchFilter(e.target.value)}
              placeholder="Cerca Coldplay, Oasis, Queen..."
              aria-label="Filtra brani per titolo o artista"
              className="w-full px-4 py-2.5 rounded-xl bg-[#090C13] border border-[#212B3E] text-sm text-[#F8FAFC] focus:outline-none focus:border-[#2DD4BF]"
            />
            <div className="space-y-2 max-h-64 overflow-y-auto">
              {filteredSongs.map((song) => {
                const idx = CONCERT_SONGS.findIndex((s) => s.id === song.id);
                return (
                  <button
                    key={song.id}
                    type="button"
                    onClick={() => {
                      setActiveSongIndex(idx >= 0 ? idx : 0);
                      setCurrentTimeMs(song.detectedPlayOffsetMs);
                      setManualOffsetMs(0);
                      setIsPlaying(true);
                      setShowSearchModal(false);
                      setScreen('teleprompter');
                    }}
                    className="w-full text-left p-3 rounded-xl bg-[#182030] hover:bg-[#212B3E] flex items-center justify-between cursor-pointer"
                  >
                    <div>
                      <p className="text-sm font-bold text-[#F8FAFC]">{song.title}</p>
                      <p className="text-xs text-[#94A3B8]">
                        {song.artist} · {song.album}
                      </p>
                    </div>
                    <span className="text-xs font-mono text-[#2DD4BF]">
                      Sincronizza
                    </span>
                  </button>
                );
              })}
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
