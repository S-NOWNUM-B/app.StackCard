import type { Metadata } from 'next';
import { Button, Header, LinkButton } from '@/components/ui';

export const metadata: Metadata = {
  title: 'Мобильное приложение | StackCard',
  description:
    'StackCard для Android и iOS. Публичные сборки пока недоступны; продолжить работу можно в браузере.',
};
export default function DownloadPage() {
  return (
    <>
      <Header
        links={[
          { label: 'На главную', href: '/' },
          { label: 'Войти', href: '/sign-in' },
        ]}
      />
      <main id="main" className="container stack landing-content">
        <h1 className="visually-hidden">Мобильное приложение StackCard</h1>
        <p className="muted">Редактируйте свою профессиональную базу на телефоне и в браузере.</p>
        <div className="columns">
          {['Android', 'iOS'].map((platform) => (
            <section className="stack" key={platform}>
              <h2>{platform}</h2>
              <p id={`release-${platform}`}>Публичная версия для скачивания пока недоступна.</p>
              <Button disabled aria-describedby={`release-${platform}`}>
                Скачать для {platform}
              </Button>
            </section>
          ))}
        </div>
        <section className="section stack">
          <h3>Продолжить в браузере</h3>
          <p>Откройте кабинет, чтобы работать с профилем, проектами, резюме и портфолио.</p>
          <LinkButton href="/workspace" variant="primary">
            Открыть кабинет
          </LinkButton>
        </section>
        <p className="muted">Опубликованные документы доступны по ссылке без входа.</p>
        <LinkButton href="/examples/resume" variant="quiet">
          Посмотреть пример резюме
        </LinkButton>
        <div className="stack">
          <small className="muted">Android и iOS — целевые мобильные платформы</small>
          <LinkButton href="/">На главную</LinkButton>
        </div>
      </main>
    </>
  );
}
