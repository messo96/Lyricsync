import React from 'react';

interface AlbumArtworkProps {
  motif: 'milan-rain' | 'solar-bronze' | 'mediterranean-wave' | 'analog-reel' | 'custom';
  title: string;
  artist: string;
  accentColor?: string;
  className?: string;
}

export const AlbumArtwork: React.FC<AlbumArtworkProps> = ({
  motif,
  title,
  artist,
  accentColor = '#f59e0b',
  className = 'w-20 h-20',
}) => {
  return (
    <div
      className={`relative overflow-hidden rounded-2xl bg-slate-900 border border-slate-800/90 select-none shrink-0 ${className}`}
      role="img"
      aria-label={`Copertina album ${title} di ${artist}`}
    >
      {motif === 'milan-rain' && (
        <svg viewBox="0 0 200 200" className="w-full h-full">
          <defs>
            <linearGradient id="milanBg" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#090d16" />
              <stop offset="60%" stopColor="#1e293b" />
              <stop offset="100%" stopColor="#451a03" />
            </linearGradient>
            <radialGradient id="milanGlow" cx="70%" cy="35%" r="50%">
              <stop offset="0%" stopColor="#f59e0b" stopOpacity="0.65" />
              <stop offset="100%" stopColor="#f59e0b" stopOpacity="0" />
            </radialGradient>
          </defs>
          <rect width="200" height="200" fill="url(#milanBg)" />
          <circle cx="140" cy="70" r="85" fill="url(#milanGlow)" />
          {/* Architectural arches & reflections */}
          <path d="M20 200 L20 95 Q55 60 90 95 L90 200 Z" fill="#0f172a" opacity="0.85" />
          <path d="M105 200 L105 110 Q140 75 175 110 L175 200 Z" fill="#0f172a" opacity="0.7" />
          <line x1="0" y1="155" x2="200" y2="155" stroke="#f59e0b" strokeWidth="1.5" strokeOpacity="0.4" />
          <line x1="25" y1="170" x2="175" y2="170" stroke="#fbbf24" strokeWidth="1" strokeOpacity="0.3" />
          <circle cx="140" cy="70" r="14" fill="#fbbf24" opacity="0.9" />
        </svg>
      )}

      {motif === 'solar-bronze' && (
        <svg viewBox="0 0 200 200" className="w-full h-full">
          <defs>
            <linearGradient id="solarBg" x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor="#090d16" />
              <stop offset="100%" stopColor="#172554" />
            </linearGradient>
          </defs>
          <rect width="200" height="200" fill="url(#solarBg)" />
          <circle cx="100" cy="100" r="68" fill="none" stroke="#38bdf8" strokeWidth="1.5" strokeOpacity="0.35" />
          <circle cx="100" cy="100" r="48" fill="none" stroke="#38bdf8" strokeWidth="2" strokeOpacity="0.6" />
          <circle cx="100" cy="100" r="24" fill="#0284c7" opacity="0.85" />
          <path d="M32 100 L168 100" stroke="#7dd3fc" strokeWidth="1" strokeOpacity="0.4" />
          <path d="M100 32 L100 168" stroke="#7dd3fc" strokeWidth="1" strokeOpacity="0.4" />
        </svg>
      )}

      {motif === 'mediterranean-wave' && (
        <svg viewBox="0 0 200 200" className="w-full h-full">
          <defs>
            <linearGradient id="medBg" x1="0" y1="0" x2="1" y2="1">
              <stop offset="0%" stopColor="#0c192c" />
              <stop offset="55%" stopColor="#1e3a8a" />
              <stop offset="100%" stopColor="#7c2d12" />
            </linearGradient>
          </defs>
          <rect width="200" height="200" fill="url(#medBg)" />
          <circle cx="100" cy="78" r="36" fill="#fb923c" opacity="0.85" />
          <path d="M0 125 Q50 108 100 125 T200 125 L200 200 L0 200 Z" fill="#0f172a" opacity="0.82" />
          <path d="M0 150 Q50 135 100 150 T200 150 L200 200 L0 200 Z" fill="#090d16" opacity="0.95" />
          <path d="M35 140 Q100 128 165 140" stroke="#fdba74" strokeWidth="1.5" fill="none" strokeOpacity="0.5" />
        </svg>
      )}

      {motif === 'analog-reel' && (
        <svg viewBox="0 0 200 200" className="w-full h-full">
          <rect width="200" height="200" fill="#1c1917" />
          <circle cx="65" cy="100" r="42" fill="#292524" stroke="#eab308" strokeWidth="2" strokeOpacity="0.65" />
          <circle cx="135" cy="100" r="42" fill="#292524" stroke="#eab308" strokeWidth="2" strokeOpacity="0.65" />
          <circle cx="65" cy="100" r="12" fill="#eab308" opacity="0.85" />
          <circle cx="135" cy="100" r="12" fill="#eab308" opacity="0.85" />
          <line x1="65" y1="142" x2="135" y2="142" stroke="#fef08a" strokeWidth="1.5" strokeOpacity="0.5" />
        </svg>
      )}

      {motif === 'custom' && (
        <svg viewBox="0 0 200 200" className="w-full h-full">
          <rect width="200" height="200" fill="#0f172a" />
          <circle cx="100" cy="100" r="64" fill="none" stroke={accentColor} strokeWidth="2" strokeOpacity="0.5" />
          <circle cx="100" cy="100" r="22" fill={accentColor} opacity="0.8" />
        </svg>
      )}
    </div>
  );
};
