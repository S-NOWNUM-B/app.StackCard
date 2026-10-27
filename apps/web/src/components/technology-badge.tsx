'use client';
import { useEffect, useState } from 'react';
import { findTechnology } from '@/lib/technology-catalog';

// Path data Simple Icons грузится одним ленивым chunk при первом известном знаке.
let loadedPaths: Record<string, string> | null = null;
let pendingPaths: Promise<Record<string, string>> | null = null;

function useTechnologyPaths(needed: boolean) {
  const [paths, setPaths] = useState(loadedPaths);
  useEffect(() => {
    if (!needed || paths) return;
    let alive = true;
    pendingPaths ??= import('@/lib/technology-icon-paths').then(
      (module) => (loadedPaths = module.technologyIconPaths),
    );
    pendingPaths.then(
      (value) => alive && setPaths(value),
      () => {
        // Ошибка chunk не ломает строку: остаётся нейтральная плашка, повтор при следующем показе.
        pendingPaths = null;
      },
    );
    return () => {
      alive = false;
    };
  }, [needed, paths]);
  return paths;
}

// Многоцветные оригиналы Design v2 рисуются без перекраски, как в mobile.
const multicolor = new Set(['flutter', 'dart']);

// Иконка на тёмной плашке 24px: известная технология — фирменный знак, иначе папка.
export function TechnologyIcon({ label }: { label: string }) {
  const info = findTechnology(label);
  const paths = useTechnologyPaths(!!info?.slug);
  let glyph;
  if (!info)
    glyph = (
      <img
        className="technology-fallback"
        src="/icons/lucide/folder.svg"
        alt=""
        width={16}
        height={16}
      />
    );
  else if (!info.slug) {
    const name = info.title.toLowerCase();
    glyph = multicolor.has(name) ? (
      <img src={`/icons/technology/${name}.svg`} alt="" width={18} height={18} />
    ) : (
      <span
        className="technology-mask"
        style={{
          backgroundColor: info.color,
          maskImage: `url(/icons/technology/${name}.svg)`,
          WebkitMaskImage: `url(/icons/technology/${name}.svg)`,
        }}
      />
    );
  } else {
    const d = paths?.[info.slug];
    glyph = d ? (
      <svg width={18} height={18} viewBox="0 0 24 24" focusable="false">
        <path d={d} fill={info.color} />
      </svg>
    ) : null;
  }
  return (
    <span className="technology-icon" aria-hidden="true">
      {glyph}
    </span>
  );
}

export function TechnologyChip({ label }: { label: string }) {
  return (
    <span className="technology-chip">
      <TechnologyIcon label={label} />
      <span className="technology-chip-label">{label}</span>
    </span>
  );
}
