'use client';

import { useCallback, useEffect, useId, useRef, useState } from 'react';
import { Button } from './ui';

// Обычное подтверждение — «Отмена / Подтвердить»; выбор при уходе — «Отмена / Не сохранять / Сохранить».
type Confirmation = {
  title: string;
  message: string;
  discardLabel?: string;
  confirmLabel?: string;
};
export type Choice = 'cancel' | 'discard' | 'confirm';

export function ConfirmationDialog({
  request,
  onDecision,
}: {
  request: Confirmation | null;
  onDecision: (choice: Choice) => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null),
    titleId = useId(),
    messageId = useId();
  useEffect(() => {
    const current = dialog.current;
    if (!current || !request) return;
    const previous = document.activeElement as HTMLElement | null;
    current.showModal();
    current.querySelector<HTMLButtonElement>('button')?.focus();
    return () => {
      current.close();
      if (previous?.isConnected) previous.focus();
    };
  }, [request]);
  return (
    <dialog
      ref={dialog}
      className="dialog confirmation-dialog"
      aria-labelledby={titleId}
      aria-describedby={messageId}
      onCancel={(event) => {
        event.preventDefault();
        onDecision('cancel');
      }}
      onKeyDown={(event) => {
        if (event.key !== 'Tab') return;
        const buttons = event.currentTarget.querySelectorAll<HTMLButtonElement>('button'),
          first = buttons[0],
          last = buttons[buttons.length - 1],
          active = event.currentTarget.ownerDocument.activeElement;
        if (event.shiftKey && active === first) {
          event.preventDefault();
          last?.focus();
        } else if (!event.shiftKey && active === last) {
          event.preventDefault();
          first?.focus();
        }
      }}
    >
      <div className="stack">
        <h2 id={titleId}>{request?.title}</h2>
        <p id={messageId}>{request?.message}</p>
        <div className="dialog-actions">
          <Button variant="secondary" onClick={() => onDecision('cancel')}>
            Отмена
          </Button>
          {request?.discardLabel && (
            <Button variant="secondary" onClick={() => onDecision('discard')}>
              {request.discardLabel}
            </Button>
          )}
          <Button onClick={() => onDecision('confirm')}>
            {request?.confirmLabel ?? 'Подтвердить'}
          </Button>
        </div>
      </div>
    </dialog>
  );
}

export function useConfirmation() {
  const [request, setRequest] = useState<Confirmation | null>(null);
  const pending = useRef<((choice: Choice) => void) | null>(null);
  const ask = useCallback((next: Confirmation) => {
    if (pending.current) return Promise.resolve<Choice>('cancel');
    return new Promise<Choice>((resolve) => {
      pending.current = resolve;
      setRequest(next);
    });
  }, []);
  const confirm = useCallback(
    async (message: string, title = 'Подтверждение') =>
      (await ask({ title, message })) === 'confirm',
    [ask],
  );
  const choose = useCallback(
    (message: string, title: string, discardLabel: string, confirmLabel: string) =>
      ask({ title, message, discardLabel, confirmLabel }),
    [ask],
  );
  const decide = useCallback((choice: Choice) => {
    const resolve = pending.current;
    pending.current = null;
    setRequest(null);
    resolve?.(choice);
  }, []);
  useEffect(
    () => () => {
      pending.current?.('cancel');
      pending.current = null;
    },
    [],
  );
  return {
    confirm,
    choose,
    confirmation: <ConfirmationDialog request={request} onDecision={decide} />,
  };
}
