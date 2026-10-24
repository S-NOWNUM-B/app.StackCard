'use client';

import { useEffect, useRef, useState } from 'react';
import { Button } from '@/components/ui';

export function ShareActions({ title, publicId }: { title: string; publicId: string }) {
  const [url, setUrl] = useState('');
  const [canShare, setCanShare] = useState(false);
  const [status, setStatus] = useState('');
  const input = useRef<HTMLInputElement>(null);
  useEffect(() => {
    setUrl(`${window.location.origin}/d/${publicId}`);
    setStatus('');
    setCanShare(typeof navigator.share === 'function');
  }, [publicId]);
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
    if (!navigator.share) return;
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
        {canShare && (
          <Button variant="quiet" onClick={share} disabled={!url}>
            Поделиться
          </Button>
        )}
      </div>
      <p className="muted" role="status" aria-live="polite">
        {status}
      </p>
    </section>
  );
}
