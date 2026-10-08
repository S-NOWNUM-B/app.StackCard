import { clone, resolveDocument, type WorkspaceContent, type PortfolioDocument } from './model';
import type { PublicDocumentContent } from './public-document';
// Только owner preview. Настоящую публичную проекцию создаёт доверенный backend.
export function documentPreview(
  workspace: WorkspaceContent,
  document: PortfolioDocument,
): PublicDocumentContent {
  const content = resolveDocument(workspace, document);
  const visible = (kind: string) => content.blocks.some((b) => b.kind === kind && b.visible);
  const profile = content.profile;
  return {
    profile: {
      name: visible('profile') ? profile.name : '',
      username: visible('profile') ? profile.username : '',
      headline: visible('profile') ? profile.headline : '',
      bio: visible('about') ? profile.bio : '',
      locationText:
        visible('location') && workspace.profile.publishLocation && profile.publishLocation
          ? profile.locationText
          : '',
      avatarUrl: visible('profile') ? profile.avatarUrl : '',
    },
    skills: visible('skills') ? clone(content.skills) : [],
    projects: visible('featuredProjects')
      ? content.projects
          .filter((p) => p.visible && workspace.projects.find((base) => base.id === p.id)?.visible)
          .map((p) => ({
            id: p.id,
            title: p.title,
            description: p.description,
            contribution: p.contribution,
            technologies: p.technologies,
            repositoryUrl: p.repositoryUrl,
            liveUrl: p.liveUrl,
            featured: p.featured,
            visible: true,
            imageUrls: [],
          }))
      : [],
    experience: visible('experience') ? clone(content.experience) : [],
    education: visible('education') ? clone(content.education) : [],
    links: content.links
      .filter(
        (l) =>
          l.visible &&
          l.publishAllowed &&
          workspace.links.find((c) => c.id === l.id && c.visible)?.publishAllowed &&
          visible(l.kind === 'github' ? 'github' : 'links'),
      )
      .map(({ id, label, url, kind }) => ({ id, label, url, kind })),
    blocks: content.blocks.filter((b) => b.visible).map((b) => ({ kind: b.kind, visible: true })),
    resumeText: visible('resume') ? content.resumeText : '',
    theme: content.theme,
  };
}
