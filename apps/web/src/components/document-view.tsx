import type { ReactNode } from 'react';
import { Icon } from '@/components/ui';
import { publicProjectIcon, safePublicHref, safePublicMedia } from '@/lib/public-document';
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
  modernPortfolio = false,
}: {
  content: PublicDocumentContent;
  kind: PublicDocumentKind;
  attachedResumeUrl?: string;
  preview?: boolean;
  publicId?: string;
  version?: number;
  profilePhoto?: ReactNode;
  modernPortfolio?: boolean;
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
        width={128}
        height={128}
        alt={`Фото ${profile.name || 'автора'}`}
        referrerPolicy="no-referrer"
      />
    ) : null;
  const id = (name: string) => (preview ? undefined : name);
  const visible = new Set(content.blocks.filter((b) => b.visible).map((b) => b.kind));
  const attached =
    attachedResumeUrl && /^\/d\/[a-f0-9]{32}$/.test(attachedResumeUrl) ? attachedResumeUrl : null;
  const hasProfile =
    visible.has('profile') && (profile.name.trim() || profile.headline.trim() || photo);
  const bio = visible.has('about') && profile.bio.trim() ? profile.bio : '';
  const location =
    visible.has('location') && profile.locationText.trim() ? profile.locationText : '';
  return (
    <article
      className={`document-paper ${kind === 'resume' ? 'public-resume' : 'public-portfolio'}`}
      data-theme="light"
      aria-label={kind === 'resume' ? 'Резюме' : 'Портфолио'}
    >
      {(hasProfile || bio || location) && (
        <header className={`identity document-profile${modernPortfolio ? ' modern-profile' : ''}`}>
          {visible.has('profile') && photo}
          {visible.has('profile') && profile.name.trim() && <h1>{profile.name}</h1>}
          {visible.has('profile') && profile.headline.trim() && <h3>{profile.headline}</h3>}
          {modernPortfolio && location && <p className="muted">{location}</p>}
          {bio && <p className={modernPortfolio ? 'profile-bio' : undefined}>{bio}</p>}
          {!modernPortfolio && location && <p className="muted">{location}</p>}
        </header>
      )}
      {content.blocks
        .filter((block) => block.visible)
        .map((block) => {
          switch (block.kind) {
            case 'profile':
            case 'about':
            case 'location':
              return null;
            case 'skills':
              return content.skills.length ? (
                <section className="document-section" key={block.kind}>
                  <h3>Навыки</h3>
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
              return content.projects.some((project) => project.visible) ? (
                <section className="document-section" id={id('projects')} key={block.kind}>
                  <h2>Проекты</h2>
                  <div className="document-project-list">
                    {content.projects
                      .filter((p) => p.visible)
                      .map((project) => {
                        const repositoryHref = safePublicHref(project.repositoryUrl.trim());
                        const productHref = safePublicHref(project.liveUrl.trim());
                        return (
                          <div className="document-project-row" key={project.id}>
                            <img
                              className="document-project-icon"
                              src={`/icons/lucide/${publicProjectIcon(project.iconId)}.svg`}
                              width={24}
                              height={24}
                              alt=""
                              aria-hidden="true"
                            />
                            <div className="document-project-text">
                              <h3>{project.title}</h3>
                              {project.description.trim() && <p>{project.description}</p>}
                              {(repositoryHref || productHref) && (
                                <div className="document-project-links">
                                  {repositoryHref && (
                                    <a
                                      className="button secondary"
                                      href={repositoryHref}
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      aria-label={`Репозиторий проекта ${project.title}`}
                                    >
                                      <Icon name="github" size={20} />
                                      Репозиторий
                                    </a>
                                  )}
                                  {productHref && (
                                    <a
                                      className="button secondary"
                                      href={productHref}
                                      target="_blank"
                                      rel="noopener noreferrer nofollow"
                                      aria-label={`Продукт проекта ${project.title}`}
                                    >
                                      <Icon name="globe" size={20} />
                                      Продукт
                                    </a>
                                  )}
                                </div>
                              )}
                            </div>
                          </div>
                        );
                      })}
                  </div>
                </section>
              ) : null;
            case 'links': {
              const links = content.links.filter(
                (link) =>
                  (link.kind !== 'github' || (modernPortfolio && visible.has('github'))) &&
                  safePublicHref(link.url, link.kind),
              );
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
              if (modernPortfolio && visible.has('links')) return null;
              const links = content.links.filter(
                (link) => link.kind === 'github' && safePublicHref(link.url, link.kind),
              );
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
              return content.resumeText.trim() || attached ? (
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
      name: 'Алекс Морган',
      username: '',
      headline: 'Flutter- и веб-разработчик',
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
        technologies: ['Flutter', 'Dart', 'Дизайн интерфейсов'],
        repositoryUrl: '',
        liveUrl: '',
        featured: true,
        visible: true,
        iconId: 'panels-top-left',
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
        iconId: 'file-text',
      },
    ],
    experience: [
      {
        id: 'demo-experience',
        role: 'Разработчик интерфейсов',
        organization: 'Демонстрационная студия',
        period: '2024–2026',
        description: '',
      },
    ],
    education: [
      {
        id: 'demo-education',
        institution: 'Пример учебного профиля',
        qualification: 'Программная инженерия',
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
    theme: 'light',
  };
}
