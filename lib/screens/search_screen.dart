import 'package:flutter/material.dart';
import '../models/synced_song.dart';
import '../services/music_recognition_service.dart';
import '../theme/app_theme.dart';
import 'lyrics_teleprompter_screen.dart';

class SearchScreen extends StatefulWidget {
  final MusicRecognitionService recognitionService;

  const SearchScreen({
    super.key,
    required this.recognitionService,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SyncedSong> _results = [];
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) {
      setState(() {
        _results = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final matches = await widget.recognitionService.searchLrclib(clean);
      if (mounted) {
        setState(() {
          _results = matches;
          _isLoading = false;
          if (matches.isEmpty) {
            _errorMessage = 'Nessun testo sincronizzato trovato per "$clean". Prova con un altro titolo o artista.';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Errore di connessione durante la ricerca dei testi.';
        });
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Cerca Canzone o Testo'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Campo di ricerca
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Es. Fix You, Wonderwall, Blinding Lights...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.accentAmber),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: AppTheme.textSecondary),
                          onPressed: () {
                            _searchController.clear();
                            _performSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF1E293B)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Color(0xFF1E293B)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.accentAmber, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onSubmitted: _performSearch,
                textInputAction: TextInputAction.search,
              ),
            ),

            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accentAmber),
                ),
              ),

            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ),

            // Lista dei risultati
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _results.length,
                separatorBuilder: (_, __) => const Divider(color: Color(0xFF1E293B), height: 1),
                itemBuilder: (context, index) {
                  final song = _results[index];
                  final minutes = song.duration.inMinutes.remainder(60);
                  final seconds = song.duration.inSeconds.remainder(60).toString().padLeft(2, '0');

                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: const Icon(Icons.music_note_rounded, color: AppTheme.accentAmber, size: 22),
                    ),
                    title: Text(
                      song.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      '${song.artist} · $minutes:$seconds',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textMuted),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LyricsTeleprompterScreen(song: song),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

