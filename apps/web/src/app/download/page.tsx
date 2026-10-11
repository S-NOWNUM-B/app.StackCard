import type { Metadata } from 'next';
import { MarketingPage, PageIntro } from '@/components/marketing';
import { Icon, LinkButton } from '@/components/ui';

export const metadata: Metadata = {
  title: 'Мобильное приложение',
  description:
    'StackCard для Android и iOS. Публичные сборки пока недоступны; продолжить работу можно в браузере.',
};
export default function DownloadPage() {
  return (
    <MarketingPage>
      <PageIntro
        eyebrow="StackCard на ваших устройствах"
        title={
          <>
            Ваше пространство.
            <br />
            <em>Там, где удобно.</em>
          </>
        }
        description="Продолжайте работу в браузере. Мобильное приложение для Android и iOS развивается отдельно; публичные сборки пока недоступны."
      />
      <section className="marketing-section site-width" aria-labelledby="platforms-title">
        <span className="numbered-label">01 / Выберите платформу</span>
        <h2 className="section-heading" id="platforms-title">
          Начните прямо в браузере.
        </h2>
        <p className="section-lead">Профиль, проекты, резюме и портфолио — в одном кабинете.</p>
        <div className="platform-grid">
          <article className="platform-card stack">
            <span className="feature-icon">
              <Icon name="panels-top-left" />
            </span>
            <h3>Браузер</h3>
            <span className="release-status">Без установки</span>
            <p>
              Откройте кабинет на компьютере или телефоне. Для загрузки и сохранения данных нужен
              интернет.
            </p>
            <LinkButton href="/workspace" variant="primary">
              Открыть StackCard <Icon name="arrow-up" size={16} />
            </LinkButton>
          </article>
          <article className="platform-card stack">
            <span className="numbered-label">Мобильное приложение</span>
            <h3>Android</h3>
            <span className="release-status">Публичного релиза пока нет</span>
            <p id="release-android">
              Сборка для скачивания ещё недоступна. Пока вы можете работать со своими документами в
              браузере.
            </p>
          </article>
          <article className="platform-card stack">
            <span className="numbered-label">Мобильное приложение</span>
            <h3>iOS</h3>
            <span className="release-status">Публичного релиза пока нет</span>
            <p id="release-ios">
              Версия для iPhone — целевая платформа проекта. Ссылки на установку пока нет.
            </p>
          </article>
        </div>
      </section>
      <section
        className="marketing-section site-width split-section"
        aria-labelledby="no-account-title"
      >
        <div className="stack">
          <span className="numbered-label">02 / Сначала познакомьтесь</span>
          <h2 className="section-heading" id="no-account-title">
            Посмотреть можно
            <br />
            без регистрации.
          </h2>
        </div>
        <div className="stack">
          <p className="section-lead">
            Откройте пример резюме или портфолио, чтобы увидеть результат.
          </p>
          <p>
            Опубликованные документы доступны посетителям по ссылке без входа. Аккаунт нужен для
            собственного рабочего пространства и редактирования.
          </p>
          <div className="marketing-actions">
            <LinkButton href="/examples">
              Посмотреть примеры <Icon name="arrow-up" size={16} />
            </LinkButton>
            <LinkButton href="/help#getting-started">Как начать</LinkButton>
          </div>
        </div>
      </section>
    </MarketingPage>
  );
}
