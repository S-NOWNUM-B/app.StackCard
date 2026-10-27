'use client';
import { useEffect, useId, useRef, useState, type ReactNode } from 'react';
import { Button, Field, Icon, Notice } from './ui';
import { TagEditor } from './tag-editor';
import { RecordEditor, type RecordField } from './record-editor';
import { EditorCard } from './editor-card';
import { InlineIcon, contactIcon } from './inline-icon';
import { moveItem, SortableList } from './sortable-list';
import {
  uid,
  linkKinds,
  mainPortfolioSectionOrder,
  safeContactUrl,
  type DocumentContent,
  type Profile,
  type Contact,
  type Skill,
  type Experience,
  type Education,
  type MainPortfolioSectionKind,
} from '@/lib/model';
export const contactLabels: Record<Contact['kind'], string> = {
  other: 'Другая ссылка',
  github: 'GitHub',
  website: 'Сайт',
  linkedin: 'LinkedIn',
  email: 'Почта',
  phone: 'Телефон',
  telegram: 'Telegram',
};
// Порядок выбора типа как в mobile: сначала ссылки, затем прямые контакты.
const contactKindOrder: Contact['kind'][] = [
  'website',
  'github',
  'linkedin',
  'other',
  'email',
  'phone',
  'telegram',
].filter((kind): kind is Contact['kind'] => linkKinds.includes(kind as Contact['kind']));
const contactHints: Record<Contact['kind'], string> = {
  other: 'https://…',
  github: 'https://github.com/username',
  website: 'https://example.com',
  linkedin: 'https://www.linkedin.com/in/username',
  email: 'name@example.com',
  phone: '+77001234567',
  telegram: '@username или https://t.me/username',
};
const contactErrors: Record<Contact['kind'], string> = {
  other: 'Введите ссылку, которая начинается с https:// или http://',
  github: 'Введите ссылку, которая начинается с https:// или http://',
  website: 'Введите ссылку, которая начинается с https:// или http://',
  linkedin: 'Введите ссылку, которая начинается с https:// или http://',
  email: 'Введите адрес почты, например name@example.com',
  phone: 'Введите номер в международном формате, например +77001234567',
  telegram: 'Введите @username или ссылку https://t.me/username',
};
// Как mobile: почта и телефон получают схему, Telegram @username — ссылку t.me.
export function normalizeContactUrl(value: string, kind: Contact['kind']): string {
  let result = value.trim();
  if (kind === 'email' && result && !result.startsWith('mailto:')) result = `mailto:${result}`;
  else if (kind === 'phone' && result) {
    result = result.replace(/[\s()-]/g, '');
    if (!result.startsWith('tel:')) result = `tel:${result}`;
  } else if (kind === 'telegram' && result.startsWith('@'))
    result = `https://t.me/${result.slice(1)}`;
  return result;
}
// Видимое значение без служебной схемы: в форме редактируется привычный адрес.
const contactInput = (contact: Contact) =>
  contact.kind === 'email'
    ? contact.url.replace(/^mailto:/, '')
    : contact.kind === 'phone'
      ? contact.url.replace(/^tel:/, '')
      : contact.url;
export function saveContact(
  items: Contact[],
  previous: Contact | null,
  draft: { label: string; kind: Contact['kind']; url: string },
): Contact[] {
  const label = draft.label.trim(),
    url = normalizeContactUrl(draft.url, draft.kind);
  if (!label) throw new Error('Заполните «Название ссылки»');
  if (label.length > 80) throw new Error('«Название ссылки»: максимум 80 символов');
  if (!url) throw new Error('Заполните «Адрес»');
  if (url.length > 2048 || !safeContactUrl(url, draft.kind))
    throw new Error(contactErrors[draft.kind]);
  const next: Contact = {
    id: previous?.id ?? uid(),
    label,
    url,
    kind: draft.kind,
    publishAllowed: true,
    visible: true,
  };
  if (!previous) return [...items, next];
  if (!items.some((item) => item.id === previous.id))
    throw new Error('Контакт изменился. Откройте его снова');
  return items.map((item) => (item.id === previous.id ? next : item));
}

function ContactsEditor({
  id,
  items,
  onChange,
}: {
  id: string;
  items: Contact[];
  onChange: (items: Contact[]) => void;
}) {
  const dialog = useRef<HTMLDialogElement>(null),
    previous = useRef<Contact | null>(null),
    titleId = useId(),
    errorId = useId();
  const [draft, setDraft] = useState<{
      label: string;
      kind: Contact['kind'];
      url: string;
    } | null>(null),
    [error, setError] = useState(''),
    // Каждое открытие — новая сессия: close event асинхронный и не должен блокировать повтор.
    [session, setSession] = useState(0);
  function open(item: Contact | null) {
    // Состояние диалога задаётся только при открытии: асинхронный close event не сбрасывает новое.
    previous.current = item;
    setSession((value) => value + 1);
    setError('');
    setDraft(
      item
        ? { label: item.label, kind: item.kind, url: contactInput(item) }
        : { label: '', kind: 'website', url: '' },
    );
  }
  useEffect(() => {
    const current = dialog.current;
    if (!draft || !current) return;
    if (!current.open) current.showModal();
    current.querySelector<HTMLInputElement>('input')?.focus();
  }, [session]);
  function save() {
    if (!draft) return;
    try {
      onChange(saveContact(items, previous.current, draft));
      dialog.current?.close();
    } catch (failure) {
      setError(failure instanceof Error ? failure.message : 'Не удалось сохранить');
    }
  }
  return (
    <EditorCard
      id={id}
      title="Контакты и ссылки"
      count={items.length}
      action={
        <Button
          variant="quiet"
          className="tag-editor-action"
          aria-label="Добавить контакт или ссылку"
          title="Добавить контакт или ссылку"
          onClick={() => open(null)}
        >
          <Icon name="plus" />
        </Button>
      }
    >
      {items.length > 0 ? (
        <SortableList
          className="contact-editor-list"
          label="Контакты и ссылки"
          items={items}
          itemKey={(item) => item.id}
          itemLabel={(item) => item.label || contactLabels[item.kind]}
          onMove={(from, to) => onChange(moveItem(items, from, to))}
          renderItem={(item) => (
            <div className="record-editor-item">
              <Button
                variant="quiet"
                className="record-editor-summary contact-summary"
                aria-label={`Редактировать контакт ${item.label}`}
                title="Редактировать контакт"
                onClick={() => open(item)}
              >
                <span className="contact-glyph">
                  <InlineIcon name={contactIcon[item.kind]} size={20} />
                </span>
                <span className="record-editor-copy">
                  <strong>{item.label || 'Без названия'}</strong>
                  <small className="muted">
                    {contactLabels[item.kind]} · {contactInput(item)}
                  </small>
                </span>
              </Button>
              <Button
                variant="quiet"
                className="record-editor-action"
                aria-label={`Удалить контакт ${item.label}`}
                title={`Удалить контакт ${item.label}`}
                onClick={() => onChange(items.filter((v) => v.id !== item.id))}
              >
                <InlineIcon name="x" size={20} />
              </Button>
            </div>
          )}
        />
      ) : (
        <p className="editor-empty muted">Пока пусто. Нажмите «+», чтобы добавить</p>
      )}
      <dialog ref={dialog} className="dialog contact-editor-dialog" aria-labelledby={titleId}>
        <form
          className="stack"
          onSubmit={(event) => {
            event.preventDefault();
            save();
          }}
        >
          <h2 id={titleId}>
            {previous.current ? 'Редактировать контакт' : 'Добавить контакт или ссылку'}
          </h2>
          {draft && (
            <>
              <Field
                label="Название ссылки"
                value={draft.label}
                maxLength={80}
                required
                aria-describedby={error ? errorId : undefined}
                onChange={(event) => {
                  setDraft({ ...draft, label: event.target.value });
                  setError('');
                }}
              />
              <label className="field">
                <span>Тип ссылки</span>
                <select
                  value={draft.kind}
                  onChange={(event) => {
                    setDraft({ ...draft, kind: event.target.value as Contact['kind'] });
                    setError('');
                  }}
                >
                  {contactKindOrder.map((kind) => (
                    <option key={kind} value={kind}>
                      {contactLabels[kind]}
                    </option>
                  ))}
                </select>
              </label>
              <Field
                label="Адрес"
                value={draft.url}
                maxLength={2048}
                required
                inputMode={
                  draft.kind === 'email' ? 'email' : draft.kind === 'phone' ? 'tel' : 'url'
                }
                autoComplete="off"
                placeholder={contactHints[draft.kind]}
                aria-invalid={error ? true : undefined}
                aria-describedby={error ? errorId : undefined}
                onChange={(event) => {
                  setDraft({ ...draft, url: event.target.value });
                  setError('');
                }}
              />
            </>
          )}
          {error && (
            <div id={errorId}>
              <Notice error>{error}</Notice>
            </div>
          )}
          <div className="dialog-actions">
            <Button variant="secondary" onClick={() => dialog.current?.close()}>
              Отмена
            </Button>
            <Button type="submit">Сохранить</Button>
          </div>
        </form>
      </dialog>
    </EditorCard>
  );
}
export function appendPortfolioSkill(items: Skill[], input: string): Skill[] {
  const name = input.trim();
  if (!name) throw new Error('Введите название');
  if (name.length > 60) throw new Error('Максимум 60 символов');
  if (items.some((item) => item.name.trim().toLowerCase() === name.toLowerCase()))
    throw new Error('Навык уже добавлен');
  return [...items, { id: uid(), name }];
}
export const experienceFields: RecordField<Experience>[] = [
  { key: 'role', label: 'Должность', maxLength: 120, required: true },
  { key: 'organization', label: 'Организация', maxLength: 160, required: true },
  { key: 'period', label: 'Период', maxLength: 120 },
  { key: 'description', label: 'Описание', maxLength: 4000, textarea: true },
];
export const educationFields: RecordField<Education>[] = [
  { key: 'institution', label: 'Учебное заведение', maxLength: 160, required: true },
  { key: 'qualification', label: 'Квалификация', maxLength: 160, required: true },
  { key: 'period', label: 'Период', maxLength: 120 },
  { key: 'description', label: 'Описание', maxLength: 4000, textarea: true },
];
export const sectionTitles: Record<MainPortfolioSectionKind, string> = {
  links: 'Контакты и ссылки',
  skills: 'Навыки',
  featuredProjects: 'Реализованные проекты',
  experience: 'Опыт работы',
  education: 'Образование',
};
export const editorSectionId = (kind: MainPortfolioSectionKind | 'profile') =>
  `editor-section-${kind}`;

// Липкое оглавление: кнопки прокручивают к разделу без изменения hash кабинета.
function SectionIndex({ sections }: { sections: { id: string; label: string }[] }) {
  const [active, setActive] = useState(sections[0]?.id ?? '');
  const nav = useRef<HTMLElement>(null);
  useEffect(() => {
    // Активная кнопка остаётся видимой в горизонтальном оглавлении на узком экране.
    const button = nav.current?.querySelector<HTMLElement>('[aria-current="true"]');
    if (nav.current && button)
      nav.current.scrollTo({ left: Math.max(0, button.offsetLeft - 16), behavior: 'auto' });
  }, [active]);
  useEffect(() => {
    // Активен последний раздел, верх которого уже прошёл под липким оглавлением.
    let frame = 0;
    const update = () => {
      frame = 0;
      let current = sections[0]?.id ?? '';
      for (const section of sections) {
        const element = document.getElementById(section.id);
        if (element && element.getBoundingClientRect().top <= 180) current = section.id;
      }
      setActive(current);
    };
    const schedule = () => {
      if (!frame) frame = requestAnimationFrame(update);
    };
    update();
    window.addEventListener('scroll', schedule, { passive: true });
    window.addEventListener('resize', schedule);
    return () => {
      if (frame) cancelAnimationFrame(frame);
      window.removeEventListener('scroll', schedule);
      window.removeEventListener('resize', schedule);
    };
  }, [sections.map((section) => section.id).join()]);
  return (
    <nav ref={nav} className="editor-index" aria-label="Разделы редактора">
      {sections.map((section) => (
        <button
          key={section.id}
          type="button"
          className="editor-index-link"
          aria-current={active === section.id ? 'true' : undefined}
          onClick={() => {
            const element = document.getElementById(section.id);
            if (!element) return;
            const reduce =
              !!element.closest('[data-reduced-motion="true"]') ||
              window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
            element.scrollIntoView({ behavior: reduce ? 'auto' : 'smooth', block: 'start' });
            setActive(section.id);
          }}
        >
          {section.label}
        </button>
      ))}
    </nav>
  );
}

export function ContentEditor({
  content,
  onChange,
  photo,
  projects,
}: {
  content: DocumentContent;
  onChange: (content: DocumentContent) => void;
  photo?: ReactNode;
  projects?: ReactNode;
}) {
  const patch = (p: Partial<DocumentContent>) => onChange({ ...content, ...p });
  const profile = (p: Partial<Profile>) => patch({ profile: { ...content.profile, ...p } });
  // Порядок разделов — из сохранённого blocks, как в mobile; перестановки разделов нет.
  const order = mainPortfolioSectionOrder(content).filter(
    (kind) => kind !== 'featuredProjects' || projects,
  );
  const sections: Record<MainPortfolioSectionKind, ReactNode> = {
    links: (
      <ContactsEditor
        id={editorSectionId('links')}
        items={content.links}
        onChange={(links) => patch({ links })}
      />
    ),
    skills: (
      <TagEditor
        card={{ id: editorSectionId('skills'), title: 'Навыки' }}
        title="Навык"
        addLabel="Добавить навык"
        removeLabel="Удалить навык"
        listLabel="Навыки портфолио"
        items={content.skills}
        onAdd={(name) => patch({ skills: appendPortfolioSkill(content.skills, name) })}
        onRemove={(index) =>
          patch({ skills: content.skills.filter((_, position) => position !== index) })
        }
        onMove={(from, to) => patch({ skills: moveItem(content.skills, from, to) })}
      />
    ),
    featuredProjects: projects,
    experience: (
      <RecordEditor
        id={editorSectionId('experience')}
        title="Опыт работы"
        addLabel="Добавить опыт"
        editLabel="Редактировать опыт"
        removeLabel="Удалить опыт"
        items={content.experience}
        fields={experienceFields}
        create={() => ({ id: uid(), role: '', organization: '', period: '', description: '' })}
        summary={(item) => ({
          title: item.role,
          detail: [item.organization, item.period].filter(Boolean).join(' · '),
        })}
        onChange={(experience) => patch({ experience })}
        onMove={(from, to) => patch({ experience: moveItem(content.experience, from, to) })}
      />
    ),
    education: (
      <RecordEditor
        id={editorSectionId('education')}
        title="Образование"
        addLabel="Добавить образование"
        editLabel="Редактировать образование"
        removeLabel="Удалить образование"
        items={content.education}
        fields={educationFields}
        create={() => ({
          id: uid(),
          institution: '',
          qualification: '',
          period: '',
          description: '',
        })}
        summary={(item) => ({
          title: item.qualification,
          detail: [item.institution, item.period].filter(Boolean).join(' · '),
        })}
        onChange={(education) => patch({ education })}
        onMove={(from, to) => patch({ education: moveItem(content.education, from, to) })}
      />
    ),
  };
  return (
    <div className="stack portfolio-editor">
      <SectionIndex
        sections={[
          { id: editorSectionId('profile'), label: 'Профиль' },
          ...order.map((kind) => ({ id: editorSectionId(kind), label: sectionTitles[kind] })),
        ]}
      />
      <EditorCard id={editorSectionId('profile')} title="Профиль">
        {photo}
        <div className="editor-fields">
          <Field
            label="Имя"
            value={content.profile.name}
            maxLength={100}
            autoComplete="name"
            onChange={(e) => profile({ name: e.target.value })}
          />
          <Field
            label="Должность"
            value={content.profile.headline}
            maxLength={160}
            autoComplete="organization-title"
            onChange={(e) => profile({ headline: e.target.value })}
          />
          <Field
            label="Город / страна"
            value={content.profile.locationText}
            maxLength={200}
            onChange={(e) => profile({ locationText: e.target.value, publishLocation: true })}
          />
        </div>
        <Field
          label="О себе"
          textarea
          value={content.profile.bio}
          maxLength={4000}
          helper={`${content.profile.bio.length} / 4000`}
          onChange={(e) => profile({ bio: e.target.value })}
        />
      </EditorCard>
      {order.map((kind) => (
        <div className="editor-slot" key={kind}>
          {sections[kind]}
        </div>
      ))}
      {content.resumeText && (
        <EditorCard title="Дополнительно">
          <Field
            label="Дополнительный текст"
            textarea
            value={content.resumeText}
            maxLength={20000}
            onChange={(e) => patch({ resumeText: e.target.value })}
          />
        </EditorCard>
      )}
    </div>
  );
}
