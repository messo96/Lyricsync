import { LyricLine, parseLrc } from '../utils/lyricsEngine';

export interface ListeningEnvOption {
  id: 'casa' | 'al_chiuso' | 'concerto';
  label: string;
  shortLabel: string;
  badgeColor: string;
  description: string;
  sampleDurationMs: number;
  latencyOffsetMs: number;
}

export const LISTENING_ENVIRONMENTS: ListeningEnvOption[] = [
  {
    id: 'casa',
    label: 'Casa / Silenzio',
    shortLabel: 'CASA',
    badgeColor: '#10B981',
    description:
      'Basso rumore · Campionamento ottimizzato (4.8s) ad alta fedeltà mono per cassa o TV vicina',
    sampleDurationMs: 4800,
    latencyOffsetMs: -150,
  },
  {
    id: 'al_chiuso',
    label: 'Al chiuso con persone',
    shortLabel: 'AL CHIUSO',
    badgeColor: '#38BDF8',
    description:
      'Locale, festa, bar · Filtro per voci di fondo, brusio e riverbero indoor (6.0s)',
    sampleDurationMs: 6000,
    latencyOffsetMs: 0,
  },
  {
    id: 'concerto',
    label: 'Live Concert',
    shortLabel: 'LIVE CONCERT',
    badgeColor: '#F59E0B',
    description:
      'Stadio, concerto, arena · Filtro anti-distorsione per boato folla e acustica da palco (7.5s)',
    sampleDurationMs: 7500,
    latencyOffsetMs: 350,
  },
];

export interface ConcertSong {
  id: string;
  title: string;
  artist: string;
  album: string;
  durationMs: number;
  detectedPlayOffsetMs: number;
  bpm: number;
  musicalKey: string;
  spotifyUrl: string;
  rawLrc: string;
  lines: LyricLine[];
}

const RAW_CONCERT_SONGS: Array<Omit<ConcertSong, 'lines'>> = [
  {
    id: 'coldplay-fix-you',
    title: 'Fix You (Live in Concert)',
    artist: 'Coldplay',
    album: 'Music of the Spheres World Tour',
    durationMs: 295000,
    detectedPlayOffsetMs: 14200,
    bpm: 138,
    musicalKey: 'Mib magg (Eb)',
    spotifyUrl: 'https://open.spotify.com/track/7LVHVU3tWfcxj5aiPsvW4Q',
    rawLrc: `
[00:00.00] (Intro di organo e pianoforte - Atmosfera stadio) | (Intro strumentale dal vivo)
[00:14.20] When you try your best, but you don't succeed | Quando fai del tuo meglio, ma non ci riesci
[00:21.00] When you get what you want, but not what you need | Quando ottieni ciò che vuoi, ma non ciò di cui hai bisogno
[00:28.00] When you feel so tired, but you can't sleep | Quando ti senti così stanco, ma non riesci a dormire
[00:35.00] Stuck in reverse | Bloccato nella marcia indietro
[00:41.50] And the tears come streaming down your face | E le lacrime scendono rigando il tuo viso
[00:48.30] When you lose something you can't replace | Quando perdi qualcosa che non puoi rimpiazzare
[00:55.20] When you love someone, but it goes to waste | Quando ami qualcuno, ma tutto va sprecato
[01:02.10] Could it be worse? | Potrebbe andare peggio?
[01:09.00] Lights will guide you home | Le luci ti guideranno verso casa
[01:17.50] And ignite your bones | E accenderanno le tue ossa
[01:25.80] And I will try to fix you | E io proverò a guarirti
    `.trim(),
  },
  {
    id: 'oasis-wonderwall',
    title: 'Wonderwall (Live at Wembley)',
    artist: 'Oasis',
    album: 'Live Forever Concert Tour',
    durationMs: 258000,
    detectedPlayOffsetMs: 10500,
    bpm: 87,
    musicalKey: 'Fa# min (F#m)',
    spotifyUrl: 'https://open.spotify.com/track/1qHe2fHq1lI2eP9R57V26Q',
    rawLrc: `
[00:00.00] (Accordi di chitarra acustica - Liam Gallagher al microfono) | (Intro acustica live)
[00:10.50] Today is gonna be the day that they're gonna throw it back to you | Oggi sarà il giorno in cui te lo rinfacceranno
[00:16.80] By now you should've somehow realized what you gotta do | A quest'ora avresti già dovuto capire cosa fare
[00:23.00] I don't believe that anybody feels the way I do about you now | Non credo che qualcuno provi quello che provo io per te adesso
[00:33.20] Backbeat, the word is on the street that the fire in your heart is out | Il ritmo incalza, si dice in giro che il fuoco nel tuo cuore si sia spento
[00:39.50] I'm sure you've heard it all before, but you never really had a doubt | Sono sicuro che tu l'abbia già sentito, ma non hai mai dubitato
[00:45.60] I don't believe that anybody feels the way I do about you now | Non credo che qualcuno provi ciò che provo io per te adesso
[00:54.00] And all the roads we have to walk are winding | E tutte le strade che dobbiamo percorrere sono tortuose
[01:00.20] And all the lights that lead us there are blinding | E tutte le luci che ci conducono lì sono accecanti
[01:06.50] Because maybe... You're gonna be the one that saves me | Perché forse... Sarai tu colei che mi salverà
[01:15.00] And after all... You're my wonderwall! | E dopo tutto... Sei il mio punto di riferimento!
    `.trim(),
  },
  {
    id: 'queen-bohemian-rhapsody',
    title: 'Bohemian Rhapsody (Live Aid)',
    artist: 'Queen',
    album: 'Live at Wembley Stadium',
    durationMs: 355000,
    detectedPlayOffsetMs: 54000,
    bpm: 72,
    musicalKey: 'Sib magg (Bb)',
    spotifyUrl: 'https://open.spotify.com/track/7tFiyTwD0nx5a1eklYtX2J',
    rawLrc: `
[00:00.00] Is this the real life? Is this just fantasy? | È questa la vita reale? O è solo fantasia?
[00:16.80] Open your eyes, look up to the skies and see | Apri gli occhi, guarda su verso il cielo e guarda
[00:27.50] I'm just a poor boy, I need no sympathy | Sono solo un povero ragazzo, non cerco pietà
[00:54.00] Mama, just killed a man | Mamma, ho appena ucciso un uomo
[01:01.00] Put a gun against his head, pulled my trigger, now he's dead | Gli ho puntato una pistola alla testa, ho premuto il grilletto, ora è morto
[01:13.00] Mama, life had just begun | Mamma, la vita era appena iniziata
[01:21.00] But now I've gone and thrown it all away | Ma adesso me ne sono andato e ho buttato tutto al vento
[01:28.50] Mama, ooh, didn't mean to make you cry | Mamma, ooh, non volevo farti piangere
[01:38.20] If I'm not back again this time tomorrow | Se non sarò tornato a quest'ora domani
[01:43.50] Carry on, carry on as if nothing really matters | Va' avanti, va' avanti come se nulla contasse davvero
    `.trim(),
  },
];

export const CONCERT_SONGS: ConcertSong[] = RAW_CONCERT_SONGS.map((s) => ({
  ...s,
  lines: parseLrc(s.rawLrc, s.durationMs),
}));
