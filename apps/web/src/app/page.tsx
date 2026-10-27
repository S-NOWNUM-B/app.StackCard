import type { Metadata } from 'next';
import Link from 'next/link';
import { Icon, LinkButton } from '@/components/ui';
import { MarketingPage, StartSection } from '@/components/marketing';
import { ProductDemo } from '@/components/product-demo';

export const metadata: Metadata = {
  title: { absolute: 'StackCard — ваша работа, ваша история' },
  description:
    'Соберите профиль, проекты и опыт в одно портфолио. Импортируйте работы из GitHub, скачайте PDF и поделитесь постоянной ссылкой',
};

export default function LandingPage() {
  return (
    <MarketingPage>
      <section className="landing-hero">
        <Link href="/about" className="hero-note">
          <span className="status-dot" /> Для тех, кто создаёт <span aria-hidden="true">↗</span>
        </Link>
        <h1>
          Ваша работа.
          <br />
          <em>Ваша история</em>
        </h1>
        <p>
          Соберите профиль, проекты и опыт в одно портфолио.
          <br className="desktop-break" /> Скачайте PDF или поделитесь постоянной ссылкой, когда
          будете готовы
        </p>
        <div className="marketing-actions">
          <LinkButton href="/workspace" variant="primary">
            Создать портфолио{' '}
            <span className="arrow-right" aria-hidden="true">
              →
            </span>
          </LinkButton>
          <LinkButton href="/examples">
            Посмотреть пример <span aria-hidden="true">↗</span>
          </LinkButton>
        </div>
        <div className="hero-meta">
          <span>Одно портфолио</span>
          <i />
          <span>Импорт из GitHub</span>
          <i />
          <span>Публикация под вашим контролем</span>
        </div>
        <ProductDemo />
        <p className="demo-caption">Показаны вымышленный профиль и демонстрационные проекты</p>
      </section>
      <section className="marketing-section site-width" id="features">
        <div className="section-heading" data-reveal>
          <span className="eyebrow">Три раздела. Одно портфолио</span>
          <h2>
            Всё связано.
            <br />
            <em>Всё по-вашему</em>
          </h2>
          <p className="section-lead">
            Вы уже сделали работу. StackCard помогает рассказать о ней — в одном портфолио, которое
            легко обновлять
          </p>
        </div>
        <div className="base-flow" data-reveal>
          <div className="flow-source">
            <Icon name="user-round" size={24} />
            <strong>Ваше основное портфолио</strong>
            <span>Профиль · контакты · навыки · проекты · опыт · образование</span>
          </div>
          <span className="flow-arrow" aria-hidden="true">
            ↓
          </span>
          <div className="flow-outputs">
            <Link href="/features#home">
              <Icon name="home" />
              <strong>Главная</strong>
              <span>Сохранённая версия и PDF</span>
            </Link>
            <Link href="/features#projects">
              <Icon name="folder" />
              <strong>Проекты</strong>
              <span>Библиотека и импорт из GitHub</span>
            </Link>
            <Link href="/features#editor">
              <Icon name="pencil" />
              <strong>Редактор</strong>
              <span>Правки с явным сохранением</span>
            </Link>
          </div>
        </div>
        <div className="feature-grid">
          <div className="feature-item" data-reveal>
            <span className="numbered-label">01 / НАЧНИТЕ</span>
            <h3>Четыре шага знакомства</h3>
            <p>
              GitHub-профиль, имя с должностью и городом, рассказ о себе и фото. Любой шаг можно
              пропустить и вернуться к нему позже
            </p>
          </div>
          <div className="feature-item" data-reveal>
            <span className="numbered-label">02 / СОБЕРИТЕ</span>
            <h3>Проекты из GitHub</h3>
            <p>
              Выберите нужные репозитории одного профиля и импортируйте их одним действием.
              Остальные работы добавьте вручную
            </p>
          </div>
          <div className="feature-item" data-reveal>
            <span className="numbered-label">03 / ПОДЕЛИТЕСЬ</span>
            <h3>PDF и постоянная ссылка</h3>
            <p>
              PDF собирается из сохранённой версии. Публичная страница появляется только после
              отдельной публикации
            </p>
          </div>
        </div>
      </section>
      <section className="soft-section">
        <div className="site-width split-section">
          <div className="section-heading" data-reveal>
            <span className="eyebrow">Ваша работа говорит за вас</span>
            <h2>
              Репозитории.
              <br />
              <em>Без копирования</em>
            </h2>
            <p className="section-lead">
              Укажите GitHub-профиль один раз — при знакомстве или в настройках. Отметьте проекты в
              списке и импортируйте их пачкой. Описание, свой вклад, технологии и иконку уточните в
              библиотеке
            </p>
            <Link className="text-link" href="/use-cases">
              Найти свой сценарий <span aria-hidden="true">↗</span>
            </Link>
          </div>
          <div className="project-story" data-reveal>
            <div className="story-source">
              <span className="project-glyph">
                <Icon name="github" size={28} />
              </span>
              <div>
                <span className="mini-label">ИМПОРТ ИЗ GITHUB</span>
                <h3>github.com/alexmorgan</h3>
                <p>Поиск по названию и описанию</p>
              </div>
            </div>
            <div className="story-version">
              <span className="story-check is-checked" aria-hidden="true">
                <Icon name="check" size={16} />
              </span>
              <div>
                <span>Выбран · React · TypeScript</span>
                <p>atlas-ui-kit</p>
              </div>
            </div>
            <div className="story-version">
              <span className="story-check is-checked" aria-hidden="true">
                <Icon name="check" size={16} />
              </span>
              <div>
                <span>Выбран · Flutter · Firebase</span>
                <p>pocket-tasks</p>
              </div>
            </div>
            <div className="story-version">
              <span className="story-check" aria-hidden="true" />
              <div>
                <span>Не выбран · Dart</span>
                <p>playground</p>
              </div>
            </div>
            <span className="story-caption">
              Импорт сохраняется отдельно: он не публикует портфолио и не трогает несохранённые
              правки редактора
            </span>
          </div>
        </div>
      </section>
      <section className="marketing-section site-width publication-section">
        <div className="section-heading" data-reveal>
          <span className="eyebrow">Без сюрпризов</span>
          <h2>
            Ваш черновик.
            <br />
            <em>Ваше решение</em>
          </h2>
          <p className="section-lead">
            Редактируйте спокойно. «Сохранить» не публикует — новые правки появятся по ссылке только
            после отдельной публикации
          </p>
        </div>
        <div className="publication-flow">
          <div data-reveal>
            <span className="step-number">01</span>
            <h3>Отредактируйте</h3>
            <p>Заполните то, что готовы показать</p>
          </div>
          <span aria-hidden="true">→</span>
          <div data-reveal>
            <span className="step-number">02</span>
            <h3>Сохраните</h3>
            <p>Главная и PDF возьмут эту версию</p>
          </div>
          <span aria-hidden="true">→</span>
          <div data-reveal>
            <span className="step-number">03</span>
            <h3>Опубликуйте</h3>
            <p>Получите постоянную ссылку</p>
          </div>
        </div>
        <Link href="/help#publication" className="text-link">
          Как устроена публикация <span aria-hidden="true">↗</span>
        </Link>
      </section>
      <section className="site-width application-teaser" data-reveal>
        <div>
          <span className="eyebrow">Там, где вам удобно</span>
          <h2>
            Браузер и телефон.
            <br />
            <em>Одни данные</em>
          </h2>
          <p>
            Веб-кабинет и мобильное приложение работают с одним аккаунтом. В приложении есть визитка
            с QR-кодом и кнопка «Поделиться». Публичных сборок для Android и iOS пока нет
          </p>
        </div>
        <LinkButton href="/download">
          О приложении <span aria-hidden="true">↗</span>
        </LinkButton>
      </section>
      <StartSection />
    </MarketingPage>
  );
}
