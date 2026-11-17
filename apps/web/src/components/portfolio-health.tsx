'use client';
import { Button } from './ui';
import {
  healthCheckId,
  healthSectionFraction,
  healthSections,
  healthTip,
  type HealthSection,
  type PortfolioHealth,
} from '@/lib/portfolio-health';

// Раздел редактора, к которому ведёт совет; публикация живёт на Главной.
// Фото редактируется внутри карточки «Профиль».
export const healthEditorSection: Record<Exclude<HealthSection, 'publication'>, string> = {
  profile: 'editor-section-profile',
  avatar: 'editor-section-profile',
  projects: 'editor-section-featuredProjects',
  experience: 'editor-section-experience',
  education: 'editor-section-education',
  skills: 'editor-section-skills',
  contacts: 'editor-section-links',
};

const summaryText = (health: PortfolioHealth) =>
  health.isPerfect ? 'Отлично, советов нет' : `Советов: ${health.improvements.length}`;

// Кольцо счёта: круг длиной 100, поэтому длина дуги равна баллу.
export function ScoreRing({ score, size = 56 }: { score: number; size?: number }) {
  return (
    <span className="health-ring" style={{ width: size, height: size }}>
      <svg viewBox="0 0 36 36" aria-hidden="true">
        <circle className="health-ring-track" cx="18" cy="18" r="15.9155" />
        <circle
          className={`health-ring-value${score >= 80 ? ' is-good' : ''}`}
          cx="18"
          cy="18"
          r="15.9155"
          strokeDasharray={`${score} 100`}
        />
      </svg>
      <span className="health-ring-score">{score}</span>
    </span>
  );
}

// Компактная карточка Главной: счёт и переход к деталям. Только чтение.
export function HealthCard({ health, onOpen }: { health: PortfolioHealth; onOpen: () => void }) {
  return (
    <button
      type="button"
      className="summary-card health-card"
      onClick={onOpen}
      aria-label={`Здоровье портфолио: ${health.score} из 100. ${summaryText(health)}`}
    >
      <ScoreRing score={health.score} />
      <span className="summary-card-text">
        <span className="summary-card-title">Здоровье портфолио</span>
        <span className="muted">{summaryText(health)}</span>
      </span>
      <span className="summary-card-chevron" aria-hidden="true">
        ›
      </span>
    </button>
  );
}

// Детали: общий балл, разделы и советы с переходом в нужный раздел редактора.
export function HealthDetails({
  health,
  onBack,
  onOpenSection,
}: {
  health: PortfolioHealth | null;
  onBack: () => void;
  onOpenSection: (section: HealthSection) => void;
}) {
  return (
    <section className="stack health-view view-enter">
      <Button variant="quiet" className="back-button" onClick={onBack}>
        Назад на Главную
      </Button>
      <div className="view-heading">
        <h1>Здоровье портфолио</h1>
        <p className="muted">Оценка только читает сохранённую версию и ничего не меняет</p>
      </div>
      {!health ? (
        <div className="empty-state">
          <p className="empty-state-title">Пока нечего оценивать</p>
          <p className="muted">Заполните и сохраните портфолио в Редакторе, чтобы увидеть оценку</p>
          <Button onClick={() => onOpenSection('profile')}>Открыть редактор</Button>
        </div>
      ) : (
        <>
          <div className="health-summary">
            <ScoreRing score={health.score} size={80} />
            <p className="health-summary-text" aria-live="polite">
              {summaryText(health)}
            </p>
          </div>
          <ul className="health-sections" aria-label="Разделы оценки">
            {(Object.keys(healthSections) as HealthSection[]).map((section) => {
              const fraction = healthSectionFraction(health, section);
              if (fraction === null) return null;
              return (
                <li key={section} className={fraction === 1 ? 'is-ok' : undefined}>
                  <span className="health-section-mark" aria-hidden="true">
                    {fraction === 1 ? '✓' : '!'}
                  </span>
                  <span className="health-section-title">{healthSections[section].title}</span>
                  <span className="muted">{Math.round(fraction * 100)}%</span>
                </li>
              );
            })}
          </ul>
          {!health.isPerfect && (
            <>
              <h2>Что улучшить</h2>
              <ul className="health-tips" aria-label="Советы">
                {health.improvements.map((check) => (
                  <li key={`${check.section}:${healthCheckId(check)}`} className="health-tip">
                    <span className="muted health-tip-section">
                      {healthSections[check.section].title}
                    </span>
                    <span className="health-tip-text">{healthTip(check)}</span>
                    <Button variant="secondary" onClick={() => onOpenSection(check.section)}>
                      {check.section === 'publication' ? 'Открыть Главную' : 'Открыть в Редакторе'}
                    </Button>
                  </li>
                ))}
              </ul>
            </>
          )}
        </>
      )}
    </section>
  );
}
