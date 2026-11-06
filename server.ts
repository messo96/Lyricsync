import express from 'express';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';
import dotenv from 'dotenv';

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function startServer() {
  const app = express();
  const PORT = 3000;

  app.use(express.json({ limit: '10mb' }));

  // Endpoint to read the live updated Flutter Dart files directly from /lib
  app.get('/api/flutter-files', async (_req, res) => {
    try {
      const filesToRead = [
        {
          id: 'pulsing_waveform',
          path: 'lib/widgets/pulsing_waveform.dart',
          title: 'lib/widgets/pulsing_waveform.dart (Hyper-Fluid Kinetic Orb 120 FPS)',
        },
        {
          id: 'home_screen',
          path: 'lib/screens/home_screen.dart',
          title: 'lib/screens/home_screen.dart (Pipeline Continua Zero-Blocchi)',
        },
        {
          id: 'audio_recorder_service',
          path: 'lib/services/audio_recorder_service.dart',
          title: 'lib/services/audio_recorder_service.dart (Transizione Continua Chunks)',
        },
      ];

      const results = await Promise.all(
        filesToRead.map(async (item) => {
          const fullPath = path.join(__dirname, item.path);
          const content = await fs.readFile(fullPath, 'utf-8');
          return { ...item, content };
        })
      );

      res.json({ files: results });
    } catch (error) {
      res.status(500).json({ error: String(error) });
    }
  });

  if (process.env.NODE_ENV !== 'production') {
    const { createServer: createViteServer } = await import('vite');
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(__dirname, 'dist');
    app.use(express.static(distPath));
    app.get('*', (_req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`LyricSync server running on http://0.0.0.0:${PORT}`);
  });
}

startServer();
