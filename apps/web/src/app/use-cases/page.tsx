import type { Metadata } from 'next';
import { MarketingPage, PageIntro, StartSection } from '@/components/marketing';
import { Icon, LinkButton, TechnologyBadges } from '@/components/ui';

export const metadata: Metadata = {
  title: 'Для кого',
  description:
    'Резюме для поиска работы, портфолио для клиентов и история учебных проектов. Соберите версию под свою задачу в StackCard.',
};

export default function UseCasesPage() {
  return (
    <MarketingPage>
      <PageIntro
        eyebrow="Для тех, кто создаёт"
        title={
          <>
            Ваша работа.
            <br />
            <em>Новый контекст.</em>
          </>
        }
        description="Вакансия, клиент или первый учебный проект. Хорошее представление начинается с выбора того, что важно именно сейчас."
      />
      <section className="marketing-section site-width" aria-label="Сценарии использования">
        <article className="editorial-row" id="career">
          <span className="numbered-label">01 / Поиск работы</span>
          <div className="stack">
            <h2 className="section-heading">
              Резюме под роль.
              <br />А не на все случаи.
            </h2>
            <p className="section-lead">Покажите работодателю опыт, который отвечает его задаче.</p>
            <p>
              Создайте отдельную версию для фронтенд-, мобильной или фулстек-разработки. Оставьте
              нужные навыки и проекты, измените описание своего вклада — общая база и остальные
              документы сохранятся.
            </p>
            <ul className="feature-list">
              <li>Выберите проекты, которые раскрывают нужные навыки.</li>
              <li>Оставьте опыт, который относится к выбранной роли.</li>
              <li>Проверьте контакты и предпросмотр перед публикацией.</li>
            </ul>
            <div className="marketing-actions">
              <LinkButton href="/examples/resume">
                Посмотреть резюме <Icon name="arrow-up" size={16} />
              </LinkButton>
            </div>
          </div>
        </article>
        <article className="editorial-row" id="clients">
          <span className="numbered-label">02 / Работа с клиентами</span>
          <div className="stack">
            <h2 className="section-heading">
              Проекты, которые
              <br />
              объясняют ваш подход.
            </h2>
            <p className="section-lead">Расскажите, какую задачу вы решили и что сделали лично.</p>
            <p>
              В портфолио можно сделать акцент на выбранных работах: описание результата,
              технологии, ваш вклад, исходный код и работающая демоверсия. Один проект может
              получить разные формулировки в разных документах.
            </p>
            <TechnologyBadges items={['React', 'TypeScript', 'Flutter', 'Dart']} />
            <ul className="feature-list">
              <li>Выберите работы, близкие к запросу клиента.</li>
              <li>Объясните результат понятными словами.</li>
              <li>Поделитесь опубликованной версией по одной ссылке.</li>
            </ul>
            <div className="marketing-actions">
              <LinkButton href="/examples/portfolio">
                Посмотреть портфолио <Icon name="arrow-up" size={16} />
              </LinkButton>
            </div>
          </div>
        </article>
        <article className="editorial-row" id="learning">
          <span className="numbered-label">03 / Учёба и первые шаги</span>
          <div className="stack">
            <h2 className="section-heading">
              Первый проект —<br />
              уже часть истории.
            </h2>
            <p className="section-lead">Начните с того, что есть. Дополняйте по мере роста.</p>
            <p>
              Курсовая, небольшой сервис, интерфейс или командная работа — всё это можно собрать в
              библиотеку. Укажите свою роль, технологии и то, чему научились. Опыт и образование
              добавляйте в базу, а лучшие работы выбирайте для первого резюме.
            </p>
            <ul className="feature-list">
              <li>Добавьте проект вручную, даже если у него нет публичного репозитория.</li>
              <li>Отделите свой вклад от результата всей команды.</li>
              <li>Соберите первую версию и обновляйте её осознанно.</li>
            </ul>
            <div className="marketing-actions">
              <LinkButton href="/workspace" variant="primary">
                Собрать свою историю <Icon name="arrow-up" size={16} />
              </LinkButton>
              <LinkButton href="/help#getting-started">С чего начать</LinkButton>
            </div>
          </div>
        </article>
      </section>
      <StartSection />
    </MarketingPage>
  );
}
