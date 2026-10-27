import Link from 'next/link';
import type { ReactNode } from 'react';
import { Header, Icon, LinkButton } from './ui';

export function MarketingPage({ children }: { children: ReactNode }) {
  return (
    <>
      <Header />
      <main id="main" className="marketing-main">
        {children}
      </main>
      <SiteFooter />
    </>
  );
}

export function PageIntro({
  eyebrow,
  title,
  description,
}: {
  eyebrow: string;
  title: ReactNode;
  description: string;
}) {
  return (
    <section className="page-intro site-width" data-intro>
      <span className="eyebrow">{eyebrow}</span>
      <h1>{title}</h1>
      <p>{description}</p>
    </section>
  );
}

export function StartSection() {
  return (
    <section className="start-section site-width" data-reveal>
      <span className="eyebrow">Ваша следующая глава</span>
      <h2>
        Дайте вашей работе
        <br />
        <em>хорошую форму</em>
      </h2>
      <p>Одно портфолио, которое легко обновлять и удобно показывать</p>
      <div className="marketing-actions">
        <LinkButton href="/workspace" variant="primary">
          Открыть StackCard <Icon name="arrow-up" size={16} />
        </LinkButton>
        <LinkButton href="/examples">Посмотреть пример</LinkButton>
      </div>
    </section>
  );
}

export function SiteFooter() {
  return (
    <footer className="site-footer site-width">
      <div className="footer-top">
        <div className="footer-brand">
          <Link href="/" aria-label="StackCard — на главную">
            <img
              src="/branding/stackcard-v2-wordmark-ink.svg"
              alt="StackCard"
              width={146}
              height={20}
            />
          </Link>
          <p>
            Всё, что вы создаёте.
            <br />В одной профессиональной истории
          </p>
        </div>
        <div>
          <h2>Продукт</h2>
          <Link href="/features">Возможности</Link>
          <Link href="/use-cases">Сценарии</Link>
          <Link href="/examples">Примеры</Link>
          <Link href="/download">Приложение</Link>
        </div>
        <div>
          <h2>StackCard</h2>
          <Link href="/about">О проекте</Link>
          <Link href="/help">Помощь</Link>
          <Link href="/help#privacy">Приватность</Link>
          <Link href="/sign-in">Войти в аккаунт</Link>
        </div>
        <div>
          <h2>Рабочее пространство</h2>
          <Link href="/workspace">Личный кабинет</Link>
          <Link href="/workspace#projects">Проекты</Link>
        </div>
      </div>
      <div className="footer-bottom">
        <small>© {new Date().getFullYear()} StackCard</small>
        <small>Сделано для тех, кто создаёт</small>
        <Link href="/help#publication">
          Вы управляете публикацией <span aria-hidden="true">↗</span>
        </Link>
      </div>
    </footer>
  );
}
