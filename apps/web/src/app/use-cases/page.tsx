import type { Metadata } from 'next';
import { MarketingPage, PageIntro, StartSection } from '@/components/marketing';
import { Icon, LinkButton, TechnologyBadges } from '@/components/ui';

export const metadata: Metadata = {
  title: 'Для кого',
  description:
    'Портфолио и PDF для поиска работы, ссылка для клиентов и первая история учебных проектов. Соберите своё портфолио в StackCard',
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
            <em>Новый контекст</em>
          </>
        }
        description="Вакансия, клиент или первый учебный проект. Хорошее портфолио начинается с выбора того, что важно показать именно сейчас"
      />
      <section className="marketing-section site-width" aria-label="Сценарии использования">
        <article className="editorial-row" id="career" data-reveal>
          <span className="numbered-label">01 / Поиск работы</span>
          <div className="stack">
            <h2 className="section-heading">
              Портфолио к отклику.
              <br />И PDF к письму
            </h2>
            <p className="section-lead">Покажите работодателю опыт, который отвечает его задаче</p>
            <p>
              Соберите проекты, опыт, образование и навыки в одно портфолио. Прикрепите PDF к
              отклику или отправьте постоянную ссылку — по ней откроется опубликованная версия
            </p>
            <ul className="feature-list">
              <li>Выберите проекты, которые раскрывают нужные навыки</li>
              <li>Скачайте PDF из сохранённой версии — публикация для этого не нужна</li>
              <li>Проверьте контакты перед публикацией</li>
            </ul>
            <div className="marketing-actions">
              <LinkButton href="/examples/portfolio">
                Посмотреть пример <Icon name="arrow-up" size={16} />
              </LinkButton>
            </div>
          </div>
        </article>
        <article className="editorial-row" id="clients" data-reveal>
          <span className="numbered-label">02 / Работа с клиентами</span>
          <div className="stack">
            <h2 className="section-heading">
              Проекты, которые
              <br />
              объясняют ваш подход
            </h2>
            <p className="section-lead">Расскажите, какую задачу вы решили и что сделали лично</p>
            <p>
              Для каждой работы укажите результат, технологии, свой вклад, исходный код и
              демоверсию. Отметьте избранные проекты и задайте их порядок — так клиент сразу увидит
              главное
            </p>
            <TechnologyBadges items={['React', 'TypeScript', 'Flutter', 'Dart']} />
            <ul className="feature-list">
              <li>Выберите работы, близкие к запросу клиента</li>
              <li>Объясните результат понятными словами</li>
              <li>Поделитесь опубликованным портфолио по одной ссылке</li>
            </ul>
            <div className="marketing-actions">
              <LinkButton href="/examples/portfolio">
                Посмотреть портфолио <Icon name="arrow-up" size={16} />
              </LinkButton>
            </div>
          </div>
        </article>
        <article className="editorial-row" id="learning" data-reveal>
          <span className="numbered-label">03 / Учёба и первые шаги</span>
          <div className="stack">
            <h2 className="section-heading">
              Первый проект —<br />
              уже часть истории
            </h2>
            <p className="section-lead">Начните с того, что есть. Дополняйте по мере роста</p>
            <p>
              Курсовая, небольшой сервис, интерфейс или командная работа — всё это можно собрать в
              библиотеку. Укажите свою роль, технологии и то, чему научились. Опыт и образование
              добавьте в редакторе, а лучшие работы — в портфолио
            </p>
            <ul className="feature-list">
              <li>Импортируйте учебные репозитории из своего GitHub-профиля</li>
              <li>Добавьте проект вручную, даже если у него нет публичного репозитория</li>
              <li>Заполните только то, что есть: пустые поля не мешают сохранению</li>
            </ul>
            <div className="marketing-actions">
              <LinkButton href="/workspace" variant="primary">
                Собрать портфолио <Icon name="arrow-up" size={16} />
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
