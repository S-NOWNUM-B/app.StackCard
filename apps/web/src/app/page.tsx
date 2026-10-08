import type { Metadata } from 'next';
import Link from 'next/link';
import { DocumentView, exampleDocumentContent } from '@/components/document-view';
import { Header, LinkButton, TechnologyBadges } from '@/components/ui';

export const metadata: Metadata = {
  title: 'StackCard — профессиональная база, резюме и портфолио',
  description:
    'Соберите профессиональную базу и библиотеку проектов. Создавайте независимые резюме и портфолио, публикуйте выбранные версии.',
};

export default function LandingPage() {
  return (
    <>
      <Header />
      <main id="main" className="container stack landing-content">
        <section className="section stack">
          <h1 className="hero">Один профиль. Резюме и портфолио под вашу задачу.</h1>
          <h2>Ваша работа в нужной версии</h2>
          <div className="columns">
            <div className="stack">
              <h2>Начните с профессиональной базы</h2>
              <p>Добавьте сведения о себе, выберите проекты и опубликуйте нужный документ.</p>
              <div className="row">
                <LinkButton href="/workspace" variant="primary">
                  Создать документ
                </LinkButton>
                <LinkButton href="/examples/portfolio">Посмотреть пример</LinkButton>
              </div>
            </div>
            <div className="stack">
              <h2>Пример портфолио</h2>
              <p>Проекты, технологии и выбранные контакты в одной композиции.</p>
              <div className="section preview-crop">
                <DocumentView
                  kind="portfolio"
                  content={exampleDocumentContent('portfolio', true)}
                  preview
                />
              </div>
            </div>
          </div>
        </section>
        <section id="features" className="stack">
          <h2>Общая база → разные документы</h2>
          <div className="columns three">
            <div className="stack">
              <h2>Профессиональная база</h2>
              <p>
                Имя, роль, фото, публичные контакты, опыт и навыки. Фото и необязательные сведения
                можно пропустить.
              </p>
            </div>
            <div className="stack">
              <h2>Резюме под роль</h2>
              <p>Выберите подходящие сведения и проекты. Изменения относятся к этому резюме.</p>
            </div>
            <div className="stack">
              <h2>Портфолио под аудиторию</h2>
              <p>
                Представьте свои работы, настройте порядок и видимость для конкретного портфолио.
              </p>
            </div>
          </div>
        </section>
        <section className="stack">
          <h2>Проекты из одной библиотеки</h2>
          <div className="columns three">
            <div className="stack">
              <h2>Из GitHub или вручную</h2>
              <p>
                Импортируйте исходные сведения или создайте проект сами. Обновления источника
                просматривайте перед применением.
              </p>
              <TechnologyBadges items={['Flutter', 'Dart', 'React', 'TypeScript']} />
            </div>
            <div className="stack">
              <h2>Atlas UI Kit</h2>
              <p>Набор компонентов для спокойных и удобных интерфейсов.</p>
            </div>
            <div className="stack">
              <h2>Readme Studio</h2>
              <p>Редактор структуры README для небольших open source проектов.</p>
            </div>
          </div>
        </section>
        <section className="stack">
          <h2>Резюме для конкретной роли</h2>
          <div className="columns">
            <div className="stack">
              <h2>Выберите то, что подходит</h2>
              <p>
                Контакты, опыт, образование, технологии и проекты собираются в читаемый документ.
                Пустые секции не появляются.
              </p>
              <LinkButton href="/examples/resume">Пример резюме</LinkButton>
            </div>
            <div className="stack">
              <h2>Документ без лишнего</h2>
              <p>Фото необязательно. Содержание и оформление редактируются отдельно.</p>
              <div className="section preview-crop">
                <DocumentView
                  kind="resume"
                  content={exampleDocumentContent('resume', true)}
                  preview
                />
              </div>
            </div>
          </div>
        </section>
        <section className="section stack">
          <h3>Портфолио ваших работ</h3>
          <p>
            Используйте одну работу в разных портфолио. Для каждого выберите порядок, видимость и
            проекты, на которые хотите обратить внимание.
          </p>
          <p>
            Добавляйте публичные контакты и выбранное резюме. Удаление проекта из портфолио
            сохраняет работу в библиотеке.
          </p>
          <LinkButton href="/examples/portfolio">Пример портфолио</LinkButton>
        </section>
        <section className="stack">
          <h2>Публикуйте только нужную версию</h2>
          <div className="columns three">
            <div className="stack">
              <h2>Сохраните изменения</h2>
              <p>
                Рабочий черновик остаётся вашим. Правки и сохранение не меняют то, что уже видят по
                опубликованной ссылке.
              </p>
            </div>
            <div className="stack">
              <h2>Опубликуйте отдельно</h2>
              <p>
                Проверьте выбранные сведения и явно опубликуйте документ. Публичный просмотр
                доступен без входа.
              </p>
            </div>
            <div className="stack">
              <h2>Поделитесь адресом</h2>
              <p>
                У каждого документа свой постоянный адрес. Переименование сохраняет его; снятие с
                публикации закрывает доступ.
              </p>
            </div>
          </div>
        </section>
        <section className="section stack" id="application">
          <h3>Мобильное приложение</h3>
          <p className="muted">
            Android и iOS — мобильные платформы StackCard. Публичных релизов для скачивания пока
            нет.
          </p>
          <h2>Доступность установки</h2>
          <div className="columns">
            <div className="stack">
              <h3>Android</h3>
              <p>Публичная сборка пока недоступна.</p>
              <LinkButton href="/download">Страница приложения</LinkButton>
            </div>
            <div className="stack">
              <h3>iOS</h3>
              <p>Публичная сборка пока недоступна.</p>
              <LinkButton href="/download">Открыть приложение</LinkButton>
            </div>
          </div>
          <small className="muted">
            Скачивание станет доступно после появления публичного релиза.
          </small>
        </section>
        <section className="section stack">
          <h3>Начните с вашего профиля</h3>
          <p>Добавьте свою работу, выберите данные под задачу и контролируйте публикацию.</p>
          <div className="row">
            <LinkButton href="/workspace" variant="primary">
              Создать документ
            </LinkButton>
            <LinkButton href="/sign-in">Войти</LinkButton>
          </div>
        </section>
        <footer className="stack">
          <p>StackCard</p>
          <div className="columns">
            <div className="stack">
              <h3>Профессиональная база, резюме и портфолио</h3>
              <p>Данные выбираете вы. Документы публикуете отдельно.</p>
              <div className="row">
                <LinkButton variant="quiet" href="#features">
                  Возможности
                </LinkButton>
                <LinkButton variant="quiet" href="/download">
                  Мобильное приложение
                </LinkButton>
              </div>
            </div>
            <div className="stack">
              <h3>Разделы</h3>
              <p>Выберите нужный сценарий.</p>
              <div className="row">
                <LinkButton variant="quiet" href="/workspace">
                  Проекты
                </LinkButton>
                <LinkButton variant="quiet" href="/examples/resume">
                  Резюме
                </LinkButton>
              </div>
              <div className="row">
                <LinkButton variant="quiet" href="/examples/portfolio">
                  Портфолио
                </LinkButton>
                <LinkButton variant="quiet" href="/workspace">
                  Публикация
                </LinkButton>
              </div>
            </div>
          </div>
          <small className="muted">
            Alex Morgan и показанные проекты — демонстрационные примеры.{' '}
            <Link href="/examples/portfolio">Подробнее о примере</Link>
          </small>
        </footer>
      </main>
    </>
  );
}
