import type { Metadata } from 'next';
import { DocumentView, exampleDocumentContent } from '@/components/document-view';
import { Header, LinkButton } from '@/components/ui';

export const metadata: Metadata = {
  title: 'Демонстрационное портфолио | StackCard',
  robots: { index: false, follow: false },
};
export default function ExamplePortfolioPage() {
  return (
    <>
      <Header
        context="public"
        links={[
          { label: 'Проекты', href: '#projects' },
          { label: 'Контакты', href: '#contacts' },
        ]}
      />
      <main id="main" className="container stack">
        <div className="stack public-page-label">
          <p className="muted">Демонстрационное портфолио</p>
          <p className="muted">
            Alex Morgan и проекты — вымышленные примеры. Они не являются публикацией пользователя.
          </p>
        </div>
        <DocumentView kind="portfolio" content={exampleDocumentContent('portfolio')} />
        <div className="section stack">
          <h3>Представьте свои работы</h3>
          <LinkButton href="/workspace" variant="primary">
            Создать портфолио
          </LinkButton>
          <LinkButton href="/examples/resume">Пример резюме</LinkButton>
        </div>
      </main>
    </>
  );
}
