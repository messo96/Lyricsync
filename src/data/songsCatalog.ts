import { LyricLine, parseLrc } from '../utils/lyricsEngine';

export interface AmbientSong {
  id: string;
  title: string;
  artist: string;
  album: string;
  releaseYear: number;
  bpm: number;
  musicalKey: string;
  durationMs: number;
  defaultRoomOffsetMs: number; // Simulates detecting a song already playing in a bar/car/room
  confidenceScore: number;
  acousticEnvironment: string;
  coverPalette: {
    primary: string;
    secondary: string;
    accent: string;
    motif: 'milan-rain' | 'solar-bronze' | 'mediterranean-wave' | 'analog-reel';
  };
  chordProgressionFreqs: number[][]; // Frequencies in Hz for Web Audio API synth
  lrcRaw: string;
  lines: LyricLine[];
}

export interface AmbientEnvironmentPreset {
  id: string;
  label: string;
  description: string;
  noiseFloorDb: number;
  simulatedLatencyMs: number;
  defaultSongId: string;
  simulatedRoomOffsetMs: number;
}

export const AMBIENT_ENVIRONMENTS: AmbientEnvironmentPreset[] = [
  {
    id: 'navigli-lounge',
    label: 'Locale sui Navigli (Milano)',
    description: 'Brano già iniziato al secondo 00:18 con riverbero ambientale e brusio di fondo (-16 dB).',
    noiseFloorDb: -16,
    simulatedLatencyMs: 320,
    defaultSongId: 'luci-di-brera',
    simulatedRoomOffsetMs: 18200,
  },
  {
    id: 'car-fm-radio',
    label: 'Autoradio FM in Movimento',
    description: 'Rilevamento rapido sul ritornello (00:27.5) con compressione FM e rumore stradale (-12 dB).',
    noiseFloorDb: -12,
    simulatedLatencyMs: 410,
    defaultSongId: 'solaris-midnight',
    simulatedRoomOffsetMs: 27500,
  },
  {
    id: 'sunset-terrace',
    label: 'Terrazza Mediterranea Live',
    description: 'Acustica aperta sul mare, aggancio al verso centrale (00:14.0) con sincronia LRC immediata.',
    noiseFloorDb: -22,
    simulatedLatencyMs: 240,
    defaultSongId: 'onde-di-vetro',
    simulatedRoomOffsetMs: 14000,
  },
  {
    id: 'vinyl-studio',
    label: 'Impianto Hi-Fi Vinile Studio',
    description: 'Segnale cristallino ad alta dinamica (-38 dB), aggancio dall’intro strumentale (00:04.5).',
    noiseFloorDb: -38,
    simulatedLatencyMs: 180,
    defaultSongId: 'velvet-horizon',
    simulatedRoomOffsetMs: 4500,
  },
];

const RAW_SONGS: Array<Omit<AmbientSong, 'lines'>> = [
  {
    id: 'luci-di-brera',
    title: 'Luci di Brera',
    artist: 'Cosmo & Vettori',
    album: 'Notturni Urbani',
    releaseYear: 2026,
    bpm: 118,
    musicalKey: 'Fa min (Fm)',
    durationMs: 68000,
    defaultRoomOffsetMs: 18200,
    confidenceScore: 99.4,
    acousticEnvironment: 'Locale sui Navigli · Impronta Spettrale 44.1 kHz',
    coverPalette: {
      primary: '#0f172a',
      secondary: '#1e293b',
      accent: '#f59e0b',
      motif: 'milan-rain',
    },
    chordProgressionFreqs: [
      [174.61, 207.65, 261.63, 311.13], // Fm7
      [138.59, 174.61, 207.65, 261.63], // Dbmaj7
      [155.56, 196.0, 233.08, 293.66],  // Eb6
      [130.81, 164.81, 196.0, 246.94],  // Cm7
    ],
    lrcRaw: `
[00:00.00] ♫ Introduzione synth analogico e pioggia su Brera ♫ | ♫ Analog synth intro and rain over Brera ♫
[00:04.50] Camminiamo piano tra i riflessi del tram | We walk slowly among the tram reflections
[00:09.00] L'odore di pioggia sopra il pavé bagnato | The scent of rain upon the wet cobblestones
[00:13.60] Una cassa suona dietro i vetri appannati | A speaker plays behind fogged-up glass
[00:18.20] E all'improvviso riconosco questa melodia | And suddenly I recognize this melody
[00:22.80] Ogni parola cade esattamente sul battito | Every word falls right on the beat
[00:27.40] Non serve chiedere il titolo a nessuno | No need to ask anyone for the title
[00:32.00] Luci di Brera che danzano fino all'alba | Lights of Brera dancing until dawn
[00:36.80] Siamo sincronizzati sullo stesso respiro | We are synchronized on the very same breath
[00:41.50] Mentre la notte scorre veloce sui Navigli | While the night flows fast along the Navigli
[00:46.20] Resta con me dentro questo accordo sospeso | Stay with me inside this suspended chord
[00:51.00] Finché l'ultima nota svanisce nel mattino | Until the last note fades into the morning
[00:56.50] ♫ Outro: Arpeggio Rhodes & Basso Profondo ♫ | ♫ Outro: Rhodes Arpeggio & Deep Bass ♫
    `.trim(),
  },
  {
    id: 'solaris-midnight',
    title: 'Solaris (Midnight Edit)',
    artist: 'Kiasmos & Aura',
    album: 'Architecture of Sound',
    releaseYear: 2025,
    bpm: 122,
    musicalKey: 'La min (Am)',
    durationMs: 64000,
    defaultRoomOffsetMs: 27500,
    confidenceScore: 98.8,
    acousticEnvironment: 'Autoradio FM · Compensazione Doppler Attiva',
    coverPalette: {
      primary: '#18181b',
      secondary: '#27272a',
      accent: '#38bdf8',
      motif: 'solar-bronze',
    },
    chordProgressionFreqs: [
      [220.0, 261.63, 329.63, 392.0],   // Am7
      [174.61, 220.0, 261.63, 329.63],  // Fmaj7
      [130.81, 164.81, 196.0, 246.94],  // Cmaj7
      [196.0, 246.94, 293.66, 349.23],  // G7
    ],
    lrcRaw: `
[00:00.00] ♫ Pulsazione sub-bass e archi nordici ♫ | ♫ Sub-bass pulse and Nordic strings ♫
[00:04.20] Across the glass horizon the signal wakes | Oltre l'orizzonte di vetro il segnale si sveglia
[00:08.80] Every frequency aligns inside the dark | Ogni frequenza si allinea dentro il buio
[00:13.50] You hear the echo rising from the street | Senti l'eco salire dalla strada
[00:18.10] Captured in a fraction of a second | Catturato in una frazione di secondo
[00:22.90] No matter where the song began to play | Non importa dove sia iniziata la canzone
[00:27.50] Solaris locks the rhythm to your eyes | Solaris aggancia il ritmo ai tuoi occhi
[00:32.20] Word by word the midnight sky unfolds | Parola dopo parola il cielo di mezzanotte si apre
[00:37.00] Tracing constellations in real time | Tracciando costellazioni in tempo reale
[00:41.80] Hold the phase and let the silence glow | Mantieni la fase e lascia brillare il silenzio
[00:46.60] Drifting through the amber city lights | Scivolando tra le luci ambrate della città
[00:51.50] Until the final harmonic resolves in peace | Finché l'ultima armonica si risolve in pace
    `.trim(),
  },
  {
    id: 'onde-di-vetro',
    title: 'Onde di Vetro',
    artist: 'Nu Genea & Serena',
    album: 'Mediterraneo Elettrico',
    releaseYear: 2026,
    bpm: 112,
    musicalKey: 'Re min (Dm)',
    durationMs: 62000,
    defaultRoomOffsetMs: 14000,
    confidenceScore: 99.1,
    acousticEnvironment: 'Terrazza Aperto · Filtro Vento Adattivo',
    coverPalette: {
      primary: '#0c192c',
      secondary: '#172a45',
      accent: '#fb923c',
      motif: 'mediterranean-wave',
    },
    chordProgressionFreqs: [
      [146.83, 174.61, 220.0, 261.63],  // Dm7
      [196.0, 233.08, 293.66, 349.23],  // Gm7
      [220.0, 277.18, 329.63, 392.0],   // A7
      [146.83, 174.61, 220.0, 293.66],  // Dm
    ],
    lrcRaw: `
[00:00.00] ♫ Chitarra funk mediterranea e percussioni ♫ | ♫ Mediterranean funk guitar and percussion ♫
[00:04.60] Il vento porta accordi da lontano | The wind carries chords from afar
[00:09.20] Sopra la scogliera che profuma di sale | Above the cliff that smells of salt
[00:14.00] Onde di vetro scivolano lente | Waves of glass glide slowly
[00:18.60] Mentre la voce si disegna sullo schermo | While the voice draws itself across the screen
[00:23.30] Segui il tempo senza perdere una sillaba | Follow the tempo without missing a syllable
[00:28.00] Dal Golfo a tutta la costa illuminata | From the Gulf to the entire illuminated coast
[00:32.70] Canta insieme al mare aperto | Sing along with the open sea
[00:37.50] Ogni strofa brilla nel crepuscolo | Every verse shines in the twilight
[00:42.30] Il giro di basso non si ferma mai | The bassline never stops
[00:47.10] Sotto le stelle di questa estate infinita | Under the stars of this endless summer
    `.trim(),
  },
  {
    id: 'velvet-horizon',
    title: 'Velvet Horizon',
    artist: 'Parcels & Daft Studio',
    album: 'Tape Loops Vol. 4',
    releaseYear: 2025,
    bpm: 116,
    musicalKey: 'Mi min (Em)',
    durationMs: 60000,
    defaultRoomOffsetMs: 4500,
    confidenceScore: 99.7,
    acousticEnvironment: 'Studio Analogico · Rapporto Segnale/Rumore +38 dB',
    coverPalette: {
      primary: '#1c1917',
      secondary: '#292524',
      accent: '#eab308',
      motif: 'analog-reel',
    },
    chordProgressionFreqs: [
      [164.81, 196.0, 246.94, 293.66],  // Em7
      [220.0, 277.18, 329.63, 415.3],   // Amaj7
      [146.83, 185.0, 220.0, 277.18],   // Dmaj7
      [196.0, 246.94, 293.66, 369.99],  // Gmaj7
    ],
    lrcRaw: `
[00:00.00] ♫ Nastro magnetico e clavinet funk ♫ | ♫ Magnetic tape and funk clavinet ♫
[00:04.50] Spin the reel and catch the groove in flight | Fai girare la bobina e cattura il groove in volo
[00:09.10] Warmth of analog inside a digital frame | Calore analogico dentro una cornice digitale
[00:13.80] Instant lock on every single rhyme | Aggancio istantaneo su ogni singola rima
[00:18.40] Velvet horizon glowing on your palm | Orizzonte di velluto che brilla sul tuo palmo
[00:23.10] Step into the chorus right on cue | Entra nel ritornello esattamente a tempo
[00:27.80] Zero latency between the room and you | Latenza zero tra la stanza e te
[00:32.50] Feel the bassline lock into the grid | Senti il basso agganciarsi alla griglia
[00:37.20] Every lyric painted as it's sung | Ogni verso dipinto mentre viene cantato
[00:42.00] Golden frequencies until the tape runs out | Frequenze dorate finché il nastro finisce
    `.trim(),
  },
];

export const SONGS_CATALOG: AmbientSong[] = RAW_SONGS.map((song) => ({
  ...song,
  lines: parseLrc(song.lrcRaw, song.durationMs),
}));
