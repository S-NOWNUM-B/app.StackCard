import type { Metadata } from 'next';
import { DocumentView, exampleDocumentContent } from '@/components/document-view';
import { Header, LinkButton } from '@/components/ui';

export const metadata: Metadata = {
  title: 'Демонстрационное резюме | StackCard',
  robots: { index: false, follow: false },
};
export default function ExampleResumePage() {
  return (
    <>
      <Header
        context="public"
        links={[
          { label: 'Проекты', href: '#projects' },
          { label: 'Контакты', href: '#contacts' },
        ]}
      />
      <main id="main" className="container">
        <div className="public-resume stack">
          <div className="stack public-page-label">
            <p className="muted">Демонстрационное резюме</p>
            <p className="muted">
              Alex Morgan — вымышленный профиль из примера. Этот документ не является опубликованным
              резюме пользователя.
            </p>
          </div>
          <DocumentView kind="resume" content={exampleDocumentContent('resume')} />
          <div className="section stack">
            <h3>Создайте свою версию</h3>
            <LinkButton href="/workspace" variant="primary">
              Создать резюме
            </LinkButton>
            <LinkButton href="/examples/portfolio">Пример портфолио</LinkButton>
          </div>
        </div>
      </main>
    </>
  );
}
