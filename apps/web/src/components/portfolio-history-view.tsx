'use client';
import { Button } from './ui';
import { DocumentView } from './document-view';
import {
  historyLimit,
  snapshotPreview,
  summarizeSnapshot,
  type PortfolioSnapshot,
  type SnapshotChange,
} from '@/lib/portfolio-history';

// Состояние чтения локального хранилища: загрузка, ошибка или список (возможно, пустой).
export type HistoryState =
  { status: 'loading' } | { status: 'error' } | { status: 'ready'; items: PortfolioSnapshot[] };

export function historyDate(value: string): string {
  const date = new Date(value);
  const two = (number: number) => String(number).padStart(2, '0');
  return `${two(date.getDate())}.${two(date.getMonth() + 1)}.${date.getFullYear()} ${two(date.getHours())}:${two(date.getMinutes())}`;
}

export function historyChange({ kind, count }: SnapshotChange): string {
  switch (kind) {
    case 'profile':
      return 'изменён профиль';
    case 'projectsAdded':
      return `добавлено проектов: ${count}`;
    case 'projectsRemoved':
      return `убрано проектов: ${count}`;
    case 'projectsEdited':
      return `изменено проектов: ${count}`;
    case 'skillsAdded':
      return `добавлено навыков: ${count}`;
    case 'skillsRemoved':
      return `убрано навыков: ${count}`;
    case 'experience':
      return 'изменён опыт';
    case 'education':
      return 'изменено образование';
    case 'contacts':
      return 'изменены контакты';
    case 'layout':
      return 'изменён порядок разделов';
  }
}

function Frame({
  title,
  backLabel,
  onBack,
  children,
}: {
  title: string;
  backLabel: string;
  onBack: () => void;
  children: React.ReactNode;
}) {
  return (
    <section className="stack history-view view-enter">
      <Button variant="quiet" className="back-button" onClick={onBack}>
        {backLabel}
      </Button>
      <div className="view-heading">
        <h1>{title}</h1>
      </div>
      {children}
    </section>
  );
}

function Loading({ label }: { label: string }) {
  return (
    <div className="workspace-loading" role="status">
      <span className="spinner" aria-hidden="true" />
      {label}
    </div>
  );
}

function Failure({ title, onRetry }: { title: string; onRetry: () => void }) {
  return (
    <div className="status-card stack" role="alert">
      <p>{title}</p>
      <p className="muted">Попробуйте ещё раз. Сохранённое портфолио не затронуто</p>
      <Button onClick={onRetry}>Повторить</Button>
    </div>
  );
}

// Список локальных версий: дата, числа и что изменилось. Только чтение.
export function HistoryList({
  state,
  onBack,
  onRetry,
  onOpen,
}: {
  state: HistoryState;
  onBack: () => void;
  onRetry: () => void;
  onOpen: (id: string) => void;
}) {
  return (
    <Frame title="История версий" backLabel="Назад на Главную" onBack={onBack}>
      {state.status === 'loading' ? (
        <Loading label="Загружаем версии…" />
      ) : state.status === 'error' ? (
        <Failure title="Не удалось загрузить версии" onRetry={onRetry} />
      ) : state.items.length === 0 ? (
        <div className="empty-state">
          <p className="empty-state-title">Пока нет сохранённых версий</p>
          <p className="muted">Версия появляется после каждого сохранения основного портфолио</p>
        </div>
      ) : (
        <>
          <p className="muted">Версии хранятся только в этом браузере, последние {historyLimit}</p>
          <ul className="history-list" aria-label="Версии портфолио">
            {state.items.map((snapshot, index) => {
              const previous = state.items[index + 1];
              const summary = summarizeSnapshot(snapshot, previous);
              const changes =
                summary.changes.length > 0
                  ? summary.changes.map(historyChange).join(', ')
                  : previous
                    ? 'без видимых изменений'
                    : 'первая версия';
              return (
                <li key={snapshot.id}>
                  <button
                    type="button"
                    className="history-item"
                    onClick={() => onOpen(snapshot.id)}
                  >
                    <span className="history-item-text">
                      <span className="history-item-date">{historyDate(snapshot.savedAt)}</span>
                      <span className="muted">
                        Проектов: {summary.projects} · Навыков: {summary.skills}
                      </span>
                      <span className="muted history-item-changes">{changes}</span>
                    </span>
                    <span className="summary-card-chevron" aria-hidden="true">
                      ›
                    </span>
                  </button>
                </li>
              );
            })}
          </ul>
        </>
      )}
    </Frame>
  );
}

// Просмотр версии в виде сохранённой Главной и откат в буфер редактора.
export function HistoryVersion({
  state,
  snapshotId,
  onBack,
  onRetry,
  onRestore,
}: {
  state: HistoryState;
  snapshotId: string;
  onBack: () => void;
  onRetry: () => void;
  onRestore: (snapshot: PortfolioSnapshot) => void;
}) {
  const snapshot =
    state.status === 'ready' ? state.items.find((item) => item.id === snapshotId) : undefined;
  return (
    <Frame title="Версия" backLabel="Назад к версиям" onBack={onBack}>
      {state.status === 'loading' ? (
        <Loading label="Загружаем версию…" />
      ) : state.status === 'error' ? (
        <Failure title="Не удалось загрузить версию" onRetry={onRetry} />
      ) : !snapshot ? (
        <div className="empty-state">
          <p className="empty-state-title">Версия не найдена</p>
          <p className="muted">Возможно, она вытеснена более новыми</p>
          <Button onClick={onBack}>К списку версий</Button>
        </div>
      ) : (
        <>
          <p className="history-version-date">{historyDate(snapshot.savedAt)}</p>
          {snapshot.hasAvatar && (
            <p className="muted">Фото в версии не хранится, при восстановлении останется текущее</p>
          )}
          <div className="portfolio-actions">
            <Button onClick={() => onRestore(snapshot)}>Восстановить</Button>
          </div>
          <div className="paper-frame">
            <DocumentView
              content={snapshotPreview(snapshot)}
              kind="portfolio"
              modernPortfolio
              preview
            />
          </div>
        </>
      )}
    </Frame>
  );
}
