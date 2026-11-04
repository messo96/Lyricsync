import 'package:flutter/material.dart';

class SpotifyIconButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const SpotifyIconButton({
    super.key,
    required this.onTap,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(size * 0.28),
      splashColor: const Color(0xFF1DB954).withValues(alpha: 0.3),
      child: Tooltip(
        message: 'Apri su Spotify',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1DB954).withValues(alpha: 0.35),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.28),
            child: Image.asset(
              'assets/icons/spotify_logo.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF1DB954),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.music_note, color: Colors.black, size: 18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
