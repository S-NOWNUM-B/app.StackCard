import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import { DocumentView } from '@/components/document-view';
import { ShareActions } from '@/components/share-actions';
import { Header, LinkButton } from '@/components/ui';
import {
  publicDocumentMetadata,
  readPublicDocument,
  PublicDocumentUnavailable,
} from '@/lib/public-document';

export const dynamic = 'force-dynamic';
export const revalidate = 0;
type Props = { params: Promise<{ publicId: string }> };

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const { publicId } = await params;
  try {
    const document = await readPublicDocument(publicId);
    if (!document)
      return { title: 'Документ недоступен | StackCard', robots: { index: false, follow: false } };
    const metadata = publicDocumentMetadata(document);
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
      alternates: canonical ? { canonical } : undefined,
      openGraph: { ...metadata, type: 'website', url: canonical },
      robots: { index: true, follow: true },
    };
  } catch {
    return {
      title: 'Документ временно недоступен | StackCard',
      robots: { index: false, follow: false },
    };
  }
}

export default async function PublicDocumentPage({ params }: Props) {
  const { publicId } = await params;
  let document;
  try {
    document = await readPublicDocument(publicId);
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
      const resume = await readPublicDocument(document.attachedResumePublicId);
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
