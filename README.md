# 🎤 LyricSync (Live Concert Edition)

**LyricSync** è un'applicazione nativa **Flutter** creata appositamente per chi partecipa a concerti ed eventi dal vivo e vuole cantare ogni canzone a squarciagola anche quando non ricorda il testo o fatica a seguire il tempo dell'artista sul palco.

L'applicazione ascolta la musica ambientale dal microfono, individua la canzone e la posizione temporale esatta dell'esecuzione (`play_offset`), e fa scorrere un **teleprompter per concerti ad alto contrasto** sincronizzato parola per parola o verso per verso con file `.LRC`.

---

## 🌟 Funzionalità Principali

### 1. 🎙️ Rilevamento Musicale Live da Microfono
- Cattura audio a 44.1 kHz con filtraggio del rumore e visualizzatore decibel ad anelli pulsanti.
- Calcolo automatico della latenza tra il suono emesso sul palco e la ricezione del microfono.
- Cronologia persistente locale dei brani riconosciuti durante i tuoi concerti.

### 2. ⚡ Teleprompter da Palco Sincronizzato (Live Teleprompter)
- **Auto-centratura intelligente**: grazie a `ScrollablePositionedList`, la riga cantata in quel preciso secondo si posiziona automaticamente a circa il 35% dello schermo, mantenendo lo sguardo alla naturale altezza di lettura.
- **Evidenziazione Karaokistica**: il verso attivo brilla con un'aura dorata ad alto contrasto, corredato da barra di avanzamento del verso e scorrimento parola per parola.
- **Traduzione Italiana Contestuale**: possibilità di attivare o disattivare istantaneamente la traduzione in italiano sotto ciascun verso originale.
- **Scalatura Caratteri (`AA-` / `AA+`)**: regola la dimensione dei caratteri con un tocco per una leggibilità immediata anche con il braccio alzato in mezzo alla folla.

### 3. 🏟️ Compensatore di Ritardo Stadio (Sound Travel Delay)
La velocità del suono nell'aria è di ~343 m/s (circa 300 ms di ritardo ogni 100 metri):
- Pulsanti di micro-calibrazione rapidi: **`-500ms`**, **`-100ms`**, **`+100ms`**, **`+500ms`** e reset rapido.
- Preset acustici: *Sotto il palco (0ms)*, *Prato centrale (+250ms)*, *Gradinata (+500ms)*.

### 4. 🔦 Modalità Concert Glowstick (Light Show)
- Trasforma la parte superiore dello smartphone in una luce da concerto (Gold, Cyan, Hot Pink, Emerald, Violet) che pulsa al ritmo della musica mentre leggi il testo.

### 5. 🔍 Ricerca & Setlist Offline Anthems
- Integrazione con l'API gratuita e aperta **LRCLIB** per cercare qualsiasi brano o verso cantato.
- Catalogo offline pre-caricato per gli inni da stadio più cantati al mondo (Coldplay, Oasis, Queen, Måneskin, The Weeknd) in caso di assenza di rete cellulare negli stadi affollati.

---

## 📁 Architettura del Progetto

```
lib/
├── data/
│   └── concert_setlists.dart        # Catalogo offline inni da stadio e testi .LRC sincronizzati
├── models/
│   └── synced_song.dart             # Modelli LyricLine, LyricWord, SyncedSong e parser .LRC nativo
├── screens/
│   ├── home_screen.dart             # Schermata radar con visualizzatore audio, preset stadio e setlist
│   ├── lyrics_teleprompter_screen.dart # Teleprompter immersivo ad alto contrasto con auto-scroll a 60fps
│   └── search_screen.dart           # Ricerca rapida brani e testi online (LRCLIB) e offline
├── services/
│   ├── audio_recorder_service.dart  # Registrazione microfonica e monitoraggio decibel (record)
│   ├── music_recognition_service.dart # Riconoscimento audio, offset matching e cache SharedPreferences
│   └── realtime_lyrics_sync_controller.dart # Motore di sincronizzazione a precisione millisecondo
├── theme/
│   └── app_theme.dart               # Palette OLED Dark ad altissimo contrasto per ambienti notturni
└── main.dart                        # Entry-point dell'applicazione
```

---

## 🚀 Requisiti e Avvio

### Prerequisiti
- **Flutter SDK**: `>= 3.20.0`
- **Dart SDK**: `>= 3.8.0`
- Dispositivo Android (minSdk 21) o iOS (12.0+) o macOS

### Installazione ed esecuzione

```bash
# 1. Recupera le dipendenze
flutter pub get

# 2. Esegui i test di validazione
flutter test

# 3. Avvia l'applicazione sul tuo dispositivo o simulatore
flutter run
```

---

## 🔒 Permessi di Sistema

L'applicazione include già le configurazioni per i permessi necessari:
- **Android (`AndroidManifest.xml`)**: `RECORD_AUDIO`, `INTERNET`, `ACCESS_NETWORK_STATE`, `WAKE_LOCK`.
- **iOS (`Info.plist`)**: `NSMicrophoneUsageDescription`.
- **macOS (`DebugProfile.entitlements`, `Release.entitlements`)**: `audio-input`, `network.client`.
