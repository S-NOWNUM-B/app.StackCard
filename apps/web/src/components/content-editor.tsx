'use client';
import { Button, Field } from './ui';
import {
  uid,
  linkKinds,
  blockKinds,
  type DocumentContent,
  type Profile,
  type WorkspaceContent,
  type Contact,
} from '@/lib/model';
const labels: Record<string, string> = {
  name: 'Имя',
  username: 'Username',
  headline: 'Профессиональная роль',
  bio: 'О себе',
  locationText: 'Город и страна',
  avatarUrl: 'URL фотографии',
  profile: 'Профиль',
  about: 'О себе',
  skills: 'Навыки',
  featuredProjects: 'Проекты',
  experience: 'Опыт',
  education: 'Образование',
  github: 'GitHub',
  links: 'Контакты',
  resume: 'Резюме',
  location: 'Местоположение',
};
const max: Record<string, number> = {
  name: 100,
  username: 30,
  headline: 160,
  bio: 4000,
  locationText: 200,
  avatarUrl: 2048,
};
type Props = {
  content: DocumentContent;
  onChange: (content: DocumentContent) => void;
  isBase?: boolean;
  contacts?: Contact[];
};
export function ContentEditor({ content, onChange, isBase = false, contacts = [] }: Props) {
  const patch = (p: Partial<DocumentContent>) => onChange({ ...content, ...p });
  const profile = (p: Partial<Profile>) => patch({ profile: { ...content.profile, ...p } });
  return (
    <div className="stack">
      <details className="editor-section" open>
        <summary>Профиль</summary>
        {(['name', 'username', 'headline', 'bio', 'locationText', 'avatarUrl'] as const).map(
          (key) => (
            <Field
              key={key}
              label={labels[key]}
              textarea={key === 'bio'}
              maxLength={max[key]}
              helper={
                key === 'avatarUrl'
                  ? 'Для публикации подходят фото GitHub или Unsplash. Можно загрузить своё изображение ниже.'
                  : undefined
              }
              value={content.profile[key]}
              onChange={(e) => profile({ [key]: e.target.value })}
            />
          ),
        )}
        <label className="checkbox">
          <input
            type="checkbox"
            checked={content.profile.publishLocation}
            onChange={(e) => profile({ publishLocation: e.target.checked })}
          />
          Разрешить публикацию местоположения
        </label>
        {isBase && (
          <small className="muted">
            Разрешение действует для следующих публикаций. Уже опубликованное местоположение
            исчезнет после обновления или снятия документа с публикации.
          </small>
        )}
        {content.profile.avatarPath && (
          <p className="muted">
            Загруженная фотография сохранена. Ссылка не заменяет её; выберите новое изображение
            через загрузку фото.
          </p>
        )}
      </details>
      <details className="editor-section">
        <summary>Навыки</summary>
        {content.skills.map((s, i) => (
          <div className="row" key={s.id}>
            <Field
              label={`Навык ${i + 1}`}
              value={s.name}
              maxLength={60}
              required
              onChange={(e) =>
                patch({
                  skills: content.skills.map((v) =>
                    v.id === s.id ? { ...v, name: e.target.value } : v,
                  ),
                })
              }
            />
            <Button
              variant="quiet"
              onClick={() => patch({ skills: content.skills.filter((v) => v.id !== s.id) })}
            >
              Удалить
            </Button>
          </div>
        ))}
        <Button
          variant="secondary"
          onClick={() =>
            patch({
              skills: [...content.skills, { id: uid(), name: 'Новый навык' }],
            })
          }
        >
          Добавить навык
        </Button>
      </details>
      <details className="editor-section">
        <summary>Опыт работы</summary>
        {content.experience.map((x, i) => (
          <div key={x.id} className="stack section">
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
                textarea={k === 'description'}
                maxLength={k === 'description' ? 4000 : k === 'organization' ? 160 : 120}
                required={k === 'role' || k === 'organization'}
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
              variant="danger"
              onClick={() =>
                patch({
                  experience: content.experience.filter((v) => v.id !== x.id),
                })
              }
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
                {
                  id: uid(),
                  role: 'Должность',
                  organization: 'Организация',
                  period: '',
                  description: '',
                },
              ],
            })
          }
        >
          Добавить опыт
        </Button>
      </details>
      <details className="editor-section">
        <summary>Образование</summary>
        {content.education.map((x, i) => (
          <div key={x.id} className="stack section">
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
                textarea={k === 'description'}
                maxLength={k === 'description' ? 4000 : k === 'period' ? 120 : 160}
                required={k === 'institution' || k === 'qualification'}
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
              variant="danger"
              onClick={() =>
                patch({
                  education: content.education.filter((v) => v.id !== x.id),
                })
              }
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
                {
                  id: uid(),
                  institution: 'Учебное заведение',
                  qualification: 'Квалификация',
                  period: '',
                  description: '',
                },
              ],
            })
          }
        >
          Добавить образование
        </Button>
      </details>
      <details className="editor-section">
        <summary>Контакты и приватность</summary>
        <p className="muted">
          Почта входа не становится публичным контактом.{' '}
          {isBase
            ? 'Разрешение базы действует для следующих публикаций. Уже опубликованный документ нужно обновить или снять с публикации.'
            : 'Контакт публикуется только при действующем разрешении общей базы.'}
        </p>
        {content.links.map((l) => (
          <div key={l.id} className="stack section">
            <Field
              label="Название контакта"
              value={l.label}
              required
              maxLength={80}
              onChange={(e) =>
                patch({
                  links: content.links.map((v) =>
                    v.id === l.id ? { ...v, label: e.target.value } : v,
                  ),
                })
              }
            />
            <label className="field">
              <span>Тип</span>
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
                    {
                      {
                        other: 'Другая ссылка',
                        github: 'GitHub',
                        website: 'Сайт',
                        linkedin: 'LinkedIn',
                        email: 'Почта',
                        phone: 'Телефон',
                        telegram: 'Telegram',
                      }[k]
                    }
                  </option>
                ))}
              </select>
            </label>
            <Field
              label="Адрес"
              value={l.url}
              required
              maxLength={2048}
              helper="https://… · mailto:… · tel:+… · https://t.me/…"
              onChange={(e) =>
                patch({
                  links: content.links.map((v) =>
                    v.id === l.id ? { ...v, url: e.target.value } : v,
                  ),
                })
              }
            />
            {isBase ? (
              <label className="checkbox">
                <input
                  type="checkbox"
                  checked={l.publishAllowed}
                  onChange={(e) =>
                    patch({
                      links: content.links.map((v) =>
                        v.id === l.id ? { ...v, publishAllowed: e.target.checked } : v,
                      ),
                    })
                  }
                />
                Разрешить публикацию этого контакта
              </label>
            ) : (
              <>
                <label className="checkbox">
                  <input
                    type="checkbox"
                    checked={l.visible}
                    onChange={(e) =>
                      patch({
                        links: content.links.map((v) =>
                          v.id === l.id ? { ...v, visible: e.target.checked } : v,
                        ),
                      })
                    }
                  />
                  Включить в этот документ
                </label>
                {!contacts.find((c) => c.id === l.id)?.publishAllowed && (
                  <p className="muted">Публикация запрещена в общей базе.</p>
                )}
              </>
            )}
            <Button
              variant="danger"
              onClick={() => patch({ links: content.links.filter((v) => v.id !== l.id) })}
            >
              Удалить контакт
            </Button>
          </div>
        ))}
        {isBase && (
          <Button
            variant="secondary"
            onClick={() =>
              patch({
                links: [
                  ...content.links,
                  {
                    id: uid(),
                    label: 'Личный сайт',
                    url: 'https://',
                    kind: 'website',
                    publishAllowed: false,
                    visible: true,
                  },
                ],
              })
            }
          >
            Добавить контакт
          </Button>
        )}
      </details>
      {!isBase && (
        <>
          <details className="editor-section">
            <summary>Порядок и видимость секций</summary>
            {content.blocks.map((b, i) => (
              <div key={b.kind} className="row">
                <label className="checkbox">
                  <input
                    type="checkbox"
                    checked={b.visible}
                    onChange={(e) =>
                      patch({
                        blocks: content.blocks.map((v) =>
                          v.kind === b.kind ? { ...v, visible: e.target.checked } : v,
                        ),
                      })
                    }
                  />
                  {labels[b.kind] ?? b.kind}
                </label>
                <Button
                  variant="quiet"
                  disabled={i === 0}
                  onClick={() => {
                    const blocks = [...content.blocks];
                    [blocks[i - 1], blocks[i]] = [blocks[i], blocks[i - 1]];
                    patch({ blocks });
                  }}
                >
                  Вверх
                </Button>
                <Button
                  variant="quiet"
                  disabled={i === content.blocks.length - 1}
                  onClick={() => {
                    const blocks = [...content.blocks];
                    [blocks[i + 1], blocks[i]] = [blocks[i], blocks[i + 1]];
                    patch({ blocks });
                  }}
                >
                  Вниз
                </Button>
              </div>
            ))}
          </details>
          <details className="editor-section">
            <summary>Оформление</summary>
            <label className="field">
              <span>Тема документа</span>
              <select
                value={content.theme}
                onChange={(e) => patch({ theme: e.target.value as 'dark' | 'light' })}
              >
                <option value="dark">Тёмная</option>
                <option value="light">Светлая</option>
              </select>
            </label>
            <Field
              label="Дополнительный текст резюме"
              textarea
              value={content.resumeText}
              maxLength={20000}
              onChange={(e) => patch({ resumeText: e.target.value })}
            />
          </details>
        </>
      )}
    </div>
  );
}
