'use client';
import { useEffect, useId, useRef, useState } from 'react';
import { Button, Notice } from './ui';
import { InlineIcon } from './inline-icon';
import { TechnologyChip } from './technology-badge';
import { encodeQr, qrPath } from '@/lib/qr-code';
import { readPublicDocument, safePublicMedia, type PublicDocument } from '@/lib/public-document';
import type { Publication } from '@/lib/publication';

// Технологии визитки как в mobile: навыки, затем технологии видимых проектов, без повторов.
export function cardTechnologies(document: PublicDocument): string[] {
  const seen = new Set<string>(),
    result: string[] = [];
  for (const name of [
    ...document.content.skills.map((skill) => skill.name),
    ...document.content.projects.flatMap((project) => project.technologies),
  ]) {
    const key = name.trim().toLowerCase();
    if (!key || seen.has(key)) continue;
    seen.add(key);
    result.push(name);
  }
  return result;
}

export function QrCode({ url, size = 200 }: { url: string; size?: number }) {
  let matrix;
  try {
    matrix = encodeQr(url);
  } catch {
    return null;
  }
  const total = matrix.size + 8;
  return (
    <svg
      className="qr-code"
      width={size}
      height={size}
      viewBox={`0 0 ${total} ${total}`}
      shapeRendering="crispEdges"
      role="img"
      aria-label="QR-код публичной ссылки"
    >
      <rect width={total} height={total} fill="#ffffff" />
      <path d={qrPath(matrix)} fill="#17181b" />
    </svg>
  );
}

type CardState =
  | { status: 'loading' }
  | { status: 'ready'; document: PublicDocument }
  | { status: 'error'; message: string };

// Визитка читает тот же anonymous public snapshot, что и публичная страница; private data не нужны.
export function DeveloperCardDialog({
  publication,
  onClose,
  onPublish,
}: {
  publication: Publication | undefined;
  onClose: () => void;
  onPublish: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null),
    titleId = useId();
  const [state, setState] = useState<CardState>({ status: 'loading' }),
    [attempt, setAttempt] = useState(0),
    [all, setAll] = useState(false),
    [status, setStatus] = useState(''),
    [canShare, setCanShare] = useState(false);
  const published = publication?.state === 'published' && !!publication.url;
  useEffect(() => {
    const current = dialog.current;
    if (current && !current.open) current.showModal();
    setCanShare(typeof navigator.share === 'function');
  }, []);
  useEffect(() => {
    if (!published) return;
    let alive = true;
    setState({ status: 'loading' });
    readPublicDocument(publication!.publicId)
      .then((document) => {
        if (!alive) return;
        if (!document)
          setState({
            status: 'error',
            message: 'Публичная версия не найдена. Проверьте публикацию',
          });
        else if (document.version !== publication!.version)
          setState({ status: 'error', message: 'Публичная версия изменилась. Обновите карточку' });
        else setState({ status: 'ready', document });
      })
      .catch(() => {
        if (alive)
          setState({
            status: 'error',
            message:
              'Не удалось проверить опубликованное портфолио. Подключитесь к сети и повторите',
          });
      });
    return () => {
      alive = false;
    };
  }, [published, publication?.publicId, publication?.version, attempt]);
  async function copy(url: string) {
    try {
      await navigator.clipboard.writeText(url);
      setStatus('Ссылка скопирована');
    } catch {
      setStatus('Выделите адрес под QR-кодом и скопируйте его');
    }
  }
  async function share(url: string) {
    try {
      await navigator.share({ title: 'Портфолио', url });
    } catch (error) {
      if (!(error instanceof Error && error.name === 'AbortError'))
        setStatus('Не удалось открыть меню «Поделиться». Скопируйте ссылку');
    }
  }
  const url = publication?.url ?? '';
  return (
    <dialog
      ref={dialog}
      className="dialog developer-card-dialog"
      aria-labelledby={titleId}
      onClose={onClose}
    >
      <div className="stack">
        <h2 id={titleId}>Визитка</h2>
        {!published ? (
          <>
            <p>
              Портфолио ещё не опубликовано или снято с публикации. QR-код появится после
              подтверждённой публикации
            </p>
            <div className="dialog-actions">
              <Button variant="secondary" onClick={() => dialog.current?.close()}>
                Отмена
              </Button>
              <Button
                onClick={() => {
                  dialog.current?.close();
                  onPublish();
                }}
              >
                Опубликовать
              </Button>
            </div>
          </>
        ) : state.status === 'loading' ? (
          <p className="muted" role="status">
            Проверяем опубликованную версию…
          </p>
        ) : state.status === 'error' ? (
          <>
            <Notice error>{state.message}</Notice>
            <div className="dialog-actions">
              <Button variant="secondary" onClick={() => dialog.current?.close()}>
                Закрыть
              </Button>
              <Button onClick={() => setAttempt((value) => value + 1)}>Повторить проверку</Button>
            </div>
          </>
        ) : (
          <>
            <p className="muted">Опубликованная версия</p>
            <CardView document={state.document} url={url} all={all} onAll={() => setAll(true)} />
            <div className="developer-card-actions">
              <Button variant="secondary" onClick={() => void copy(url)}>
                <InlineIcon name="copy" size={20} />
                Копировать ссылку
              </Button>
              <a className="button secondary" href={url} target="_blank" rel="noopener noreferrer">
                Открыть портфолио
              </a>
              {canShare && <Button onClick={() => void share(url)}>Поделиться ссылкой</Button>}
            </div>
            <p className="muted" role="status" aria-live="polite">
              {status}
            </p>
            <div className="dialog-actions">
              <Button variant="secondary" onClick={() => dialog.current?.close()}>
                Закрыть
              </Button>
            </div>
          </>
        )}
      </div>
    </dialog>
  );
}

function CardView({
  document,
  url,
  all,
  onAll,
}: {
  document: PublicDocument;
  url: string;
  all: boolean;
  onAll: () => void;
}) {
  const profile = document.content.profile,
    visible = new Set(document.content.blocks.map((block) => block.kind)),
    name = (visible.has('profile') && profile.name.trim()) || document.title,
    headline = visible.has('profile') ? profile.headline.trim() : '',
    avatar = visible.has('profile')
      ? safePublicMedia(profile.avatarUrl, document.publicId, document.version)
      : null,
    technologies = cardTechnologies(document),
    shown = all ? technologies : technologies.slice(0, 8);
  return (
    <article className="developer-card" aria-label="Визитка разработчика">
      <img
        className="developer-card-brand"
        src="/branding/stackcard-v2-wordmark-ink.svg"
        alt="StackCard"
        width={117}
        height={16}
      />
      {avatar ? (
        <img
          className="developer-card-avatar"
          src={avatar}
          alt={`Фото ${name}`}
          width={96}
          height={96}
          referrerPolicy="no-referrer"
        />
      ) : (
        <span className="developer-card-avatar developer-card-initials" aria-hidden="true">
          {name.trim().charAt(0).toUpperCase() || '?'}
        </span>
      )}
      <h3>{name}</h3>
      {headline && <p className="muted">{headline}</p>}
      {visible.has('profile') && profile.username && <p>@{profile.username}</p>}
      {technologies.length > 0 && (
        <div className="developer-card-technologies">
          {shown.map((technology) => (
            <TechnologyChip key={technology} label={technology} />
          ))}
          {!all && technologies.length > 8 && (
            <button
              type="button"
              className="technology-more"
              aria-label="Показать все технологии"
              onClick={onAll}
            >
              +{technologies.length - 8}
            </button>
          )}
        </div>
      )}
      <QrCode url={url} />
      <p className="developer-card-url">{url}</p>
    </article>
  );
}
