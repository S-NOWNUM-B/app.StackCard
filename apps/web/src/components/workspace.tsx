'use client';
import { signOut, type User } from 'firebase/auth';
import { useRouter } from 'next/navigation';
import { useEffect, useState, useRef } from 'react';
import { useSession } from './auth-session';
import { Button, Field, Header, Icon, LinkButton, Notice } from './ui';
import { ContentEditor } from './content-editor';
import { AttachmentsEditor, emptyProject, GitHubImporter, ProjectForm } from './project-editor';
import { DocumentView } from './document-view';
import { AccountSettings } from './account-settings';
import { MediaUpload, PrivateImage } from './media-upload';
import { firebaseServices } from '@/lib/firebase';
import { loadDraft, saveDraft } from '@/lib/draft-repository';
import {
  inventory,
  publicationRequest,
  isDefinitivePublicationError,
  type PublicationMutation,
  type Inventory,
  type Publication,
  type OperationResult,
} from '@/lib/publication';
import { documentPreview } from '@/lib/preview';
import {
  clearPublicationReceipt,
  readPublicationReceipt,
  writePublicationReceipt,
} from '@/lib/publication-contract';
import {
  applyDocumentBaseReview,
  createDocumentBaseReview,
  clone,
  createDocument,
  duplicateDocument,
  emptyContent,
  equal,
  resolveDocument,
  safeHttpUrl,
  uid,
  validateWorkspace,
  type DraftEnvelope,
  type PortfolioDocument,
  type WorkspaceContent,
  type DocumentContent,
  type DocumentBaseReview,
} from '@/lib/model';
type View =
  'home' | 'resumes' | 'projects' | 'portfolios' | 'base' | 'settings' | `document/${string}`;
type PendingOperation = PublicationMutation;
function errorMessage(e: unknown) {
  return e instanceof Error ? e.message : 'Действие не завершено. Повторите попытку.';
}
function reviewText(value: unknown): string {
  if (value == null) return 'Нет значения';
  if (typeof value === 'boolean') return value ? 'Да' : 'Нет';
  if (typeof value === 'string') return value || 'Пустой текст';
  const labels: Record<string, string> = {
    name: 'Название',
    role: 'Роль',
    organization: 'Организация',
    period: 'Период',
    description: 'Описание',
    institution: 'Учебное заведение',
    qualification: 'Квалификация',
    label: 'Название',
    url: 'Ссылка',
    kind: 'Тип контакта',
    publishAllowed: 'Разрешено публиковать',
    visible: 'Показывать',
    avatarUrl: 'Ссылка на фото',
    avatarPath: 'Приватное фото',
  };
  const kinds: Record<string, string> = {
    email: 'Почта',
    phone: 'Телефон',
    telegram: 'Telegram',
    github: 'GitHub',
    website: 'Сайт',
    linkedin: 'LinkedIn',
    other: 'Другая ссылка',
  };
  return Object.entries(value as Record<string, unknown>)
    .filter(([key]) => key !== 'id')
    .map(
      ([key, v]) =>
        `${labels[key] ?? key}: ${key === 'kind' ? (kinds[String(v)] ?? v) : reviewText(v)}`,
    )
    .join('\n');
}
export function Workspace({ initialView = 'home' }: { initialView?: string }) {
  const session = useSession();
  const router = useRouter();
  useEffect(() => {
    if (!session.loading && !session.error && !session.user)
      router.replace('/sign-in?returnTo=%2Fworkspace');
  }, [session, router]);
  if (session.loading)
    return (
      <>
        <Header context="workspace" />
        <main id="main" className="container">
          <Notice>Проверяем вход…</Notice>
        </main>
      </>
    );
  if (session.error)
    return (
      <>
        <Header context="workspace" />
        <main id="main" className="container stack">
          <Notice error>{session.error}</Notice>
          <LinkButton href="/">На главную</LinkButton>
        </main>
      </>
    );
  if (!session.user) return <p>Требуется вход…</p>;
  return <OwnerWorkspace key={session.user.uid} user={session.user} initialView={initialView} />;
}
function OwnerWorkspace({ user, initialView }: { user: User; initialView: string }) {
  const [basis, setBasis] = useState<DraftEnvelope | null>(null),
    [content, setContent] = useState<WorkspaceContent>(emptyContent),
    [notes, setNotes] = useState(''),
    [loading, setLoading] = useState(true),
    [blocked, setBlocked] = useState(false),
    [busy, setBusy] = useState(false),
    [saving, setSaving] = useState(false),
    [error, setError] = useState(''),
    [message, setMessage] = useState(''),
    [view, setView] = useState<View>(initialView as View),
    [mode, setMode] = useState<'edit' | 'preview'>('edit'),
    [publications, setPublications] = useState<Inventory | null>(null),
    [publicationError, setPublicationError] = useState(''),
    [pending, setPending] = useState<PendingOperation | null>(null),
    [receiptError, setReceiptError] = useState(''),
    [search, setSearch] = useState(''),
    [review, setReview] = useState<DocumentBaseReview | null>(null),
    [selected, setSelected] = useState<Set<string>>(new Set());
  const reviewDialog = useRef<HTMLElement | null>(null);
  const saveAttempt = useRef<{
    mutationId: string;
    basis: DraftEnvelope | null;
    content: WorkspaceContent;
    notes: string;
  } | null>(null);
  const input = useRef({ content, notes });
  input.current = { content, notes };
  const activeUid = useRef(user.uid);
  const dirty = !equal(content, basis?.content ?? emptyContent()) || notes !== (basis?.notes ?? '');
  const dirtyRef = useRef(dirty);
  dirtyRef.current = dirty;
  const operationKey = `stackcard.publication.${user.uid}`;
  const activeDocument = view.startsWith('document/')
    ? content.documents.find((d) => d.id === view.slice(9))
    : undefined;
  const activePublication = activeDocument
    ? publications?.publications.find((p) => p.documentId === activeDocument.id)
    : undefined;
  const publishReady =
    !dirty && !!basis && !!publications && !pending && !receiptError && !!activeDocument;
  const owned = () =>
    activeUid.current === user.uid && firebaseServices().auth.currentUser?.uid === user.uid;
  async function refreshInventory() {
    if (!owned()) return;
    try {
      const result = await inventory(user);
      if (!owned()) return;
      setPublications(result);
      setPublicationError('');
    } catch (e) {
      if (owned()) setPublicationError(errorMessage(e));
    }
  }
  async function reload() {
    if (!owned()) return;
    setLoading(true);
    setError('');
    setBlocked(false);
    try {
      const saved = await loadDraft(user);
      if (!owned()) return;
      setBasis(saved);
      setContent(saved?.content ?? emptyContent());
      setNotes(saved?.notes ?? '');
      saveAttempt.current = null;
    } catch (e) {
      if (owned()) {
        setError(errorMessage(e));
        setBlocked(true);
      }
    } finally {
      if (owned()) setLoading(false);
    }
  }
  useEffect(() => {
    activeUid.current = user.uid;
    void reload();
    void refreshInventory();
    try {
      setPending(readPublicationReceipt(localStorage, operationKey));
      const hash = decodeURIComponent(window.location.hash.slice(1));
      if (
        hash &&
        /^(home|resumes|projects|portfolios|base|settings|document\/[A-Za-z0-9_-]+)$/.test(hash)
      )
        setView(hash as View);
    } catch (e) {
      setReceiptError(errorMessage(e));
    }
    return () => {
      activeUid.current = '';
    };
  }, [user.uid]);
  useEffect(() => {
    function changed(event: StorageEvent) {
      if (event.key !== operationKey) return;
      try {
        setPending(readPublicationReceipt(localStorage, operationKey));
        setReceiptError('');
      } catch (e) {
        setReceiptError(errorMessage(e));
      }
    }
    window.addEventListener('storage', changed);
    return () => window.removeEventListener('storage', changed);
  }, [operationKey]);
  useEffect(() => {
    function beforeUnload(event: BeforeUnloadEvent) {
      if (dirtyRef.current) {
        event.preventDefault();
        event.returnValue = '';
      }
    }
    window.addEventListener('beforeunload', beforeUnload);
    return () => window.removeEventListener('beforeunload', beforeUnload);
  }, []);
  useEffect(() => {
    if (!review) return;
    const previous = document.activeElement as HTMLElement | null;
    const dialog = reviewDialog.current;
    if (!dialog) return;
    const focusable = () =>
      Array.from(
        dialog.querySelectorAll<HTMLElement>(
          'button:not(:disabled),input:not(:disabled),select:not(:disabled),textarea:not(:disabled),a[href],[tabindex="0"]',
        ),
      );
    focusable()[0]?.focus();
    function key(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        event.preventDefault();
        setReview(null);
      }
      if (event.key === 'Tab') {
        const nodes = focusable(),
          first = nodes[0],
          last = nodes.at(-1);
        if (event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last?.focus();
        } else if (!event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first?.focus();
        }
      }
    }
    document.addEventListener('keydown', key);
    return () => {
      document.removeEventListener('keydown', key);
      previous?.focus();
    };
  }, [review]);
  function navigate(next: View, preserve = false) {
    if (busy || review) return;
    if (
      !preserve &&
      dirty &&
      !window.confirm('Есть несохранённые изменения. Отбросить их и перейти?')
    )
      return;
    if (!preserve && dirty) {
      setContent(clone(basis?.content ?? emptyContent()));
      setNotes(basis?.notes ?? '');
      saveAttempt.current = null;
    }
    setView(next);
    setMode('edit');
    setReview(null);
    window.history.replaceState(null, '', `/workspace#${encodeURIComponent(next)}`);
  }
  function update(next: WorkspaceContent) {
    setContent(next);
    setMessage('');
  }
  function updateDocument(document: PortfolioDocument) {
    update({
      ...content,
      documents: content.documents.map((d) =>
        d.id === document.id ? { ...document, updatedAt: new Date().toISOString() } : d,
      ),
    });
  }
  function openBaseReview() {
    if (busy || loading || blocked || !owned() || !activeDocument) return;
    if (!basis?.content) {
      setError('Сначала сохраните общую базу, затем откройте обновление документа.');
      return;
    }
    const captured = createDocumentBaseReview(user.uid, basis.content, activeDocument);
    setSelected(new Set(captured.changes.filter((c) => !c.localOverride).map((c) => c.id)));
    setReview(captured);
  }
  function applyBaseReview() {
    if (!review || !owned()) return;
    try {
      if (!basis?.content || !activeDocument)
        throw new Error('Данные изменились. Откройте обновление из базы заново.');
      updateDocument(
        applyDocumentBaseReview(review, user.uid, basis.content, activeDocument, selected),
      );
    } catch (e) {
      setError(errorMessage(e));
    }
    setReview(null);
  }
  function reviewValue(id: string, value: unknown) {
    const path =
      id === 'profile.avatarPath' && value && typeof value === 'object'
        ? (value as { avatarPath?: unknown }).avatarPath
        : null;
    return typeof path === 'string' && path ? (
      <PrivateImage user={user} path={path} />
    ) : (
      <pre>{reviewText(value)}</pre>
    );
  }
  async function save() {
    if (blocked || busy || review || !owned()) return;
    setBusy(true);
    setSaving(true);
    setError('');
    setMessage('');
    try {
      let attempt = saveAttempt.current;
      // После неизвестного ответа сначала подтверждаем прежнюю операцию,
      // даже если пользователь уже продолжил редактирование.
      if (!attempt) {
        attempt = {
          mutationId: `web-${uid()}`,
          basis,
          content: clone(validateWorkspace(content, user.uid)),
          notes,
        };
        saveAttempt.current = attempt;
      }
      const saved = await saveDraft(
        user,
        attempt.basis,
        attempt.content,
        attempt.notes,
        attempt.mutationId,
      );
      if (!owned()) return;
      const hasNewerInput =
        !equal(input.current.content, attempt.content) || input.current.notes !== attempt.notes;
      setBasis(saved);
      setContent((current) =>
        equal(current, attempt.content) ? (saved.content ?? emptyContent()) : current,
      );
      setNotes((current) => (current === attempt.notes ? saved.notes : current));
      saveAttempt.current = null;
      setMessage(
        hasNewerInput
          ? 'Сохранение подтверждено. Более поздние правки остались в форме; сохраните их отдельно.'
          : 'Сохранено и подтверждено сервером. Публикация не изменилась.',
      );
    } catch (e) {
      if (owned())
        setError(
          errorMessage(e) +
            (saveAttempt.current
              ? ' Повтор Save подтвердит предыдущую версию; более поздние правки останутся в форме.'
              : ''),
        );
    } finally {
      if (owned()) {
        setBusy(false);
        setSaving(false);
      }
    }
  }
  function storePending(operation: PendingOperation | null, completedOperationId?: string) {
    if (!owned()) return;
    try {
      if (operation) {
        writePublicationReceipt(localStorage, operationKey, operation);
        setPending(operation);
      } else if (completedOperationId)
        setPending(clearPublicationReceipt(localStorage, operationKey, completedOperationId));
    } catch (e) {
      setReceiptError(errorMessage(e));
      throw e;
    }
  }
  async function completeOperation(result: OperationResult, operation: PendingOperation) {
    if (!owned()) return;
    if (result.status !== 'completed') {
      setMessage(
        result.status === 'pending'
          ? 'Операция выполняется. Проверьте статус.'
          : 'Результат пока неизвестен. Проверьте статус или повторите ту же операцию.',
      );
      return;
    }
    if (result.publication?.documentId !== operation.documentId)
      throw new Error('Сервис подтвердил другой документ.');
    storePending(null, operation.operationId);
    setMessage('Сервер подтвердил операцию.');
    await refreshInventory();
    if (!owned()) return;
    if (operation.action === 'deleteDocument') {
      if (dirtyRef.current) {
        setContent((current) => ({
          ...current,
          documents: current.documents
            .filter((d) => d.id !== operation.documentId)
            .map((d) => ({
              ...d,
              attachedResumeId:
                d.attachedResumeId === operation.documentId ? null : d.attachedResumeId,
            })),
        }));
        setMessage(
          'Документ удалён. Более поздние правки других данных сохранены в форме. Перед Save сверьте серверную версию.',
        );
      } else await reload();
    }
  }
  async function perform(operation: PendingOperation, recovery = false) {
    if (busy || !owned()) return;
    setBusy(true);
    setError('');
    try {
      if (recovery) {
        const status = await publicationRequest<OperationResult>(user, {
          action: 'status',
          operationId: operation.operationId,
        });
        if (!owned()) return;
        if (status.status === 'completed' || status.status === 'pending') {
          if (status.action !== operation.action)
            throw new Error('Сервис подтвердил другую операцию.');
          await completeOperation(status, operation);
          return;
        }
      }
      storePending(operation);
      const result = await publicationRequest<OperationResult>(user, operation);
      if (owned()) await completeOperation(result, operation);
    } catch (e) {
      if (owned()) {
        if (isDefinitivePublicationError(e)) {
          storePending(null, operation.operationId);
          await refreshInventory();
          if (!owned()) return;
          setError(
            errorMessage(e) +
              ' Операция отклонена; введённые данные сохранены. Сверьте серверную версию перед повтором.',
          );
        } else
          setError(
            errorMessage(e) +
              ' Статус операции можно проверить; новая операция пока заблокирована.',
          );
      }
    } finally {
      if (owned()) setBusy(false);
    }
  }
  function beginPublication(action: PendingOperation['action']) {
    if (
      !activeDocument ||
      !basis ||
      !publications ||
      (action !== 'unpublish' && dirty) ||
      pending ||
      receiptError ||
      busy
    )
      return;
    const p = activePublication;
    if (
      action === 'publish' &&
      !window.confirm(
        'Опубликовать текущую сохранённую версию? Выбранные контакты и изображения станут доступны по постоянной ссылке.',
      )
    )
      return;
    if (
      action === 'unpublish' &&
      !window.confirm(
        'Снять документ с публикации? Постоянный адрес сохранится, содержимое станет недоступно.',
      )
    )
      return;
    if (
      action === 'deleteDocument' &&
      !window.confirm(
        'Удалить документ и отозвать его публичную страницу? Это действие нельзя отменить.',
      )
    )
      return;
    void perform({
      action,
      documentId: activeDocument.id,
      operationId: uid(),
      expectedMutationId: basis.mutationId,
      expectedVersion: p?.version ?? 0,
      expectedGeneration: publications.lifecycleGeneration,
    });
  }
  function create(kind: PortfolioDocument['kind']) {
    if (busy) return;
    try {
      const document = createDocument(
        content,
        kind,
        kind === 'resume' ? 'Новое резюме' : 'Новое портфолио',
      );
      update({ ...content, documents: [...content.documents, document] });
      navigate(`document/${document.id}`, true);
    } catch (e) {
      setError(errorMessage(e));
    }
  }
  function duplicate(document: PortfolioDocument) {
    if (busy) return;
    if (content.documents.length >= 20) {
      setError('Можно сохранить не больше 20 документов.');
      return;
    }
    const copy = duplicateDocument(document);
    update({ ...content, documents: [...content.documents, copy] });
    navigate(`document/${copy.id}`, true);
  }
  async function exit() {
    if (busy || review || !owned()) return;
    if (dirty && !window.confirm('Отбросить несохранённые изменения и выйти?')) return;
    try {
      await signOut(firebaseServices().auth);
    } catch (e) {
      setError(errorMessage(e));
    }
  }
  async function copy(publication: Publication) {
    if (publication.state !== 'published' || !publication.url || !safeHttpUrl(publication.url))
      return;
    try {
      await navigator.clipboard.writeText(publication.url);
      setMessage('Постоянная ссылка скопирована.');
    } catch {
      setError('Не удалось скопировать ссылку. Выделите её и скопируйте вручную.');
    }
  }
  const shownDocuments = content.documents.filter(
    (d) =>
      (view === 'resumes'
        ? d.kind === 'resume'
        : view === 'portfolios'
          ? d.kind === 'portfolio'
          : true) &&
      `${d.title} ${d.content.profile.name}`.toLowerCase().includes(search.toLowerCase()),
  );
  return (
    <div className="workspace">
      <Header
        context="workspace"
        actions={
          <Button
            className="workspace-settings-access"
            variant="quiet"
            aria-label="Настройки"
            aria-current={view === 'settings' ? 'page' : undefined}
            disabled={busy || !!review}
            onClick={() => navigate('settings')}
          >
            <Icon name="settings" />
          </Button>
        }
      />
      <div className="workspace-body" inert={!!review}>
        <nav className="workspace-nav" aria-label="Рабочая область">
          {(
            [
              { key: 'home', label: 'Главная', icon: 'home' },
              { key: 'resumes', label: 'Резюме', icon: 'file-text' },
              { key: 'projects', label: 'Проекты', icon: 'folder' },
              {
                key: 'portfolios',
                label: 'Портфолио',
                icon: 'panels-top-left',
              },
              { key: 'settings', label: 'Настройки', icon: 'settings' },
            ] as const
          ).map((n) => (
            <Button
              key={n.key}
              disabled={busy}
              variant="quiet"
              className={`${view === n.key ? 'active' : ''} ${n.key === 'settings' ? 'settings-entry' : ''}`}
              aria-current={view === n.key ? 'page' : undefined}
              onClick={() => navigate(n.key)}
            >
              <Icon name={n.icon} />
              {n.label}
            </Button>
          ))}
        </nav>
        <main id="main" className="workspace-main stack" aria-busy={loading || busy}>
          {loading ? (
            <Notice>Загружаем серверную версию…</Notice>
          ) : (
            <>
              <h1>
                {view === 'home'
                  ? 'Рабочая область'
                  : view === 'base'
                    ? 'Общая профессиональная база'
                    : view === 'projects'
                      ? 'Библиотека проектов'
                      : view === 'resumes'
                        ? 'Резюме'
                        : view === 'portfolios'
                          ? 'Портфолио'
                          : view === 'settings'
                            ? 'Настройки'
                            : activeDocument
                              ? `${mode === 'preview' ? 'Просмотр' : 'Редактор'} ${activeDocument.kind === 'resume' ? 'резюме' : 'портфолио'}`
                              : 'Документ не найден'}
              </h1>
              {error && <Notice error>{error}</Notice>}
              {message && <Notice>{message}</Notice>}
              {blocked && (
                <>
                  <p>Сохранение заблокировано до успешного чтения совместимых данных.</p>
                  <Button onClick={() => void reload()}>Повторить чтение</Button>
                </>
              )}
              {!blocked && (
                <>
                  {receiptError && (
                    <Notice error>
                      {receiptError} Сначала проверьте публикации. Повреждённую квитанцию нельзя
                      автоматически принять за успешную операцию.
                    </Notice>
                  )}
                  {pending && (
                    <section className="section stack">
                      <h2>Незавершённая операция</h2>
                      <p>
                        Проверка результата сохраняет тот же ID операции и защищает от повторной
                        публикации или удаления.
                      </p>
                      <Button disabled={busy} onClick={() => void perform(pending, true)}>
                        Проверить и восстановить результат
                      </Button>
                    </section>
                  )}
                  {publicationError && (
                    <div className="stack">
                      <Notice error>{publicationError}</Notice>
                      <Button variant="secondary" onClick={() => void refreshInventory()}>
                        Повторить проверку публикаций
                      </Button>
                    </div>
                  )}
                  <fieldset disabled={busy && !saving} className="workspace-fieldset">
                    {view === 'home' && (
                      <section className="stack">
                        <h2>Общая профессиональная база</h2>
                        <div className="list-row">
                          <span className="stack">
                            <strong>{content.profile.name || 'Профиль пока пуст'}</strong>
                            <small className="muted">
                              {content.profile.headline || 'Добавьте роль, опыт и контакты'}
                            </small>
                          </span>
                          <Button variant="quiet" onClick={() => navigate('base')}>
                            Открыть профиль
                          </Button>
                        </div>
                        <div className="row">
                          <Button variant="secondary" onClick={() => navigate('base')}>
                            Контакты и профиль
                          </Button>
                          <Button variant="secondary" onClick={() => navigate('projects')}>
                            Библиотека проектов
                          </Button>
                        </div>
                      </section>
                    )}
                    {['home', 'resumes', 'portfolios'].includes(view) && (
                      <section className="stack">
                        <h2>Документы</h2>
                        <div className="row">
                          {view !== 'portfolios' && (
                            <Button onClick={() => create('resume')}>Создать резюме</Button>
                          )}
                          {view !== 'resumes' && (
                            <Button
                              variant={view === 'portfolios' ? 'primary' : 'secondary'}
                              onClick={() => create('portfolio')}
                            >
                              Создать портфолио
                            </Button>
                          )}
                        </div>
                        <div className="search-field">
                          <Icon name="search" />
                          <Field
                            label="Поиск документов"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                          />
                        </div>
                        {!shownDocuments.length && (
                          <p className="muted">
                            Документов пока нет. Создайте первый из общей базы или начните с пустого
                            профиля.
                          </p>
                        )}
                        {shownDocuments.map((d) => {
                          const p = publications?.publications.find((p) => p.documentId === d.id);
                          return (
                            <article key={d.id} className="section document-card">
                              <p className="document-type">
                                <Icon
                                  name={d.kind === 'resume' ? 'file-text' : 'panels-top-left'}
                                />
                                {d.kind === 'resume' ? 'РЕЗЮМЕ' : 'ПОРТФОЛИО'}
                              </p>
                              <h3>{d.title}</h3>
                              <p className="muted">
                                {d.content.profile.name} · {d.content.profile.headline}
                              </p>
                              <p
                                className={p?.state === 'published' ? 'publication-state' : 'muted'}
                              >
                                {p?.state === 'published' ? 'Опубликовано' : 'Черновик'}
                              </p>
                              <div className="row">
                                <Button
                                  variant="secondary"
                                  onClick={() => navigate(`document/${d.id}`)}
                                >
                                  Редактировать
                                </Button>
                                <Button
                                  variant="quiet"
                                  disabled={busy}
                                  onClick={() => duplicate(d)}
                                >
                                  Создать копию
                                </Button>
                                {p?.state === 'published' && p.url && (
                                  <Button variant="secondary" onClick={() => void copy(p)}>
                                    Копировать ссылку
                                  </Button>
                                )}
                              </div>
                            </article>
                          );
                        })}
                      </section>
                    )}
                    {view === 'base' && (
                      <div className="stack">
                        <p className="muted">
                          Изменения базы не переписывают документы. Выборочное обновление доступно в
                          их редакторах.
                        </p>
                        <ContentEditor
                          content={content}
                          isBase
                          onChange={(c) =>
                            update({
                              ...content,
                              ...c,
                              documents: content.documents,
                            })
                          }
                        />
                        <MediaUpload
                          user={user}
                          onUploaded={(path) =>
                            setContent((current) => ({
                              ...current,
                              profile: { ...current.profile, avatarPath: path },
                            }))
                          }
                        />
                        <PrivateImage user={user} path={content.profile.avatarPath} />
                        {content.profile.avatarPath && (
                          <Button
                            variant="quiet"
                            onClick={() =>
                              update({
                                ...content,
                                profile: { ...content.profile, avatarPath: '' },
                              })
                            }
                          >
                            Убрать фото из базы
                          </Button>
                        )}
                        <Field
                          label="Приватные заметки"
                          textarea
                          value={notes}
                          onChange={(e) => setNotes(e.target.value)}
                          helper="Заметки никогда не публикуются."
                        />
                      </div>
                    )}
                    {view === 'projects' && (
                      <section className="stack">
                        <Button
                          onClick={() =>
                            update({
                              ...content,
                              projects: [...content.projects, emptyProject()],
                            })
                          }
                        >
                          Создать проект
                        </Button>
                        <GitHubImporter
                          workspace={content}
                          onAdd={(p) =>
                            update({
                              ...content,
                              projects: [...content.projects, p],
                            })
                          }
                        />
                        <div className="search-field">
                          <Icon name="search" />
                          <Field
                            label="Поиск проектов"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                          />
                        </div>
                        {content.projects
                          .filter((p) =>
                            `${p.title} ${p.description} ${p.technologies.join(' ')}`
                              .toLowerCase()
                              .includes(search.toLowerCase()),
                          )
                          .map((p) => (
                            <div key={p.id} className="stack">
                              <ProjectForm
                                project={p}
                                onChange={(next) =>
                                  update({
                                    ...content,
                                    projects: content.projects.map((v) =>
                                      v.id === p.id ? next : v,
                                    ),
                                  })
                                }
                                onDelete={() => {
                                  const refs = content.documents.filter((d) =>
                                    d.projects.some((a) => a.projectId === p.id),
                                  );
                                  if (
                                    !window.confirm(
                                      `Удалить проект из Library${refs.length ? ` и открепить от ${refs.length} документов` : ''}? Опубликованные версии не изменятся до отдельного Publish.`,
                                    )
                                  )
                                    return;
                                  update({
                                    ...content,
                                    projects: content.projects.filter((v) => v.id !== p.id),
                                    documents: content.documents.map((d) => ({
                                      ...d,
                                      projects: d.projects.filter((a) => a.projectId !== p.id),
                                    })),
                                  });
                                }}
                              />
                              <MediaUpload
                                user={user}
                                onUploaded={(path) =>
                                  setContent((current) => ({
                                    ...current,
                                    projects: current.projects.map((v) =>
                                      v.id === p.id && v.imagePaths.length < 6
                                        ? {
                                            ...v,
                                            imagePaths: [...v.imagePaths, path],
                                          }
                                        : v,
                                    ),
                                  }))
                                }
                              />
                              {p.imagePaths.map((path) => (
                                <div className="row" key={path}>
                                  <PrivateImage user={user} path={path} alt="Изображение проекта" />
                                  <Button
                                    variant="quiet"
                                    onClick={() =>
                                      update({
                                        ...content,
                                        projects: content.projects.map((v) =>
                                          v.id === p.id
                                            ? {
                                                ...v,
                                                imagePaths: v.imagePaths.filter((x) => x !== path),
                                              }
                                            : v,
                                        ),
                                      })
                                    }
                                  >
                                    Убрать из проекта
                                  </Button>
                                </div>
                              ))}
                            </div>
                          ))}
                        {!content.projects.length && (
                          <p className="muted">
                            Библиотека пока пуста. Создайте проект или явно добавьте публичный
                            репозиторий из GitHub.
                          </p>
                        )}
                      </section>
                    )}
                    {activeDocument && (
                      <>
                        <div className="row mode-switch">
                          <Button
                            variant={mode === 'edit' ? 'primary' : 'secondary'}
                            onClick={() => setMode('edit')}
                          >
                            Редактирование
                          </Button>
                          <Button
                            variant={mode === 'preview' ? 'primary' : 'secondary'}
                            onClick={() => setMode('preview')}
                          >
                            Просмотр
                          </Button>
                        </div>
                        <div className={`workspace-panes mode-${mode}`}>
                          <div className="workspace-editor stack">
                            <Field
                              label="Название документа"
                              maxLength={120}
                              required
                              value={activeDocument.title}
                              onChange={(e) =>
                                updateDocument({
                                  ...activeDocument,
                                  title: e.target.value,
                                })
                              }
                              helper="Название не меняет постоянный адрес."
                            />
                            {mode === 'edit' ? (
                              <>
                                <ContentEditor
                                  content={activeDocument.content}
                                  contacts={content.links}
                                  onChange={(c) =>
                                    updateDocument({
                                      ...activeDocument,
                                      content: c,
                                    })
                                  }
                                />
                                <MediaUpload
                                  key={activeDocument.id}
                                  user={user}
                                  onUploaded={(path) =>
                                    setContent((current) => ({
                                      ...current,
                                      documents: current.documents.map((d) =>
                                        d.id === activeDocument.id
                                          ? {
                                              ...d,
                                              updatedAt: new Date().toISOString(),
                                              content: {
                                                ...d.content,
                                                profile: {
                                                  ...d.content.profile,
                                                  avatarPath: path,
                                                },
                                              },
                                            }
                                          : d,
                                      ),
                                    }))
                                  }
                                />
                                {activeDocument.content.profile.avatarPath && (
                                  <Button
                                    variant="quiet"
                                    onClick={() =>
                                      updateDocument({
                                        ...activeDocument,
                                        content: {
                                          ...activeDocument.content,
                                          profile: {
                                            ...activeDocument.content.profile,
                                            avatarPath: '',
                                            avatarUrl: '',
                                          },
                                        },
                                      })
                                    }
                                  >
                                    Без фотографии
                                  </Button>
                                )}
                                <AttachmentsEditor
                                  workspace={content}
                                  document={activeDocument}
                                  onChange={updateDocument}
                                />
                                <Button
                                  variant="secondary"
                                  disabled={busy}
                                  onClick={openBaseReview}
                                >
                                  Обновить из базы
                                </Button>
                                <Button variant="secondary" onClick={() => setMode('preview')}>
                                  Просмотр
                                </Button>
                              </>
                            ) : (
                              <>
                                <p className="muted">
                                  {dirty
                                    ? 'Есть несохранённые изменения.'
                                    : basis
                                      ? 'Текущая версия сохранена и подтверждена сервером.'
                                      : 'Документ нужно сохранить.'}
                                </p>
                                <Button variant="secondary" onClick={() => setMode('edit')}>
                                  Редактировать
                                </Button>
                                <p className="muted">Save и Publish — отдельные действия.</p>
                              </>
                            )}
                            <section className="section stack">
                              <h3>Публикация</h3>
                              <p>
                                {activePublication?.state === 'published'
                                  ? 'Опубликовано'
                                  : activePublication?.state === 'deleted'
                                    ? 'Документ удалён'
                                    : 'Не опубликовано'}
                              </p>
                              {activePublication?.state === 'published' &&
                                activePublication.url && (
                                  <>
                                    <a
                                      href={activePublication.url}
                                      target="_blank"
                                      rel="noopener noreferrer"
                                    >
                                      {activePublication.url}
                                    </a>
                                    <Button
                                      variant="secondary"
                                      onClick={() => void copy(activePublication)}
                                    >
                                      Копировать ссылку
                                    </Button>
                                    <Button
                                      variant="danger"
                                      disabled={
                                        !publications || !!pending || !!receiptError || busy
                                      }
                                      onClick={() => beginPublication('unpublish')}
                                    >
                                      Снять с публикации
                                    </Button>
                                  </>
                                )}
                              <Button
                                disabled={!publishReady}
                                onClick={() => beginPublication('publish')}
                              >
                                {activePublication?.state === 'published'
                                  ? 'Опубликовать обновления'
                                  : 'Опубликовать документ'}
                              </Button>
                              {!publishReady && (
                                <small className="muted">
                                  Сохраните документ и дождитесь подтверждённой версии и inventory
                                  публикаций.
                                </small>
                              )}
                              <Button
                                variant="quiet"
                                disabled={busy}
                                onClick={() => duplicate(activeDocument)}
                              >
                                Создать копию
                              </Button>
                              <Button
                                variant="danger"
                                disabled={!publishReady}
                                onClick={() => beginPublication('deleteDocument')}
                              >
                                Удалить документ
                              </Button>
                            </section>
                          </div>
                          <div className="workspace-preview">
                            <p className="muted">Предпросмотр документа</p>
                            <DocumentView
                              content={documentPreview(content, activeDocument)}
                              kind={activeDocument.kind}
                              profilePhoto={
                                activeDocument.content.profile.avatarPath ? (
                                  <PrivateImage
                                    user={user}
                                    path={activeDocument.content.profile.avatarPath}
                                  />
                                ) : undefined
                              }
                              attachedResumeUrl={
                                publications?.publications.find(
                                  (p) =>
                                    p.documentId === activeDocument.attachedResumeId &&
                                    p.state === 'published',
                                )?.url ?? undefined
                              }
                              preview
                            />
                          </div>
                        </div>
                      </>
                    )}
                    {view === 'settings' && <AccountSettings user={user} />}
                    {view.startsWith('document/') && !activeDocument && (
                      <>
                        <p>Документ отсутствует в вашей базе.</p>
                        <Button onClick={() => navigate('home')}>К документам</Button>
                      </>
                    )}
                  </fieldset>
                </>
              )}
            </>
          )}
        </main>
      </div>
      <footer className="workspace-footer" inert={!!review}>
        <small className="muted">
          {dirty
            ? 'Есть несохранённые изменения'
            : busy
              ? 'Выполняем действие…'
              : basis
                ? 'Серверная версия загружена; публикация обновляется отдельно'
                : 'Новая база'}
        </small>
        <div className="row">
          <Button
            variant="secondary"
            disabled={busy || loading || !!review}
            onClick={() => {
              if (dirty && !window.confirm('Отбросить изменения и загрузить серверную версию?'))
                return;
              void reload();
            }}
          >
            Отмена / перезагрузить
          </Button>
          <Button
            disabled={busy || loading || blocked || !!review || (!dirty && !saveAttempt.current)}
            onClick={() => void save()}
          >
            {saving ? 'Сохраняем…' : 'Сохранить'}
          </Button>
          <Button variant="quiet" disabled={busy || !!review} onClick={() => void exit()}>
            Выйти
          </Button>
        </div>
      </footer>
      {review && (
        <div className="dialog-backdrop">
          <section
            ref={reviewDialog}
            className="dialog stack"
            role="dialog"
            aria-modal="true"
            aria-labelledby="review-title"
          >
            <h2 id="review-title">Обновление из общей базы</h2>
            <p>
              Выберите изменения сохранённой базы. После применения сохраните документ отдельно.
            </p>
            {review.changes.map((c) => (
              <div key={c.id} className="section stack">
                <label className="checkbox">
                  <input
                    type="checkbox"
                    checked={selected.has(c.id)}
                    onChange={(e) => {
                      const next = new Set(selected);
                      e.target.checked ? next.add(c.id) : next.delete(c.id);
                      setSelected(next);
                    }}
                  />
                  {c.label}
                  {c.localOverride ? ' · своё значение' : ''}
                </label>
                <div className="review-comparison">
                  <div>
                    <small className="muted">В документе</small>
                    {reviewValue(c.id, c.current)}
                  </div>
                  <div>
                    <small className="muted">В общей базе</small>
                    {reviewValue(c.id, c.incoming)}
                  </div>
                </div>
              </div>
            ))}
            {!review.changes.length && <p>Новых изменений базы нет.</p>}
            <div className="row">
              <Button variant="secondary" onClick={() => setReview(null)}>
                Отмена
              </Button>
              <Button onClick={applyBaseReview}>Применить выбранное</Button>
            </div>
          </section>
        </div>
      )}
    </div>
  );
}
