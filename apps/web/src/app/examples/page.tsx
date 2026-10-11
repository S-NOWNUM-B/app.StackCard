import type { Metadata } from 'next';
import { exampleDocumentContent } from '@/components/document-view';
import { MarketingPage, PageIntro, StartSection } from '@/components/marketing';
import { Icon, LinkButton, TechnologyBadges } from '@/components/ui';

export const metadata: Metadata = {
  title: 'Примеры резюме и портфолио',
  description:
    'Посмотрите, как одна профессиональная база превращается в резюме и портфолио. Демонстрационные документы StackCard.',
};

export default function ExamplesPage() {
  const resume = exampleDocumentContent('resume');
  const portfolio = exampleDocumentContent('portfolio');

  return (
    <MarketingPage>
      <PageIntro
        eyebrow="Примеры документов"
        title={
          <>
            Две формы.
            <br />
            <em>Одна история.</em>
          </>
        }
        description="Посмотрите, как выглядит готовое представление в StackCard. Резюме помогает быстро познакомиться с опытом; портфолио — подробнее раскрыть работы."
      />
      <section className="marketing-section site-width" aria-labelledby="examples-title">
        <span className="numbered-label">01 / Посмотрите в действии</span>
        <h2 className="section-heading" id="examples-title">
          Выберите, с чего начать.
        </h2>
        <p className="section-lead">
          Алекс Морган и работы ниже — вымышленные демонстрационные данные. Это примеры, а не
          публикации пользователей.
        </p>
        <div className="example-grid">
          <article className="example-card">
            <div className="example-paper stack" aria-label="Фрагмент демонстрационного резюме">
              <div className="stack">
                <span className="eyebrow">Резюме</span>
                <h3>{resume.profile.name}</h3>
                <p className="muted">{resume.profile.headline}</p>
              </div>
              <hr />
              <div className="stack">
                <h4>Технологии</h4>
                <TechnologyBadges items={resume.skills.map((skill) => skill.name)} />
              </div>
              <div className="stack">
                <h4>Опыт</h4>
                {resume.experience.map((experience) => (
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
                {resume.education.map((education) => (
                  <div key={education.id}>
                    <strong>{education.qualification}</strong>
                    <p className="muted">{education.institution}</p>
                  </div>
                ))}
              </div>
            </div>
            <div className="stack">
              <span className="numbered-label">01 / Опыт и навыки</span>
              <h2>Резюме</h2>
              <p>
                Короткое представление для знакомства: роль, технологии, опыт, образование и
                выбранные проекты.
              </p>
              <div className="marketing-actions">
                <LinkButton href="/examples/resume" variant="primary">
                  Открыть резюме <Icon name="arrow-up" size={16} />
                </LinkButton>
              </div>
            </div>
          </article>
          <article className="example-card">
            <div className="example-paper stack" aria-label="Фрагмент демонстрационного портфолио">
              <div className="stack">
                <span className="eyebrow">Портфолио</span>
                <h3>{portfolio.profile.name}</h3>
                <p className="muted">{portfolio.profile.headline}</p>
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
              <span className="numbered-label">02 / Работы и результаты</span>
              <h2>Портфолио</h2>
              <p>
                Больше пространства для проектов: описания работ, используемые технологии и ваше
                профессиональное направление.
              </p>
              <div className="marketing-actions">
                <LinkButton href="/examples/portfolio" variant="primary">
                  Открыть портфолио <Icon name="arrow-up" size={16} />
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
        <div className="stack">
          <span className="numbered-label">02 / Ваша версия</span>
          <h2 className="section-heading" id="your-version-title">
            Форма готова.
            <br />
            История — ваша.
          </h2>
        </div>
        <div className="stack">
          <p>
            В кабинете документы создаются из вашей базы. Выберите секции, добавьте проекты и
            измените формулировки под нужную задачу. Примеры помогают понять структуру; они не
            добавляют вымышленные данные в ваш аккаунт.
          </p>
          <div className="marketing-actions">
            <LinkButton href="/help#documents">
              Как создать документ <Icon name="arrow-up" size={16} />
            </LinkButton>
          </div>
        </div>
      </section>
      <StartSection />
    </MarketingPage>
  );
}
