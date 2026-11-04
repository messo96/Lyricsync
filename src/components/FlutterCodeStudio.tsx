import React, { useState } from 'react';
import { Copy, Check, Download, FileCode2, Layers, Cpu, Radio } from 'lucide-react';
import { FLUTTER_PROJECT_FILES, FlutterCodeFile } from '../data/flutterProjectCode';

export const FlutterCodeStudio: React.FC = () => {
  const [selectedFileId, setSelectedFileId] = useState<string>(FLUTTER_PROJECT_FILES[0].id);
  const [copiedId, setCopiedId] = useState<string | null>(null);

  const activeFile: FlutterCodeFile =
    FLUTTER_PROJECT_FILES.find((f) => f.id === selectedFileId) || FLUTTER_PROJECT_FILES[0];

  const handleCopyFile = async (file: FlutterCodeFile) => {
    try {
      await navigator.clipboard.writeText(file.content);
      setCopiedId(file.id);
      setTimeout(() => setCopiedId(null), 2000);
    } catch {
      // Fallback copy
    }
  };

  const handleDownloadAllFlutterFiles = () => {
    const bundleText = FLUTTER_PROJECT_FILES.map(
      (f) =>
        `// ==========================================\n// FILE: ${f.path}\n// ${f.description}\n// ==========================================\n\n${f.content}\n\n`
    ).join('\n');

    const blob = new Blob([bundleText], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = 'aurasync_flutter_complete_project.txt';
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  };

  return (
    <section
      id="flutter-architecture"
      className="space-y-6"
      aria-label="Architettura e Codice Sorgente Flutter"
    >
      {/* Architecture Pipeline Overview */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="rounded-2xl bg-slate-900/90 border border-slate-800 p-5">
          <div className="flex items-center gap-2.5 text-amber-400 text-xs font-semibold">
            <Radio className="w-4 h-4 shrink-0" />
            <span>01. Cattura & Impronta Acustica</span>
          </div>
          <h3 className="text-base font-bold text-slate-100 mt-2">
            Audio PCM + Offset Ambientale
          </h3>
          <p className="text-xs text-slate-400 mt-1.5 leading-relaxed">
            Il pacchetto <code className="text-slate-200">record</code> cattura 4 secondi di audio
            dalla stanza. ACRCloud / AudD restituisce non solo titolo e artista, ma anche{' '}
            <code className="text-amber-300">play_offset_ms</code> (es. il brano nel locale è già a
            01:14.20).
          </p>
        </div>

        <div className="rounded-2xl bg-slate-900/90 border border-slate-800 p-5">
          <div className="flex items-center gap-2.5 text-sky-400 text-xs font-semibold">
            <Cpu className="w-4 h-4 shrink-0" />
            <span>02. Compensazione Latenza di Rete</span>
          </div>
          <h3 className="text-base font-bold text-slate-100 mt-2">
            Allineamento al Millisecondo
          </h3>
          <p className="text-xs text-slate-400 mt-1.5 leading-relaxed">
            Il motore <code className="text-slate-200">RealtimeLyricsController</code> calcola{' '}
            <code className="text-sky-300">
              posizione = play_offset_ms + network_latency + stopwatch.elapsed
            </code>
            , agganciando immediatamente la riga cantata in quel preciso istante.
          </p>
        </div>

        <div className="rounded-2xl bg-slate-900/90 border border-slate-800 p-5">
          <div className="flex items-center gap-2.5 text-emerald-400 text-xs font-semibold">
            <Layers className="w-4 h-4 shrink-0" />
            <span>03. Rendering Karaoke 60/120 FPS</span>
          </div>
          <h3 className="text-base font-bold text-slate-100 mt-2">
            LRCLIB & ScrollablePositionedList
          </h3>
          <p className="text-xs text-slate-400 mt-1.5 leading-relaxed">
            Scarica gratuitamente i file <code className="text-slate-200">.lrc</code> da LRCLIB,
            esegue il parsing dei timestamp <code className="text-emerald-300">[mm:ss.xx]</code> e
            scorre automaticamente la vista mantenendo il verso attivo al centro dello schermo.
          </p>
        </div>
      </div>

      {/* Multi-file Code Explorer */}
      <div className="rounded-2xl bg-slate-900 border border-slate-800 overflow-hidden">
        <div className="p-4 border-b border-slate-800 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
          <div>
            <h2 className="text-base font-bold text-slate-100">
              Progetto Flutter Completo (Dart 3 + Material 3)
            </h2>
            <p className="text-xs text-slate-400 mt-0.5">
              Esplora, copia o scarica i moduli pronti per <code className="text-slate-200">flutter run</code> su iOS e Android.
            </p>
          </div>

          <div className="flex items-center gap-2 shrink-0">
            <button
              type="button"
              onClick={() => handleCopyFile(activeFile)}
              className="min-h-[40px] px-3.5 py-2 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-100 border border-slate-700 text-xs font-medium flex items-center gap-2 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
            >
              {copiedId === activeFile.id ? (
                <>
                  <Check className="w-4 h-4 text-emerald-400" />
                  <span>File Copiato</span>
                </>
              ) : (
                <>
                  <Copy className="w-4 h-4 text-slate-400" />
                  <span>Copia {activeFile.filename}</span>
                </>
              )}
            </button>

            <button
              type="button"
              onClick={handleDownloadAllFlutterFiles}
              className="min-h-[40px] px-3.5 py-2 rounded-xl bg-amber-500 hover:bg-amber-400 text-slate-950 font-semibold text-xs flex items-center gap-2 transition-colors whitespace-nowrap shrink-0 cursor-pointer"
            >
              <Download className="w-4 h-4" />
              <span>Scarica Sorgenti Flutter</span>
            </button>
          </div>
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-12">
          {/* File Tree Sidebar */}
          <div className="lg:col-span-4 border-b lg:border-b-0 lg:border-r border-slate-800 p-3 space-y-1.5 bg-slate-950/50">
            {FLUTTER_PROJECT_FILES.map((file) => {
              const isSelected = file.id === activeFile.id;
              return (
                <button
                  key={file.id}
                  type="button"
                  onClick={() => setSelectedFileId(file.id)}
                  className={`w-full text-left p-3 rounded-xl transition-colors cursor-pointer flex items-start gap-3 ${
                    isSelected
                      ? 'bg-slate-800/90 border border-amber-500/40 text-slate-50'
                      : 'hover:bg-slate-900 text-slate-400 border border-transparent'
                  }`}
                >
                  <FileCode2
                    className={`w-4 h-4 mt-0.5 shrink-0 ${
                      isSelected ? 'text-amber-400' : 'text-slate-500'
                    }`}
                  />
                  <div className="min-w-0 flex-1">
                    <div className="flex items-center justify-between gap-2">
                      <span className="font-mono text-xs font-semibold truncate">
                        {file.path}
                      </span>
                      <span className="font-mono text-[11px] text-slate-500 tabular-nums shrink-0">
                        {file.linesOfCode} righe
                      </span>
                    </div>
                    <p className="text-[11px] text-slate-400 mt-1 line-clamp-2">
                      {file.description}
                    </p>
                  </div>
                </button>
              );
            })}
          </div>

          {/* Code Viewer */}
          <div className="lg:col-span-8 bg-slate-950 p-5 overflow-x-auto">
            <div className="flex items-center justify-between pb-3 mb-3 border-b border-slate-800/80 text-xs text-slate-400 font-mono">
              <span>{activeFile.path}</span>
              <span>Linguaggio: {activeFile.language.toUpperCase()}</span>
            </div>
            <pre
              className="font-mono text-xs leading-relaxed text-slate-200 overflow-x-auto"
              data-testid="flutter-code-display"
            >
              <code>{activeFile.content}</code>
            </pre>
          </div>
        </div>
      </div>
    </section>
  );
};
