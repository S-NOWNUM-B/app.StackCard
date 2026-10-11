import type { Metadata } from 'next';
import Link from 'next/link';
import { Icon, LinkButton } from '@/components/ui';
import { MarketingPage, StartSection } from '@/components/marketing';
import { ProductDemo } from '@/components/product-demo';

export const metadata: Metadata = {
  title: { absolute: 'StackCard — ваша работа, ваша история' },
  description:
    'Соберите проекты, опыт и навыки в одну базу. Создавайте резюме и портфолио для разных задач и делитесь выбранной версией.',
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
          <em>Ваша история.</em>
        </h1>
        <p>
          Соберите проекты, опыт и навыки в одном месте.
          <br className="desktop-break" /> Превратите их в резюме и портфолио — под вашу следующую
          цель.
        </p>
        <div className="marketing-actions">
          <LinkButton href="/workspace" variant="primary">
            Создать свою историю <span aria-hidden="true">→</span>
          </LinkButton>
          <LinkButton href="/examples">
            Посмотреть примеры <span aria-hidden="true">↗</span>
          </LinkButton>
        </div>
        <div className="hero-meta">
          <span>Одна база</span>
          <i />
          <span>Независимые документы</span>
          <i />
          <span>Публикация под вашим контролем</span>
        </div>
        <ProductDemo />
        <p className="demo-caption">Показаны вымышленный профиль и демонстрационные проекты.</p>
      </section>
      <section className="marketing-section site-width" id="features">
        <div className="section-heading">
          <span className="eyebrow">Одна база. Больше возможностей.</span>
          <h2>
            Всё связано.
            <br />
            <em>Всё по-вашему.</em>
          </h2>
          <p className="section-lead">
            Вы уже сделали работу. StackCard помогает рассказать о ней — без сборки каждого
            документа с нуля.
          </p>
        </div>
        <div className="base-flow">
          <div className="flow-source">
            <Icon name="user-round" size={24} />
            <strong>Ваш профессиональный профиль</strong>
            <span>Опыт · навыки · образование · контакты</span>
          </div>
          <span className="flow-arrow" aria-hidden="true">
            ↓
          </span>
          <div className="flow-outputs">
            <Link href="/features#resumes">
              <Icon name="file-text" />
              <strong>Резюме</strong>
              <span>Под конкретную роль</span>
            </Link>
            <Link href="/features#projects">
              <Icon name="folder" />
              <strong>Проекты</strong>
              <span>Ваша библиотека работ</span>
            </Link>
            <Link href="/features#portfolios">
              <Icon name="panels-top-left" />
              <strong>Портфолио</strong>
              <span>Под вашу аудиторию</span>
            </Link>
          </div>
        </div>
        <div className="feature-grid">
          <div className="feature-item">
            <span className="numbered-label">01 / СОБЕРИТЕ</span>
            <h3>Начните с себя</h3>
            <p>
              Добавьте свой опыт и работы в общую базу. Используйте её как основу новых документов.
            </p>
          </div>
          <div className="feature-item">
            <span className="numbered-label">02 / АДАПТИРУЙТЕ</span>
            <h3>Выберите главное</h3>
            <p>
              Свои акценты, проекты и порядок секций для каждой роли. Другие документы сохраняют
              свою версию.
            </p>
          </div>
          <div className="feature-item">
            <span className="numbered-label">03 / ПОДЕЛИТЕСЬ</span>
            <h3>Публикуйте осознанно</h3>
            <p>
              Сохранение и публикация — отдельные действия. Вы решаете, какую версию увидят по
              ссылке.
            </p>
          </div>
        </div>
      </section>
      <section className="soft-section">
        <div className="site-width split-section">
          <div className="section-heading">
            <span className="eyebrow">Ваша работа говорит за вас</span>
            <h2>
              Один проект.
              <br />
              <em>Разные акценты.</em>
            </h2>
            <p className="section-lead">
              Покажите архитектуру работодателю, результат клиенту, процесс — команде. Работа
              хранится в одной библиотеке, её история меняется под задачу.
            </p>
            <Link className="text-link" href="/use-cases">
              Найти свой сценарий <span aria-hidden="true">↗</span>
            </Link>
          </div>
          <div className="project-story">
            <div className="story-source">
              <span className="project-glyph">{'{ }'}</span>
              <div>
                <span className="mini-label">ПРИМЕР ПРОЕКТА</span>
                <h3>Atlas UI Kit</h3>
                <p>React · TypeScript · Дизайн-системы</p>
              </div>
            </div>
            <div className="story-version">
              <Icon name="file-text" size={20} />
              <div>
                <span>В резюме</span>
                <p>«Разработал библиотеку переиспользуемых компонентов»</p>
              </div>
            </div>
            <div className="story-version">
              <Icon name="panels-top-left" size={20} />
              <div>
                <span>В портфолио</span>
                <p>«От идеи до интерфейса: система, которая объединяет продукт»</p>
              </div>
            </div>
            <span className="story-caption">
              Своё описание в каждом документе. Общий проект в библиотеке.
            </span>
          </div>
        </div>
      </section>
      <section className="marketing-section site-width publication-section">
        <div className="section-heading">
          <span className="eyebrow">Без сюрпризов</span>
          <h2>
            Ваш черновик.
            <br />
            <em>Ваше решение.</em>
          </h2>
          <p className="section-lead">
            Редактируйте спокойно. Новые правки появятся в публичном документе только после
            отдельной публикации.
          </p>
        </div>
        <div className="publication-flow">
          <div>
            <span className="step-number">01</span>
            <h3>Создайте</h3>
            <p>Работайте над своей версией.</p>
          </div>
          <span aria-hidden="true">→</span>
          <div>
            <span className="step-number">02</span>
            <h3>Сохраните</h3>
            <p>Зафиксируйте черновик.</p>
          </div>
          <span aria-hidden="true">→</span>
          <div>
            <span className="step-number">03</span>
            <h3>Опубликуйте</h3>
            <p>Поделитесь выбранной версией.</p>
          </div>
        </div>
        <Link href="/help#publication" className="text-link">
          Как устроена публикация <span aria-hidden="true">↗</span>
        </Link>
      </section>
      <section className="site-width application-teaser">
        <div>
          <span className="eyebrow">Там, где вам удобно</span>
          <h2>
            Большой экран.
            <br />
            <em>И большие планы.</em>
          </h2>
          <p>Работайте в браузере. Узнайте о мобильной версии для Android и iOS.</p>
        </div>
        <LinkButton href="/download">
          О приложении <span aria-hidden="true">↗</span>
        </LinkButton>
      </section>
      <StartSection />
    </MarketingPage>
  );
}
