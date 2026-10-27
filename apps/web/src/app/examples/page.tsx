import type { Metadata } from 'next';
import { MarketingPage, PageIntro, StartSection } from '@/components/marketing';
import { Icon, LinkButton, TechnologyBadges } from '@/components/ui';
import { mainPortfolioExample } from './main-portfolio-example';

export const metadata: Metadata = {
  title: 'Пример портфолио',
  description:
    'Посмотрите, как основное портфолио StackCard выглядит по публичной ссылке и в PDF. Демонстрационные данные',
};

export default function ExamplesPage() {
  const portfolio = mainPortfolioExample();

  return (
    <MarketingPage>
      <PageIntro
        eyebrow="Пример портфолио"
        title={
          <>
            Одно портфолио.
            <br />
            <em>Ссылка и PDF</em>
          </>
        }
        description="Посмотрите, как выглядит готовый результат в StackCard. Публичная страница и PDF собираются из одного основного портфолио"
      />
      <section className="marketing-section site-width" aria-labelledby="examples-title">
        <span className="numbered-label" data-reveal>
          01 / Посмотрите в действии
        </span>
        <h2 className="section-heading" id="examples-title" data-reveal>
          Две формы одной истории
        </h2>
        <p className="section-lead" data-reveal>
          Алекс Морган и работы ниже — вымышленные демонстрационные данные. Это пример, а не
          публикация пользователя
        </p>
        <div className="example-grid">
          <article className="example-card" data-reveal>
            <div className="example-paper stack" aria-label="Фрагмент демонстрационного портфолио">
              <div className="stack">
                <span className="eyebrow">Публичная страница</span>
                <h3>{portfolio.profile.name}</h3>
                <p className="muted">
                  {portfolio.profile.headline} · {portfolio.profile.locationText}
                </p>
              </div>
              <hr />
              <div className="stack">
                <h4>Избранные работы</h4>
                {portfolio.projects.map((project) => (
                  <div className="stack" key={project.id}>
                    <strong>{project.title}</strong>
                    <p>{project.description}</p>
                    <TechnologyBadges items={project.technologies} />
                  </div>
                ))}
              </div>
            </div>
            <div className="stack">
              <span className="numbered-label">01 / По ссылке</span>
              <h2>Публичное портфолио</h2>
              <p>
                Профиль, контакты, навыки, проекты, опыт и образование. Открывается по постоянной
                ссылке после публикации
              </p>
              <div className="marketing-actions">
                <LinkButton href="/examples/portfolio" variant="primary">
                  Открыть пример <Icon name="arrow-up" size={16} />
                </LinkButton>
              </div>
            </div>
          </article>
          <article className="example-card" data-reveal>
            <div className="example-paper stack" aria-label="Фрагмент демонстрационного PDF">
              <div className="stack">
                <span className="eyebrow">PDF · A4</span>
                <h3>{portfolio.profile.name}</h3>
                <p className="muted">{portfolio.profile.headline}</p>
              </div>
              <hr />
              <div className="stack">
                <h4>Навыки</h4>
                <TechnologyBadges items={portfolio.skills.map((skill) => skill.name)} />
              </div>
              <div className="stack">
                <h4>Опыт</h4>
                {portfolio.experience.map((experience) => (
                  <div key={experience.id}>
                    <strong>{experience.role}</strong>
                    <p className="muted">
                      {experience.organization} · {experience.period}
                    </p>
                  </div>
                ))}
              </div>
              <div className="stack">
                <h4>Образование</h4>
                {portfolio.education.map((education) => (
                  <div key={education.id}>
                    <strong>{education.qualification}</strong>
                    <p className="muted">{education.institution}</p>
                  </div>
                ))}
              </div>
            </div>
            <div className="stack">
              <span className="numbered-label">02 / Файлом</span>
              <h2>PDF-портфолио</h2>
              <p>
                Настоящий PDF с текстом, ссылками и фото. Собирается из сохранённой версии,
                публикация для него не нужна
              </p>
              <div className="marketing-actions">
                <LinkButton href="/examples/portfolio#pdf" variant="primary">
                  Подробнее о PDF <Icon name="arrow-up" size={16} />
                </LinkButton>
              </div>
            </div>
          </article>
        </div>
      </section>
      <section
        className="marketing-section site-width split-section"
        aria-labelledby="your-version-title"
      >
        <div className="stack" data-reveal>
          <span className="numbered-label">02 / Ваша версия</span>
          <h2 className="section-heading" id="your-version-title">
            Форма готова.
            <br />
            История — ваша
          </h2>
        </div>
        <div className="stack" data-reveal>
          <p>
            В кабинете вы заполняете своё портфолио: импортируйте проекты из GitHub, добавьте опыт и
            образование, сохраните и решите, когда публиковать. Пример помогает понять структуру и
            не добавляет вымышленные данные в ваш аккаунт
          </p>
          <div className="marketing-actions">
            <LinkButton href="/help#documents">
              Как собрать портфолио <Icon name="arrow-up" size={16} />
            </LinkButton>
          </div>
        </div>
      </section>
      <StartSection />
    </MarketingPage>
  );
}
