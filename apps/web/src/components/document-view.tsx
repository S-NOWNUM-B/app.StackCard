import { TechnologyBadges } from '@/components/ui';
import type { ReactNode } from 'react';
import { safePublicHref, safePublicMedia } from '@/lib/public-document';
import type {
  PublicDocumentContent,
  PublicDocumentKind,
  PublicLinkKind,
} from '@/lib/public-document';

function Contact({ label, url, kind }: { label: string; url: string; kind: PublicLinkKind }) {
  const href = safePublicHref(url, kind);
  if (!href) return null;
  const external = /^https?:/.test(href);
  return (
    <div className="stack">
      <p className="muted">{label}</p>
      <a
        className="public-contact"
        href={href}
        rel={external ? 'noopener noreferrer nofollow' : undefined}
        target={external ? '_blank' : undefined}
      >
        {url}
      </a>
    </div>
  );
}

export function DocumentView({
  content,
  kind,
  attachedResumeUrl,
  preview = false,
  publicId,
  version,
  profilePhoto,
}: {
  content: PublicDocumentContent;
  kind: PublicDocumentKind;
  attachedResumeUrl?: string;
  preview?: boolean;
  publicId?: string;
  version?: number;
  profilePhoto?: ReactNode;
}) {
  const profile = content.profile;
  const avatar =
    preview && profile.avatarUrl === '/images/demo-portrait.png'
      ? profile.avatarUrl
      : safePublicMedia(profile.avatarUrl, publicId, version);
  const photo =
    preview && profilePhoto !== undefined ? (
      profilePhoto
    ) : avatar ? (
      <img
        className="portrait"
        src={avatar}
        width={80}
        height={80}
        alt={`Фото ${profile.name || 'автора'}`}
        referrerPolicy="no-referrer"
      />
    ) : null;
  const id = (name: string) => (preview ? undefined : name);
  const visible = new Set(content.blocks.filter((b) => b.visible).map((b) => b.kind));
  const attached =
    attachedResumeUrl && /^\/d\/[a-f0-9]{32}$/.test(attachedResumeUrl) ? attachedResumeUrl : null;
  return (
    <article
      className={`document-paper ${kind === 'resume' ? 'public-resume' : 'public-portfolio'}`}
      data-theme={content.theme}
      aria-label={kind === 'resume' ? 'Резюме' : 'Портфолио'}
    >
      {content.blocks
        .filter((block) => block.visible)
        .map((block) => {
          switch (block.kind) {
            case 'profile':
              return profile.name || profile.headline || photo ? (
                <div className="identity" key={block.kind}>
                  {photo}
                  {profile.name && <h1>{profile.name}</h1>}
                  {profile.headline && <h3>{profile.headline}</h3>}
                </div>
              ) : null;
            case 'about':
              return profile.bio ? (
                <p className="document-section" key={block.kind}>
                  {profile.bio}
                </p>
              ) : null;
            case 'location':
              return profile.locationText ? (
                <section className="document-section" key={block.kind}>
                  <h3>Местоположение</h3>
                  <p>{profile.locationText}</p>
                </section>
              ) : null;
            case 'skills':
              return content.skills.length ? (
                <section className="document-section" key={block.kind}>
                  <h3>Технологии</h3>
                  <p>{content.skills.map((s) => s.name).join(' · ')}</p>
                </section>
              ) : null;
            case 'experience':
              return content.experience.length ? (
                <section className="document-section" key={block.kind}>
                  <h3>Опыт</h3>
                  {content.experience.map((item) => (
                    <div className="stack" key={item.id}>
                      <p>{item.role}</p>
                      <p>{[item.organization, item.period].filter(Boolean).join(' · ')}</p>
                      {item.description && <p>{item.description}</p>}
                    </div>
                  ))}
                </section>
              ) : null;
            case 'education':
              return content.education.length ? (
                <section className="document-section" key={block.kind}>
                  <h3>Образование</h3>
                  {content.education.map((item) => (
                    <div className="stack" key={item.id}>
                      <p>{item.qualification}</p>
                      <p>{[item.institution, item.period].filter(Boolean).join(' · ')}</p>
                      {item.description && <p>{item.description}</p>}
                    </div>
                  ))}
                </section>
              ) : null;
            case 'featuredProjects':
              return content.projects.length ? (
                <section className="document-section" id={id('projects')} key={block.kind}>
                  <h2>Проекты</h2>
                  <div className={kind === 'portfolio' ? 'project-grid' : 'stack'}>
                    {content.projects
                      .filter((p) => p.visible)
                      .map((project) => (
                        <div className="stack" key={project.id}>
                          <h3>{project.title}</h3>
                          {project.description && <p>{project.description}</p>}
                          {project.contribution && <p>{project.contribution}</p>}
                          {project.imageUrls.map((value, index) => {
                            const src = safePublicMedia(value, publicId, version);
                            return src ? (
                              <img
                                className="project-image"
                                key={value}
                                src={src}
                                alt={`${project.title} — изображение ${index + 1}`}
                                loading="lazy"
                                referrerPolicy="no-referrer"
                              />
                            ) : null;
                          })}
                          {project.technologies.length > 0 && (
                            <TechnologyBadges items={project.technologies} />
                          )}
                          <div className="row">
                            {safePublicHref(project.repositoryUrl) && (
                              <a
                                className="button secondary"
                                href={project.repositoryUrl}
                                target="_blank"
                                rel="noopener noreferrer nofollow"
                              >
                                Исходный код
                              </a>
                            )}
                            {safePublicHref(project.liveUrl) && (
                              <a
                                className="button secondary"
                                href={project.liveUrl}
                                target="_blank"
                                rel="noopener noreferrer nofollow"
                              >
                                Открыть проект
                              </a>
                            )}
                          </div>
                        </div>
                      ))}
                  </div>
                </section>
              ) : null;
            case 'links': {
              const links = content.links.filter((link) => link.kind !== 'github');
              return links.length ? (
                <section
                  className={`document-section ${kind === 'portfolio' ? 'section' : ''}`}
                  id={id('contacts')}
                  key={block.kind}
                >
                  {kind === 'portfolio' && <h3>Контакты</h3>}
                  {links.map((link) => (
                    <Contact key={link.id} {...link} />
                  ))}
                </section>
              ) : null;
            }
            case 'github': {
              const links = content.links.filter((link) => link.kind === 'github');
              return links.length ? (
                <section
                  className="document-section"
                  id={visible.has('links') ? undefined : id('contacts')}
                  key={block.kind}
                >
                  {links.map((link) => (
                    <Contact key={link.id} {...link} />
                  ))}
                </section>
              ) : null;
            }
            case 'resume':
              return content.resumeText || attached ? (
                <section className="document-section" key={block.kind}>
                  {content.resumeText && <p>{content.resumeText}</p>}
                  {attached && (
                    <a className="button secondary" href={attached}>
                      Открыть опубликованное резюме
                    </a>
                  )}
                </section>
              ) : null;
            default:
              return null;
          }
        })}
    </article>
  );
}

// Вымышленный пример из макета. Он не попадает в owner data или publicDocuments.
export function exampleDocumentContent(
  kind: PublicDocumentKind,
  portrait = false,
): PublicDocumentContent {
  return {
    profile: {
      name: 'Alex Morgan',
      username: '',
      headline: 'Flutter & Web Developer',
      bio: 'Создаю понятные цифровые продукты: от небольших мобильных приложений до интерфейсов для веба. Люблю чистую типографику, продуманные детали и код, который легко поддерживать.',
      locationText: 'Алматы, Казахстан',
      avatarUrl: portrait ? '/images/demo-portrait.png' : '',
    },
    skills: ['Flutter', 'Dart', 'React', 'TypeScript'].map((name, index) => ({
      id: `demo-skill-${index}`,
      name,
    })),
    projects: [
      {
        id: 'demo-atlas',
        title: 'Atlas UI Kit',
        description: 'Набор компонентов для спокойных и удобных интерфейсов.',
        contribution: '',
        technologies: ['Flutter', 'Dart', 'UI Design'],
        repositoryUrl: '',
        liveUrl: '',
        featured: true,
        visible: true,
        imageUrls: [],
      },
      {
        id: 'demo-pocket',
        title: 'Pocket Tasks',
        description: 'Небольшой планировщик, который помогает держать фокус.',
        contribution: '',
        technologies: ['Flutter', 'Dart', 'Firebase'],
        repositoryUrl: '',
        liveUrl: '',
        featured: false,
        visible: true,
        imageUrls: [],
      },
    ],
    experience: [
      {
        id: 'demo-experience',
        role: 'Frontend Developer',
        organization: 'Studio Example',
        period: '2024–2026',
        description: '',
      },
    ],
    education: [
      {
        id: 'demo-education',
        institution: 'Пример учебного профиля',
        qualification: 'Software Engineering',
        period: '2023–2027',
        description: '',
      },
    ],
    links:
      kind === 'resume'
        ? [
            {
              id: 'demo-mail',
              label: 'Контактная почта',
              url: 'mailto:hello@example.com',
              kind: 'email',
            },
            { id: 'demo-site', label: 'Личный сайт', url: 'https://example.com', kind: 'website' },
          ]
        : [{ id: 'demo-site', label: 'Личный сайт', url: 'https://example.com', kind: 'website' }],
    blocks: (kind === 'resume'
      ? [
          'profile',
          'about',
          'links',
          'location',
          'skills',
          'experience',
          'education',
          'featuredProjects',
        ]
      : ['profile', 'about', 'skills', 'featuredProjects', 'links']
    ).map((kind) => ({ kind, visible: true })),
    resumeText: '',
    theme: 'dark',
  };
}
