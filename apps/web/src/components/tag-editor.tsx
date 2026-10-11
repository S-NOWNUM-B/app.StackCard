'use client';
import { useId, useRef, useState, type ReactNode } from 'react';
import { Button, Icon, Notice, TechnologyBadges } from './ui';

export function TagEditor({
  heading,
  title,
  addLabel,
  removeLabel,
  listLabel,
  items,
  onAdd,
  onRemove,
}: {
  heading: ReactNode;
  title: string;
  addLabel: string;
  removeLabel: string;
  listLabel: string;
  items: { id: string; name: string }[];
  onAdd: (name: string) => void;
  onRemove: (index: number) => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null),
    input = useRef<HTMLInputElement>(null),
    titleId = useId(),
    errorId = useId();
  const [name, setName] = useState(''),
    [error, setError] = useState('');
  function add() {
    try {
      onAdd(name);
      setName('');
      setError('');
      dialog.current?.close();
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'Не удалось сохранить.');
      input.current?.focus();
    }
  }
  return (
    <div className="stack tag-editor">
      <div className="tag-editor-heading">
        {heading}
        <Button
          variant="quiet"
          className="tag-editor-action"
          aria-label={addLabel}
          title={addLabel}
          onClick={() => {
            setError('');
            dialog.current?.showModal();
            input.current?.focus();
          }}
        >
          <Icon name="plus" />
        </Button>
      </div>
      {items.length > 0 && (
        <ul className="tag-editor-list" aria-label={listLabel}>
          {items.map((item, index) => (
            <li className="tag-editor-item" key={item.id}>
              <TechnologyBadges items={[item.name]} />
              <Button
                variant="quiet"
                className="tag-editor-action"
                aria-label={`${removeLabel} ${item.name}`}
                title={`${removeLabel} ${item.name}`}
                onClick={() => onRemove(index)}
              >
                <svg
                  width="20"
                  height="20"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  strokeWidth="1.8"
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  aria-hidden="true"
                  focusable="false"
                >
                  <path d="m6 6 12 12M18 6 6 18" />
                </svg>
              </Button>
            </li>
          ))}
        </ul>
      )}
      <dialog
        ref={dialog}
        className="dialog tag-editor-dialog"
        aria-labelledby={titleId}
        onKeyDown={(event) => {
          if (event.key !== 'Tab') return;
          const active = event.currentTarget.ownerDocument.activeElement,
            submit = event.currentTarget.querySelector<HTMLButtonElement>('button[type="submit"]');
          if (event.shiftKey && active === input.current) {
            event.preventDefault();
            submit?.focus();
          } else if (!event.shiftKey && active === submit) {
            event.preventDefault();
            input.current?.focus();
          }
        }}
      >
        <form
          className="stack"
          onSubmit={(event) => {
            event.preventDefault();
            add();
          }}
        >
          <h2 id={titleId}>{title}</h2>
          <label className="field">
            <span>Название</span>
            <input
              ref={input}
              value={name}
              autoComplete="off"
              aria-invalid={error ? true : undefined}
              aria-describedby={error ? errorId : undefined}
              onChange={(event) => {
                setName(event.target.value);
                setError('');
              }}
            />
          </label>
          {error && (
            <div id={errorId}>
              <Notice error>{error}</Notice>
            </div>
          )}
          <div className="tag-editor-dialog-actions">
            <Button variant="secondary" onClick={() => dialog.current?.close()}>
              Отмена
            </Button>
            <Button type="submit">Сохранить</Button>
          </div>
        </form>
      </dialog>
    </div>
  );
}
