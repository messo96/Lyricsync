/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useEffect, useMemo, useRef, useState } from 'react';
import {
  Search,
  History,
  Trash2,
  Clock,
  Sliders,
  Code2,
  Music2,
  AlertCircle,
} from 'lucide-react';
import {
  AMBIENT_ENVIRONMENTS,
  AmbientEnvironmentPreset,
  AmbientSong,
  SONGS_CATALOG,
} from './data/songsCatalog';
import {
  formatDisplayTime,
  getSyncStateAtTime,
  parseLrc,
} from './utils/lyricsEngine';
import { soundEngine } from './utils/soundSynth';
import { AcousticVisualizer } from './components/AcousticVisualizer';
import { LiveLyricsTeleprompter } from './components/LiveLyricsTeleprompter';
import { FlutterCodeStudio } from './components/FlutterCodeStudio';
import { AlbumArtwork } from './components/AlbumArtwork';

interface RecognitionHistoryItem {
  id: string;
  songId: string;
  title: string;
  artist: string;
  environmentLabel: string;
  detectedOffsetMs: number;
  matchedAtFormatted: string;
}

const HISTORY_STORAGE_KEY = 'aurasync_recognition_history_v1';

export default function App() {
  const [songs, setSongs] = useState<AmbientSong[]>(SONGS_CATALOG);
  const [selectedEnvId, setSelectedEnvId] = useState<string>(AMBIENT_ENVIRONMENTS[0].id);
  const [activeSongId, setActiveSongId] = useState<string>(SONGS_CATALOG[0].id);

  // Playback & Real-time synchronization clock
  const [currentTimeMs, setCurrentTimeMs] = useState<number>(
    SONGS_CATALOG[0].defaultRoomOffsetMs
  );
  const [isPlaying, setIsPlaying] = useState<boolean>(true);
  const [manualOffsetMs, setManualOffsetMs] = useState<number>(0);
  const [showTranslation, setShowTranslation] = useState<boolean>(true);
  const [isMuted, setIsMuted] = useState<boolean>(true);

  // Ambient detection state
  const [isListening, setIsListening] = useState<boolean>(false);
  const [isRecordingMic, setIsRecordingMic] = useState<boolean>(false);
  const [listenProgress, setListenProgress] = useState<number>(0);
  const [listenStepLabel, setListenStepLabel] = useState<string>(
    'In attesa di scansione acustica'
  );

  // Search / Custom Song Identifier form state
  const [searchQuery, setSearchQuery] = useState<string>('');
  const [searchError, setSearchError] = useState<string | null>(null);
  const [isSearchingApi, setIsSearchingApi] = useState<boolean>(false);

  // Active workspace view tab on mobile/desktop quick jump
  const [activeTab, setActiveTab] = useState<'live' | 'flutter'>('live');

  // Recognition History
  const [history, setHistory] = useState<RecognitionHistoryItem[]>(() => {
    try {
      const saved = localStorage.getItem(HISTORY_STORAGE_KEY);
      if (saved) {
        const parsed = JSON.parse(saved);
        if (Array.isArray(parsed) && parsed.length > 0) return parsed;
      }
    } catch {
      // Ignore storage errors
    }
    return [
      {
        id: 'hist-initial-1',
        songId: 'luci-di-brera',
        title: 'Luci di Brera',
        artist: 'Cosmo & Vettori',
        environmentLabel: 'Locale sui Navigli (Milano)',
        detectedOffsetMs: 18200,
        matchedAtFormatted: 'Oggi, 21:42',
      },
      {
        id: 'hist-initial-2',
        songId: 'solaris-midnight',
        title: 'Solaris (Midnight Edit)',
        artist: 'Kiasmos & Aura',
        environmentLabel: 'Autoradio FM in Movimento',
        detectedOffsetMs: 27500,
        matchedAtFormatted: 'Oggi, 20:15',
      },
    ];
  });

  useEffect(() => {
    try {
      localStorage.setItem(HISTORY_STORAGE_KEY, JSON.stringify(history));
    } catch {
      // Ignore storage errors
    }
  }, [history]);

  const activeSong: AmbientSong = useMemo(() => {
    return songs.find((s) => s.id === activeSongId) || songs[0];
  }, [songs, activeSongId]);

  const selectedEnv: AmbientEnvironmentPreset = useMemo(() => {
    return (
      AMBIENT_ENVIRONMENTS.find((env) => env.id === selectedEnvId) ||
      AMBIENT_ENVIRONMENTS[0]
    );
  }, [selectedEnvId]);

  // High-precision 50ms ticker for real-time lyric synchronization
  const lastTickRef = useRef<number>(performance.now());

  useEffect(() => {
    if (!isPlaying || isListening) return;

    lastTickRef.current = performance.now();
    const timer = window.setInterval(() => {
      const now = performance.now();
      const delta = now - lastTickRef.current;
      lastTickRef.current = now;

      setCurrentTimeMs((prev) => {
        const next = prev + delta;
        if (next >= activeSong.durationMs) {
          return 0; // Loop smoothly for continuous live demo
        }
        return next;
      });
    }, 60);

    return () => clearInterval(timer);
  }, [isPlaying, isListening, activeSong.durationMs]);

  // Compute active line and word state
  const syncState = useMemo(() => {
    return getSyncStateAtTime(activeSong.lines, currentTimeMs, manualOffsetMs);
  }, [activeSong.lines, currentTimeMs, manualOffsetMs]);

  // Handle Web Audio API ambient synthesizer state
  const handleToggleMute = () => {
    const nextMuted = !isMuted;
    setIsMuted(nextMuted);
    soundEngine.setMuted(nextMuted);
    if (!nextMuted && isPlaying) {
      soundEngine.startAmbientTrack(activeSong.chordProgressionFreqs, activeSong.bpm);
    } else if (nextMuted) {
      soundEngine.stop();
    }
  };

  // Select a preset acoustic room environment & immediately lock onto its song & timestamp
  const handleSelectEnvironment = (env: AmbientEnvironmentPreset) => {
    setSelectedEnvId(env.id);
    const targetSong = songs.find((s) => s.id === env.defaultSongId) || songs[0];
    setActiveSongId(targetSong.id);
    setCurrentTimeMs(env.simulatedRoomOffsetMs);
    setManualOffsetMs(0);
    setIsPlaying(true);

    if (!isMuted) {
      soundEngine.startAmbientTrack(targetSong.chordProgressionFreqs, targetSong.bpm);
    }
  };

  // Perform full ambient acoustic scan & lock lyrics to external timestamp
  const handleStartAmbientScan = () => {
    if (isListening || isRecordingMic) return;
    setIsListening(true);
    setListenProgress(8);
    setListenStepLabel('Cattura spettro acustico ambientale (44.1 kHz)...');

    const step1 = window.setTimeout(() => {
      setListenProgress(45);
      setListenStepLabel('Estrazione impronta FFT e filtraggio rumore stanza...');
    }, 350);

    const step2 = window.setTimeout(() => {
      setListenProgress(82);
      setListenStepLabel('Match database acustico + calcolo play_offset_ms...');
    }, 750);

    const step3 = window.setTimeout(() => {
      setListenProgress(100);
      setIsListening(false);

      // Cycle to the environment's song or next song in catalog for rich testing
      const currentIdx = songs.findIndex((s) => s.id === activeSong.id);
      const nextSong = songs[(currentIdx + 1) % songs.length] || songs[0];
      const matchedEnv =
        AMBIENT_ENVIRONMENTS.find((e) => e.defaultSongId === nextSong.id) ||
        selectedEnv;

      setSelectedEnvId(matchedEnv.id);
      setActiveSongId(nextSong.id);
      const compensatedOffset =
        nextSong.defaultRoomOffsetMs + matchedEnv.simulatedLatencyMs;
      setCurrentTimeMs(compensatedOffset);
      setManualOffsetMs(0);
      setIsPlaying(true);

      const nowStr = new Date().toLocaleTimeString('it-IT', {
        hour: '2-digit',
        minute: '2-digit',
      });

      setHistory((prev) => [
        {
          id: `hist-${Date.now()}`,
          songId: nextSong.id,
          title: nextSong.title,
          artist: nextSong.artist,
          environmentLabel: matchedEnv.label,
          detectedOffsetMs: compensatedOffset,
          matchedAtFormatted: `Oggi, ${nowStr}`,
        },
        ...prev.slice(0, 9),
      ]);

      if (!isMuted) {
        soundEngine.startAmbientTrack(nextSong.chordProgressionFreqs, nextSong.bpm);
      }
    }, 1150);

    return () => {
      clearTimeout(step1);
      clearTimeout(step2);
      clearTimeout(step3);
    };
  };

  // Real Microphone capture + Server-side Gemini recognition
  const handleRecordRealMic = async () => {
    if (isListening || isRecordingMic) return;
    setSearchError(null);
    setIsRecordingMic(true);
    setListenProgress(15);
    setListenStepLabel('Ascolto dal microfono del dispositivo...');

    try {
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        throw new Error('Microfono non disponibile in questo browser');
      }

      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const mediaRecorder = new MediaRecorder(stream);
      const chunks: BlobPart[] = [];

      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) chunks.push(e.data);
      };

      const progressTimer = window.setInterval(() => {
        setListenProgress((p) => Math.min(92, p + 18));
      }, 450);

      mediaRecorder.onstop = async () => {
        clearInterval(progressTimer);
        stream.getTracks().forEach((t) => t.stop());
        setListenStepLabel('Invio impronta audio a Gemini API per riconoscimento...');

        try {
          const blob = new Blob(chunks, { type: mediaRecorder.mimeType || 'audio/webm' });
          const reader = new FileReader();
          reader.onloadend = async () => {
            const base64Data = String(reader.result || '').split(',')[1] || '';
            const res = await fetch('/api/recognize-audio', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({
                audioBase64: base64Data,
                mimeType: blob.type || 'audio/webm',
              }),
            });

            if (res.ok) {
              const data = await res.json();
              if (data.title && data.lrcRaw) {
                const newSongId = `mic-${Date.now()}`;
                const durationMs = 60000;
                const customSong: AmbientSong = {
                  id: newSongId,
                  title: data.title,
                  artist: data.artist || 'Artista Rilevato',
                  album: data.album || 'Rilevamento Microfono Live',
                  releaseYear: data.releaseYear || 2026,
                  bpm: data.bpm || 120,
                  musicalKey: data.musicalKey || 'Do min (Cm)',
                  durationMs,
                  defaultRoomOffsetMs: data.detectedRoomOffsetMs || 12000,
                  confidenceScore: 98.9,
                  acousticEnvironment: 'Microfono Dispositivo · Analisi Gemini Live',
                  coverPalette: {
                    primary: '#0f172a',
                    secondary: '#1e293b',
                    accent: '#38bdf8',
                    motif: 'custom',
                  },
                  chordProgressionFreqs: SONGS_CATALOG[0].chordProgressionFreqs,
                  lrcRaw: data.lrcRaw,
                  lines: parseLrc(data.lrcRaw, durationMs),
                };

                setSongs((prev) => [customSong, ...prev]);
                setActiveSongId(customSong.id);
                setCurrentTimeMs(customSong.defaultRoomOffsetMs);
                setIsPlaying(true);
              }
            }
            setIsRecordingMic(false);
            setListenProgress(0);
          };
          reader.readAsDataURL(blob);
        } catch {
          setIsRecordingMic(false);
          setListenProgress(0);
        }
      };

      mediaRecorder.start();
      setTimeout(() => {
        if (mediaRecorder.state === 'recording') {
          mediaRecorder.stop();
        }
      }, 2400);
    } catch {
      // Graceful fallback to simulated room scan if user denies mic or in headless mode
      setIsRecordingMic(false);
      handleStartAmbientScan();
    }
  };

  // Search / Identify any song by title, artist, or sung lyrics via Server-Side Gemini API
  const handleIdentifyByQuery = async (e: React.FormEvent) => {
    e.preventDefault();
    const trimmed = searchQuery.trim();
    if (!trimmed) {
      setSearchError('Inserisci il titolo di una canzone, un artista o una frase del testo.');
      return;
    }

    setSearchError(null);
    setIsSearchingApi(true);

    try {
      const response = await fetch('/api/identify-by-query', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ query: trimmed }),
      });

      const data = await response.json();
      if (!response.ok) {
        setSearchError(data.error || 'Impossibile identificare il brano richiesto.');
        setIsSearchingApi(false);
        return;
      }

      const durationMs = 60000;
      const parsedLines = parseLrc(data.lrcRaw || '', durationMs);
      const newSongId = `custom-${Date.now()}`;
      const detectedOffset =
        typeof data.detectedRoomOffsetMs === 'number' ? data.detectedRoomOffsetMs : 13800;

      const newSong: AmbientSong = {
        id: newSongId,
        title: data.title || trimmed,
        artist: data.artist || 'Artista Rilevato',
        album: data.album || 'Sessione Live',
        releaseYear: data.releaseYear || 2026,
        bpm: data.bpm || 120,
        musicalKey: data.musicalKey || 'La min (Am)',
        durationMs,
        defaultRoomOffsetMs: detectedOffset,
        confidenceScore: 99.2,
        acousticEnvironment: 'Ricerca Acustica & Sincronizzazione LRC',
        coverPalette: {
          primary: '#0f172a',
          secondary: '#1e293b',
          accent: '#f59e0b',
          motif: 'custom',
        },
        chordProgressionFreqs: SONGS_CATALOG[1].chordProgressionFreqs,
        lrcRaw: data.lrcRaw,
        lines: parsedLines.length > 0 ? parsedLines : SONGS_CATALOG[0].lines,
      };

      setSongs((prev) => [newSong, ...prev]);
      setActiveSongId(newSong.id);
      setCurrentTimeMs(detectedOffset);
      setManualOffsetMs(0);
      setIsPlaying(true);
      setSearchQuery('');

      const nowStr = new Date().toLocaleTimeString('it-IT', {
        hour: '2-digit',
        minute: '2-digit',
      });

      setHistory((prev) => [
        {
          id: `hist-${Date.now()}`,
          songId: newSong.id,
          title: newSong.title,
          artist: newSong.artist,
          environmentLabel: 'Riconoscimento Diretto / LRC Cloud',
          detectedOffsetMs: detectedOffset,
          matchedAtFormatted: `Oggi, ${nowStr}`,
        },
        ...prev.slice(0, 9),
      ]);
    } catch {
      setSearchError('Errore di connessione durante la generazione del testo sincronizzato.');
    } finally {
      setIsSearchingApi(false);
    }
  };

  const handleUpdateCustomLrc = (newLrcRaw: string) => {
    const updatedLines = parseLrc(newLrcRaw, activeSong.durationMs);
    if (updatedLines.length === 0) return;

    setSongs((prev) =>
      prev.map((s) =>
        s.id === activeSong.id
          ? {
              ...s,
              lrcRaw: newLrcRaw,
              lines: updatedLines,
            }
          : s
      )
    );
  };

  const handleDeleteHistoryItem = (id: string) => {
    setHistory((prev) => prev.filter((item) => item.id !== id));
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 flex flex-col">
      {/* Strict 3-Zone Top Bar Contract */}
      <header className="sticky top-0 z-30 bg-slate-950/90 backdrop-blur-md border-b border-slate-800/90 px-4 sm:px-8 py-3.5 flex items-center justify-between gap-8">
        {/* Zone 1: Single text element wordmark */}
        <a
          href="#top"
          className="text-lg font-bold tracking-tight text-slate-50 whitespace-nowrap shrink-0"
        >
          AuraSync Flutter
        </a>

        {/* Zone 2: 4 concise single-line navigation links */}
        <nav
          aria-label="Navigazione principale"
          className="hidden md:flex items-center gap-6 text-sm font-medium text-slate-300"
        >
          <a
            href="#live-workspace"
            onClick={() => setActiveTab('live')}
            className="hover:text-amber-400 transition-colors whitespace-nowrap shrink-0"
          >
            Sincronia Live
          </a>
          <a
            href="#ambient-presets"
            onClick={() => setActiveTab('live')}
            className="hover:text-amber-400 transition-colors whitespace-nowrap shrink-0"
          >
            Ambienti Acustici
          </a>
          <a
            href="#recognition-history"
            onClick={() => setActiveTab('live')}
            className="hover:text-amber-400 transition-colors whitespace-nowrap shrink-0"
          >
            Cronologia
          </a>
          <a
            href="#flutter-architecture"
            onClick={() => setActiveTab('flutter')}
            className="hover:text-amber-400 transition-colors whitespace-nowrap shrink-0"
          >
            Codice Flutter
          </a>
        </nav>

        {/* Zone 3: 1 primary action */}
        <div className="flex items-center gap-3 shrink-0">
          <button
            type="button"
            onClick={handleStartAmbientScan}
            disabled={isListening}
            className="min-h-[40px] px-4 py-2 text-xs font-semibold text-slate-950 bg-amber-500 hover:bg-amber-400 rounded-xl transition-colors whitespace-nowrap shrink-0 cursor-pointer"
          >
            {isListening ? 'Ascolto in corso...' : 'Rileva Canzone'}
          </button>
        </div>
      </header>

      {/* Main Content Container */}
      <main id="top" className="flex-1 max-w-7xl w-full mx-auto px-4 sm:px-6 lg:px-8 py-6 space-y-10">
        {/* Workspace Mode Switcher & Intro Bar */}
        <div className="flex flex-col md:flex-row md:items-end justify-between gap-4 pb-2 border-b border-slate-800/80">
          <div>
            <p className="text-xs font-medium text-amber-400">
              Riconoscimento Musicale Ambientale · Allineamento Testi LRC in Tempo Reale
            </p>
            <h2
              className="text-2xl sm:text-3xl font-bold text-slate-50 tracking-tight mt-1"
              style={{ textWrap: 'balance' }}
            >
              Ascolta l’ambiente esterno e sincronizza ogni parola sul battito
            </h2>
          </div>

          {/* Functional Segmented Control for Live Prototype vs Flutter Dart Code */}
          <div
            role="tablist"
            aria-label="Modalità di visualizzazione"
            className="flex items-center gap-1 p-1 bg-slate-900 border border-slate-800 rounded-xl self-start md:self-auto shrink-0"
          >
            <button
              type="button"
              role="tab"
              aria-selected={activeTab === 'live'}
              onClick={() => setActiveTab('live')}
              className={`min-h-[38px] px-3.5 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-2 transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                activeTab === 'live'
                  ? 'bg-amber-500 text-slate-950'
                  : 'text-slate-300 hover:text-white'
              }`}
            >
              <Music2 className="w-3.5 h-3.5" />
              <span>Simulatore & Testi Live</span>
            </button>
            <button
              type="button"
              role="tab"
              aria-selected={activeTab === 'flutter'}
              onClick={() => setActiveTab('flutter')}
              className={`min-h-[38px] px-3.5 py-1.5 rounded-lg text-xs font-semibold flex items-center gap-2 transition-colors whitespace-nowrap shrink-0 cursor-pointer ${
                activeTab === 'flutter'
                  ? 'bg-amber-500 text-slate-950'
                  : 'text-slate-300 hover:text-white'
              }`}
            >
              <Code2 className="w-3.5 h-3.5" />
              <span>Progetto Flutter (.dart)</span>
            </button>
          </div>
        </div>

        {/* Primary 12-Column Interactive Split Workspace */}
        {activeTab === 'live' && (
          <section
            id="live-workspace"
            className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-stretch"
          >
            {/* Left Column (5 cols): Acoustic Sensor, Search/Identify, Room Scenarios & History */}
            <div className="lg:col-span-5 flex flex-col gap-5">
              <AcousticVisualizer
                isListening={isListening}
                isPlaying={isPlaying}
                listenStepLabel={listenStepLabel}
                listenProgress={listenProgress}
                isMuted={isMuted}
                onToggleMute={handleToggleMute}
                onStartAmbientScan={handleStartAmbientScan}
                onRecordRealMic={handleRecordRealMic}
                isRecordingMic={isRecordingMic}
                noiseFloorDb={selectedEnv.noiseFloorDb}
                bpm={activeSong.bpm}
                musicalKey={activeSong.musicalKey}
              />

              {/* Identify Any Song or Lyric Snippet via Server-Side Gemini API */}
              <div className="rounded-2xl bg-slate-900/90 border border-slate-800 p-5">
                <h3 className="text-sm font-semibold text-slate-100">
                  Identifica o Simula Qualsiasi Canzone
                </h3>
                <p className="text-xs text-slate-400 mt-0.5">
                  Scrivi un titolo, un artista o un verso che stai ascoltando per generare e agganciare il testo sincronizzato.
                </p>

                <form onSubmit={handleIdentifyByQuery} className="mt-3 space-y-2.5" noValidate>
                  <div className="flex items-center gap-2">
                    <label htmlFor="song-query-input" className="sr-only">
                      Titolo canzone, artista o testo
                    </label>
                    <div className="relative flex-1">
                      <Search className="w-4 h-4 text-slate-400 absolute left-3.5 top-1/2 -translate-y-1/2 pointer-events-none" />
                      <input
                        id="song-query-input"
                        type="text"
                        value={searchQuery}
                        onChange={(e) => {
                          setSearchQuery(e.target.value);
                          if (searchError) setSearchError(null);
                        }}
                        placeholder="Es. Blinding Lights - The Weeknd..."
                        className="w-full min-h-[42px] pl-10 pr-3 py-2 rounded-xl bg-slate-950 border border-slate-800 text-xs text-slate-100 placeholder:text-slate-500 focus:outline-none focus:border-amber-500"
                      />
                    </div>
                    <button
                      type="submit"
                      disabled={isSearchingApi}
                      className="min-h-[42px] px-4 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 disabled:opacity-60 text-slate-100 border border-slate-700 text-xs font-semibold transition-colors whitespace-nowrap shrink-0 cursor-pointer"
                    >
                      {isSearchingApi ? 'Sincro...' : 'Sincronizza'}
                    </button>
                  </div>

                  {searchError && (
                    <div
                      role="alert"
                      className="flex items-center gap-2 text-xs text-rose-400 bg-rose-950/40 border border-rose-800/50 rounded-xl px-3 py-2"
                    >
                      <AlertCircle className="w-4 h-4 shrink-0" />
                      <span>{searchError}</span>
                    </div>
                  )}
                </form>
              </div>

              {/* Ambient Acoustic Scenarios (Simulates External Room Environments) */}
              <div
                id="ambient-presets"
                className="rounded-2xl bg-slate-900/90 border border-slate-800 p-5 space-y-3"
              >
                <div className="flex items-center justify-between">
                  <h3 className="text-sm font-semibold text-slate-100">
                    Scenari Acustici Esterni (Test Offset)
                  </h3>
                  <span className="text-xs text-slate-400 font-mono tabular-nums">
                    4 Ambienti
                  </span>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                  {AMBIENT_ENVIRONMENTS.map((env) => {
                    const isSelected = env.id === selectedEnvId;
                    return (
                      <button
                        key={env.id}
                        type="button"
                        onClick={() => handleSelectEnvironment(env)}
                        className={`text-left p-3 rounded-xl border transition-all cursor-pointer ${
                          isSelected
                            ? 'bg-slate-800/95 border-amber-500/50 text-slate-50'
                            : 'bg-slate-950/60 border-slate-800/80 text-slate-300 hover:border-slate-700'
                        }`}
                      >
                        <div className="flex items-center justify-between gap-2">
                          <span className="text-xs font-semibold truncate">
                            {env.label}
                          </span>
                          <span className="font-mono tabular-nums text-[11px] text-amber-400 shrink-0">
                            @{formatDisplayTime(env.simulatedRoomOffsetMs)}
                          </span>
                        </div>
                        <p className="text-[11px] text-slate-400 mt-1 line-clamp-2">
                          {env.description}
                        </p>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Recognition History List */}
              <div
                id="recognition-history"
                className="rounded-2xl bg-slate-900/90 border border-slate-800 p-5 space-y-3"
              >
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <History className="w-4 h-4 text-amber-400" />
                    <h3 className="text-sm font-semibold text-slate-100">
                      Brani Rilevati di Recente
                    </h3>
                  </div>
                  <span
                    className="text-xs text-slate-400 font-mono tabular-nums"
                    data-testid="history-count"
                  >
                    {history.length} rilevamenti
                  </span>
                </div>

                {history.length === 0 ? (
                  <p className="text-xs text-slate-500 py-4 text-center">
                    Nessun brano in cronologia. Premi &ldquo;Rileva Canzone&rdquo; per iniziare.
                  </p>
                ) : (
                  <div className="divide-y divide-slate-800/70">
                    {history.slice(0, 4).map((item) => {
                      const matchedSong =
                        songs.find((s) => s.id === item.songId) || SONGS_CATALOG[0];
                      return (
                        <div
                          key={item.id}
                          className="py-2.5 first:pt-0 last:pb-0 flex items-center justify-between gap-3"
                        >
                          <button
                            type="button"
                            aria-label={`Sincronizza ${item.title} di ${item.artist} dall'offset ${formatDisplayTime(item.detectedOffsetMs)}`}
                            onClick={() => {
                              setActiveSongId(matchedSong.id);
                              setCurrentTimeMs(item.detectedOffsetMs);
                              setIsPlaying(true);
                            }}
                            className="flex items-center gap-3 min-w-0 flex-1 text-left group cursor-pointer"
                          >
                            <AlbumArtwork
                              motif={matchedSong.coverPalette.motif}
                              title={item.title}
                              artist={item.artist}
                              className="w-10 h-10 rounded-xl"
                            />
                            <div className="min-w-0 flex-1">
                              <p className="text-xs font-semibold text-slate-100 group-hover:text-amber-400 truncate transition-colors">
                                {item.title}
                              </p>
                              <p className="text-[11px] text-slate-400 truncate">
                                {item.artist} · Offset {formatDisplayTime(item.detectedOffsetMs)}
                              </p>
                            </div>
                          </button>

                          <button
                            type="button"
                            onClick={() => handleDeleteHistoryItem(item.id)}
                            aria-label={`Rimuovi ${item.title} dalla cronologia`}
                            className="min-h-[36px] min-w-[36px] rounded-lg hover:bg-slate-800 text-slate-500 hover:text-rose-400 flex items-center justify-center transition-colors cursor-pointer"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                          </button>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>

            {/* Right Column (7 cols): Live Synchronized Lyrics Teleprompter */}
            <div className="lg:col-span-7 flex flex-col">
              <LiveLyricsTeleprompter
                song={activeSong}
                currentTimeMs={currentTimeMs}
                syncState={syncState}
                isPlaying={isPlaying}
                manualOffsetMs={manualOffsetMs}
                showTranslation={showTranslation}
                onTogglePlay={() => setIsPlaying((p) => !p)}
                onSeekToMs={(ms) => setCurrentTimeMs(ms)}
                onAdjustOffset={(delta) => setManualOffsetMs((o) => o + delta)}
                onResetOffset={() => setManualOffsetMs(0)}
                onToggleTranslation={() => setShowTranslation((t) => !t)}
                onUpdateCustomLrc={handleUpdateCustomLrc}
                onJumpToRoomOffset={() => {
                  setCurrentTimeMs(activeSong.defaultRoomOffsetMs);
                  setManualOffsetMs(0);
                  setIsPlaying(true);
                }}
              />
            </div>
          </section>
        )}

        {/* Complete Flutter & Dart Source Code Studio Section */}
        <FlutterCodeStudio />
      </main>

      {/* Quiet Footer */}
      <footer className="border-t border-slate-900 py-6 px-4 sm:px-8 mt-12 text-xs text-slate-500">
        <div className="max-w-7xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
          <span>
            AuraSync Studio — Architettura Flutter per Riconoscimento Acustico & Testi LRC in Tempo Reale
          </span>
          <div className="flex items-center gap-4">
            <span className="font-mono tabular-nums">LRC Standard [mm:ss.xx]</span>
            <span aria-hidden="true">·</span>
            <span>Dart 3 / Flutter 3.24+</span>
          </div>
        </div>
      </footer>
    </div>
  );
}
