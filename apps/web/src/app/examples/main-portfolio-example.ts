import { exampleDocumentContent } from '@/components/document-view';
import type { PublicDocumentContent } from '@/lib/public-document';

// Демонстрационное основное портфолио: полный набор разделов в порядке по умолчанию (ADR 0005).
export function mainPortfolioExample(): PublicDocumentContent {
  const content = exampleDocumentContent('resume', true);
  return {
    ...content,
    // Маркетинговое правило: последнее предложение блока без точки.
    profile: { ...content.profile, bio: withoutFinalPeriod(content.profile.bio) },
    projects: content.projects.map((project) => ({
      ...project,
      description: withoutFinalPeriod(project.description),
    })),
    blocks: [
      'profile',
      'about',
      'location',
      'links',
      'skills',
      'featuredProjects',
      'experience',
      'education',
    ].map((kind) => ({ kind, visible: true as const })),
  };
}

function withoutFinalPeriod(text: string): string {
  return text.replace(/\.$/, '');
}
