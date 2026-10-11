'use client';
import { signOut, type User } from 'firebase/auth';
import { useRouter } from 'next/navigation';
import { useEffect, useRef, useState } from 'react';
import { useSession } from './auth-session';
import { Button, Field, Header, Icon, LinkButton, Notice } from './ui';
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
  type Project,
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
const errorMessage = (error: unknown) =>
  error instanceof Error ? error.message : 'Действие не завершено. Повторите попытку.';
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
  const { confirm, confirmation } = useConfirmation();
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
    [avatarBusy, setAvatarBusy] = useState(false);
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
  const scopedAttempt = useRef<{
    mutationId: string;
    basis: DraftEnvelope | null;
    previous: WorkspaceContent;
    content: WorkspaceContent;
    notes: string;
  } | null>(null);
  const input = useRef({ content, notes, githubInput });
  input.current = { content, notes, githubInput };
  const activeUid = useRef(user.uid),
    shareAfter = useRef(false);
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
    return accepted && owned() && equal(captured, confirmationContext.current);
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
        saved = await saveDraft(
          user,
          saved,
          attempt.content,
          saved?.notes ?? '',
          attempt.mutationId,
        );
        if (!currentRead()) return;
      }
      initializationAttempt.current = null;
      setBasis(saved);
      setContent(saved.content ?? emptyContent());
      setGitHubInput(saved.content?.githubUsername ?? '');
      setNotes(saved.notes);
      saveAttempt.current = null;
      scopedAttempt.current = null;
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
    try {
      setPending(readPublicationReceipt(localStorage, operationKey));
      const hash = decodeURIComponent(window.location.hash.slice(1));
      if (hash) setView(ownerView(hash));
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
      const next = ownerView(decodeURIComponent(window.location.hash.slice(1)));
      if (busy || avatarBusy) {
        window.history.replaceState(null, '', `/workspace#${view}`);
        return;
      }
      const accepted =
        !dirtyRef.current ||
        (await confirmAction('Есть несохранённые изменения. Отбросить их и перейти?'));
      if (version !== navigationVersion || !owned()) return;
      if (!accepted) {
        window.history.replaceState(null, '', `/workspace#${view}`);
        return;
      }
      if (dirtyRef.current) {
        setContent(clone(basis?.content ?? emptyContent()));
        setGitHubInput(basis?.content?.githubUsername ?? '');
        setNotes(basis?.notes ?? '');
        saveAttempt.current = null;
      }
      setView(next);
    }
    window.addEventListener('popstate', history);
    return () => {
      navigationVersion++;
      window.removeEventListener('popstate', history);
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
    if (
      !preserve &&
      dirty &&
      !(await confirmAction('Есть несохранённые изменения. Отбросить их и перейти?'))
    )
      return;
    if (!owned()) return;
    if (!preserve && dirty) {
      setContent(clone(basis?.content ?? emptyContent()));
      setGitHubInput(basis?.content?.githubUsername ?? '');
      setNotes(basis?.notes ?? '');
      saveAttempt.current = null;
    }
    setView(next);
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
      throw new Error('Дождитесь завершения предыдущего действия.');
    setBusy(true);
    setError('');
    try {
      let attempt = scopedAttempt.current;
      if (attempt && !equal(next, attempt.content))
        throw new Error('Сначала подтвердите незавершённое изменение библиотеки кнопкой выше.');
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
      const saved = await saveDraft(
        user,
        attempt.basis,
        attempt.content,
        attempt.notes,
        attempt.mutationId,
      );
      if (!owned()) return;
      setBasis(saved);
      setContent((working) => rebaseLibraryChange(saved.content!, attempt.previous, working));
      setGitHubInput((current) =>
        canonicalGitHub(current) === attempt.previous.githubUsername
          ? saved.content!.githubUsername
          : current,
      );
      scopedAttempt.current = null;
      setMessage('Изменения библиотеки сохранены. Публичная версия не изменилась.');
    } finally {
      if (owned()) setBusy(false);
    }
  }
  async function save() {
    if (blocked || busy || avatarBusy || !owned()) return;
    if (scopedAttempt.current) {
      setError('Сначала подтвердите незавершённое изменение библиотеки кнопкой выше.');
      return;
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
          content: clone(
            validateWorkspace(
              { ...content, githubUsername: normalizeGitHubUsername(githubInput) },
              user.uid,
            ),
          ),
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
        !equal(
          { ...input.current.content, githubUsername: canonicalGitHub(input.current.githubInput) },
          attempt.content,
        ) ||
        input.current.notes !== attempt.notes ||
        canonicalGitHub(input.current.githubInput) !== attempt.content.githubUsername;
      setBasis(saved);
      setContent((current) =>
        equal(
          { ...current, githubUsername: canonicalGitHub(input.current.githubInput) },
          attempt.content,
        )
          ? (saved.content ?? emptyContent())
          : current,
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
    if (shareAfter.current && result.publication?.state === 'published') {
      shareAfter.current = false;
      await sharePublication(result.publication);
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
  async function beginPublication(action: PendingOperation['action'], confirmed = false) {
    if (!activeDocument || !basis || !publications || pending || receiptError || busy) {
      shareAfter.current = false;
      return;
    }
    const p = activePublication;
    if (
      action === 'publish' &&
      !confirmed &&
      !(await confirmAction(
        'Опубликовать текущую сохранённую версию? Введённые контакты и фотография станут доступны по постоянной ссылке.',
        'Опубликовать портфолио?',
      ))
    ) {
      shareAfter.current = false;
      return;
    }
    if (
      action === 'unpublish' &&
      !(await confirmAction(
        'Снять документ с публикации? Постоянный адрес сохранится, содержимое станет недоступно.',
        'Снять с публикации?',
      ))
    )
      return;
    if (
      action === 'deleteDocument' &&
      !(await confirmAction(
        'Удалить документ и отозвать его публичную страницу? Это действие нельзя отменить.',
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
      throw new Error('Нет подтверждённой публичной ссылки.');
    if (!owned()) return;
    try {
      if (navigator.share) {
        await navigator.share({ title: 'Портфолио', url: publication.url });
        if (owned()) setMessage('Ссылка отправлена.');
      } else {
        await navigator.clipboard.writeText(publication.url);
        if (owned()) setMessage('Ссылка скопирована.');
      }
    } catch (e) {
      if (e instanceof Error && e.name === 'AbortError') return;
      if (owned()) {
        setManualShareUrl(publication.url);
        setMessage('Скопируйте постоянную ссылку ниже.');
      }
    }
  }
  function share() {
    shareAfter.current = false;
    setError('');
    if (!basis || !savedMain) {
      setError('Сначала сохраните портфолио.');
      return;
    }
    if (!publications) {
      setError(publicationError || 'Не удалось проверить публичную версию. Повторите проверку.');
      void refreshInventory();
      return;
    }
    if (pending || receiptError) {
      setError('Сначала восстановите незавершённую операцию публикации.');
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
    shareAfter.current = true;
    beginPublication('publish');
  }
  async function download() {
    if (busy || !savedMain || !owned()) return;
    setBusy(true);
    setError('');
    try {
      const captured = resolveDocument(savedWorkspace, savedMain),
        owner = user.uid;
      const avatarBytes = captured.profile.avatarPath
        ? await readAvatarBytes(user, captured.profile.avatarPath)
        : captured.profile.avatarUrl
          ? await readLegacyAvatarBytes(user, captured.profile.avatarUrl)
          : undefined;
      if (!owned() || owner !== user.uid) return;
      const { generatePortfolioPdf } = await import('@/lib/portfolio-pdf');
      const blob = await generatePortfolioPdf(captured, { avatarBytes });
      if (!owned()) return;
      const url = URL.createObjectURL(blob),
        link = document.createElement('a');
      link.href = url;
      link.download = 'StackCard-portfolio.pdf';
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 30000);
      setMessage('PDF подготовлен для скачивания.');
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
      const migrated = migrateMainPortfolio(content, migrationChoice);
      const saved = await saveDraft(user, basis, migrated, notes, `web-migrate-${uid()}`);
      if (!owned()) return;
      setBasis(saved);
      setContent(saved.content!);
      setMigrationPreview(false);
      setMessage(
        'Основное портфолио сохранено. Прежние данные сохранены для восстановления; публикация не изменилась.',
      );
    } catch (e) {
      if (owned()) setError(errorMessage(e));
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
      const saved = await saveDraft(
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
      if (owned())
        setError(
          errorMessage(e) +
            (saveAttempt.current ? ' Повторное действие подтвердит предыдущий шаг.' : ''),
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
  async function removeProject(id: string) {
    if (
      !(await confirmAction(
        'Удалить проект из StackCard и убрать из портфолио? Репозиторий GitHub сохранится. Если проект опубликован, обновите публичную версию отдельно.',
        'Удалить проект?',
      ))
    )
      return;
    if (!savedWorkspace.projects.some((p) => p.id === id)) {
      update(deleteLibraryProject(content, id));
      return;
    }
    try {
      await commitScoped(deleteLibraryProject(savedWorkspace, id));
    } catch (e) {
      if (owned()) setError(errorMessage(e));
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
      onChange={(e) => {
        setGitHubInput(e.target.value);
        try {
          update({ ...content, githubUsername: normalizeGitHubUsername(e.target.value) });
        } catch {
          /* Не завершённый URL не заменяет сохранённый источник. */
        }
      }}
    />
  );
  const previewCandidate =
    migrationNeeded && migrationPreview ? migrateMainPortfolio(content, migrationChoice) : null;
  const showSave =
    !onboarding &&
    !migrationNeeded &&
    !inboxView &&
    (view === 'editor' || view === 'projects' || view.startsWith('project/'));
  return (
    <div className="workspace single-portfolio-workspace">
      <Header
        context="workspace"
        actions={
          <Button
            className="workspace-settings-access"
            variant="quiet"
            aria-label="Настройки"
            aria-current={view === 'settings' ? 'page' : undefined}
            disabled={busy || avatarBusy}
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
            <Notice>Загружаем сохранённую версию…</Notice>
          ) : blocked ? (
            <>
              <p>Не удалось прочитать совместимые данные. Введённые данные не заменены.</p>
              <Button onClick={() => void reload()}>Повторить чтение</Button>
            </>
          ) : (
            <>
              {scopedAttempt.current && (
                <section className="stack">
                  <Notice>Нужно подтвердить результат предыдущего изменения библиотеки.</Notice>
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
              {migrationNeeded ? (
                <section className="stack">
                  <h1>Выберите основу портфолио</h1>
                  <p className="muted">
                    Перенесём один источник без смешивания текстов. Прежние данные и постоянные
                    ссылки сохранятся.
                  </p>
                  <label className="project-row">
                    <input
                      type="radio"
                      name="migration"
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
                  <Button disabled={busy || !migrationPreview} onClick={() => void migrate()}>
                    Использовать выбранную основу
                  </Button>
                </section>
              ) : onboarding && workingMain ? (
                <section className="stack personalization">
                  <p className="muted">Шаг {content.personalization.step + 1} из 4</p>
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
                    </>
                  ) : content.personalization.step === 2 ? (
                    <>
                      <Field
                        label="Краткое описание"
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
                    <section className="stack portfolio-home">
                      <div className="portfolio-actions">
                        <Button disabled={busy || !savedMain} onClick={() => void download()}>
                          Скачать портфолио
                        </Button>
                        <Button variant="secondary" disabled={busy || !savedMain} onClick={share}>
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
                      {publicationError && <Notice error>{publicationError}</Notice>}
                      {savedMain && (
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
                      )}
                      {savedMain && !portfolioHasContent(savedWorkspace, savedMain) && (
                        <div className="empty-portfolio">
                          <p>Портфолио пока пустое</p>
                          <p className="muted">Откройте вкладку «Редактор», чтобы заполнить его.</p>
                        </div>
                      )}
                    </section>
                  )}
                  {view === 'editor' && workingMain && (
                    <>
                      <h1>Редактор</h1>
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
                        github={githubField}
                      />
                    </>
                  )}
                  {view === 'projects' && (
                    <section className="stack">
                      <h1>Проекты</h1>
                      <div className="row">
                        <Button variant="secondary" onClick={() => navigate('github-import', true)}>
                          Импортировать из GitHub
                        </Button>
                        <Button
                          onClick={() => {
                            const p = emptyProject();
                            update({ ...content, projects: [...content.projects, p] });
                            navigate(`project/${p.id}`, true);
                          }}
                        >
                          Создать проект
                        </Button>
                      </div>
                      <Field
                        label="Поиск по библиотеке"
                        type="search"
                        value={search}
                        onChange={(e) => setSearch(e.target.value)}
                      />
                      {content.projects
                        .filter((p) =>
                          `${p.title} ${p.description}`
                            .toLowerCase()
                            .includes(search.toLowerCase()),
                        )
                        .map((p) => (
                          <article className="project-row library-project" key={p.id}>
                            <Icon name={p.iconId ?? 'folder'} />
                            <div className="project-copy">
                              <strong>{p.title}</strong>
                              {p.description && <p>{p.description}</p>}
                            </div>
                            <div className="project-actions">
                              <Button
                                variant="quiet"
                                onClick={() => navigate(`project/${p.id}`, true)}
                              >
                                Редактировать
                              </Button>
                              <Button
                                variant="quiet"
                                className="text-danger"
                                onClick={() => void removeProject(p.id)}
                              >
                                Удалить
                              </Button>
                            </div>
                          </article>
                        ))}
                      {content.projects.length === 0 && <p>Проектов пока нет</p>}
                      {content.projects.length > 0 &&
                        !content.projects.some((p) =>
                          `${p.title} ${p.description}`
                            .toLowerCase()
                            .includes(search.toLowerCase()),
                        ) && <p>Ничего не найдено</p>}
                    </section>
                  )}
                  {view === 'github-import' && (
                    <GitHubImporter
                      ownerUid={user.uid}
                      username={content.githubUsername}
                      projects={content.projects}
                      onUsername={saveGitHub}
                      onImport={importProjects}
                      onBack={() => navigate('projects', true)}
                    />
                  )}
                  {view.startsWith('project/') && project && (
                    <section className="stack">
                      <Button variant="quiet" onClick={() => navigate('projects')}>
                        Назад к проектам
                      </Button>
                      <h1>Редактор проекта</h1>
                      <ProjectForm
                        project={project}
                        onChange={(next) =>
                          update({
                            ...content,
                            projects: content.projects.map((p) => (p.id === next.id ? next : p)),
                          })
                        }
                      />
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
                              setMessage('Кэш GitHub очищен. Проекты и портфолио сохранены.');
                            } catch {
                              setError('Не удалось очистить кэш браузера.');
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
                          Push-уведомления в web не подключены. Входящие работают независимо от них.
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
        <footer className="workspace-footer" inert={shareChoice}>
          <small className="muted">{dirty ? 'Есть несохранённые изменения' : 'Сохранено'}</small>
          <div className="dialog-actions">
            <Button
              variant="secondary"
              disabled={busy || avatarBusy}
              onClick={async () => {
                if (dirty && !(await confirmAction('Отбросить несохранённые изменения?'))) return;
                if (!owned()) return;
                void reload();
              }}
            >
              Отмена
            </Button>
            <Button disabled={busy || avatarBusy || loading || blocked} onClick={() => void save()}>
              {saving ? 'Сохраняем…' : 'Сохранить'}
            </Button>
          </div>
        </footer>
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
              Сохранённая версия изменилась. Можно обновить её или отправить существующую ссылку.
            </p>
            <div className="dialog-actions">
              <Button variant="secondary" onClick={() => setShareChoice(false)}>
                Отмена
              </Button>
              <Button
                variant="secondary"
                onClick={() => {
                  setShareChoice(false);
                  if (activePublication) void sharePublication(activePublication);
                }}
              >
                Отправить существующую
              </Button>
              <Button
                onClick={() => {
                  setShareChoice(false);
                  shareAfter.current = true;
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
