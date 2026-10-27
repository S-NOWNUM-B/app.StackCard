import type { Metadata } from 'next';
import { MarketingPage, PageIntro, StartSection } from '@/components/marketing';
import { Icon, LinkButton } from '@/components/ui';

export const metadata: Metadata = {
  title: 'О проекте',
  description:
    'StackCard помогает разработчикам собрать профессиональную историю: библиотеку работ и одно портфолио для ссылки, PDF и визитки',
};

export default function AboutPage() {
  return (
    <MarketingPage>
      <PageIntro
        eyebrow="О проекте StackCard"
        title={
          <>
            Не просто
            <br />
            <em>список технологий</em>
          </>
        }
        description="За каждым навыком стоит работа. За каждой работой — ваш вклад. StackCard помогает связать их в профессиональную историю, которую удобно рассказать"
      />
      <section className="marketing-section site-width split-section" aria-labelledby="idea-title">
        <div className="stack" data-reveal>
          <span className="numbered-label">01 / Идея</span>
          <h2 className="section-heading" id="idea-title">
            Собрать один раз
            <br />
            Показывать везде
          </h2>
        </div>
        <div className="stack" data-reveal>
          <p className="section-lead">
            Ссылка, PDF и визитка опираются на одно портфолио — его достаточно поддерживать в
            актуальном виде
          </p>
          <p>
            Обычно сведения о себе живут в нескольких местах: резюме повторяют друг друга, описания
            расходятся, а хорошие проекты теряются среди ссылок. StackCard начинается с библиотеки
            работ и одного основного портфолио
          </p>
          <p>
            Вы заполняете то, что готовы показать, объясняете свой вклад и сохраняете результат.
            Когда публиковать — решаете сами
          </p>
          <div className="marketing-actions">
            <LinkButton href="/features">
              Что умеет StackCard <Icon name="arrow-up" size={16} />
            </LinkButton>
          </div>
        </div>
      </section>
      <section className="marketing-section site-width" aria-labelledby="principles-title">
        <span className="numbered-label" data-reveal>
          02 / Принципы
        </span>
        <h2 className="section-heading" id="principles-title" data-reveal>
          Меньше повторов
          <br />
          Больше собственного голоса
        </h2>
        <div className="feature-grid">
          <article className="feature-item" data-reveal>
            <span className="numbered-label">01</span>
            <h3>Работы важнее громких слов</h3>
            <p>
              Покажите задачу, результат и личный вклад. Небольшой законченный проект может
              рассказать о вас больше, чем длинный список навыков
            </p>
          </article>
          <article className="feature-item" data-reveal>
            <span className="numbered-label">02</span>
            <h3>Одно портфолио вместо копий</h3>
            <p>
              Не нужно поддерживать похожие резюме по отдельности. Обновите портфолио — и PDF сразу
              возьмёт сохранённую версию
            </p>
          </article>
          <article className="feature-item" data-reveal>
            <span className="numbered-label">03</span>
            <h3>Публикация по вашему решению</h3>
            <p>
              Черновик остаётся рабочим пространством. Сохранение не заменяет публичную версию: вы
              решаете, когда поделиться обновлениями
            </p>
          </article>
        </div>
      </section>
      <section
        className="marketing-section site-width split-section"
        aria-labelledby="creator-title"
      >
        <div className="stack" data-reveal>
          <span className="numbered-label">03 / Кто создаёт</span>
          <h2 className="section-heading" id="creator-title">
            Из практики
            <br />
            Для людей дела
          </h2>
        </div>
        <div className="stack" data-reveal>
          <h3>Станислав Мамаев</h3>
          <p className="muted">Разработчик · Алматы</p>
          <p>
            StackCard — самостоятельный проект Станислава Мамаева, студента программной инженерии в
            AlmaU. В основе — задача, знакомая начинающим разработчикам: собрать свои работы и
            объяснить, что умеешь, даже когда большого коммерческого опыта ещё нет
          </p>
          <p>
            Проект развивается вокруг этого сценария: библиотека работ, одно понятное портфолио и
            осознанный выбор того, что становится публичным
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
