import React, { useEffect, useState } from 'react';
import { Mic, Radio, Volume2, VolumeX, Sparkles } from 'lucide-react';
import { soundEngine } from '../utils/soundSynth';

interface AcousticVisualizerProps {
  isListening: boolean;
  isPlaying: boolean;
  listenStepLabel: string;
  listenProgress: number; // 0 to 100
  isMuted: boolean;
  onToggleMute: () => void;
  onStartAmbientScan: () => void;
  onRecordRealMic: () => void;
  isRecordingMic: boolean;
  noiseFloorDb: number;
  bpm: number;
  musicalKey: string;
}

export const AcousticVisualizer: React.FC<AcousticVisualizerProps> = ({
  isListening,
  isPlaying,
  listenStepLabel,
  listenProgress,
  isMuted,
  onToggleMute,
  onStartAmbientScan,
  onRecordRealMic,
  isRecordingMic,
  noiseFloorDb,
  bpm,
  musicalKey,
}) => {
  const [bars, setBars] = useState<number[]>(() => Array.from({ length: 28 }, () => 0.22));

  useEffect(() => {
    if (!isListening && !isPlaying && !isRecordingMic) {
      setBars(
        Array.from({ length: 28 }, (_, i) => 0.16 + Math.sin(i * 0.45) * 0.06)
      );
      return;
    }

    const interval = window.setInterval(() => {
      setBars(soundEngine.getFrequencyLevels(28));
    }, 85);

    return () => clearInterval(interval);
  }, [isListening, isPlaying, isRecordingMic]);

  return (
    <div className="rounded-2xl bg-slate-900/90 border border-slate-800 p-5 flex flex-col justify-between gap-4">
      <div className="flex items-center justify-between gap-3">
        <div>
          <h2 className="text-sm font-semibold text-slate-100">
            Sensore Acustico Ambientale
          </h2>
          <p className="text-xs text-slate-400 mt-0.5">
            {isRecordingMic
              ? 'Cattura microfono reale in corso (44.1 kHz PCM)...'
              : isListening
              ? listenStepLabel
              : isPlaying
              ? `Aggancio attivo · ${bpm} BPM · ${musicalKey} · Rumore ${noiseFloorDb} dB`
              : 'Pronto ad ascoltare la musica nella stanza'}
          </p>
        </div>

        <button
          type="button"
          onClick={onToggleMute}
          aria-label={isMuted ? 'Attiva audio sintetizzatore ambientale' : 'Disattiva audio sintetizzatore ambientale'}
          className="min-h-[40px] px-3 py-1.5 rounded-xl bg-slate-800/90 hover:bg-slate-700/80 text-xs font-medium text-slate-200 flex items-center gap-2 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
        >
          {isMuted ? <VolumeX className="w-4 h-4 text-slate-400" /> : <Volume2 className="w-4 h-4 text-amber-400" />}
          <span>{isMuted ? 'Audio Muto' : 'Audio Stanza ON'}</span>
        </button>
      </div>

      {/* Spectrum Bars */}
      <div
        className="h-24 flex items-end justify-between gap-1 px-2 py-2 rounded-xl bg-slate-950/80 border border-slate-800/70"
        data-testid="acoustic-spectrum-bars"
        aria-label="Spettro di frequenza acustica in tempo reale"
      >
        {bars.map((val, idx) => {
          const heightPct = Math.round(Math.max(12, Math.min(100, val * 100)));
          return (
            <div
              key={idx}
              className="flex-1 rounded-full transition-all duration-100"
              style={{
                height: `${heightPct}%`,
                backgroundColor:
                  isListening || isRecordingMic
                    ? '#38bdf8'
                    : isPlaying
                    ? idx % 3 === 0
                      ? '#f59e0b'
                      : '#fbbf24'
                    : '#334155',
                opacity: isListening || isPlaying || isRecordingMic ? 0.9 : 0.45,
              }}
            />
          );
        })}
      </div>

      {/* Progress bar during ambient fingerprinting */}
      {(isListening || isRecordingMic) && (
        <div className="space-y-1.5">
          <div className="flex items-center justify-between text-xs text-sky-300 font-mono tabular-nums">
            <span>{listenStepLabel}</span>
            <span>{Math.round(listenProgress)}%</span>
          </div>
          <div className="w-full h-1.5 bg-slate-800 rounded-full overflow-hidden">
            <div
              className="h-full bg-sky-400 transition-all duration-150"
              style={{ width: `${Math.min(100, Math.max(5, listenProgress))}%` }}
            />
          </div>
        </div>
      )}

      {/* Primary Trigger Actions */}
      <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5 pt-1">
        <button
          type="button"
          onClick={onStartAmbientScan}
          disabled={isListening || isRecordingMic}
          className="min-h-[44px] px-4 py-2.5 rounded-xl bg-amber-500 hover:bg-amber-400 disabled:opacity-60 text-slate-950 font-semibold text-xs flex items-center justify-center gap-2 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
        >
          <Radio className="w-4 h-4 shrink-0" />
          <span>{isListening ? 'Analisi Spettrale...' : 'Rileva Canzone nell’Ambiente'}</span>
        </button>

        <button
          type="button"
          onClick={onRecordRealMic}
          disabled={isListening || isRecordingMic}
          className="min-h-[44px] px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 disabled:opacity-60 text-slate-100 border border-slate-700 font-medium text-xs flex items-center justify-center gap-2 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
        >
          <Mic className="w-4 h-4 text-sky-400 shrink-0" />
          <span>{isRecordingMic ? 'Ascolto Microfono...' : 'Usa Microfono Dispositivo'}</span>
        </button>
      </div>
    </div>
  );
};
