import type { Metadata } from 'next';
import { MarketingPage, PageIntro, StartSection } from '@/components/marketing';
import { Icon, LinkButton } from '@/components/ui';

export const metadata: Metadata = {
  title: 'Возможности',
  description:
    'Одно основное портфолио, библиотека проектов с импортом из GitHub, настоящий PDF и публикация по постоянной ссылке',
};

const features = [
  {
    id: 'home',
    icon: 'home',
    title: 'Главная',
    description:
      'Сохранённая версия портфолио: профиль и только заполненные разделы. Отсюда скачивается PDF',
  },
  {
    id: 'projects',
    icon: 'folder',
    title: 'Библиотека проектов',
    description:
      'Описание, свой вклад, технологии, ссылки и иконка из каталога. Проект хранится один раз и попадает в портфолио по вашему выбору',
  },
  {
    id: 'github',
    icon: 'github',
    title: 'Импорт из GitHub',
    description:
      'Укажите один GitHub-профиль, найдите репозитории по названию и описанию и импортируйте выбранные одним действием',
  },
  {
    id: 'editor',
    icon: 'pencil',
    title: 'Редактор',
    description:
      'Профиль, контакты, навыки, проекты, опыт и образование. Все поля необязательны, изменения сохраняются кнопкой «Сохранить»',
  },
  {
    id: 'onboarding',
    icon: 'user-round',
    title: 'Знакомство за четыре шага',
    description:
      'GitHub, имя с должностью и городом, рассказ о себе и фото. Любой шаг можно пропустить и вернуться к нему позже',
  },
  {
    id: 'pdf',
    icon: 'file-text',
    title: 'Настоящий PDF',
    description:
      'Файл с текстом, ссылками и фото собирается из сохранённой версии. Публикация для него не нужна',
  },
];

export default function FeaturesPage() {
  return (
    <MarketingPage>
      <PageIntro
        eyebrow="Возможности StackCard"
        title={
          <>
            Одно портфолио.
            <br />
            <em>Всё, что вы сделали</em>
          </>
        }
        description="Три раздела — «Главная», «Проекты» и «Редактор». Без нескольких копий одного и того же: вы ведёте одно основное портфолио и решаете, когда им поделиться"
      />
      <section className="marketing-section site-width" aria-labelledby="features-title">
        <span className="numbered-label" data-reveal>
          01 / Рабочее пространство
        </span>
        <h2 className="section-heading" id="features-title" data-reveal>
          От проекта до готового портфолио
        </h2>
        <p className="section-lead" data-reveal>
          Библиотека хранит работы. Редактор собирает из них историю, а главная показывает
          сохранённый результат
        </p>
        <div className="feature-grid">
          {features.map((feature) => (
            <article className="feature-item" id={feature.id} key={feature.id} data-reveal>
              <span className="feature-icon">
                <Icon name={feature.icon} />
              </span>
              <h3>{feature.title}</h3>
              <p>{feature.description}</p>
            </article>
          ))}
        </div>
      </section>
      <section
        className="marketing-section site-width split-section"
        aria-labelledby="single-title"
      >
        <div className="stack" data-reveal>
          <span className="numbered-label">02 / Одно портфолио</span>
          <h2 className="section-heading" id="single-title">
            Одна версия.
            <br />
            Всегда под рукой
          </h2>
          <p className="section-lead">
            Не нужно поддерживать несколько похожих документов. Главная, PDF и публичная страница
            опираются на одно основное портфолио
          </p>
          <div className="marketing-actions">
            <LinkButton href="/use-cases">
              Выбрать свой сценарий <Icon name="arrow-up" size={16} />
            </LinkButton>
          </div>
        </div>
        <div className="stack" data-reveal>
          <ul className="feature-list">
            <li>
              <strong>Начните с того, что есть.</strong> Пустые поля не мешают сохранению —
              дополняйте портфолио по мере роста
            </li>
            <li>
              <strong>Добавьте фото и город.</strong> Аватар загружается в профиль, город и страна
              вводятся вручную. Геопозиция не запрашивается
            </li>
            <li>
              <strong>Расставьте разделы.</strong> В мобильном приложении порядок контактов,
              навыков, проектов, опыта и образования меняется перетаскиванием. Главная, PDF и
              публичная страница сохраняют этот порядок
            </li>
            <li>
              <strong>Сохраните прежние документы.</strong> Резюме и портфолио из прежней версии
              остаются в архиве для восстановления и не публикуются автоматически
            </li>
          </ul>
        </div>
      </section>
      <section
        className="marketing-section site-width split-section"
        aria-labelledby="control-title"
        id="publication"
      >
        <div className="stack" data-reveal>
          <span className="numbered-label">03 / Ваш контроль</span>
          <h2 className="section-heading" id="control-title">
            Сначала подготовьте.
            <br />
            Потом поделитесь
          </h2>
          <p className="section-lead">Сохранение и публикация — два отдельных решения</p>
        </div>
        <div className="stack" data-reveal>
          <p>
            «Сохранить» фиксирует работу в кабинете: главная и PDF берут эту версию. Публичная
            страница при этом не меняется
          </p>
          <p>
            Публикация открывает сохранённую версию по постоянной ссылке — она не меняется после
            обновлений. Обновления выходят отдельным действием, а публикацию можно отозвать
          </p>
          <p>
            В мобильном приложении опубликованное портфолио превращается в визитку с QR-кодом. Ею
            можно поделиться через системное меню «Поделиться»
          </p>
          <p>
            Почта для входа не становится публичным контактом. Контакты и местоположение
            показываются только с вашего разрешения
          </p>
          <div className="marketing-actions">
            <LinkButton href="/help#publication">
              Как работает публикация <Icon name="arrow-up" size={16} />
            </LinkButton>
          </div>
        </div>
      </section>
      <section className="marketing-section site-width split-section" aria-labelledby="sync-title">
        <div className="stack" data-reveal>
          <span className="numbered-label">04 / Один аккаунт</span>
          <h2 className="section-heading" id="sync-title">
            Браузер и телефон.
            <br />
            Одни данные
          </h2>
        </div>
        <div className="stack" data-reveal>
          <p className="section-lead">
            Войдите по почте и паролю или через Google. Веб-кабинет и мобильное приложение для
            Android и iOS работают с одним портфолио
          </p>
          <p>
            Интерфейс светлый и на русском языке. Публичных сборок мобильного приложения пока нет —
            актуальный статус на странице приложения
          </p>
          <div className="marketing-actions">
            <LinkButton href="/download">
              О приложении <Icon name="arrow-up" size={16} />
            </LinkButton>
          </div>
        </div>
      </section>
      <StartSection />
    </MarketingPage>
  );
}
