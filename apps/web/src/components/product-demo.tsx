'use client';

import { useState } from 'react';
import Link from 'next/link';
import { DEMO_PROFILE_NAME, exampleDocumentContent } from './document-view';
import { Icon, TechnologyBadges } from './ui';

// Демонстрация одного основного портфолио: публичный вид и PDF из сохранённой версии.
// Маркетинговое правило: последнее предложение блока без точки.
const withoutFinalPeriod = (text: string) => text.replace(/\.$/, '');

export function ProductDemo() {
  const [view, setView] = useState<'portfolio' | 'pdf'>('portfolio');
  const content = exampleDocumentContent('resume', true);
  return (
    <div className="product-scene">
      <div className="floating-paper floating-resume" aria-hidden="true">
        <span className="mini-label">PDF / СОХРАНЁННАЯ ВЕРСИЯ</span>
        <strong>{DEMO_PROFILE_NAME}</strong>
        <span>Flutter- и веб-разработчик</span>
        <hr />
        <b>Навыки и проекты</b>
        <div className="paper-lines">
          <i />
          <i />
          <i />
        </div>
        <b>Опыт и образование</b>
        <div className="paper-lines">
          <i />
          <i />
        </div>
      </div>
      <div className="floating-paper floating-project" aria-hidden="true">
        <span className="mini-label">ИМПОРТ ИЗ GITHUB</span>
        <div className="project-glyph">
          <Icon name="github" size={28} />
        </div>
        <strong>Выбрано 2 из 3</strong>
        <ul className="floating-checklist">
          <li className="is-checked">atlas-ui-kit</li>
          <li className="is-checked">pocket-tasks</li>
          <li>playground</li>
        </ul>
        <hr />
        <span>Импортировать выбранные</span>
      </div>
      <div className="product-window">
        <div className="demo-toolbar">
          <div className="window-dots" aria-hidden="true">
            <i />
            <i />
            <i />
          </div>
          <span>Ваше рабочее пространство</span>
          <span className="demo-label">Демонстрация</span>
        </div>
        <div className="demo-layout">
          <aside className="demo-sidebar">
            <img
              src="/branding/stackcard-v2-wordmark-ink.svg"
              alt="StackCard"
              width={112}
              height={16}
            />
            <span className="mini-label">РАБОЧЕЕ ПРОСТРАНСТВО</span>
            <Link href="/workspace#home" className="selected">
              <Icon name="home" size={16} />
              Главная
            </Link>
            <Link href="/workspace#projects">
              <Icon name="folder" size={16} />
              Проекты
            </Link>
            <Link href="/workspace#editor">
              <Icon name="panels-top-left" size={16} />
              Редактор
            </Link>
            <div className="demo-account">
              <span className="initials">ВИ</span>
              <div>
                <b>{DEMO_PROFILE_NAME}</b>
                <span>Пример профиля</span>
              </div>
            </div>
          </aside>
          <div className="demo-content">
            <div className="demo-heading">
              <div>
                <span className="mini-label">ГЛАВНАЯ</span>
                <h2>Ваше портфолио</h2>
              </div>
              <Link href="/workspace#editor" className="demo-add" aria-label="Открыть редактор">
                <Icon name="pencil" size={18} />
              </Link>
            </div>
            <div className="demo-switch" aria-label="Вид демонстрационного портфолио">
              <button
                type="button"
                aria-pressed={view === 'portfolio'}
                onClick={() => setView('portfolio')}
              >
                Портфолио
              </button>
              <button type="button" aria-pressed={view === 'pdf'} onClick={() => setView('pdf')}>
                PDF
              </button>
            </div>
            <div className="demo-document" key={view}>
              <div className="demo-document-head">
                <div>
                  <span className="mini-label">
                    {view === 'portfolio' ? 'ОСНОВНОЕ ПОРТФОЛИО' : 'PDF · A4'}
                  </span>
                  <h3>{content.profile.name}</h3>
                  <p>
                    {content.profile.headline} · {content.profile.locationText}
                  </p>
                </div>
                <img
                  src="/images/demo-portrait.png"
                  alt="Демонстрационное фото профиля"
                  width={58}
                  height={58}
                />
              </div>
              <p className="demo-bio">{withoutFinalPeriod(content.profile.bio)}</p>
              {view === 'portfolio' ? (
                <div className="demo-projects">
                  {content.projects.slice(0, 2).map((project, index) => (
                    <div key={project.id}>
                      <div className={`demo-project-cover cover-${index}`}>
                        <span>{index === 0 ? 'Aa' : '</>'}</span>
                        <span>{index === 0 ? 'ДИЗАЙН-СИСТЕМА' : 'ИМПОРТ ИЗ GITHUB'}</span>
                      </div>
                      <h4>{project.title}</h4>
                      <p>{withoutFinalPeriod(project.description)}</p>
                      <TechnologyBadges items={project.technologies.slice(0, 2)} />
                    </div>
                  ))}
                </div>
              ) : (
                <div className="demo-resume-body">
                  <div>
                    <span className="mini-label">ОПЫТ</span>
                    {content.experience.slice(0, 2).map((item) => (
                      <div key={item.id}>
                        <b>{item.role}</b>
                        <p>
                          {item.organization} · {item.period}
                        </p>
                      </div>
                    ))}
                    <span className="mini-label demo-pdf-label">ОБРАЗОВАНИЕ</span>
                    {content.education.slice(0, 1).map((item) => (
                      <div key={item.id}>
                        <b>{item.qualification}</b>
                        <p>{item.period}</p>
                      </div>
                    ))}
                  </div>
                  <div>
                    <span className="mini-label">НАВЫКИ</span>
                    <TechnologyBadges items={content.skills.map((item) => item.name).slice(0, 4)} />
                  </div>
                </div>
              )}
              <Link className="demo-open" href="/examples/portfolio">
                Открыть полный пример <span aria-hidden="true">↗</span>
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
