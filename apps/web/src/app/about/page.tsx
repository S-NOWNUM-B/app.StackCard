import type { Metadata } from 'next';
import { MarketingPage, PageIntro, StartSection } from '@/components/marketing';
import { Icon, LinkButton } from '@/components/ui';

export const metadata: Metadata = {
  title: 'О проекте',
  description:
    'StackCard помогает разработчикам собрать профессиональную историю: одну базу, библиотеку работ и разные резюме и портфолио.',
};

export default function AboutPage() {
  return (
    <MarketingPage>
      <PageIntro
        eyebrow="О проекте StackCard"
        title={
          <>
            Вы больше,
            <br />
            <em>чем список технологий.</em>
          </>
        }
        description="За каждым навыком стоит работа. За каждой работой — ваш вклад. StackCard помогает связать их в профессиональную историю, которую удобно рассказать."
      />
      <section className="marketing-section site-width split-section" aria-labelledby="idea-title">
        <div className="stack">
          <span className="numbered-label">01 / Идея</span>
          <h2 className="section-heading" id="idea-title">
            Собрать один раз.
            <br />
            Представить по-разному.
          </h2>
        </div>
        <div className="stack">
          <p className="section-lead">
            Резюме для работодателя и портфолио для клиента опираются на один опыт, но расставляют
            разные акценты.
          </p>
          <p>
            Обычно эти версии живут отдельно: сведения повторяются, описания расходятся, а хорошие
            проекты теряются среди ссылок. StackCard начинается с общей профессиональной базы и
            библиотеки работ.
          </p>
          <p>
            Из них вы создаёте независимые документы. Выбираете нужные факты, объясняете свой вклад
            и готовите версию под конкретную задачу.
          </p>
          <div className="marketing-actions">
            <LinkButton href="/features">
              Что умеет StackCard <Icon name="arrow-up" size={16} />
            </LinkButton>
          </div>
        </div>
      </section>
      <section className="marketing-section site-width" aria-labelledby="principles-title">
        <span className="numbered-label">02 / Принципы</span>
        <h2 className="section-heading" id="principles-title">
          Меньше повторов.
          <br />
          Больше собственного голоса.
        </h2>
        <div className="feature-grid">
          <article className="feature-item">
            <span className="numbered-label">01</span>
            <h3>Работы важнее громких слов</h3>
            <p>
              Покажите задачу, результат и личный вклад. Небольшой законченный проект может
              рассказать о вас больше, чем длинный список навыков.
            </p>
          </article>
          <article className="feature-item">
            <span className="numbered-label">02</span>
            <h3>Одна база, разные акценты</h3>
            <p>
              Документы используют общий опыт, сохраняя собственные формулировки и отбор проектов.
              Вы обновляете их выборочно.
            </p>
          </article>
          <article className="feature-item">
            <span className="numbered-label">03</span>
            <h3>Публикация — ваше решение</h3>
            <p>
              Черновик остаётся рабочим пространством. Сохранение не заменяет публичную версию; вы
              решаете, когда поделиться обновлениями.
            </p>
          </article>
        </div>
      </section>
      <section
        className="marketing-section site-width split-section"
        aria-labelledby="creator-title"
      >
        <div className="stack">
          <span className="numbered-label">03 / Кто создаёт</span>
          <h2 className="section-heading" id="creator-title">
            Из практики.
            <br />
            Для тех, кто делает.
          </h2>
        </div>
        <div className="stack">
          <h3>Станислав Мамаев</h3>
          <p className="muted">Разработчик · Алматы</p>
          <p>
            StackCard — самостоятельный проект Станислава Мамаева, студента программной инженерии в
            AlmaU. В основе — задача, знакомая начинающим разработчикам: собрать свои работы и
            объяснить, что умеешь, даже когда большого коммерческого опыта ещё нет.
          </p>
          <p>
            Проект развивается вокруг этого сценария: профессиональная база, понятные документы и
            осознанный выбор того, что становится публичным.
          </p>
          <div className="marketing-actions">
            <LinkButton href="/use-cases">
              Найти свой сценарий <Icon name="arrow-up" size={16} />
            </LinkButton>
          </div>
        </div>
      </section>
      <StartSection />
    </MarketingPage>
  );
}
