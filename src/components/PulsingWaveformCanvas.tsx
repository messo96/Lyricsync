import React, { useEffect, useRef, useState } from 'react';
import { Mic, Waves, Radio } from 'lucide-react';
import {
  advanceKineticOrbPhysics,
  KineticOrbPhysicsState,
} from '../utils/lyricsEngine';

interface SilkPetalSpec {
  primaryRgba: (a: number) => string;
  secondaryRgba: (a: number) => string;
  speedMultiplier: number;
  phaseOffset: number;
  lobeCount: number;
  baseScale: number;
}

const SILK_PETALS: SilkPetalSpec[] = [
  {
    primaryRgba: (a) => `rgba(0, 245, 212, ${a})`,
    secondaryRgba: (a) => `rgba(14, 165, 233, ${a})`,
    speedMultiplier: 1.15,
    phaseOffset: 0.0,
    lobeCount: 3,
    baseScale: 1.04,
  },
  {
    primaryRgba: (a) => `rgba(99, 102, 241, ${a})`,
    secondaryRgba: (a) => `rgba(168, 85, 247, ${a})`,
    speedMultiplier: -0.92,
    phaseOffset: 1.57,
    lobeCount: 3,
    baseScale: 1.0,
  },
  {
    primaryRgba: (a) => `rgba(245, 158, 11, ${a})`,
    secondaryRgba: (a) => `rgba(244, 63, 94, ${a})`,
    speedMultiplier: 1.38,
    phaseOffset: 3.14,
    lobeCount: 2,
    baseScale: 0.96,
  },
  {
    primaryRgba: (a) => `rgba(45, 212, 191, ${a})`,
    secondaryRgba: (a) => `rgba(56, 189, 248, ${a})`,
    speedMultiplier: -1.24,
    phaseOffset: 4.71,
    lobeCount: 4,
    baseScale: 0.92,
  },
];

interface PulsingWaveformCanvasProps {
  isListening: boolean;
  statusText: string;
  onToggleListening: () => void;
  size?: number;
}

/**
 * 1:1 Web Renderer of the new Flutter `PulsingWaveform` ("Siri / Shazam Liquid Silk & Sonic Ripples"):
 * - Keeps the crisp white Microphone capsule centered at all times, bouncing elastically on the beat
 * - 4 overlapping translucent 3D Liquid Silk Petals (Cyan, Indigo/Violet, Amber/Coral, Mint) that bloom and rotate
 * - 4 clean Shazam-style concentric shockwave rings expanding smoothly outward
 * - Rotating comet radar arc along the outer perimeter
 */
export const PulsingWaveformCanvas: React.FC<PulsingWaveformCanvasProps> = ({
  isListening,
  statusText,
  onToggleListening,
  size = 280,
}) => {
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const [micBounceScale, setMicBounceScale] = useState<number>(1);
  const physicsRef = useRef<KineticOrbPhysicsState>({
    basePhase: 0,
    dynamicPhase: 0,
    rippleClock: 0,
    smoothVolume: 0,
    smoothTransient: 0,
    listeningBlend: isListening ? 1 : 0,
  });

  const rawAudioRef = useRef<{
    volume: number;
    transient: number;
    db: number;
    lastEventAt: number;
  }>({
    volume: 0,
    transient: 0,
    db: -52,
    lastEventAt: 0,
  });

  const [badgeInfo, setBadgeInfo] = useState<{
    label: string;
    isLively: boolean;
    isDetected: boolean;
  }>({
    label: 'ASCOLTO AMBIENTALE ATTIVO',
    isLively: false,
    isDetected: false,
  });

  useEffect(() => {
    if (!isListening) {
      rawAudioRef.current.volume = 0;
      rawAudioRef.current.transient = 0;
      return;
    }

    let audioCtx: AudioContext | null = null;
    let mediaStream: MediaStream | null = null;
    let step = 0;

    const simInterval = window.setInterval(() => {
      step++;
      const t = performance.now() / 1000;
      const beatPulse = Math.pow(Math.max(0, Math.sin(t * 4.0)), 4);
      const vocalContour = 0.36 + 0.28 * Math.sin(t * 2.1) + 0.18 * Math.cos(t * 3.4);
      const combinedVol = Math.min(0.96, Math.max(0.24, vocalContour * 0.65 + beatPulse * 0.48));
      const isHit = beatPulse > 0.65 || step % 6 === 0;

      rawAudioRef.current = {
        volume: combinedVol,
        transient: isHit ? 0.88 : combinedVol * 0.32,
        db: -44 + combinedVol * 30,
        lastEventAt: performance.now(),
      };
    }, 60);

    if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
      navigator.mediaDevices
        .getUserMedia({ audio: true })
        .then((stream) => {
          mediaStream = stream;
          const AudioCtx =
            window.AudioContext ||
            (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
          audioCtx = new AudioCtx();
          const source = audioCtx.createMediaStreamSource(stream);
          const analyser = audioCtx.createAnalyser();
          analyser.fftSize = 128;
          source.connect(analyser);
          const data = new Uint8Array(analyser.frequencyBinCount);

          const pollMic = () => {
            if (!audioCtx) return;
            analyser.getByteFrequencyData(data);
            let sum = 0;
            for (let i = 0; i < data.length; i++) sum += data[i];
            const avg = sum / (data.length * 255);
            if (avg > 0.08) {
              rawAudioRef.current = {
                volume: Math.min(1, avg * 1.85),
                transient: avg > 0.3 ? Math.min(1, avg * 2.1) : 0,
                db: -48 + avg * 42,
                lastEventAt: performance.now(),
              };
            }
          };
          const micTimer = window.setInterval(pollMic, 35);
          return () => clearInterval(micTimer);
        })
        .catch(() => {});
    }

    return () => {
      clearInterval(simInterval);
      if (mediaStream) mediaStream.getTracks().forEach((t) => t.stop());
      if (audioCtx) audioCtx.close().catch(() => {});
    };
  }, [isListening]);

  useEffect(() => {
    let rafId = 0;
    let lastTime = performance.now();
    let frameCount = 0;

    const renderFrame = (now: number) => {
      const dtSeconds = (now - lastTime) / 1000;
      lastTime = now;

      const msSinceAudio = now - rawAudioRef.current.lastEventAt;
      const p = advanceKineticOrbPhysics(physicsRef.current, {
        dtSeconds,
        isListening,
        rawVolume: rawAudioRef.current.volume,
        rawTransient: rawAudioRef.current.transient,
        msSinceAudio,
      });
      physicsRef.current = p;

      frameCount++;
      if (frameCount % 3 === 0) {
        const idleS = 1 + Math.sin(p.basePhase) * 0.028;
        const activeS =
          1 +
          Math.sin(p.dynamicPhase * 1.5) * 0.04 +
          p.smoothVolume * 0.13 +
          p.smoothTransient * 0.11;
        setMicBounceScale(idleS * (1 - p.listeningBlend) + activeS * p.listeningBlend);
      }

      if (frameCount % 12 === 0 && isListening) {
        const energy = Math.min(1, p.smoothVolume * 0.7 + p.smoothTransient * 0.45);
        const isLively = energy > 0.36;
        const isDetected = p.smoothVolume > 0.22;
        const dbRounded = Math.round(rawAudioRef.current.db);
        setBadgeInfo({
          isLively,
          isDetected,
          label: isDetected
            ? p.smoothTransient > 0.42
              ? `RITMO RILEVATO · ${dbRounded} dB`
              : `ONDA SONORA ATTIVA · ${dbRounded} dB`
            : 'ASCOLTO AMBIENTALE ATTIVO',
        });
      }

      const canvas = canvasRef.current;
      if (canvas) {
        const dpr = window.devicePixelRatio || 1;
        const targetW = Math.round(size * dpr);
        const targetH = Math.round(size * dpr);
        if (canvas.width !== targetW || canvas.height !== targetH) {
          canvas.width = targetW;
          canvas.height = targetH;
        }

        const ctx = canvas.getContext('2d');
        if (ctx) {
          ctx.save();
          ctx.scale(dpr, dpr);
          ctx.clearRect(0, 0, size, size);

          const cx = size / 2;
          const cy = size / 2;
          const scale = size / 276;
          const maxR = size / 2 - 4;

          // 1. Multicolor Atmospheric Halo
          const haloR = Math.min(
            maxR,
            (68 +
              Math.sin(p.basePhase) * 6 +
              (p.smoothVolume * 44 + p.smoothTransient * 22) * p.listeningBlend) *
              scale
          );
          const haloGrad = ctx.createRadialGradient(cx, cy, 10 * scale, cx, cy, haloR);
          haloGrad.addColorStop(0, `rgba(0, 245, 212, ${0.16 + p.listeningBlend * 0.22})`);
          haloGrad.addColorStop(0.55, `rgba(99, 102, 241, ${0.1 + p.listeningBlend * 0.16})`);
          haloGrad.addColorStop(1, 'rgba(9, 12, 19, 0)');
          ctx.fillStyle = haloGrad;
          ctx.beginPath();
          ctx.arc(cx, cy, haloR, 0, Math.PI * 2);
          ctx.fill();

          // 2. Idle Breathing Rings
          if (p.listeningBlend < 0.99) {
            const idleAlpha = 1 - p.listeningBlend;
            for (let i = 0; i < 3; i++) {
              const waveR =
                (58 + i * 16 + Math.sin(p.basePhase * 0.9 - i * 0.9) * 3.5) * scale;
              ctx.strokeStyle = `rgba(56, 189, 248, ${(0.22 - i * 0.05) * idleAlpha})`;
              ctx.lineWidth = 1.4 * scale;
              ctx.beginPath();
              ctx.arc(cx, cy, waveR, 0, Math.PI * 2);
              ctx.stroke();
            }
          }

          if (p.listeningBlend > 0.01) {
            // 3. 4 Clean Concentric Shazam Shockwave Rings
            const ringCount = 4;
            for (let i = 0; i < ringCount; i++) {
              const prog = (p.rippleClock * 0.78 + i / ringCount) % 1;
              const eased = 1 - Math.pow(1 - prog, 2.6);
              const r = 48 * scale + (maxR - 48 * scale) * eased;
              const ringAlpha = Math.min(
                0.85,
                (1 - prog) * (0.48 + p.smoothVolume * 0.38) * p.listeningBlend
              );

              const rCol = Math.round(0 + prog * 99);
              const gCol = Math.round(245 - prog * 143);
              const bCol = Math.round(212 + prog * 29);
              ctx.strokeStyle = `rgba(${rCol}, ${gCol}, ${bCol}, ${ringAlpha})`;
              ctx.lineWidth = 2.8 * (1 - prog * 0.65) * scale;
              ctx.beginPath();
              ctx.arc(cx, cy, r, 0, Math.PI * 2);
              ctx.stroke();
            }

            // 4. 4 Morphing 3D Liquid Silk Petals (Siri Style)
            const steps = 72;
            const stepAngle = (Math.PI * 2) / steps;

            for (const spec of SILK_PETALS) {
              const baseR =
                (54 * spec.baseScale + p.smoothVolume * 22 + p.smoothTransient * 12) *
                scale;
              const lobeAmp =
                (8 + p.smoothVolume * 18 + p.smoothTransient * 14) *
                scale *
                p.listeningBlend;
              const secondaryAmp =
                (4 + p.smoothVolume * 9) * scale * p.listeningBlend;
              const rotation =
                p.dynamicPhase * 0.65 * spec.speedMultiplier + spec.phaseOffset;

              ctx.beginPath();
              for (let i = 0; i <= steps; i++) {
                const idx = i % steps;
                const theta = idx * stepAngle;
                const lobe = Math.sin(theta * spec.lobeCount + rotation) * lobeAmp;
                const twist =
                  Math.cos(theta * (spec.lobeCount + 1) - rotation * 1.3) *
                  secondaryAmp;
                const r = Math.max(
                  32 * scale,
                  Math.min(maxR - 6 * scale, baseR + lobe + twist)
                );
                const x = cx + Math.cos(theta) * r;
                const y = cy + Math.sin(theta) * r;
                if (i === 0) ctx.moveTo(x, y);
                else ctx.lineTo(x, y);
              }
              ctx.closePath();

              const gradR = baseR + lobeAmp;
              const petalGrad = ctx.createLinearGradient(
                cx + Math.cos(rotation) * gradR,
                cy + Math.sin(rotation) * gradR,
                cx - Math.cos(rotation) * gradR,
                cy - Math.sin(rotation) * gradR
              );
              petalGrad.addColorStop(
                0,
                spec.primaryRgba((0.28 + p.smoothVolume * 0.24) * p.listeningBlend)
              );
              petalGrad.addColorStop(
                1,
                spec.secondaryRgba(
                  (0.14 + p.smoothTransient * 0.2) * p.listeningBlend
                )
              );

              ctx.fillStyle = petalGrad;
              ctx.fill();

              ctx.strokeStyle = spec.primaryRgba(
                (0.72 + p.smoothVolume * 0.26) * p.listeningBlend
              );
              ctx.lineWidth = 1.8 * scale;
              ctx.stroke();
            }

            // 5. Outer Rotating Comet Radar Sweep Arc
            const sweepRadius = Math.min(
              maxR - 2,
              (108 + p.smoothVolume * 10) * scale
            );
            const sweepAngle = p.dynamicPhase * 0.95;
            ctx.strokeStyle = `rgba(246, 201, 116, ${0.85 * p.listeningBlend})`;
            ctx.lineWidth = 2.4 * scale;
            ctx.lineCap = 'round';
            ctx.beginPath();
            ctx.arc(
              cx,
              cy,
              sweepRadius,
              sweepAngle,
              sweepAngle + Math.PI * 0.75
            );
            ctx.stroke();
          }

          ctx.restore();
        }
      }

      rafId = requestAnimationFrame(renderFrame);
    };

    rafId = requestAnimationFrame(renderFrame);
    return () => cancelAnimationFrame(rafId);
  }, [isListening, size]);

  return (
    <div className="flex flex-col items-center select-none">
      <button
        type="button"
        onClick={onToggleListening}
        aria-label={
          isListening
            ? 'Interrompi ascolto continuo microfono'
            : 'Avvia ascolto microfono e sincronizza il testo'
        }
        data-testid="pulsing-mic-button"
        className="relative group rounded-full focus:outline-none focus-visible:ring-2 focus-visible:ring-[#00F5D4] cursor-pointer"
        style={{ width: size, height: size }}
      >
        <canvas
          ref={canvasRef}
          className="w-full h-full block pointer-events-none"
        />

        {/* Central Levitating Shazam/Siri Microphone Capsule (Always Visible!) */}
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
          <div
            className="w-24 h-24 rounded-full flex items-center justify-center transition-colors duration-300 border"
            style={{
              transform: `scale(${micBounceScale.toFixed(3)})`,
              background: isListening
                ? 'linear-gradient(135deg, #00F5D4 0%, #4F46E5 55%, #0F172A 100%)'
                : 'linear-gradient(135deg, #1E293B 0%, #0F172A 100%)',
              borderColor: isListening
                ? 'rgba(255, 255, 255, 0.78)'
                : 'rgba(255, 255, 255, 0.18)',
              boxShadow: isListening
                ? '0 0 32px rgba(0, 245, 212, 0.45), inset 0 2px 6px rgba(255, 255, 255, 0.45)'
                : '0 8px 24px rgba(0, 0, 0, 0.5), inset 0 1px 2px rgba(255, 255, 255, 0.15)',
            }}
          >
            <Mic className="w-10 h-10 text-white drop-shadow-md" />
          </div>
        </div>
      </button>

      {isListening && (
        <div
          className="mt-2.5 px-3.5 py-1 rounded-full border text-[10px] font-extrabold tracking-wider flex items-center gap-1.5 transition-colors"
          style={{
            backgroundColor: badgeInfo.isLively
              ? 'rgba(246, 201, 116, 0.15)'
              : 'rgba(0, 245, 212, 0.12)',
            borderColor: badgeInfo.isLively
              ? 'rgba(246, 201, 116, 0.55)'
              : 'rgba(0, 245, 212, 0.55)',
            color: badgeInfo.isLively ? '#F6C974' : '#00F5D4',
          }}
          data-testid="acoustic-live-badge"
        >
          {badgeInfo.isDetected ? (
            <Waves className="w-3.5 h-3.5" />
          ) : (
            <Radio className="w-3.5 h-3.5" />
          )}
          <span>{badgeInfo.label}</span>
        </div>
      )}

      {statusText && (
        <p
          className={`mt-2 text-center text-[13px] font-semibold px-4 ${
            isListening ? 'text-[#00F5D4]' : 'text-[#94A3B8]'
          }`}
          data-testid="mic-status-text"
        >
          {statusText}
        </p>
      )}
    </div>
  );
};
