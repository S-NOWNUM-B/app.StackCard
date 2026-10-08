'use client';

import { useEffect, useRef, useState } from 'react';
import { Button } from '@/components/ui';

export function ShareActions({ title }: { title: string }) {
  const [url, setUrl] = useState('');
  const [status, setStatus] = useState('');
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => {
    setUrl(`${window.location.origin}${window.location.pathname}`);
  }, []);
  function selectLink() {
    input.current?.focus();
    input.current?.select();
    setStatus('Выделите и скопируйте адрес страницы.');
  }
  async function copy() {
    try {
      if (!navigator.clipboard?.writeText) {
        selectLink();
        return;
      }
      await navigator.clipboard.writeText(url);
      setStatus('Ссылка скопирована.');
    } catch {
      selectLink();
    }
  }
  async function share() {
    if (!navigator.share) {
      await copy();
      return;
    }
    try {
      await navigator.share({ title, url });
      setStatus('Ссылка отправлена.');
    } catch (error) {
      if (error instanceof Error && error.name === 'AbortError') return;
      selectLink();
    }
  }
  return (
    <section className="section stack share-actions" aria-label="Поделиться документом">
      <h3>Ссылка на страницу</h3>
      <label className="field">
        <span className="visually-hidden">Постоянный адрес документа</span>
        <input
          ref={input}
          readOnly
          value={url}
          aria-label="Постоянный адрес документа"
          onFocus={(event) => event.target.select()}
        />
      </label>
      <div className="row">
        <Button variant="secondary" onClick={copy} disabled={!url}>
          Копировать
        </Button>
        <a
          className="button secondary"
          href={url || undefined}
          target="_blank"
          rel="noopener noreferrer"
          aria-disabled={!url}
        >
          Открыть
        </a>
      </div>
      <Button variant="quiet" onClick={share} disabled={!url}>
        Поделиться
      </Button>
      <p className="muted" role="status" aria-live="polite">
        {status}
      </p>
    </section>
  );
}
