'use client';
import type { ReactNode } from 'react';
import { Button, Field } from './ui';
import { TagEditor } from './tag-editor';
import {
  uid,
  linkKinds,
  type DocumentContent,
  type Profile,
  type Contact,
  type Skill,
} from '@/lib/model';
const contactLabels: Record<Contact['kind'], string> = {
  other: 'Другая ссылка',
  github: 'GitHub',
  website: 'Сайт',
  linkedin: 'LinkedIn',
  email: 'Почта',
  phone: 'Телефон',
  telegram: 'Telegram',
};
export function appendPortfolioSkill(items: Skill[], input: string): Skill[] {
  const name = input.trim();
  if (!name) throw new Error('Введите название.');
  if (name.length > 60) throw new Error('Максимум 60 символов.');
  if (items.some((item) => item.name.trim().toLowerCase() === name.toLowerCase()))
    throw new Error('Навык уже добавлен.');
  return [...items, { id: uid(), name }];
}
export function ContentEditor({
  content,
  onChange,
  photo,
  projects,
  github,
}: {
  content: DocumentContent;
  onChange: (content: DocumentContent) => void;
  photo?: ReactNode;
  projects?: ReactNode;
  github?: ReactNode;
}) {
  const patch = (p: Partial<DocumentContent>) => onChange({ ...content, ...p });
  const profile = (p: Partial<Profile>) => patch({ profile: { ...content.profile, ...p } });
  return (
    <div className="stack portfolio-editor">
      <section className="editor-group stack">
        {photo}
        <Field
          label="Имя"
          value={content.profile.name}
          maxLength={100}
          onChange={(e) => profile({ name: e.target.value })}
        />
        <Field
          label="Должность"
          value={content.profile.headline}
          maxLength={160}
          onChange={(e) => profile({ headline: e.target.value })}
        />
        <Field
          label="Описание"
          textarea
          value={content.profile.bio}
          maxLength={4000}
          onChange={(e) => profile({ bio: e.target.value })}
        />
        <Field
          label="Город / страна"
          value={content.profile.locationText}
          maxLength={200}
          onChange={(e) => profile({ locationText: e.target.value, publishLocation: true })}
        />
      </section>
      <section className="editor-group stack">
        <h2>Контакты и ссылки</h2>
        {content.links.map((l) => (
          <div key={l.id} className="entry-editor stack">
            <Field
              label="Название"
              value={l.label}
              maxLength={80}
              required
              onChange={(e) =>
                patch({
                  links: content.links.map((v) =>
                    v.id === l.id ? { ...v, label: e.target.value } : v,
                  ),
                })
              }
            />
            <label className="field">
              <span>Тип контакта</span>
              <select
                value={l.kind}
                onChange={(e) =>
                  patch({
                    links: content.links.map((v) =>
                      v.id === l.id ? { ...v, kind: e.target.value as Contact['kind'] } : v,
                    ),
                  })
                }
              >
                {linkKinds.map((k) => (
                  <option key={k} value={k}>
                    {contactLabels[k]}
                  </option>
                ))}
              </select>
            </label>
            <Field
              label="Адрес"
              value={l.url}
              maxLength={2048}
              required
              helper="https://… · mailto:… · tel:+… · https://t.me/…"
              onChange={(e) =>
                patch({
                  links: content.links.map((v) =>
                    v.id === l.id ? { ...v, url: e.target.value } : v,
                  ),
                })
              }
            />
            <Button
              variant="quiet"
              className="text-danger"
              onClick={() => patch({ links: content.links.filter((v) => v.id !== l.id) })}
            >
              Удалить контакт
            </Button>
          </div>
        ))}
        <Button
          variant="secondary"
          onClick={() =>
            patch({
              links: [
                ...content.links,
                {
                  id: uid(),
                  label: '',
                  url: '',
                  kind: 'website',
                  publishAllowed: true,
                  visible: true,
                },
              ],
            })
          }
        >
          Добавить контакт
        </Button>
      </section>
      <section className="editor-group stack">
        <TagEditor
          heading={<h2>Навыки</h2>}
          title="Навык"
          addLabel="Добавить навык"
          removeLabel="Удалить навык"
          listLabel="Навыки портфолио"
          items={content.skills}
          onAdd={(name) => patch({ skills: appendPortfolioSkill(content.skills, name) })}
          onRemove={(index) =>
            patch({ skills: content.skills.filter((_, position) => position !== index) })
          }
        />
      </section>
      {projects && (
        <section className="editor-group stack">
          <h2>Реализованные проекты</h2>
          {projects}
        </section>
      )}
      <section className="editor-group stack">
        <h2>Опыт работы</h2>
        {content.experience.map((x, i) => (
          <div key={x.id} className="entry-editor stack">
            <h3>Опыт {i + 1}</h3>
            {(['role', 'organization', 'period', 'description'] as const).map((k) => (
              <Field
                key={k}
                label={
                  {
                    role: 'Должность',
                    organization: 'Организация',
                    period: 'Период',
                    description: 'Описание',
                  }[k]
                }
                value={x[k]}
                required={k === 'role' || k === 'organization'}
                textarea={k === 'description'}
                maxLength={k === 'description' ? 4000 : k === 'organization' ? 160 : 120}
                onChange={(e) =>
                  patch({
                    experience: content.experience.map((v) =>
                      v.id === x.id ? { ...v, [k]: e.target.value } : v,
                    ),
                  })
                }
              />
            ))}
            <Button
              variant="quiet"
              className="text-danger"
              onClick={() => patch({ experience: content.experience.filter((v) => v.id !== x.id) })}
            >
              Удалить опыт
            </Button>
          </div>
        ))}
        <Button
          variant="secondary"
          onClick={() =>
            patch({
              experience: [
                ...content.experience,
                { id: uid(), role: '', organization: '', period: '', description: '' },
              ],
            })
          }
        >
          Добавить опыт
        </Button>
      </section>
      <section className="editor-group stack">
        <h2>Образование</h2>
        {content.education.map((x, i) => (
          <div key={x.id} className="entry-editor stack">
            <h3>Образование {i + 1}</h3>
            {(['institution', 'qualification', 'period', 'description'] as const).map((k) => (
              <Field
                key={k}
                label={
                  {
                    institution: 'Учебное заведение',
                    qualification: 'Квалификация',
                    period: 'Период',
                    description: 'Описание',
                  }[k]
                }
                value={x[k]}
                required={k === 'institution' || k === 'qualification'}
                textarea={k === 'description'}
                maxLength={k === 'description' ? 4000 : k === 'period' ? 120 : 160}
                onChange={(e) =>
                  patch({
                    education: content.education.map((v) =>
                      v.id === x.id ? { ...v, [k]: e.target.value } : v,
                    ),
                  })
                }
              />
            ))}
            <Button
              variant="quiet"
              className="text-danger"
              onClick={() => patch({ education: content.education.filter((v) => v.id !== x.id) })}
            >
              Удалить образование
            </Button>
          </div>
        ))}
        <Button
          variant="secondary"
          onClick={() =>
            patch({
              education: [
                ...content.education,
                { id: uid(), institution: '', qualification: '', period: '', description: '' },
              ],
            })
          }
        >
          Добавить образование
        </Button>
      </section>
      {github && (
        <section className="editor-group stack">
          <h2>GitHub</h2>
          {github}
        </section>
      )}
    </div>
  );
}
