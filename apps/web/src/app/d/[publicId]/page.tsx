import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { cache } from 'react';
import { DocumentView } from '@/components/document-view';
import { ShareActions } from '@/components/share-actions';
import { Header, LinkButton } from '@/components/ui';
import {
  publicDocumentMetadata,
  readPublicDocument,
  PublicDocumentUnavailable,
  safePublicMedia,
} from '@/lib/public-document';

export const dynamic = 'force-dynamic';
export const revalidate = 0;
type Props = { params: Promise<{ publicId: string }> };
// Один snapshot для metadata и страницы в пределах запроса, без кеша между посетителями.
const readDocument = cache((publicId: string) => readPublicDocument(publicId));

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { publicId } = await params;
  try {
    const document = await readDocument(publicId);
    if (!document)
      return {
        title: { absolute: 'Документ недоступен | StackCard' },
        description: 'Ссылка не найдена или документ снят с публикации.',
        robots: { index: false, follow: false },
      };
    const metadata = publicDocumentMetadata(document);
    const image = document.content.blocks.some((block) => block.kind === 'profile' && block.visible)
      ? safePublicMedia(document.content.profile.avatarUrl, document.publicId, document.version)
      : null;
    let canonical: string | undefined;
    try {
      const value = process.env.NEXT_PUBLIC_WEB_ORIGIN;
      if (value) {
        const origin = new URL(value);
        if (
          origin.origin === value &&
          origin.protocol === 'https:' &&
          !origin.username &&
          !origin.password
        )
          canonical = `${origin.origin}/d/${publicId}`;
      }
    } catch {
      /* Некорректная конфигурация не создаёт выдуманный canonical. */
    }
    return {
      ...metadata,
      title: { absolute: metadata.title },
      alternates: canonical ? { canonical } : undefined,
      openGraph: {
        ...metadata,
        type: 'website',
        siteName: 'StackCard',
        locale: 'ru_RU',
        url: canonical,
        images: image
          ? [{ url: image, alt: `Фото ${document.content.profile.name || 'автора'}` }]
          : [],
      },
      twitter: { ...metadata, card: 'summary', images: image ? [image] : [] },
      robots: { index: true, follow: true },
    };
  } catch {
    return {
      title: { absolute: 'Документ временно недоступен | StackCard' },
      description: 'Не удалось загрузить документ. Попробуйте открыть страницу снова.',
      robots: { index: false, follow: false },
    };
  }
}

export default async function PublicDocumentPage({ params }: Props) {
  const { publicId } = await params;
  let document;
  try {
    document = await readDocument(publicId);
  } catch (error) {
    if (!(error instanceof PublicDocumentUnavailable)) throw error;
    return (
      <>
        <Header context="public" />
        <main id="main" className="container">
          <section className="section stack">
            <h1>Не удалось загрузить документ</h1>
            <p>Проверьте соединение и попробуйте открыть страницу снова.</p>
            <LinkButton href={`/d/${publicId}`}>Повторить</LinkButton>
          </section>
        </main>
      </>
    );
  }
  if (!document) notFound();
  let attachedResumeUrl: string | undefined;
  if (document.attachedResumePublicId) {
    try {
      const resume = await readDocument(document.attachedResumePublicId);
      if (resume?.kind === 'resume') attachedResumeUrl = `/d/${resume.publicId}`;
    } catch (error) {
      if (!(error instanceof PublicDocumentUnavailable)) throw error;
      // Недоступное резюме не блокирует просмотр самого портфолио.
    }
  }
  const hasProjects = document.content.projects.length > 0;
  const hasContacts = document.content.links.length > 0;
  const nav = [
    ...(hasProjects ? [{ label: 'Проекты', href: '#projects' }] : []),
    ...(hasContacts ? [{ label: 'Контакты', href: '#contacts' }] : []),
  ];
  return (
    <div className="public-document-page" data-theme={document.content.theme}>
      <Header context="public" links={nav} />
      <main id="main" className="container">
        <div className={document.kind === 'resume' ? 'public-resume' : 'public-portfolio'}>
          <p className="muted public-page-label">
            {document.kind === 'resume' ? 'Резюме' : 'Портфолио'}
          </p>
          <DocumentView
            kind={document.kind}
            content={document.content}
            publicId={publicId}
            version={document.version}
            attachedResumeUrl={attachedResumeUrl}
          />
          <ShareActions title={document.title} />
        </div>
      </main>
    </div>
  );
}
