import type { Metadata } from 'next';
import { MarketingPage, PageIntro } from '@/components/marketing';
import { Icon, LinkButton } from '@/components/ui';

export const metadata: Metadata = {
  title: 'Мобильное приложение',
  description:
    'StackCard для Android и iOS в разработке, публичных сборок пока нет. Портфолио доступно в браузере',
};
export default function DownloadPage() {
  return (
    <MarketingPage>
      <PageIntro
        eyebrow="StackCard на ваших устройствах"
        title={
          <>
            Ваше портфолио
            <br />
            <em>Где вам удобно</em>
          </>
        }
        description="Работайте в браузере уже сейчас. Мобильное приложение для Android и iOS развивается параллельно; публичных сборок для установки пока нет"
      />
      <section className="marketing-section site-width" aria-labelledby="platforms-title">
        <span className="numbered-label" data-reveal>
          01 / Платформы
        </span>
        <h2 className="section-heading" id="platforms-title" data-reveal>
          Начните прямо в браузере
        </h2>
        <p className="section-lead" data-reveal>
          Главная, проекты и редактор — в одном кабинете без установки
        </p>
        <div className="platform-grid">
          <article className="platform-card stack" data-reveal>
            <span className="feature-icon">
              <Icon name="globe" />
            </span>
            <h3>Браузер</h3>
            <span className="release-status is-available">Доступно без установки</span>
            <p>
              Откройте кабинет на компьютере или телефоне. Для загрузки и сохранения данных нужен
              интернет
            </p>
            <LinkButton href="/workspace" variant="primary">
              Открыть StackCard <Icon name="arrow-up" size={16} />
            </LinkButton>
          </article>
          <article className="platform-card stack" data-reveal>
            <span className="numbered-label">Мобильное приложение</span>
            <h3>Android</h3>
            <span className="release-status">Публичного релиза пока нет</span>
            <p id="release-android">
              Приложение в разработке, ссылки на установку и страницы в магазине приложений нет.
              Пока работайте с портфолио в браузере
            </p>
          </article>
          <article className="platform-card stack" data-reveal>
            <span className="numbered-label">Мобильное приложение</span>
            <h3>iOS</h3>
            <span className="release-status">Публичного релиза пока нет</span>
            <p id="release-ios">
              Версия для iPhone — целевая платформа проекта. Ссылки на установку пока нет
            </p>
          </article>
        </div>
      </section>
      <section
        className="marketing-section site-width split-section"
        aria-labelledby="mobile-title"
      >
        <div className="stack" data-reveal>
          <span className="numbered-label">02 / Что будет в приложении</span>
          <h2 className="section-heading" id="mobile-title">
            Тот же аккаунт
            <br />
            Те же данные
          </h2>
        </div>
        <div className="stack" data-reveal>
          <ul className="feature-list">
            <li>
              <strong>Синхронизация с веб-кабинетом.</strong> Портфолио и проекты общие для браузера
              и телефона — вход по почте и паролю или через Google
            </li>
            <li>
              <strong>Визитка с QR-кодом.</strong> Опубликованное портфолио превращается в карточку
              с постоянной ссылкой
            </li>
            <li>
              <strong>Кнопка «Поделиться».</strong> Ссылку на портфолио можно отправить через
              системное меню телефона, а PDF — сохранить в файлы
            </li>
          </ul>
        </div>
      </section>
      <section
        className="marketing-section site-width split-section"
        aria-labelledby="no-account-title"
      >
        <div className="stack" data-reveal>
          <span className="numbered-label">03 / Сначала познакомьтесь</span>
          <h2 className="section-heading" id="no-account-title">
            Посмотреть можно
            <br />
            без регистрации
          </h2>
        </div>
        <div className="stack" data-reveal>
          <p className="section-lead">Откройте пример портфолио, чтобы увидеть результат</p>
          <p>
            Опубликованные портфолио доступны посетителям по ссылке без входа. Аккаунт нужен для
            собственного рабочего пространства и редактирования
          </p>
          <div className="marketing-actions">
            <LinkButton href="/examples">
              Посмотреть пример <Icon name="arrow-up" size={16} />
            </LinkButton>
            <LinkButton href="/help#getting-started">Как начать</LinkButton>
          </div>
        </div>
      </section>
    </MarketingPage>
  );
}
