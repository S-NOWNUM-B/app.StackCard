// Отпечаток источника GitHub: тот же алгоритм, что mobile gitHubProjectFingerprint
// (FNV-1a 64 бита по UTF-8 от JSON-массива полей), чтобы игнор из mobile совпадал на web.
import type { GitHubSource } from './model';

// Dart toIso8601String для UTC: миллисекунды всегда есть. Уже полная запись сохраняется как есть.
function dartIso(value: string): string {
  if (/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3,6}Z$/.test(value)) return value;
  const time = Date.parse(value);
  return Number.isNaN(time) ? value : new Date(time).toISOString();
}

export function gitHubSourceFingerprint(source: GitHubSource): string {
  const bytes = new TextEncoder().encode(
    JSON.stringify([
      source.repositoryId,
      source.name,
      source.fullName,
      source.htmlUrl,
      source.description,
      source.language,
      source.stars,
      source.forks,
      source.isFork,
      source.archived,
      dartIso(source.updatedAt),
    ]),
  );
  const mask = (1n << 64n) - 1n;
  let value = 14695981039346656037n;
  for (const byte of bytes) value = ((value ^ BigInt(byte)) * 1099511628211n) & mask;
  return `v1:${value.toString(16).padStart(16, '0')}`;
}
