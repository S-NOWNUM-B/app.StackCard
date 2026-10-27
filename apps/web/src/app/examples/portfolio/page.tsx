import type { Metadata } from 'next';
import { DocumentView } from '@/components/document-view';
import { Header, Icon, LinkButton } from '@/components/ui';
import { mainPortfolioExample } from '../main-portfolio-example';

export const metadata: Metadata = {
  title: 'Демонстрационное портфолио',
  robots: { index: false, follow: false },
};
export default function ExamplePortfolioPage() {
  return (
    <>
      <Header
        context="public"
        links={[
          { label: 'Примеры', href: '/examples' },
          { label: 'PDF', href: '#pdf' },
        ]}
      />
      <main id="main" className="container stack">
        <div className="stack public-page-label">
          <p className="muted">Демонстрационное портфолио</p>
          <p className="muted">
            Имя, фото и проекты — демонстрационные данные. Это не публикация пользователя
          </p>
        </div>
        <DocumentView kind="portfolio" content={mainPortfolioExample()} modernPortfolio preview />
        <section className="section stack example-pdf" id="pdf" aria-labelledby="pdf-title">
          <span className="feature-icon">
            <Icon name="file-text" />
          </span>
          <h3 id="pdf-title">То же портфолио в PDF</h3>
          <p className="muted">
            В кабинете на главной нажмите «Скачать портфолио». PDF с теми же разделами, ссылками и
            фото собирается из сохранённой версии — публикация для этого не нужна
          </p>
          <div className="row">
            <LinkButton href="/workspace" variant="primary">
              Создать портфолио
            </LinkButton>
            <LinkButton href="/help#documents">Как скачать PDF</LinkButton>
          </div>
        </section>
      </main>
    </>
  );
}
