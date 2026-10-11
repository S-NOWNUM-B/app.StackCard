'use client';

import { useCallback, useEffect, useId, useRef, useState } from 'react';
import { Button } from './ui';

type Confirmation = { title: string; message: string };

export function ConfirmationDialog({
  request,
  onDecision,
}: {
  request: Confirmation | null;
  onDecision: (confirmed: boolean) => void;
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
        onDecision(false);
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
          <Button variant="secondary" onClick={() => onDecision(false)}>
            Отмена
          </Button>
          <Button onClick={() => onDecision(true)}>Подтвердить</Button>
        </div>
      </div>
    </dialog>
  );
}

export function useConfirmation() {
  const [request, setRequest] = useState<Confirmation | null>(null);
  const pending = useRef<((confirmed: boolean) => void) | null>(null);
  const confirm = useCallback((message: string, title = 'Подтверждение') => {
    if (pending.current) return Promise.resolve(false);
    return new Promise<boolean>((resolve) => {
      pending.current = resolve;
      setRequest({ title, message });
    });
  }, []);
  const decide = useCallback((confirmed: boolean) => {
    const resolve = pending.current;
    pending.current = null;
    setRequest(null);
    resolve?.(confirmed);
  }, []);
  useEffect(
    () => () => {
      pending.current?.(false);
      pending.current = null;
    },
    [],
  );
  return { confirm, confirmation: <ConfirmationDialog request={request} onDecision={decide} /> };
}
