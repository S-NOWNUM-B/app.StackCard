import type { DocumentContent } from './model';

// omitAvatar: фото не удалось загрузить по legacy-ссылке, PDF строится без него.
export type PortfolioPdfOptions = { avatarBytes?: Uint8Array; omitAvatar?: boolean };

// Фото читается только для видимого профиля: private path первым, затем legacy URL.
export function pdfAvatarSource(
  content: DocumentContent,
): { path: string } | { url: string } | null {
  if (!content.blocks.some((block) => block.kind === 'profile' && block.visible)) return null;
  if (content.profile.avatarPath) return { path: content.profile.avatarPath };
  if (content.profile.avatarUrl) return { url: content.profile.avatarUrl };
  return null;
}

// Тяжёлый renderer загружается только по явному действию «Скачать портфолио».
export async function generatePortfolioPdf(
  savedContent: DocumentContent,
  options: PortfolioPdfOptions = {},
): Promise<Blob> {
  const { renderPortfolioPdf } = await import('./portfolio-pdf-renderer');
  const ids = ['folder', 'file-text', 'panels-top-left', 'home', 'image', 'camera', 'user-round'];
  const entries = await Promise.all(
    ids.map(async (id) => {
      const response = await fetch(`/icons/lucide/${id}.svg`);
      if (!response.ok)
        throw new Error('Не удалось подготовить иконки для PDF. Попробуйте ещё раз');
      return [id, await response.text()] as const;
    }),
  );
  return renderPortfolioPdf(savedContent, {
    regularFont: '/fonts/Manrope-Regular.ttf',
    boldFont: '/fonts/Manrope-Bold.ttf',
    stockIconSvg: Object.fromEntries(entries),
    avatarBytes: options.avatarBytes,
    omitAvatar: options.omitAvatar,
  });
}

export function downloadPortfolioPdf(blob: Blob, filename = 'stackcard-portfolio.pdf'): void {
  if (blob.type !== 'application/pdf' || blob.size === 0)
    throw new Error('PDF не создан. Попробуйте ещё раз');
  const url = URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  link.remove();
  // URL живёт достаточно долго для начала браузерной загрузки, затем освобождается.
  setTimeout(() => URL.revokeObjectURL(url), 60_000);
}
