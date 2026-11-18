'use client';
import { useState } from 'react';
import { Button, Field, PageHeader } from './ui';
import type { DocumentContent, MainPortfolioSectionKind } from '@/lib/model';
import {
  buildVacancyExportContent,
  matchVacancy,
  vacancyMaximumLength,
  vacancyMinimumLength,
  type VacancyMatch,
  type VacancyOrder,
} from '@/lib/vacancy-match';

const sectionTitles: Record<MainPortfolioSectionKind, string> = {
  skills: 'Навыки',
  featuredProjects: 'Проекты',
  experience: 'Опыт',
  education: 'Образование',
  links: 'Контакты',
};

function Chips({ items, ok }: { items: VacancyMatch['requirements']; ok: boolean }) {
  return (
    <ul className="vacancy-chips">
      {items.map((item) => (
        <li key={item.term.id} className={`badge vacancy-chip${ok ? ' is-ok' : ''}`}>
          <span aria-hidden="true">{ok ? '✓' : '✕'}</span>
          {item.term.label}
        </li>
      ))}
    </ul>
  );
}

// Подбор под вакансию. Текст живёт только в состоянии компонента: не попадает в draft,
// localStorage, Firestore и историю версий, а при уходе с экрана исчезает вместе с ним.
export function VacancyMatchView({
  saved,
  busy,
  onBack,
  onOpenEditor,
  onApply,
  onExport,
}: {
  // Разрешённое сохранённое основное портфолио; null — оно ещё не заполнено.
  saved: DocumentContent | null;
  busy: boolean;
  onBack: () => void;
  onOpenEditor: () => void;
  onApply: (order: VacancyOrder) => void;
  onExport: (content: DocumentContent) => Promise<void>;
}) {
  const [text, setText] = useState(''),
    [match, setMatch] = useState<VacancyMatch | null>(null),
    [matchedSaved, setMatchedSaved] = useState<DocumentContent | null>(null),
    [projects, setProjects] = useState<Set<string>>(new Set()),
    [sections, setSections] = useState<Set<MainPortfolioSectionKind>>(new Set()),
    [exporting, setExporting] = useState(false);
  const longEnough = text.trim().length >= vacancyMinimumLength;

  function compare() {
    if (!saved || !longEnough) return;
    const result = matchVacancy({ vacancyText: text, content: saved });
    const relevant = result.projects.filter((item) => item.score > 0);
    setMatch(result);
    setMatchedSaved(saved);
    // По умолчанию в PDF идут релевантные проекты (или все, если их нет).
    setProjects(
      new Set((relevant.length === 0 ? result.projects : relevant).map((item) => item.projectId)),
    );
    setSections(new Set(result.sectionOrder));
  }
  function toggle<T>(current: Set<T>, value: T, on: boolean) {
    const next = new Set(current);
    if (on) next.add(value);
    else next.delete(value);
    return next;
  }
  async function exportPdf() {
    if (!match || !matchedSaved || exporting) return;
    setExporting(true);
    try {
      await onExport(
        buildVacancyExportContent(matchedSaved, {
          projectOrder: match.projectOrder,
          includedProjects: projects,
          sectionOrder: match.sectionOrder,
          includedSections: sections,
        }),
      );
    } finally {
      setExporting(false);
    }
  }

  return (
    <section className="stack vacancy-view view-enter">
      <PageHeader
        title="Подбор под вакансию"
        back={{ label: 'Назад к проектам', onClick: onBack }}
      />
      {!saved ? (
        <div className="empty-state">
          <p className="empty-state-title">Сначала заполните портфолио</p>
          <p className="muted">Сохраните основное портфолио в Редакторе, затем вернитесь</p>
          <Button onClick={onOpenEditor}>Открыть Редактор</Button>
        </div>
      ) : (
        <>
          <p className="muted">
            Вставьте текст вакансии. Он обрабатывается в этой вкладке и нигде не сохраняется
          </p>
          <Field
            label="Текст вакансии"
            textarea
            value={text}
            placeholder="Требования, стек, обязанности"
            autoComplete="off"
            spellCheck={false}
            onChange={(event) => {
              setText(event.target.value);
              // Результат относится к прежнему тексту: экспорт и порядок скрыты.
              setMatch(null);
            }}
          />
          {text.trim() !== '' && !longEnough && (
            <p className="muted" role="status">
              Слишком короткий текст: нужно хотя бы {vacancyMinimumLength} символов
            </p>
          )}
          {text.length > vacancyMaximumLength && (
            <p className="muted" role="status">
              Текст длиннее {vacancyMaximumLength} символов: учитываются первые{' '}
              {vacancyMaximumLength}
            </p>
          )}
          <div className="portfolio-actions">
            <Button
              variant={match ? 'secondary' : 'primary'}
              disabled={!longEnough}
              onClick={compare}
            >
              {match ? 'Сопоставить снова' : 'Сопоставить'}
            </Button>
          </div>
          {match &&
            (match.noRequirements ? (
              <div className="empty-state" role="status">
                <p className="empty-state-title">Требования не найдены</p>
                <p className="muted">
                  В тексте нет знакомых технологий и направлений. Проверьте, что вставлен полный
                  текст вакансии
                </p>
              </div>
            ) : (
              <div className="stack vacancy-result">
                <div role="status" className="stack vacancy-summary">
                  <h2>
                    Совпало {match.matchedCount} из {match.totalCount}
                  </h2>
                  <p className="muted">{match.percent}% соответствия</p>
                  {match.matchedCount === 0 && (
                    <p>Совпадений нет: в портфолио не нашлось ни одного требования</p>
                  )}
                </div>
                {match.matchedRequirements.length > 0 && (
                  <>
                    <h3>Совпало</h3>
                    <Chips items={match.matchedRequirements} ok />
                  </>
                )}
                {match.missingRequirements.length > 0 && (
                  <>
                    <h3>Не хватает</h3>
                    <Chips items={match.missingRequirements} ok={false} />
                  </>
                )}
                {match.projects.length > 0 && (
                  <>
                    <h3>Проекты: релевантность и PDF</h3>
                    <div className="vacancy-checks">
                      {match.projects.map((item) => (
                        <label className="checkbox vacancy-check" key={item.projectId}>
                          <input
                            type="checkbox"
                            checked={projects.has(item.projectId)}
                            onChange={(event) =>
                              setProjects((current) =>
                                toggle(current, item.projectId, event.target.checked),
                              )
                            }
                          />
                          <span className="vacancy-check-text">
                            <strong>{item.title}</strong>
                            <small className="muted">
                              {item.matched.length === 0
                                ? 'Совпадений нет'
                                : `Совпало ${item.score}: ${item.matched.join(', ')}`}
                            </small>
                          </span>
                        </label>
                      ))}
                    </div>
                  </>
                )}
                {match.experience.some((item) => item.score > 0) && (
                  <>
                    <h3>Релевантный опыт</h3>
                    <ul className="vacancy-experience">
                      {match.experience
                        .filter((item) => item.score > 0)
                        .map((item) => (
                          <li key={item.experienceId}>
                            {item.role}: {item.matched.join(', ')}
                          </li>
                        ))}
                    </ul>
                  </>
                )}
                <h3>Разделы: порядок и PDF</h3>
                <div className="vacancy-checks">
                  {match.sectionOrder.map((kind, index) => (
                    <label className="checkbox vacancy-check" key={kind}>
                      <input
                        type="checkbox"
                        checked={sections.has(kind)}
                        onChange={(event) =>
                          setSections((current) => toggle(current, kind, event.target.checked))
                        }
                      />
                      <span className="vacancy-check-text">
                        {index + 1}. {sectionTitles[kind]}
                      </span>
                    </label>
                  ))}
                </div>
                <p className="muted vacancy-note">
                  Отметки определяют, что попадёт в PDF. Порядок применяется в Редакторе без
                  сохранения
                </p>
                <div className="portfolio-actions">
                  <Button
                    disabled={busy || exporting}
                    onClick={() =>
                      onApply({ projects: match.projectOrder, sections: match.sectionOrder })
                    }
                  >
                    Применить порядок
                  </Button>
                  <Button
                    variant="secondary"
                    disabled={busy || exporting}
                    aria-busy={exporting}
                    onClick={() => void exportPdf()}
                  >
                    {exporting ? 'Готовим PDF…' : 'Экспорт PDF под вакансию'}
                  </Button>
                </div>
                <p className="muted vacancy-disclaimer">
                  Это подсказка по ключевым словам, а не оценка работодателя
                </p>
              </div>
            ))}
        </>
      )}
    </section>
  );
}
