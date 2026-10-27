'use client';
import { signOut, type User } from 'firebase/auth';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { useSession } from './auth-session';
import { Button, Field, Header, Icon, LinkButton, Notice } from './ui';
import { InlineIcon } from './inline-icon';
import { DeveloperCardDialog } from './developer-card';
import { ContentEditor } from './content-editor';
import { AttachmentsEditor, emptyProject, ProjectForm } from './project-editor';
import { GitHubImporter } from './github-importer';
import { DocumentView } from './document-view';
import { AccountSettings, ApplicationPreferences } from './account-settings';
import { Inbox } from './inbox';
import { AvatarEditor, PrivateImage } from './media-upload';
import { useConfirmation } from './confirmation-dialog';
import { readAvatarBytes, readLegacyAvatarBytes } from '@/lib/portfolio-media-repository';
import { firebaseServices } from '@/lib/firebase';
import { loadDraft, saveDraft } from '@/lib/draft-repository';
import {
  decodeWorkspaceHash,
  joinMessages,
  sameConfirmationContext,
  userErrorMessage,
} from '@/lib/workspace-state';
import { pdfAvatarSource } from '@/lib/portfolio-pdf';
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
  clone,
  advancePersonalization,
  BasisConflictError,
  ContractError,
  emptyContent,
  equal,
  resolveDocument,
  safeHttpUrl,
  safeReturnPath,
  uid,
  validateWorkspace,
  mainDocument,
  migrateMainPortfolio,
  normalizeGitHubUsername,
  deleteLibraryProject,
  importGitHubProjects,
  rebaseLibraryChange,
  type DraftEnvelope,
  type WorkspaceContent,
  type PortfolioDocument,
  type GitHubSource,
} from '@/lib/model';
type View =
  | 'home'
  | 'projects'
  | 'editor'
  | 'github-import'
  | 'settings'
  | 'inbox'
  | `inbox/${string}`
  | `project/${string}`;
type PendingOperation = PublicationMutation;
const canonicalGitHub = (value: string) => {
  try {
    return normalizeGitHubUsername(value);
  } catch {
    return null;
  }
};
const errorMessage = (error: unknown) => userErrorMessage(error);
export function ownerView(value: string): View {
  if (
    /^(home|projects|editor|github-import|settings|inbox|inbox\/[a-f0-9]{32}|project\/[A-Za-z0-9_-]+)$/.test(
      value,
    )
  )
    return value as View;
  if (['base', 'resumes', 'portfolios'].includes(value) || value.startsWith('document/'))
    return 'editor';
  return 'home';
}
export function Workspace({ initialView = 'home' }: { initialView?: string }) {
  const session = useSession(),
    router = useRouter();
  useEffect(() => {
    if (!session.loading && !session.error && !session.user) {
      const destination = safeReturnPath(
        window.location.pathname + window.location.search + window.location.hash,
      );
      router.replace(`/sign-in?returnTo=${encodeURIComponent(destination)}`);
    }
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
  const { confirm, choose, confirmation } = useConfirmation();
  const [basis, setBasis] = useState<DraftEnvelope | null>(null),
    [content, setContent] = useState<WorkspaceContent>(emptyContent),
    [notes, setNotes] = useState(''),
    [loading, setLoading] = useState(true),
    [blocked, setBlocked] = useState(false),
    [busy, setBusy] = useState(false),
    [saving, setSaving] = useState(false),
    [error, setError] = useState(''),
    [message, setMessage] = useState(''),
    [view, setView] = useState<View>(ownerView(initialView)),
    [publications, setPublications] = useState<Inventory | null>(null),
    [publicationError, setPublicationError] = useState(''),
    [pending, setPending] = useState<PendingOperation | null>(null),
    [receiptError, setReceiptError] = useState(''),
    [search, setSearch] = useState(''),
    [migrationChoice, setMigrationChoice] = useState<string | null>(null),
    [migrationPreview, setMigrationPreview] = useState(false),
    [shareChoice, setShareChoice] = useState(false),
    [manualShareUrl, setManualShareUrl] = useState(''),
    [githubInput, setGitHubInput] = useState(''),
    [avatarBusy, setAvatarBusy] = useState(false),
    [conflict, setConflict] = useState(false),
    [shareMenu, setShareMenu] = useState(false),
    [cardOpen, setCardOpen] = useState(false),
    [editorMode, setEditorMode] = useState<'form' | 'preview'>('form');
  const shareDialog = useRef<HTMLElement | null>(null);
  const initializationAttempt = useRef<{
    mutationId: string;
    content: WorkspaceContent;
  } | null>(null);
  const reloadVersion = useRef(0);
  const saveAttempt = useRef<{
    mutationId: string;
    basis: DraftEnvelope | null;
    content: WorkspaceContent;
    notes: string;
    previousContent?: WorkspaceContent;
    githubInput?: string;
  } | null>(null);
  const migrationAttempt = useRef<{
    mutationId: string;
    basis: DraftEnvelope | null;
    content: WorkspaceContent;
    notes: string;
  } | null>(null);
  const scopedAttempt = useRef<{
    mutationId: string;
    basis: DraftEnvelope | null;
    previous: WorkspaceContent;
    content: WorkspaceContent;
    notes: string;
  } | null>(null);
  const input = useRef({ content, notes });
  input.current = { content, notes };
  const activeUid = useRef(user.uid),
    // Действие после подтверждённой публикации: отправить ссылку или открыть визитку.
    afterPublish = useRef<'share' | 'card' | null>(null);
  const dirty =
    !equal(content, basis?.content ?? emptyContent()) ||
    notes !== (basis?.notes ?? '') ||
    canonicalGitHub(githubInput) !== (basis?.content?.githubUsername ?? '');
  const dirtyRef = useRef(dirty);
  dirtyRef.current = dirty;
  const operationKey = `stackcard.publication.${user.uid}`;
  const savedWorkspace = basis?.content ?? emptyContent(),
    savedMain = mainDocument(savedWorkspace),
    workingMain = mainDocument(content);
  const activeDocument = savedMain,
    activePublication = savedMain
      ? publications?.publications.find((p) => p.documentId === savedMain.id)
      : undefined;
  const inboxView = view === 'inbox' || view.startsWith('inbox/');
  const project = view.startsWith('project/')
    ? content.projects.find((p) => p.id === view.slice(8))
    : undefined;
  const onboarding = content.personalization.status === 'inProgress';
  const migrationNeeded = !loading && !blocked && !workingMain;
  const owned = () =>
    activeUid.current === user.uid && firebaseServices().auth.currentUser?.uid === user.uid;
  const confirmationContext = useRef({
    basis,
    content,
    notes,
    githubInput,
    publications,
    pending,
    busy,
    avatarBusy,
    view,
  });
  confirmationContext.current = {
    basis,
    content,
    notes,
    githubInput,
    publications,
    pending,
    busy,
    avatarBusy,
    view,
  };
  async function confirmAction(message: string, title?: string) {
    const captured = confirmationContext.current;
    const accepted = await confirm(message, title);
    if (!accepted || !owned()) return false;
    if (!sameConfirmationContext(captured, confirmationContext.current, equal)) {
      setMessage('Данные изменились во время подтверждения. Повторите действие');
      return false;
    }
    return true;
  }
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
    const version = ++reloadVersion.current;
    const currentRead = () => owned() && version === reloadVersion.current;
    setLoading(true);
    setError('');
    setBlocked(false);
    try {
      let saved = await loadDraft(user);
      if (!currentRead()) return;
      if (!saved?.content) {
        if (!initializationAttempt.current) {
          const first = migrateMainPortfolio(emptyContent(), null);
          first.personalization = { status: 'inProgress', step: 0 };
          initializationAttempt.current = {
            mutationId: `web-initialize-${uid()}`,
            content: first,
          };
        }
        const attempt = initializationAttempt.current;
        saved = (
          await saveDraft(user, saved, attempt.content, saved?.notes ?? '', attempt.mutationId)
        ).draft;
        if (!currentRead()) return;
      }
      initializationAttempt.current = null;
      setBasis(saved);
      setContent(saved.content ?? emptyContent());
      setGitHubInput(saved.content?.githubUsername ?? '');
      setNotes(saved.notes);
      saveAttempt.current = null;
      scopedAttempt.current = null;
      migrationAttempt.current = null;
      setConflict(false);
    } catch (e) {
      if (currentRead()) {
        setError(errorMessage(e));
        setBlocked(true);
      }
    } finally {
      if (currentRead()) setLoading(false);
    }
  }
  useEffect(() => {
    activeUid.current = user.uid;
    void reload();
    void refreshInventory();
    // Битый hash ведёт на главный вид и не блокирует чтение квитанции.
    if (window.location.hash.length > 1)
      setView(ownerView(decodeWorkspaceHash(window.location.hash)));
    try {
      setPending(readPublicationReceipt(localStorage, operationKey));
    } catch (e) {
      setReceiptError(errorMessage(e));
    }
    return () => {
      activeUid.current = '';
      reloadVersion.current++;
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
    function leaving(event: BeforeUnloadEvent) {
      if (dirtyRef.current) {
        event.preventDefault();
        event.returnValue = '';
      }
    }
    window.addEventListener('beforeunload', leaving);
    return () => window.removeEventListener('beforeunload', leaving);
  }, []);
  useEffect(() => {
    let navigationVersion = 0;
    async function history() {
      const version = ++navigationVersion;
      const next = ownerView(decodeWorkspaceHash(window.location.hash));
      if (busy || avatarBusy) {
        window.history.replaceState(null, '', `/workspace#${view}`);
        return;
      }
      // Пока идёт выбор, адрес возвращается к текущему виду; переход только после решения.
      if (dirtyRef.current) window.history.replaceState(null, '', `/workspace#${view}`);
      const accepted = await resolveUnsavedRef.current();
      if (version !== navigationVersion || !owned()) return;
      if (!accepted) {
        window.history.replaceState(null, '', `/workspace#${view}`);
        return;
      }
      window.history.replaceState(null, '', `/workspace#${next}`);
      setView(next);
    }
    const listener = () => void history().catch((e) => setError(errorMessage(e)));
    window.addEventListener('popstate', listener);
    return () => {
      navigationVersion++;
      window.removeEventListener('popstate', listener);
    };
  }, [view, busy, avatarBusy, basis]);
  useEffect(() => {
    if (!shareChoice) return;
    const previous = document.activeElement as HTMLElement | null;
    const dialog = shareDialog.current;
    const buttons = () =>
      Array.from(dialog?.querySelectorAll<HTMLButtonElement>('button:not(:disabled)') ?? []);
    buttons()[0]?.focus();
    function key(event: KeyboardEvent) {
      if (event.key === 'Escape') {
        setShareChoice(false);
        event.preventDefault();
      }
      if (event.key !== 'Tab') return;
      const items = buttons(),
        first = items[0],
        last = items.at(-1);
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last?.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first?.focus();
      }
    }
    document.addEventListener('keydown', key);
    return () => {
      document.removeEventListener('keydown', key);
      previous?.focus();
    };
  }, [shareChoice]);
  async function navigate(next: View, preserve = false) {
    if (busy || avatarBusy) return;
    if (!preserve && dirty && !(await resolveUnsaved())) return;
    if (!owned()) return;
    setView(next);
    setEditorMode('form');
    window.scrollTo({ top: 0 });
    setSearch('');
    window.history.pushState(null, '', `/workspace#${next}`);
  }
  function update(next: WorkspaceContent) {
    setContent(next);
    setMessage('');
  }
  function updateDocument(document: PortfolioDocument) {
    setContent((current) => ({
      ...current,
      documents: current.documents.map((d) =>
        d.id === document.id ? { ...document, updatedAt: new Date().toISOString() } : d,
      ),
    }));
    setMessage('');
  }
  async function commitScoped(next: WorkspaceContent) {
    if (busy || avatarBusy || !owned() || blocked)
      throw new Error('Дождитесь завершения предыдущего действия');
    setBusy(true);
    setError('');
    try {
      let attempt = scopedAttempt.current;
      if (attempt && !equal(next, attempt.content))
        throw new Error('Сначала подтвердите незавершённое изменение библиотеки кнопкой выше');
      if (!attempt) {
        const previous = clone(basis?.content ?? emptyContent());
        attempt = {
          mutationId: `web-scoped-${uid()}`,
          basis,
          previous,
          content: clone(validateWorkspace(next, user.uid)),
          notes: basis?.notes ?? '',
        };
        scopedAttempt.current = attempt;
      }
      let result: Awaited<ReturnType<typeof saveDraft>>;
      try {
        result = await saveDraft(
          user,
          attempt.basis,
          attempt.content,
          attempt.notes,
          attempt.mutationId,
        );
      } catch (e) {
        // Definitive отказ: повтор того же attempt снова упрётся в тот же basis.
        if (owned() && e instanceof ContractError) {
          scopedAttempt.current = null;
          if (e instanceof BasisConflictError) setConflict(true);
        }
        throw e;
      }
      const { draft: saved, superseded } = result;
      if (!owned()) return;
      setBasis(saved);
      setContent((working) => rebaseLibraryChange(saved.content!, attempt.previous, working));
      setGitHubInput((current) =>
        canonicalGitHub(current) === attempt.previous.githubUsername
          ? saved.content!.githubUsername
          : current,
      );
      scopedAttempt.current = null;
      setMessage(
        superseded
          ? 'Изменения библиотеки сохранены. На сервере уже есть более новая версия с другого устройства, она стала основой формы'
          : 'Изменения библиотеки сохранены. Публичная версия не изменилась',
      );
    } finally {
      if (owned()) setBusy(false);
    }
  }
  // true — форма совпадает с подтверждённой версией и уход со страницы ничего не теряет.
  async function save(): Promise<boolean> {
    if (blocked || busy || avatarBusy || !owned()) return false;
    if (scopedAttempt.current) {
      setError('Сначала подтвердите незавершённое изменение библиотеки кнопкой выше');
      return false;
    }
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
      const { draft: saved, superseded } = await saveDraft(
        user,
        attempt.basis,
        attempt.content,
        attempt.notes,
        attempt.mutationId,
      );
      if (!owned()) return false;
      const hasNewerInput =
        !equal(input.current.content, attempt.content) || input.current.notes !== attempt.notes;
      setBasis(saved);
      setContent((current) =>
        equal(current, attempt.content) ? (saved.content ?? emptyContent()) : current,
      );
      setNotes((current) => (current === attempt.notes ? saved.notes : current));
      if (superseded)
        setGitHubInput((current) =>
          canonicalGitHub(current) === attempt.content.githubUsername
            ? (saved.content?.githubUsername ?? '')
            : current,
        );
      saveAttempt.current = null;
      setConflict(false);
      setMessage(
        superseded
          ? hasNewerInput
            ? 'Сохранение подтверждено, но на сервере уже есть более новая версия с другого устройства. Более поздние правки остались в форме, Save заменит ими серверную версию'
            : 'Сохранение подтверждено, но на сервере уже есть более новая версия с другого устройства. Форма показывает её'
          : hasNewerInput
            ? 'Сохранение подтверждено. Более поздние правки остались в форме; сохраните их отдельно'
            : 'Сохранено и подтверждено сервером. Публикация не изменилась',
      );
      return !hasNewerInput && !superseded;
    } catch (e) {
      if (!owned()) return false;
      // Definitive отказ: attempt со старым basis больше не повторяем.
      if (e instanceof ContractError) saveAttempt.current = null;
      if (e instanceof BasisConflictError) setConflict(true);
      setError(
        saveAttempt.current
          ? joinMessages(
              errorMessage(e),
              'Повтор Save подтвердит предыдущую версию; более поздние правки останутся в форме',
            )
          : errorMessage(e),
      );
      return false;
    } finally {
      if (owned()) {
        setBusy(false);
        setSaving(false);
      }
    }
  }
  function resetToBasis() {
    setContent(clone(basis?.content ?? emptyContent()));
    setGitHubInput(basis?.content?.githubUsername ?? '');
    setNotes(basis?.notes ?? '');
    saveAttempt.current = null;
  }
  // Уход с несохранёнными правками: «Отмена / Не сохранять / Сохранить», как в design contract.
  async function resolveUnsaved(): Promise<boolean> {
    if (!dirtyRef.current) return true;
    const captured = confirmationContext.current;
    const choice = await choose(
      'Без сохранения изменения будут потеряны',
      'Сохранить изменения?',
      'Не сохранять',
      'Сохранить',
    );
    if (choice === 'cancel' || !owned()) return false;
    if (!sameConfirmationContext(captured, confirmationContext.current, equal)) {
      setMessage('Данные изменились во время подтверждения. Повторите действие');
      return false;
    }
    if (choice === 'confirm') return save();
    resetToBasis();
    return true;
  }
  const resolveUnsavedRef = useRef(resolveUnsaved);
  resolveUnsavedRef.current = resolveUnsaved;
  // Явный выход из конфликта: новая basis с сервера, несохранённая форма не трогается.
  async function loadServerBasis() {
    if (busy || avatarBusy || !owned()) return;
    setBusy(true);
    setError('');
    setMessage('');
    try {
      const server = await loadDraft(user);
      if (!owned()) return;
      if (!server?.content) throw new Error('Серверная версия недоступна. Повторите попытку');
      setBasis(server);
      saveAttempt.current = null;
      scopedAttempt.current = null;
      setConflict(false);
      setMessage(
        'Серверная версия загружена как основа. Ваши правки остались в форме, Save заменит ими серверную версию',
      );
    } catch (e) {
      if (owned()) setError(errorMessage(e));
    } finally {
      if (owned()) setBusy(false);
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
          ? 'Операция выполняется. Проверьте статус'
          : 'Результат пока неизвестен. Проверьте статус или повторите ту же операцию',
      );
      return;
    }
    if (result.publication?.documentId !== operation.documentId)
      throw new Error('Сервис подтвердил другой документ');
    storePending(null, operation.operationId);
    setMessage('Сервер подтвердил операцию');
    await refreshInventory();
    if (!owned()) return;
    const after = afterPublish.current;
    afterPublish.current = null;
    if (after === 'share' && result.publication?.state === 'published')
      await sharePublication(result.publication);
    if (after === 'card' && result.publication?.state === 'published') setCardOpen(true);
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
            throw new Error('Сервис подтвердил другую операцию');
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
            joinMessages(
              errorMessage(e),
              'Операция отклонена; введённые данные сохранены. Сверьте серверную версию перед повтором',
            ),
          );
        } else
          setError(
            joinMessages(
              errorMessage(e),
              'Статус операции можно проверить; новая операция пока заблокирована',
            ),
          );
      }
    } finally {
      if (owned()) setBusy(false);
    }
  }
  async function beginPublication(action: PendingOperation['action'], confirmed = false) {
    if (!activeDocument || !basis || !publications || pending || receiptError || busy) {
      afterPublish.current = null;
      return;
    }
    const p = activePublication;
    if (
      action === 'publish' &&
      !confirmed &&
      !(await confirmAction(
        'Опубликовать текущую сохранённую версию? Введённые контакты и фотография станут доступны по постоянной ссылке',
        'Опубликовать портфолио?',
      ))
    ) {
      afterPublish.current = null;
      return;
    }
    if (
      action === 'unpublish' &&
      !(await confirmAction(
        'Снять документ с публикации? Постоянный адрес сохранится, содержимое станет недоступно',
        'Снять с публикации?',
      ))
    )
      return;
    if (
      action === 'deleteDocument' &&
      !(await confirmAction(
        'Удалить документ и отозвать его публичную страницу? Это действие нельзя отменить',
        'Удалить документ?',
      ))
    )
      return;
    if (!owned()) return;
    void perform({
      action,
      documentId: activeDocument.id,
      operationId: uid(),
      expectedMutationId: basis.mutationId,
      expectedVersion: p?.version ?? 0,
      expectedGeneration: publications.lifecycleGeneration,
    });
  }
  async function exit() {
    if (busy || avatarBusy || !owned()) return;
    if (dirty && !(await confirmAction('Отбросить несохранённые изменения и выйти?'))) return;
    if (!owned()) return;
    try {
      await signOut(firebaseServices().auth);
    } catch (e) {
      setError(errorMessage(e));
    }
  }
  async function sharePublication(publication: Publication) {
    if (publication.state !== 'published' || !publication.url || !safeHttpUrl(publication.url))
      throw new Error('Нет подтверждённой публичной ссылки');
    if (!owned()) return;
    try {
      if (navigator.share) {
        await navigator.share({ title: 'Портфолио', url: publication.url });
        if (owned()) setMessage('Ссылка отправлена');
      } else {
        await navigator.clipboard.writeText(publication.url);
        if (owned()) setMessage('Ссылка скопирована');
      }
    } catch (e) {
      if (e instanceof Error && e.name === 'AbortError') return;
      if (owned()) {
        setManualShareUrl(publication.url);
        setMessage('Скопируйте постоянную ссылку ниже');
      }
    }
  }
  function share() {
    afterPublish.current = null;
    setError('');
    if (!basis || !savedMain) {
      setError('Сначала сохраните портфолио');
      return;
    }
    if (!publications) {
      setError(publicationError || 'Не удалось проверить публичную версию. Повторите проверку');
      void refreshInventory();
      return;
    }
    if (pending || receiptError) {
      setError('Сначала восстановите незавершённую операцию публикации');
      return;
    }
    if (activePublication?.state === 'published') {
      if (activePublication.sourceMutationId !== basis.mutationId) {
        setShareChoice(true);
        return;
      }
      void sharePublication(activePublication).catch((e) => setError(errorMessage(e)));
      return;
    }
    afterPublish.current = 'share';
    void beginPublication('publish');
  }
  async function download() {
    if (busy || !savedMain || !owned()) return;
    setBusy(true);
    setError('');
    try {
      const captured = resolveDocument(savedWorkspace, savedMain),
        owner = user.uid;
      // Скрытый профиль не читает фото; недоступная legacy-ссылка даёт PDF без фото.
      const avatar = pdfAvatarSource(captured);
      let avatarBytes: Uint8Array | undefined,
        omitAvatar = false;
      if (avatar && 'path' in avatar) avatarBytes = await readAvatarBytes(user, avatar.path);
      else if (avatar)
        try {
          avatarBytes = await readLegacyAvatarBytes(user, avatar.url);
        } catch {
          omitAvatar = true;
        }
      if (!owned() || owner !== user.uid) return;
      const { generatePortfolioPdf } = await import('@/lib/portfolio-pdf');
      const blob = await generatePortfolioPdf(captured, { avatarBytes, omitAvatar });
      if (!owned()) return;
      const url = URL.createObjectURL(blob),
        link = document.createElement('a');
      link.href = url;
      link.download = 'StackCard-portfolio.pdf';
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 30000);
      setMessage(
        omitAvatar
          ? 'PDF подготовлен без фотографии: браузер не смог загрузить её по старой ссылке. Загрузите фото заново в редакторе'
          : 'PDF подготовлен для скачивания',
      );
    } catch (e) {
      if (owned()) setError(errorMessage(e));
    } finally {
      if (owned()) setBusy(false);
    }
  }
  async function migrate() {
    if (busy || !owned()) return;
    setBusy(true);
    setError('');
    try {
      // Повтор после неизвестного ответа подтверждает ту же операцию переноса.
      let attempt = migrationAttempt.current;
      if (!attempt) {
        attempt = {
          mutationId: `web-migrate-${uid()}`,
          basis,
          content: clone(
            validateWorkspace(migrateMainPortfolio(content, migrationChoice), user.uid),
          ),
          notes,
        };
        migrationAttempt.current = attempt;
      }
      const { draft: saved } = await saveDraft(
        user,
        attempt.basis,
        attempt.content,
        attempt.notes,
        attempt.mutationId,
      );
      if (!owned()) return;
      migrationAttempt.current = null;
      setBasis(saved);
      setContent(saved.content!);
      setNotes(saved.notes);
      setMigrationPreview(false);
      setMessage(
        'Основное портфолио сохранено. Прежние данные сохранены для восстановления; публикация не изменилась',
      );
    } catch (e) {
      if (!owned()) return;
      if (e instanceof ContractError) migrationAttempt.current = null;
      setError(
        e instanceof BasisConflictError
          ? 'Данные изменились на другом устройстве. Загрузите серверную версию и выберите основу заново'
          : migrationAttempt.current
            ? joinMessages(errorMessage(e), 'Повтор подтвердит ту же операцию переноса')
            : errorMessage(e),
      );
    } finally {
      if (owned()) setBusy(false);
    }
  }
  async function personalize(action: 'next' | 'skip' | 'back') {
    if (!workingMain || busy || avatarBusy || !owned()) return;
    setBusy(true);
    setError('');
    try {
      let attempt = saveAttempt.current;
      if (!attempt) {
        const next = advancePersonalization(
          {
            ...content,
            githubUsername:
              action === 'skip' || action === 'back'
                ? content.githubUsername
                : normalizeGitHubUsername(githubInput),
          },
          action,
        );
        attempt = {
          mutationId: `web-personalize-${uid()}`,
          basis,
          content: clone(validateWorkspace(next, user.uid)),
          notes,
          previousContent: clone(content),
          githubInput,
        };
        saveAttempt.current = attempt;
      }
      const { draft: saved } = await saveDraft(
        user,
        attempt.basis,
        attempt.content,
        attempt.notes,
        attempt.mutationId,
      );
      if (!owned()) return;
      setBasis(saved);
      setContent((current) =>
        equal(current, attempt.previousContent)
          ? saved.content!
          : { ...current, personalization: saved.content!.personalization },
      );
      setGitHubInput((current) =>
        current === attempt.githubInput ? saved.content!.githubUsername : current,
      );
      saveAttempt.current = null;
      if (saved.content!.personalization.status === 'completed') {
        setView('home');
        window.history.replaceState(null, '', '/workspace#home');
      }
    } catch (e) {
      if (!owned()) return;
      if (e instanceof ContractError) saveAttempt.current = null;
      if (e instanceof BasisConflictError) setConflict(true);
      setError(
        saveAttempt.current
          ? joinMessages(errorMessage(e), 'Повторное действие подтвердит предыдущий шаг')
          : errorMessage(e),
      );
    } finally {
      if (owned()) setBusy(false);
    }
  }
  async function saveGitHub(value: string) {
    const previous = basis?.content ?? emptyContent();
    const next = { ...previous, githubUsername: normalizeGitHubUsername(value) };
    await commitScoped(next);
  }
  async function importProjects(sources: GitHubSource[]) {
    await commitScoped(importGitHubProjects(basis?.content ?? emptyContent(), sources));
  }
  async function removeProject(id: string): Promise<boolean> {
    if (
      !(await confirmAction(
        'Удалить проект из StackCard и убрать из портфолио? Репозиторий GitHub сохранится. Если проект опубликован, обновите публичную версию отдельно',
        'Удалить проект?',
      ))
    )
      return false;
    if (!savedWorkspace.projects.some((p) => p.id === id)) {
      update(deleteLibraryProject(content, id));
      return true;
    }
    try {
      await commitScoped(deleteLibraryProject(savedWorkspace, id));
      return true;
    } catch (e) {
      if (owned()) setError(errorMessage(e));
      return false;
    }
  }
  const photo = workingMain ? (
    <AvatarEditor
      user={user}
      path={workingMain.content.profile.avatarPath}
      externalUrl={workingMain.content.profile.avatarUrl}
      disabled={busy}
      onBusyChanged={setAvatarBusy}
      onChange={(path) =>
        setContent((current) => ({
          ...current,
          documents: current.documents.map((d) =>
            d.id === current.mainPortfolioId
              ? {
                  ...d,
                  updatedAt: new Date().toISOString(),
                  content: {
                    ...d.content,
                    profile: { ...d.content.profile, avatarPath: path, avatarUrl: '' },
                  },
                }
              : d,
          ),
        }))
      }
    />
  ) : null;
  const githubField = (
    <Field
      label="GitHub-профиль"
      placeholder="https://github.com/username"
      value={githubInput}
      maxLength={120}
      onChange={(e) => setGitHubInput(e.target.value)}
    />
  );
  const savedHasContent = !!savedMain && portfolioHasContent(savedWorkspace, savedMain);
  const query = search.trim().toLowerCase();
  const shownProjects = content.projects.filter((p) =>
    `${p.title} ${p.description} ${p.technologies.join(' ')}`.toLowerCase().includes(query),
  );
  const attachedIds = new Set(workingMain?.projects.map((a) => a.projectId) ?? []);
  const previewCandidate =
    migrationNeeded && migrationPreview ? migrateMainPortfolio(content, migrationChoice) : null;
  const showSave =
    !onboarding &&
    !migrationNeeded &&
    !inboxView &&
    (view === 'editor' || view === 'projects' || view.startsWith('project/'));
  return (
    <div className="workspace single-portfolio-workspace" data-view={view.split('/')[0]}>
      <Header
        context="workspace"
        actions={
          <Button
            className="workspace-settings-access"
            variant="quiet"
            aria-label="Настройки"
            aria-current={view === 'settings' ? 'page' : undefined}
            disabled={busy || avatarBusy || onboarding || migrationNeeded}
            onClick={() => navigate('settings')}
          >
            <Icon name="settings" />
          </Button>
        }
      />
      <div className="workspace-body" inert={shareChoice}>
        <nav className="workspace-nav" aria-label="Рабочая область">
          {(
            [
              { key: 'home', label: 'Главная', icon: 'home' },
              { key: 'projects', label: 'Проекты', icon: 'folder' },
              { key: 'editor', label: 'Редактор', icon: 'file-text' },
            ] as const
          ).map((n) => (
            <Button
              key={n.key}
              variant="quiet"
              disabled={busy || avatarBusy || onboarding || migrationNeeded}
              className={
                view === n.key ||
                (n.key === 'projects' && (view === 'github-import' || view.startsWith('project/')))
                  ? 'active'
                  : ''
              }
              aria-current={view === n.key ? 'page' : undefined}
              onClick={() => navigate(n.key)}
            >
              <Icon name={n.icon} />
              {n.label}
            </Button>
          ))}
        </nav>
        <main id="main" className="workspace-main stack" aria-busy={loading || busy}>
          {error && <Notice error>{error}</Notice>}
          {message && <Notice>{message}</Notice>}
          {loading ? (
            <div className="workspace-loading" role="status">
              <span className="spinner" aria-hidden="true" />
              Загружаем сохранённую версию…
            </div>
          ) : blocked ? (
            <section className="status-card stack">
              <p>Не удалось прочитать совместимые данные. Введённые данные не заменены</p>
              <Button onClick={() => void reload()}>Повторить чтение</Button>
            </section>
          ) : (
            <>
              {scopedAttempt.current && (
                <section className="stack">
                  <Notice>Нужно подтвердить результат предыдущего изменения библиотеки</Notice>
                  <Button
                    disabled={busy || avatarBusy}
                    onClick={() => {
                      const attempt = scopedAttempt.current;
                      if (attempt)
                        void commitScoped(attempt.content).catch((e) => {
                          if (owned()) setError(errorMessage(e));
                        });
                    }}
                  >
                    Подтвердить изменение библиотеки
                  </Button>
                </section>
              )}
              {pending && (
                <section className="section stack">
                  <h2>Незавершённая публикация</h2>
                  <Button disabled={busy} onClick={() => void perform(pending, true)}>
                    Проверить и восстановить результат
                  </Button>
                </section>
              )}
              {receiptError && <Notice error>{receiptError}</Notice>}
              {conflict && !migrationNeeded && (
                <section className="status-card stack" role="alert">
                  <p>
                    <strong>Версия на сервере изменилась.</strong> Ваш ввод остался в форме.
                    Загрузите серверную версию как основу, затем сохраните правки
                  </p>
                  <Button
                    variant="secondary"
                    disabled={busy || avatarBusy}
                    onClick={() => void loadServerBasis()}
                  >
                    Загрузить серверную версию, сохранив правки
                  </Button>
                </section>
              )}
              {migrationNeeded ? (
                <section className="stack">
                  <h1>Выберите основу портфолио</h1>
                  <p className="muted">
                    Перенесём один источник без смешивания текстов. Прежние данные и постоянные
                    ссылки сохранятся
                  </p>
                  <label className="project-row">
                    <input
                      type="radio"
                      name="migration"
                      disabled={busy || !!migrationAttempt.current}
                      checked={migrationChoice === null}
                      onChange={() => {
                        setMigrationChoice(null);
                        setMigrationPreview(false);
                      }}
                    />
                    <span>Прежняя общая база</span>
                  </label>
                  {content.documents.map((d) => (
                    <label className="project-row" key={d.id}>
                      <input
                        type="radio"
                        name="migration"
                        disabled={busy || !!migrationAttempt.current}
                        checked={migrationChoice === d.id}
                        onChange={() => {
                          setMigrationChoice(d.id);
                          setMigrationPreview(false);
                        }}
                      />
                      <span className="project-copy">
                        <strong>{d.title}</strong>
                        {d.content.profile.name && <small>{d.content.profile.name}</small>}
                      </span>
                    </label>
                  ))}
                  <Button variant="secondary" onClick={() => setMigrationPreview(true)}>
                    Посмотреть перенос
                  </Button>
                  {previewCandidate && (
                    <DocumentView
                      content={documentPreview(previewCandidate, mainDocument(previewCandidate)!)}
                      kind="portfolio"
                      preview
                    />
                  )}
                  <div className="dialog-actions">
                    <Button variant="secondary" disabled={busy} onClick={() => void reload()}>
                      Загрузить серверную версию
                    </Button>
                    <Button disabled={busy || !migrationPreview} onClick={() => void migrate()}>
                      Использовать выбранную основу
                    </Button>
                  </div>
                </section>
              ) : onboarding && workingMain ? (
                <section className="stack personalization view-enter">
                  <p className="muted">Шаг {content.personalization.step + 1} из 4</p>
                  <div className="stepper" aria-hidden="true">
                    <span style={{ width: `${(content.personalization.step + 1) * 25}%` }} />
                  </div>
                  <h1>
                    {
                      ['GitHub', 'Имя и должность', 'О себе', 'Фотография'][
                        content.personalization.step
                      ]
                    }
                  </h1>
                  {content.personalization.step === 0 ? (
                    githubField
                  ) : content.personalization.step === 1 ? (
                    <>
                      <Field
                        label="Имя"
                        value={workingMain.content.profile.name}
                        maxLength={100}
                        onChange={(e) =>
                          updateDocument({
                            ...workingMain,
                            content: {
                              ...workingMain.content,
                              profile: { ...workingMain.content.profile, name: e.target.value },
                            },
                          })
                        }
                      />
                      <Field
                        label="Должность"
                        value={workingMain.content.profile.headline}
                        maxLength={160}
                        onChange={(e) =>
                          updateDocument({
                            ...workingMain,
                            content: {
                              ...workingMain.content,
                              profile: { ...workingMain.content.profile, headline: e.target.value },
                            },
                          })
                        }
                      />
                      <Field
                        label="Город / страна"
                        value={workingMain.content.profile.locationText}
                        maxLength={200}
                        onChange={(e) =>
                          updateDocument({
                            ...workingMain,
                            content: {
                              ...workingMain.content,
                              profile: {
                                ...workingMain.content.profile,
                                locationText: e.target.value,
                                publishLocation: true,
                              },
                            },
                          })
                        }
                      />
                    </>
                  ) : content.personalization.step === 2 ? (
                    <>
                      <Field
                        label="О себе"
                        textarea
                        value={workingMain.content.profile.bio}
                        maxLength={4000}
                        onChange={(e) =>
                          updateDocument({
                            ...workingMain,
                            content: {
                              ...workingMain.content,
                              profile: { ...workingMain.content.profile, bio: e.target.value },
                            },
                          })
                        }
                      />
                    </>
                  ) : (
                    photo
                  )}
                  <div className="dialog-actions">
                    <Button
                      variant="secondary"
                      disabled={busy || avatarBusy || content.personalization.step === 0}
                      onClick={() => void personalize('back')}
                    >
                      Назад
                    </Button>
                    <Button disabled={busy || avatarBusy} onClick={() => void personalize('next')}>
                      {content.personalization.step === 3 ? 'Завершить' : 'Далее'}
                    </Button>
                  </div>
                </section>
              ) : (
                <fieldset className="workspace-fieldset" disabled={busy && !saving}>
                  {view === 'home' && (
                    <section className="stack portfolio-home view-enter">
                      <div className="view-heading">
                        <h1>Главная</h1>
                        <p className="muted">Сохранённая версия портфолио</p>
                      </div>
                      <div className="portfolio-actions">
                        <Button
                          variant="secondary"
                          disabled={busy || !savedHasContent}
                          onClick={() => void download()}
                        >
                          Скачать портфолио
                        </Button>
                        <Button
                          disabled={busy || !savedHasContent}
                          onClick={() => setShareMenu(true)}
                        >
                          Поделиться
                        </Button>
                      </div>
                      {manualShareUrl && (
                        <a
                          className="public-contact"
                          href={manualShareUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                        >
                          {manualShareUrl}
                        </a>
                      )}
                      {savedMain && savedHasContent && (
                        <PublicationPanel
                          publication={activePublication}
                          loaded={!!publications}
                          error={publicationError}
                          outdated={
                            activePublication?.state === 'published' &&
                            activePublication.sourceMutationId !== basis?.mutationId
                          }
                          disabled={busy || !!pending || !!receiptError}
                          onRetry={() => void refreshInventory()}
                          onPublish={() => void beginPublication('publish')}
                          onUnpublish={() => void beginPublication('unpublish')}
                          onCard={() => setCardOpen(true)}
                          onCopied={setMessage}
                        />
                      )}
                      {savedMain && savedHasContent ? (
                        <div className="paper-frame">
                          <DocumentView
                            content={documentPreview(savedWorkspace, savedMain)}
                            kind="portfolio"
                            modernPortfolio
                            profilePhoto={
                              savedMain.content.profile.avatarPath ? (
                                <PrivateImage
                                  user={user}
                                  path={savedMain.content.profile.avatarPath}
                                />
                              ) : undefined
                            }
                            preview
                          />
                        </div>
                      ) : (
                        <div className="empty-state">
                          <span className="empty-state-icon">
                            <Icon name="file-text" size={32} />
                          </span>
                          <p className="empty-state-title">Портфолио пока пустое</p>
                          <p className="muted">
                            Заполните портфолио в Редакторе и нажмите «Сохранить»
                          </p>
                          <Button onClick={() => navigate('editor')}>Открыть редактор</Button>
                        </div>
                      )}
                    </section>
                  )}
                  {view === 'editor' && workingMain && (
                    <section className={`editor-layout view-enter mode-${editorMode}`}>
                      <div className="editor-column">
                        <div className="view-heading editor-heading">
                          <h1>Редактор</h1>
                          <div className="mode-switch" role="group" aria-label="Режим редактора">
                            <Button
                              variant="quiet"
                              aria-pressed={editorMode === 'form'}
                              onClick={() => setEditorMode('form')}
                            >
                              Форма
                            </Button>
                            <Button
                              variant="quiet"
                              aria-pressed={editorMode === 'preview'}
                              onClick={() => setEditorMode('preview')}
                            >
                              Предпросмотр
                            </Button>
                          </div>
                        </div>
                        <div className="editor-form">
                          <ContentEditor
                            content={workingMain.content}
                            onChange={(next) => updateDocument({ ...workingMain, content: next })}
                            photo={photo}
                            projects={
                              <AttachmentsEditor
                                workspace={content}
                                document={workingMain}
                                onChange={updateDocument}
                                onIconChange={(id, iconId) =>
                                  update({
                                    ...content,
                                    projects: content.projects.map((p) =>
                                      p.id === id ? { ...p, iconId } : p,
                                    ),
                                  })
                                }
                                onProjects={() => navigate('projects')}
                              />
                            }
                          />
                        </div>
                      </div>
                      <aside className="editor-preview" aria-label="Предпросмотр портфолио">
                        <div className="editor-preview-label">
                          <span>Предпросмотр</span>
                          <span className={`status-pill${dirty ? ' is-dirty' : ''}`}>
                            {dirty ? 'Не сохранено' : 'Совпадает с сохранённым'}
                          </span>
                        </div>
                        <div className="paper-frame">
                          {portfolioHasContent(content, workingMain) ? (
                            <DocumentView
                              content={documentPreview(content, workingMain)}
                              kind="portfolio"
                              modernPortfolio
                              profilePhoto={
                                workingMain.content.profile.avatarPath ? (
                                  <PrivateImage
                                    user={user}
                                    path={workingMain.content.profile.avatarPath}
                                  />
                                ) : undefined
                              }
                              preview
                            />
                          ) : (
                            <p className="muted editor-preview-empty">
                              Здесь появится портфолио, когда вы заполните первые поля
                            </p>
                          )}
                        </div>
                      </aside>
                    </section>
                  )}
                  {view === 'projects' && (
                    <section className="stack view-enter">
                      <div className="view-heading">
                        <h1>Проекты</h1>
                        <p className="muted">
                          Библиотека проектов. В портфолио попадают только выбранные в Редакторе
                        </p>
                      </div>
                      <div className="portfolio-actions">
                        <Button variant="secondary" onClick={() => navigate('github-import', true)}>
                          <Icon name="github" size={20} />
                          Импортировать из GitHub
                        </Button>
                        <Button
                          onClick={() => {
                            const p = emptyProject();
                            update({ ...content, projects: [...content.projects, p] });
                            navigate(`project/${p.id}`, true);
                          }}
                        >
                          <Icon name="plus" size={20} />
                          Создать проект
                        </Button>
                      </div>
                      {content.projects.length > 0 && (
                        <label className="field search-field">
                          <span className="visually-hidden">Поиск по библиотеке</span>
                          <Icon name="search" size={20} />
                          <input
                            type="search"
                            placeholder="Поиск по библиотеке"
                            value={search}
                            onChange={(e) => setSearch(e.target.value)}
                          />
                        </label>
                      )}
                      <div className="library-grid">
                        {shownProjects.map((p) => (
                          <article className="library-card" key={p.id}>
                            <div className="library-card-top">
                              <span className="library-card-icon">
                                <Icon name={p.iconId ?? 'folder'} />
                              </span>
                              <div className="project-copy">
                                <strong>{p.title || 'Без названия'}</strong>
                                {p.description && <p className="muted">{p.description}</p>}
                                <small className="source-badge">
                                  {p.source === 'github' ? 'GitHub' : 'Вручную'}
                                  {attachedIds.has(p.id) ? ' · В портфолио' : ''}
                                </small>
                              </div>
                              <Button
                                variant="quiet"
                                className="record-editor-action"
                                aria-label={`Удалить проект ${p.title}`}
                                title="Удалить проект"
                                onClick={() => void removeProject(p.id)}
                              >
                                <InlineIcon name="x" size={20} />
                              </Button>
                            </div>
                            <Button
                              variant="secondary"
                              className="library-card-edit"
                              onClick={() => navigate(`project/${p.id}`, true)}
                            >
                              Редактировать
                            </Button>
                          </article>
                        ))}
                      </div>
                      {content.projects.length === 0 && (
                        <div className="empty-state">
                          <span className="empty-state-icon">
                            <Icon name="folder" size={32} />
                          </span>
                          <p className="empty-state-title">Проектов пока нет</p>
                          <p className="muted">
                            Импортируйте репозитории из GitHub или создайте проект вручную
                          </p>
                        </div>
                      )}
                      {content.projects.length > 0 && shownProjects.length === 0 && (
                        <div className="empty-state">
                          <p className="empty-state-title">Ничего не найдено</p>
                          <p className="muted">Измените запрос поиска</p>
                        </div>
                      )}
                    </section>
                  )}
                  {view === 'github-import' && (
                    <GitHubImporter
                      ownerUid={user.uid}
                      username={content.githubUsername}
                      projects={content.projects}
                      onSettings={() => navigate('settings', true)}
                      onImport={importProjects}
                      onBack={() => navigate('projects', true)}
                    />
                  )}
                  {view.startsWith('project/') && !project && (
                    <section className="stack">
                      <h1>Проект не найден</h1>
                      <p className="muted">Возможно, он удалён на другом устройстве</p>
                      <Button variant="secondary" onClick={() => navigate('projects', true)}>
                        Назад к проектам
                      </Button>
                    </section>
                  )}
                  {view.startsWith('project/') && project && (
                    <section className="stack view-enter project-view">
                      <Button
                        variant="quiet"
                        className="back-link"
                        onClick={() => navigate('projects')}
                      >
                        <Icon name="arrow-left" size={20} />
                        Назад к проектам
                      </Button>
                      <div className="view-heading">
                        <h1>Редактор проекта</h1>
                        {project.source === 'github' && (
                          <p className="muted">Импортирован из GitHub. Ваши правки сохраняются</p>
                        )}
                      </div>
                      <div className="editor-card project-card">
                        <ProjectForm
                          project={project}
                          onChange={(next) =>
                            update({
                              ...content,
                              projects: content.projects.map((p) => (p.id === next.id ? next : p)),
                            })
                          }
                        />
                      </div>
                      <Button
                        variant="quiet"
                        className="text-danger"
                        onClick={() =>
                          void removeProject(project.id).then((removed) => {
                            if (removed) navigate('projects', true);
                          })
                        }
                      >
                        Удалить проект
                      </Button>
                    </section>
                  )}
                  {view === 'settings' && (
                    <section className="stack">
                      <h1>Настройки</h1>
                      <AccountSettings user={user} />
                      <section className="editor-group stack">
                        <h2>GitHub</h2>
                        {githubField}
                        <Button
                          variant="secondary"
                          disabled={busy}
                          onClick={() =>
                            void saveGitHub(githubInput).catch((e) => setError(errorMessage(e)))
                          }
                        >
                          Сохранить
                        </Button>
                      </section>
                      <ApplicationPreferences>
                        <Button
                          variant="secondary"
                          onClick={() => {
                            try {
                              const prefix = `stackcard.github-repositories.${encodeURIComponent(user.uid)}.`;
                              const keys = Array.from({ length: localStorage.length }, (_, i) =>
                                localStorage.key(i),
                              ).filter((key): key is string => !!key?.startsWith(prefix));
                              keys.forEach((key) => localStorage.removeItem(key));
                              setMessage('Кэш GitHub очищен. Проекты и портфолио сохранены');
                            } catch {
                              setError('Не удалось очистить кэш браузера');
                            }
                          }}
                        >
                          Очистить кэш GitHub
                        </Button>
                      </ApplicationPreferences>
                      <section className="editor-group stack">
                        <h2>Обращения и уведомления</h2>
                        <Button variant="secondary" onClick={() => navigate('inbox')}>
                          Входящие
                        </Button>
                        <p className="muted">
                          Push-уведомления в web не подключены. Входящие работают независимо от них
                        </p>
                      </section>
                      <section className="editor-group stack">
                        <h2>Помощь и о приложении</h2>
                        <LinkButton href="/help">Помощь</LinkButton>
                        <LinkButton href="/about">О StackCard</LinkButton>
                      </section>
                      <hr className="account-divider" />
                      <div className="account-bottom">
                        <span>{user.displayName || user.email}</span>
                        <Button
                          variant="quiet"
                          className="text-danger"
                          disabled={busy}
                          onClick={() => void exit()}
                        >
                          Выйти
                        </Button>
                      </div>
                    </section>
                  )}
                  {inboxView && (
                    <section className="stack">
                      <h1>Входящие</h1>
                      <Inbox
                        key={`${user.uid}:${view}`}
                        user={user}
                        requestId={view.startsWith('inbox/') ? view.slice(6) : undefined}
                        onOpen={(id) => navigate(`inbox/${id}`, true)}
                        onBack={() => navigate(view === 'inbox' ? 'settings' : 'inbox', true)}
                      />
                    </section>
                  )}
                </fieldset>
              )}
            </>
          )}
        </main>
      </div>
      {showSave && (
        <footer
          className={`workspace-footer save-bar${dirty ? ' is-dirty' : ''}`}
          inert={shareChoice}
          aria-label="Сохранение"
        >
          <span className="save-status" role="status">
            <span className="save-dot" aria-hidden="true" />
            {saving
              ? 'Сохраняем…'
              : conflict
                ? 'Конфликт версий'
                : dirty
                  ? 'Не сохранено'
                  : 'Сохранено'}
          </span>
          <div className="dialog-actions">
            <Button
              variant="secondary"
              disabled={busy || avatarBusy || !dirty}
              onClick={async () => {
                if (dirty && !(await confirmAction('Отбросить несохранённые изменения?'))) return;
                if (!owned()) return;
                void reload();
              }}
            >
              Отмена
            </Button>
            <Button
              disabled={
                busy ||
                avatarBusy ||
                loading ||
                blocked ||
                conflict ||
                (!dirty && !saveAttempt.current)
              }
              onClick={() => void save()}
            >
              {saving ? 'Сохраняем…' : 'Сохранить'}
            </Button>
          </div>
        </footer>
      )}
      {shareMenu && (
        <ShareMenu
          onClose={() => setShareMenu(false)}
          onLink={() => {
            setShareMenu(false);
            share();
          }}
          onCard={() => {
            setShareMenu(false);
            setCardOpen(true);
          }}
        />
      )}
      {cardOpen && (
        <DeveloperCardDialog
          publication={activePublication}
          onClose={() => setCardOpen(false)}
          onPublish={() => {
            afterPublish.current = 'card';
            void beginPublication('publish');
          }}
        />
      )}
      {shareChoice && (
        <div className="dialog-backdrop">
          <section
            className="dialog stack"
            role="dialog"
            aria-modal="true"
            aria-labelledby="share-title"
            ref={shareDialog}
          >
            <h2 id="share-title">Обновить публичное портфолио?</h2>
            <p>
              Сохранённая версия изменилась. Можно обновить её или отправить существующую ссылку
            </p>
            <div className="dialog-actions">
              <Button variant="secondary" onClick={() => setShareChoice(false)}>
                Отмена
              </Button>
              <Button
                variant="secondary"
                onClick={() => {
                  setShareChoice(false);
                  if (activePublication)
                    void sharePublication(activePublication).catch((e) =>
                      setError(errorMessage(e)),
                    );
                }}
              >
                Отправить существующую
              </Button>
              <Button
                onClick={() => {
                  setShareChoice(false);
                  afterPublish.current = 'share';
                  void beginPublication('publish', true);
                }}
              >
                Обновить и поделиться
              </Button>
            </div>
          </section>
        </div>
      )}
      {confirmation}
    </div>
  );
}
export function portfolioHasContent(
  workspace: WorkspaceContent,
  document: PortfolioDocument,
): boolean {
  const p = documentPreview(workspace, document);
  return Boolean(
    p.profile.name ||
    p.profile.headline ||
    p.profile.bio ||
    p.profile.locationText ||
    p.profile.avatarUrl ||
    document.content.profile.avatarPath ||
    p.skills.length ||
    p.projects.length ||
    p.experience.length ||
    p.education.length ||
    p.links.length,
  );
}

// Меню «Поделиться» как в mobile: ссылка или визитка с QR, «Отмена» последней.
function ShareMenu({
  onClose,
  onLink,
  onCard,
}: {
  onClose: () => void;
  onLink: () => void;
  onCard: () => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    const current = dialog.current;
    if (current && !current.open) current.showModal();
  }, []);
  return (
    <dialog
      ref={dialog}
      className="dialog share-menu"
      aria-labelledby="share-menu-title"
      onClose={onClose}
    >
      <div className="stack">
        <h2 id="share-menu-title">Поделиться портфолио</h2>
        <p className="muted">Отправьте публичную ссылку или покажите карточку с QR-кодом</p>
        <div className="share-menu-actions">
          <Button onClick={onLink}>Отправить ссылку</Button>
          <Button variant="secondary" onClick={onCard}>
            Визитка и QR
          </Button>
          <Button variant="quiet" onClick={() => dialog.current?.close()}>
            Отмена
          </Button>
        </div>
      </div>
    </dialog>
  );
}

// Состояние публикации сохранённой версии: ссылка, обновление и снятие.
function PublicationPanel({
  publication,
  loaded,
  error,
  outdated,
  disabled,
  onRetry,
  onPublish,
  onUnpublish,
  onCard,
  onCopied,
}: {
  publication: Publication | undefined;
  loaded: boolean;
  error: string;
  outdated: boolean;
  disabled: boolean;
  onRetry: () => void;
  onPublish: () => void;
  onUnpublish: () => void;
  onCard: () => void;
  onCopied: (message: string) => void;
}) {
  const published = publication?.state === 'published' && !!publication.url;
  if (!loaded)
    return (
      <section className="publication-panel" aria-label="Публикация">
        {error ? (
          <>
            <p className="publication-title">Не удалось проверить публикацию</p>
            <p className="muted">{error}</p>
            <Button variant="secondary" onClick={onRetry}>
              Повторить проверку
            </Button>
          </>
        ) : (
          <p className="muted" role="status">
            Проверяем публикацию…
          </p>
        )}
      </section>
    );
  return (
    <section
      className={`publication-panel${published ? ' is-published' : ''}`}
      aria-label="Публикация"
    >
      <div className="publication-head">
        <span className="publication-dot" aria-hidden="true" />
        <p className="publication-title">
          {published
            ? 'Опубликовано'
            : publication?.state === 'unpublished'
              ? 'Публикация снята'
              : 'Не опубликовано'}
        </p>
      </div>
      {published ? (
        <>
          <a
            className="publication-link"
            href={publication!.url!}
            target="_blank"
            rel="noopener noreferrer"
          >
            {publication!.url}
          </a>
          {outdated && (
            <p className="muted">
              Есть более новая сохранённая версия. Публичная страница обновится только после
              публикации
            </p>
          )}
          <div className="publication-actions">
            <Button
              variant="secondary"
              onClick={() =>
                void navigator.clipboard
                  ?.writeText(publication!.url!)
                  .then(() => onCopied('Ссылка скопирована'))
                  .catch(() => onCopied('Скопируйте ссылку вручную'))
              }
            >
              <InlineIcon name="copy" size={20} />
              Копировать
            </Button>
            <Button variant="secondary" onClick={onCard}>
              Визитка и QR
            </Button>
            {outdated && (
              <Button disabled={disabled} onClick={onPublish}>
                Обновить публикацию
              </Button>
            )}
            <Button
              variant="quiet"
              className="text-danger"
              disabled={disabled}
              onClick={onUnpublish}
            >
              Снять с публикации
            </Button>
          </div>
        </>
      ) : (
        <>
          <p className="muted">
            Публикация сделает сохранённую версию доступной всем, у кого есть ссылка
          </p>
          <div className="publication-actions">
            <Button disabled={disabled} onClick={onPublish}>
              Опубликовать
            </Button>
          </div>
        </>
      )}
    </section>
  );
}
