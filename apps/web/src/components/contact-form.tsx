'use client';
import { useRef, useState, useEffect } from 'react';
import { Button, Field, Notice } from './ui';
import { uid, equal } from '@/lib/model';
import {
  ContactError,
  validateContact,
  type ContactInput,
  type ContactSubmission,
} from '@/lib/contact-contract';
import { contactConfigured, submitContact } from '@/lib/contact-repository';

const empty: ContactInput = { name: '', email: '', message: '', website: '' };
export function ContactForm({ publicId }: { publicId: string }) {
  const [input, setInput] = useState<ContactInput>(empty),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(''),
    [message, setMessage] = useState('');
  const attempt = useRef<{ submission: ContactSubmission; input: ContactInput } | null>(null),
    current = useRef(input),
    alive = useRef(true);
  current.current = input;
  useEffect(() => {
    alive.current = true;
    return () => {
      alive.current = false;
    };
  }, []);
  const configured = contactConfigured();
  function change(key: keyof ContactInput, value: string) {
    setInput((v) => ({ ...v, [key]: value }));
    setMessage('');
  }
  async function send() {
    if (busy || !configured) return;
    setBusy(true);
    setError('');
    setMessage('');
    try {
      attempt.current ??= {
        submission: { ...validateContact(input), publicId, requestId: uid() },
        input: { ...input },
      };
      const captured = attempt.current;
      await submitContact(captured.submission);
      if (!alive.current) return;
      const sentInput = captured.input;
      const newer = !equal(current.current, sentInput);
      setInput((v) => (equal(v, sentInput) ? empty : v));
      attempt.current = null;
      setMessage(
        newer
          ? 'Обращение доставлено во входящие автора. Более поздний текст остался в форме.'
          : 'Обращение доставлено во входящие автора.',
      );
    } catch (e) {
      if (!alive.current) return;
      if (
        e instanceof ContactError &&
        [
          'invalid-data',
          'resource-exhausted',
          'rate-limited',
          'document-unavailable',
          'contact-unavailable',
          'not-found',
        ].includes(e.code)
      )
        attempt.current = null;
      setError(
        e instanceof ContactError
          ? e.message
          : 'Результат отправки неизвестен. Повторите отправку с этой страницы.',
      );
    } finally {
      if (alive.current) setBusy(false);
    }
  }
  return (
    <section className="section stack" id="contact-me" aria-labelledby="contact-form-title">
      <h2 id="contact-form-title">Связаться с автором</h2>
      <p className="muted">Имя, почту и сообщение увидит только автор этого документа.</p>
      {!configured ? (
        <Notice>Форма связи временно недоступна. Используйте опубликованные контакты.</Notice>
      ) : (
        <form
          className="stack"
          noValidate
          onSubmit={(e) => {
            e.preventDefault();
            void send();
          }}
        >
          <Field
            label="Ваше имя"
            autoComplete="name"
            required
            maxLength={100}
            value={input.name}
            onChange={(e) => change('name', e.target.value)}
          />
          <Field
            label="Ваша почта"
            type="email"
            autoComplete="email"
            required
            maxLength={254}
            value={input.email}
            onChange={(e) => change('email', e.target.value)}
          />
          <label className="field">
            <span>
              Сообщение <span aria-hidden="true">*</span>
            </span>
            <textarea
              required
              rows={6}
              maxLength={4000}
              value={input.message}
              onChange={(e) => change('message', e.target.value)}
            />
          </label>
          <div className="contact-honeypot" aria-hidden="true">
            <label>
              Website
              <input
                tabIndex={-1}
                autoComplete="off"
                value={input.website}
                onChange={(e) => change('website', e.target.value)}
              />
            </label>
          </div>
          {error && <Notice error>{error}</Notice>}
          {message && <Notice>{message}</Notice>}
          <Button type="submit" disabled={busy}>
            {busy ? 'Отправляем…' : attempt.current ? 'Повторить отправку' : 'Отправить обращение'}
          </Button>
        </form>
      )}
    </section>
  );
}
