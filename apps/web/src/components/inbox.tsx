'use client';
import { useEffect, useRef, useState } from 'react';
import type { User } from 'firebase/auth';
import type { QueryDocumentSnapshot } from 'firebase/firestore';
import { Button, Notice } from './ui';
import { firebaseServices } from '@/lib/firebase';
import { loadInbox, loadContactRequest, markContactRead } from '@/lib/contact-repository';
import { ContactError, type ContactRequest } from '@/lib/contact-contract';

function inboxMessage(error: unknown) {
  return error instanceof ContactError
    ? error.message
    : 'Не удалось получить подтверждение от сервера. Проверьте соединение и повторите действие.';
}

export function Inbox({
  user,
  requestId,
  onOpen,
  onBack,
}: {
  user: User;
  requestId?: string;
  onOpen: (id: string) => void;
  onBack: () => void;
}) {
  const [requests, setRequests] = useState<ContactRequest[]>([]),
    [request, setRequest] = useState<ContactRequest | null>(null),
    [loading, setLoading] = useState(true),
    [busy, setBusy] = useState(false),
    [error, setError] = useState(''),
    [hasMore, setHasMore] = useState(false);
  const cursor = useRef<QueryDocumentSnapshot | undefined>(undefined),
    alive = useRef(true),
    generation = useRef(0);
  const owned = (captured: number) =>
    alive.current &&
    generation.current === captured &&
    firebaseServices().auth.currentUser?.uid === user.uid;
  async function refresh(more = false) {
    const captured = ++generation.current;
    setError('');
    setBusy(true);
    try {
      if (requestId) {
        const result = await loadContactRequest(user, requestId);
        if (owned(captured)) setRequest(result);
      } else {
        const result = await loadInbox(user, more ? cursor.current : undefined);
        if (!owned(captured)) return;
        cursor.current = result.cursor;
        setHasMore(result.hasMore);
        setRequests((old) =>
          more
            ? [
                ...old,
                ...result.requests.filter((r) => !old.some((v) => v.requestId === r.requestId)),
              ]
            : result.requests,
        );
      }
    } catch (e) {
      if (owned(captured)) setError(inboxMessage(e));
    } finally {
      if (owned(captured)) {
        setLoading(false);
        setBusy(false);
      }
    }
  }
  useEffect(() => {
    alive.current = true;
    void refresh();
    return () => {
      alive.current = false;
      generation.current++;
    };
  }, []);
  async function read() {
    if (!requestId || busy) return;
    const captured = ++generation.current;
    setBusy(true);
    setError('');
    try {
      const result = await markContactRead(user, requestId);
      if (owned(captured)) setRequest(result);
    } catch (e) {
      if (owned(captured)) setError(inboxMessage(e));
    } finally {
      if (owned(captured)) setBusy(false);
    }
  }
  const date = (value: Date) => value.toLocaleString('ru-RU');
  return (
    <section className="section stack" aria-busy={loading || busy}>
      <div className="row">
        <Button variant="quiet" onClick={onBack}>
          {requestId ? 'К входящим' : 'К настройкам'}
        </Button>
        <Button variant="secondary" disabled={busy} onClick={() => void refresh()}>
          Обновить
        </Button>
      </div>
      <p className="muted">
        Обращения из опубликованных документов. Они сохраняются здесь независимо от
        push-уведомлений.
      </p>
      {error && <Notice error>{error}</Notice>}
      {loading ? (
        <Notice>Загружаем входящие…</Notice>
      ) : requestId ? (
        request ? (
          <>
            <h2>{request.name}</h2>
            <p className="muted">
              {request.documentTitle} · {date(request.createdAt)}
            </p>
            <a href={`mailto:${request.email}`}>{request.email}</a>
            <p className="muted">Имя и почта указаны отправителем и не подтверждены.</p>
            <p className="contact-message">{request.message}</p>
            {request.readAt ? (
              <p className="muted">Прочитано {date(request.readAt)}</p>
            ) : (
              <Button disabled={busy} onClick={() => void read()}>
                Отметить прочитанным
              </Button>
            )}
          </>
        ) : (
          !error && <Notice>Обращение не найдено или больше недоступно.</Notice>
        )
      ) : (
        <>
          {!requests.length && !error && (
            <Notice>
              Пока нет обращений. Форма связи появится у опубликованного документа с открытой
              почтой, телефоном или Telegram.
            </Notice>
          )}
          {requests.map((r) => (
            <div className="list-row" key={r.requestId}>
              <div className="stack">
                <strong>
                  {r.name}
                  {!r.readAt && ' · Новое'}
                </strong>
                <small className="muted">
                  {r.documentTitle} · {date(r.createdAt)}
                </small>
                <p className="contact-message">
                  {r.message.length > 160 ? `${r.message.slice(0, 160)}…` : r.message}
                </p>
              </div>
              <Button variant="secondary" onClick={() => onOpen(r.requestId)}>
                Открыть обращение
              </Button>
            </div>
          ))}
          {hasMore && (
            <Button variant="secondary" disabled={busy} onClick={() => void refresh(true)}>
              Загрузить ещё
            </Button>
          )}
        </>
      )}
    </section>
  );
}
