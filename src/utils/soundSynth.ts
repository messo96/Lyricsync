/**
 * Web Audio API Ambient Acoustic Synthesizer & Microphone Spectrum Analyzer
 * Generates realistic ambient harmonic chords and bass pulses locked to the song's BPM,
 * and provides real-time frequency bins for the acoustic visualizer.
 */
export class AmbientSoundEngine {
  private ctx: AudioContext | null = null;
  private analyser: AnalyserNode | null = null;
  private masterGain: GainNode | null = null;
  private stepTimer: number | null = null;
  private isPlaying = false;
  private isMuted = false;
  private currentStep = 0;

  private ensureContext(): AudioContext | null {
    if (typeof window === 'undefined') return null;
    if (!this.ctx) {
      const AudioCtx = window.AudioContext || (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
      if (!AudioCtx) return null;
      this.ctx = new AudioCtx();
      this.analyser = this.ctx.createAnalyser();
      this.analyser.fftSize = 128;
      this.analyser.smoothingTimeConstant = 0.82;

      this.masterGain = this.ctx.createGain();
      this.masterGain.gain.value = 0.14;
      this.masterGain.connect(this.analyser);
      this.analyser.connect(this.ctx.destination);
    }
    if (this.ctx.state === 'suspended') {
      this.ctx.resume().catch(() => {});
    }
    return this.ctx;
  }

  public startAmbientTrack(chords: number[][], bpm: number): void {
    this.stop();
    const ctx = this.ensureContext();
    if (!ctx || !this.masterGain) return;

    this.isPlaying = true;
    this.currentStep = 0;
    const beatMs = Math.round((60 / Math.max(70, Math.min(160, bpm))) * 1000);

    const triggerBeat = () => {
      if (!this.isPlaying || !this.ctx || !this.masterGain) return;
      if (this.isMuted) {
        this.currentStep++;
        return;
      }

      const now = this.ctx.currentTime;
      const chordIndex = Math.floor(this.currentStep / 4) % chords.length;
      const chord = chords[chordIndex] || [220, 261.63, 329.63];
      const beatInBar = this.currentStep % 4;

      // Soft warm pad chord on beat 0 and 2
      if (beatInBar === 0 || beatInBar === 2) {
        chord.forEach((freq, idx) => {
          if (!this.ctx || !this.masterGain) return;
          const osc = this.ctx.createOscillator();
          const gain = this.ctx.createGain();
          osc.type = idx === 0 ? 'triangle' : 'sine';
          osc.frequency.setValueAtTime(freq, now);

          gain.gain.setValueAtTime(0.001, now);
          gain.gain.linearRampToValueAtTime(0.06 / chord.length, now + 0.08);
          gain.gain.exponentialRampToValueAtTime(0.0008, now + (beatMs * 1.8) / 1000);

          osc.connect(gain);
          gain.connect(this.masterGain);
          osc.start(now);
          osc.stop(now + (beatMs * 1.9) / 1000);
        });
      }

      // Subtle sub-bass pulse on every beat
      const bassOsc = this.ctx.createOscillator();
      const bassGain = this.ctx.createGain();
      bassOsc.type = 'sine';
      const rootFreq = (chord[0] || 164.81) * 0.5;
      bassOsc.frequency.setValueAtTime(rootFreq, now);
      bassGain.gain.setValueAtTime(0.001, now);
      bassGain.gain.linearRampToValueAtTime(beatInBar === 0 ? 0.09 : 0.045, now + 0.03);
      bassGain.gain.exponentialRampToValueAtTime(0.001, now + (beatMs * 0.75) / 1000);

      bassOsc.connect(bassGain);
      bassGain.connect(this.masterGain);
      bassOsc.start(now);
      bassOsc.stop(now + (beatMs * 0.8) / 1000);

      this.currentStep++;
    };

    triggerBeat();
    this.stepTimer = window.setInterval(triggerBeat, beatMs);
  }

  public setMuted(muted: boolean): void {
    this.isMuted = muted;
    if (this.masterGain && this.ctx) {
      this.masterGain.gain.setTargetAtTime(muted ? 0.0001 : 0.14, this.ctx.currentTime, 0.05);
    }
  }

  public getMuted(): boolean {
    return this.isMuted;
  }

  public stop(): void {
    this.isPlaying = false;
    if (this.stepTimer !== null) {
      clearInterval(this.stepTimer);
      this.stepTimer = null;
    }
  }

  public getFrequencyLevels(barCount = 28): number[] {
    if (this.analyser && this.isPlaying && !this.isMuted) {
      const data = new Uint8Array(this.analyser.frequencyBinCount);
      this.analyser.getByteFrequencyData(data);
      const result: number[] = [];
      for (let i = 0; i < barCount; i++) {
        const binIdx = Math.min(data.length - 1, Math.floor((i / barCount) * (data.length * 0.65)));
        const normalized = data[binIdx] / 255;
        result.push(Math.max(0.12, normalized));
      }
      return result;
    }

    // Deterministic organic acoustic wave when audio output is muted or in headless browser
    const t = Date.now() / 220;
    return Array.from({ length: barCount }, (_, i) => {
      const wave1 = Math.sin(t + i * 0.42) * 0.32;
      const wave2 = Math.cos(t * 1.35 - i * 0.27) * 0.22;
      const centerBoost = 1 - Math.abs(i - barCount / 2) / (barCount / 1.6);
      return Math.max(0.14, Math.min(0.96, 0.38 + wave1 + wave2 + centerBoost * 0.25));
    });
  }
}

export const soundEngine = new AmbientSoundEngine();
