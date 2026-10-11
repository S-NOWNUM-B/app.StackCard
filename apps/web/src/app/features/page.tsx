import type { Metadata } from 'next';
import { MarketingPage, PageIntro, StartSection } from '@/components/marketing';
import { Icon, LinkButton } from '@/components/ui';

export const metadata: Metadata = {
  title: 'Возможности',
  description:
    'Общая профессиональная база, библиотека проектов и независимые резюме и портфолио. Сохраняйте и публикуйте свою работу осознанно.',
};

const features = [
  {
    id: 'base',
    icon: 'user-round',
    title: 'Профессиональная база',
    description:
      'Профиль, навыки, опыт, образование и контакты в одном месте. Новый документ получает эти данные как отправную точку.',
  },
  {
    id: 'projects',
    icon: 'folder',
    title: 'Библиотека проектов',
    description:
      'Храните описание работы, свой вклад, технологии и ссылки. Один проект можно включать в разные резюме и портфолио.',
  },
  {
    id: 'resumes',
    icon: 'file-text',
    title: 'Несколько резюме',
    description:
      'Создавайте версии под разные роли. Выбирайте секции, порядок проектов и формулировки для конкретного работодателя.',
  },
  {
    id: 'portfolios',
    icon: 'panels-top-left',
    title: 'Собственное портфолио',
    description:
      'Соберите выбранные работы в отдельную историю. Подчеркните важные проекты и добавьте ссылку на опубликованное резюме.',
  },
  {
    id: 'document-editing',
    icon: 'pencil',
    title: 'Правки под задачу',
    description:
      'Меняйте название, описание и свой вклад внутри документа. Эти формулировки не заменяют проект в общей библиотеке.',
  },
  {
    id: 'publication',
    icon: 'check',
    title: 'Вы управляете результатом',
    description:
      'Просмотрите документ, сохраните изменения и отдельно опубликуйте их. Черновик остаётся вашим рабочим пространством.',
  },
];

export default function FeaturesPage() {
  return (
    <MarketingPage>
      <PageIntro
        eyebrow="Возможности StackCard"
        title={
          <>
            Одна база.
            <br />
            <em>Ваши разные стороны.</em>
          </>
        }
        description="Всё, что вы умеете и создаёте, уже связано. StackCard помогает собрать из этого нужное представление — без заполнения профиля с нуля каждый раз."
      />
      <section className="marketing-section site-width" aria-labelledby="features-title">
        <span className="numbered-label">01 / Рабочее пространство</span>
        <h2 className="section-heading" id="features-title">
          От опыта к готовому документу.
        </h2>
        <p className="section-lead">
          База хранит факты. Документы помогают выбрать, какие из них рассказать.
        </p>
        <div className="feature-grid">
          {features.map((feature) => (
            <article className="feature-item" id={feature.id} key={feature.id}>
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
        aria-labelledby="versions-title"
      >
        <div className="stack">
          <span className="numbered-label">02 / Независимые версии</span>
          <h2 className="section-heading" id="versions-title">
            Один опыт.
            <br />
            Разные акценты.
          </h2>
          <p className="section-lead">
            Резюме для вакансии фронтенд-разработчика и портфолио для клиента могут рассказывать о
            вас по-разному.
          </p>
          <div className="marketing-actions">
            <LinkButton href="/use-cases">
              Выбрать свой сценарий <Icon name="arrow-up" size={16} />
            </LinkButton>
          </div>
        </div>
        <div className="stack">
          <ul className="feature-list">
            <li>
              <strong>Начните с общей базы.</strong> Данные профиля становятся основой нового резюме
              или портфолио.
            </li>
            <li>
              <strong>Соберите нужное представление.</strong> Выберите проекты, секции и
              формулировки для этой версии.
            </li>
            <li>
              <strong>Обновляйте выборочно.</strong> Изменение базы не переписывает готовые
              документы. Вы сами принимаете нужные изменения.
            </li>
            <li>
              <strong>Сохраните библиотеку.</strong> Удаление проекта из документа убирает связь с
              ним, а сама работа остаётся в библиотеке.
            </li>
          </ul>
        </div>
      </section>
      <section
        className="marketing-section site-width split-section"
        aria-labelledby="control-title"
      >
        <div className="stack">
          <span className="numbered-label">03 / Ваш контроль</span>
          <h2 className="section-heading" id="control-title">
            Сначала подготовьте.
            <br />
            Потом поделитесь.
          </h2>
          <p className="section-lead">Сохранение и публикация — два отдельных решения.</p>
        </div>
        <div className="stack">
          <p>
            Редактируйте документ и проверяйте результат в предпросмотре. Сохранение фиксирует вашу
            работу в кабинете; оно не меняет публичную страницу.
          </p>
          <p>
            Публикация открывает выбранную сохранённую версию по постоянной ссылке. Обновления
            выходят отдельно, а доступ к документу можно отозвать.
          </p>
          <p>
            Почта для входа не становится публичным контактом. Для контактов и местоположения вы
            отдельно разрешаете публикацию.
          </p>
          <div className="marketing-actions">
            <LinkButton href="/help#publication">
              Как работает публикация <Icon name="arrow-up" size={16} />
            </LinkButton>
          </div>
        </div>
      </section>
      <StartSection />
    </MarketingPage>
  );
}
