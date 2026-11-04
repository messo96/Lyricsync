import '../models/synced_song.dart';

class ConcertCatalog {
  static final List<SyncedSong> stadiumAnthems = [
    _coldplayFixYou,
    _oasisWonderwall,
    _queenBohemianRhapsody,
    _maneskinZittiEBuoni,
    _theWeekndBlindingLights,
    _oasisDontLookBackInAnger,
  ];

  static SyncedSong get _coldplayFixYou {
    const rawLrc = '''
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
[01:38.00] (Il pubblico canta in coro con Chris Martin) | (Coro dello stadio ad alta voce)
[01:50.00] And high up above or down below | E lassù in alto o quaggiù in basso
[01:57.00] When you're too in love to let it show | Quando sei troppo innamorato per farlo vedere
[02:04.00] But if you never try, you'll never know | Ma se non ci provi mai, non lo saprai mai
[02:11.00] Just what you're worth | Quanto vali davvero
[02:17.50] Lights will guide you home | Le luci ti guideranno verso casa
[02:26.00] And ignite your bones | E accenderanno le tue ossa
[02:34.50] And I will try to fix you | E io proverò ad aiutarti
[02:46.00] (Esplosione di chitarra elettrica e fuochi d'artificio) | (Assolo di chitarra di Jonny Buckland)
[03:15.00] Tears stream down your face | Le lacrime scendono sul tuo viso
[03:22.00] When you lose something you cannot replace | Quando perdi qualcosa che non puoi sostituire
[03:29.00] Tears stream down your face, and I... | Le lacrime scendono sul tuo viso, ed io...
[03:36.00] Tears stream down your face | Le lacrime scendono sul tuo viso
[03:42.50] I promise you I will learn from my mistakes | Ti prometto che imparerò dai miei errori
[03:49.80] Tears stream down your face, and I... | Le lacrime scendono sul tuo viso, ed io...
[03:57.00] Lights will guide you home | Le luci ti guideranno verso casa
[04:06.00] And ignite your bones | E accenderanno le tue ossa
[04:14.50] And I will try to fix you | E io proverò a farti stare bene
''';
    const totalDuration = Duration(minutes: 4, seconds: 55);
    return SyncedSong(
      id: 'coldplay-fix-you',
      title: 'Fix You (Live in Concert)',
      artist: 'Coldplay',
      album: 'Music of the Spheres World Tour',
      duration: totalDuration,
      detectedPlayOffset: const Duration(seconds: 14),
      matchedAt: DateTime.now(),
      bpm: 138,
      musicalKey: 'Mib magg (Eb)',
      isLiveConcertVersion: true,
      rawLrc: rawLrc,
      lyrics: SyncedSong.parseLrc(rawLrc, totalDuration),
    );
  }

  static SyncedSong get _oasisWonderwall {
    const rawLrc = '''
[00:00.00] (Accordi di chitarra acustica - Liam Gallagher al microfono) | (Intro acustica live)
[00:10.50] Today is gonna be the day that they're gonna throw it back to you | Oggi sarà il giorno in cui te lo rinfacceranno
[00:16.80] By now you should've somehow realized what you gotta do | A quest'ora avresti già dovuto capire cosa fare
[00:23.00] I don't believe that anybody feels the way I do about you now | Non credo che qualcuno provi quello che provo io per te adesso
[00:33.20] Backbeat, the word is on the street that the fire in your heart is out | Il ritmo incalza, si dice in giro che il fuoco nel tuo cuore si sia spento
[00:39.50] I'm sure you've heard it all before, but you never really had a doubt | Sono sicuro che tu l'abbia già sentito, ma non hai mai dubitato
[00:45.60] I don't believe that anybody feels the way I do about you now | Non credo che qualcuno provi ciò che provo io per te adesso
[00:54.00] And all the roads we have to walk are winding | E tutte le strade che dobbiamo percorrere sono tortuose
[01:00.20] And all the lights that lead us there are blinding | E tutte le luci che ci conducono lì sono accecanti
[01:06.50] There are many things that I would like to say to you | Ci sono molte cose che vorrei dirti
[01:11.80] But I don't know how | Ma non so proprio come farlo
[01:16.00] Because maybe... | Perché forse...
[01:21.50] You're gonna be the one that saves me | Sarai tu colei che mi salverà
[01:28.00] And after all... | E dopo tutto...
[01:34.00] You're my wonderwall! | Sei il mio punto di riferimento!
[01:45.00] Today was gonna be the day, but they'll never throw it back to you | Oggi doveva essere il giorno, ma non te lo rinfacceranno
[01:51.50] By now you should've somehow realized what you're not to do | Ormai avresti dovuto capire cosa non fare
[01:57.80] I don't believe that anybody feels the way I do about you now | Non credo che nessuno provi ciò che provo io per te adesso
[02:08.50] Because maybe... | Perché forse...
[02:14.00] You're gonna be the one that saves me | Sarai tu colei che mi salverà
[02:20.50] And after all... | E dopotutto...
[02:26.50] You're my wonderwall! | Sei il mio porto sicuro!
''';
    const totalDuration = Duration(minutes: 4, seconds: 18);
    return SyncedSong(
      id: 'oasis-wonderwall',
      title: 'Wonderwall (Live at Wembley)',
      artist: 'Oasis',
      album: 'Live Forever Concert Tour',
      duration: totalDuration,
      detectedPlayOffset: const Duration(seconds: 10),
      matchedAt: DateTime.now(),
      bpm: 87,
      musicalKey: 'Fa# min (F#m)',
      isLiveConcertVersion: true,
      rawLrc: rawLrc,
      lyrics: SyncedSong.parseLrc(rawLrc, totalDuration),
    );
  }

  static SyncedSong get _queenBohemianRhapsody {
    const rawLrc = '''
[00:00.00] Is this the real life? Is this just fantasy? | È questa la vita reale? O è solo fantasia?
[00:08.50] Caught in a landslide, no escape from reality | Travolto da una frana, nessuna via di fuga dalla realtà
[00:16.80] Open your eyes, look up to the skies and see | Apri gli occhi, guarda su verso il cielo e guarda
[00:27.50] I'm just a poor boy, I need no sympathy | Sono solo un povero ragazzo, non cerco pietà
[00:33.80] Because I'm easy come, easy go, little high, little low | Perché vado e vengo facilmente, un po' su, un po' giù
[00:43.00] Any way the wind blows doesn't really matter to me, to me | Comunque soffi il vento, per me non ha importanza
[00:54.00] Mama, just killed a man | Mamma, ho appena ucciso un uomo
[01:01.00] Put a gun against his head, pulled my trigger, now he's dead | Gli ho puntato una pistola alla testa, ho premuto il grilletto, ora è morto
[01:13.00] Mama, life had just begun | Mamma, la vita era appena iniziata
[01:21.00] But now I've gone and thrown it all away | Ma adesso me ne sono andato e ho buttato tutto al vento
[01:28.50] Mama, ooh, didn't mean to make you cry | Mamma, ooh, non volevo farti piangere
[01:38.20] If I'm not back again this time tomorrow | Se non sarò tornato a quest'ora domani
[01:43.50] Carry on, carry on as if nothing really matters | Va' avanti, va' avanti come se nulla contasse davvero
[01:54.00] Too late, my time has come | Troppo tardi, la mia ora è giunta
[02:01.20] Sends shivers down my spine, body's aching all the time | Brividi lungo la schiena, il corpo mi fa male continuamente
[02:11.00] Goodbye, everybody, I've got to go | Addio a tutti, me ne devo andare
[02:18.00] Gotta leave you all behind and face the truth | Devo lasciarvi tutti indietro e affrontare la verità
[02:26.50] Mama, ooh, I don't wanna die | Mamma, ooh, non voglio morire
[02:35.50] I sometimes wish I'd never been born at all! | A volte vorrei non essere mai nato affatto!
[03:02.00] (Scena Opera: I see a little silhouetto of a man) | (Coro d'opera al centro dello stadio)
[03:07.50] Scaramouche, Scaramouche, will you do the Fandango? | Scaramouche, ballerai il Fandango?
[03:12.00] Thunderbolt and lightning, very, very frightening me! | Fulmini e saette, mi spaventano moltissimo!
[03:16.80] Galileo, Galileo, Galileo Figaro magnifico! | Galileo Figaro magnifico!
''';
    const totalDuration = Duration(minutes: 5, seconds: 55);
    return SyncedSong(
      id: 'queen-bohemian-rhapsody',
      title: 'Bohemian Rhapsody (Live Aid)',
      artist: 'Queen',
      album: 'Live at Wembley Stadium',
      duration: totalDuration,
      detectedPlayOffset: const Duration(seconds: 54),
      matchedAt: DateTime.now(),
      bpm: 72,
      musicalKey: 'Sib magg (Bb)',
      isLiveConcertVersion: true,
      rawLrc: rawLrc,
      lyrics: SyncedSong.parseLrc(rawLrc, totalDuration),
    );
  }

  static SyncedSong get _maneskinZittiEBuoni {
    const rawLrc = '''
[00:00.00] (Riff di basso distorcente di Victoria De Angelis) | (Intro rock live)
[00:08.50] Loro non sanno di che parlo | Loro non sanno di cosa parlo
[00:11.80] Voi siete sporchi fra' di fango | Voi siete coperti di fango
[00:15.00] Giallo di siga fra le dita | Macchie gialle di fumo tra le dita
[00:18.20] Io con la siga camminando | Io con la sigaretta in mano cammino
[00:21.50] Scusami ma ci credo tanto | Scusatemi ma ci credo davvero tanto
[00:24.80] Che posso fare questo salto | Che posso compiere questo salto
[00:28.00] E anche se la strada è in salita | E anche se la salita è ripida
[00:31.20] Per questo ora mi sto allenando | Mi sto preparando per questo momento
[00:35.00] E buonasera signore e signori | Buonasera al pubblico dello stadio
[00:38.20] Fuori gli attori | Fate spazio a chi recita
[00:41.50] Vi conviene non fare più errori | Non vi conviene sbagliare ancora
[00:44.80] Vi conviene stare zitti e buoni | Vi conviene tacere e fare i bravi
[00:48.20] Qui la gente è strana tipo spacciatori | Qui intorno ci sono persone imprevedibili
[00:51.50] Troppe notti stavo chiuso fuori | Quante notti rimasto ad aspettare fuori
[00:54.80] Mo li svaligio 'sti cassetti | Adesso mi prendo tutto ciò che mi spetta
[00:57.90] 'Sti condomini con mille sfaccettature | In mezzo a palazzoni e vite complicate
[01:01.50] Sono fuori di testa, ma diverso da loro! | Sono pazzo, ma totalmente diverso da loro!
[01:08.00] E tu sei fuori di testa, ma diversa da loro! | E anche tu sei folle, ma diversa da tutti!
[01:14.50] Siamo fuori di testa, ma diversi da loro! | Siamo pazzi e liberi, diversi dalla folla!
[01:21.00] Siamo fuori di testa, ma diversi da loro! | Cantiamo tutti insieme a squarciagola!
''';
    const totalDuration = Duration(minutes: 3, seconds: 14);
    return SyncedSong(
      id: 'maneskin-zitti-e-buoni',
      title: 'Zitti e Buoni (Live San Siro)',
      artist: 'Måneskin',
      album: 'Teatro d’Ira Tour',
      duration: totalDuration,
      detectedPlayOffset: const Duration(seconds: 35),
      matchedAt: DateTime.now(),
      bpm: 134,
      musicalKey: 'Mi min (Em)',
      isLiveConcertVersion: true,
      rawLrc: rawLrc,
      lyrics: SyncedSong.parseLrc(rawLrc, totalDuration),
    );
  }

  static SyncedSong get _theWeekndBlindingLights {
    const rawLrc = '''
[00:00.00] (Sintetizzatori synthwave anni 80 ad alto volume) | (Intro sintetizzatore da stadio)
[00:13.50] Yeah... | Yeah...
[00:16.80] I've been tryna call | Ho provato a chiamarti
[00:19.50] I've been on my own for long enough | Sono rimasto da solo per troppo tempo
[00:24.00] Maybe you can show me how to love, maybe | Forse tu puoi mostrarmi come amare, forse
[00:31.50] I'm going through withdrawals | Sto affrontando una crisi di astinenza
[00:36.00] You don't even have to do too much | Non devi nemmeno fare un granché
[00:40.00] You can turn me on with just a touch, baby | Ti basta solo un tocco per accendermi
[00:47.50] I look around and Sin City's cold and empty | Mi guardo attorno e la città è gelida e deserta
[00:53.20] No one's around to judge me | Non c'è nessuno nei paraggi a giudicarmi
[00:57.00] I can't see clearly when you're gone | Non riesco a vedere nitidamente quando sei lontana
[01:03.00] I said, ooh, I'm blinded by the lights | Ho detto: ooh, sono accecato dalle luci dei riflettori
[01:09.50] No, I can't sleep until I feel your touch | No, non posso chiudere occhio finché non sento il tuo tocco
[01:17.50] I said, ooh, I'm drowning in the night | Ho detto: ooh, sto annegando dentro la notte
[01:24.50] Oh, when I'm like this, you're the one I trust | Quando mi sento così, sei l'unica di cui mi fido
''';
    const totalDuration = Duration(minutes: 3, seconds: 20);
    return SyncedSong(
      id: 'the-weeknd-blinding-lights',
      title: 'Blinding Lights (After Hours Stadium Tour)',
      artist: 'The Weeknd',
      album: 'After Hours Live',
      duration: totalDuration,
      detectedPlayOffset: const Duration(seconds: 47),
      matchedAt: DateTime.now(),
      bpm: 171,
      musicalKey: 'Fa min (Fm)',
      isLiveConcertVersion: true,
      rawLrc: rawLrc,
      lyrics: SyncedSong.parseLrc(rawLrc, totalDuration),
    );
  }

  static SyncedSong get _oasisDontLookBackInAnger {
    const rawLrc = '''
[00:00.00] (Intro con accordi di piano alla John Lennon) | (Intro pianoforte live)
[00:15.50] Slip inside the eye of your mind | Scivola nell'occhio della tua mente
[00:20.50] Don't you know you might find a better place to play? | Non sai che potresti trovare un posto migliore per giocare?
[00:29.80] You said that you'd never been | Dicevi di non esserci mai stato prima
[00:35.00] But all the things that you've seen will slowly fade away | Ma tutte le cose che hai visto svaniranno lentamente
[00:44.20] So I start a revolution from my bed | Così inizio una rivoluzione dal mio letto
[00:51.50] 'Cause you said the brains I had went to my head | Perché dicevi che mi ero montato la testa
[00:58.80] Step outside, summertime's in bloom | Fai un passo fuori, l'estate sta fiorendo
[01:05.50] Stand up beside the fireplace, take that look from off your face | Alzati vicino al camino, togliti quell'espressione dal viso
[01:13.20] You ain't ever gonna burn my heart out! | Non riuscirai mai a spegnere il fuoco nel mio cuore!
[01:21.00] And so Sally can wait | E così Sally può attendere
[01:27.50] She knows it's too late as we're walking on by | Sa che è troppo tardi mentre proseguiamo oltre
[01:34.50] Her soul slides away | La sua anima scivola via
[01:42.00] But don't look back in anger, I heard you say! | Ma non guardare al passato con rabbia, ti ho sentito dire!
''';
    const totalDuration = Duration(minutes: 4, seconds: 48);
    return SyncedSong(
      id: 'oasis-dont-look-back-in-anger',
      title: "Don't Look Back in Anger (Live Anthem)",
      artist: 'Oasis',
      album: 'Familiar to Millions',
      duration: totalDuration,
      detectedPlayOffset: const Duration(seconds: 44),
      matchedAt: DateTime.now(),
      bpm: 84,
      musicalKey: 'Do magg (C)',
      isLiveConcertVersion: true,
      rawLrc: rawLrc,
      lyrics: SyncedSong.parseLrc(rawLrc, totalDuration),
    );
  }
}

