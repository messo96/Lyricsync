import 'package:flutter/material.dart';

/// Ambienti acustici per la calibrazione automatica del campionamento microfonico e filtri
enum ListeningEnvironment {
  casa(
    id: 'casa',
    label: 'Casa / Silenzio',
    shortLabel: 'CASA',
    icon: Icons.home_rounded,
    badgeColor: Color(0xFF10B981), // Verde smeraldo calmo
    description: 'Basso rumore · Campionamento ottimizzato (4.8s) ad alta fedeltà mono per cassa o TV vicina',
    sampleDurationMs: 4800,
    bitRate: 128000,
    latencyOffsetMs: -150,
  ),
  alChiuso(
    id: 'al_chiuso',
    label: 'Al chiuso con persone',
    shortLabel: 'AL CHIUSO',
    icon: Icons.groups_rounded,
    badgeColor: Color(0xFF38BDF8), // Celeste calmo
    description: 'Locale, festa, bar · Filtro per voci di fondo, brusio e riverbero indoor (6.0s)',
    sampleDurationMs: 6000,
    bitRate: 128000,
    latencyOffsetMs: 0,
  ),
  concerto(
    id: 'concerto',
    label: 'Live Concert',
    shortLabel: 'LIVE CONCERT',
    icon: Icons.festival_rounded,
    badgeColor: Color(0xFFF59E0B), // Ambra calda
    description: 'Stadio, concerto, arena · Filtro anti-distorsione per boato folla e acustica da palco (7.5s)',
    sampleDurationMs: 7500,
    bitRate: 128000,
    latencyOffsetMs: 350,
  );

  final String id;
  final String label;
  final String shortLabel;
  final IconData icon;
  final Color badgeColor;
  final String description;
  final int sampleDurationMs;
  final int bitRate;
  final int latencyOffsetMs;

  const ListeningEnvironment({
    required this.id,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.badgeColor,
    required this.description,
    required this.sampleDurationMs,
    required this.bitRate,
    required this.latencyOffsetMs,
  });

  static ListeningEnvironment fromId(String? id) {
    return ListeningEnvironment.values.firstWhere(
      (e) => e.id == id,
      orElse: () => ListeningEnvironment.concerto,
    );
  }
}
