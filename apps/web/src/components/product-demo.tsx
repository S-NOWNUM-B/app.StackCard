'use client';

import { useState } from 'react';
import Link from 'next/link';
import { exampleDocumentContent } from './document-view';
import { Icon, TechnologyBadges } from './ui';

export function ProductDemo() {
  const [kind, setKind] = useState<'portfolio' | 'resume'>('portfolio');
  const content = exampleDocumentContent(kind, true);
  return (
    <div className="product-scene">
      <div className="floating-paper floating-resume" aria-hidden="true">
        <span className="mini-label">РЕЗЮМЕ / 01</span>
        <strong>Алекс Морган</strong>
        <span>Разработчик интерфейсов</span>
        <hr />
        <b>Опыт и навыки</b>
        <div className="paper-lines">
          <i />
          <i />
          <i />
        </div>
        <b>Избранные проекты</b>
        <div className="paper-lines">
          <i />
          <i />
        </div>
      </div>
      <div className="floating-paper floating-project" aria-hidden="true">
        <span className="mini-label">БИБЛИОТЕКА ПРОЕКТОВ</span>
        <div className="project-glyph">{'{ }'}</div>
        <strong>Atlas UI Kit</strong>
        <span>React · TypeScript</span>
        <hr />
        <span>
          Одна работа.
          <br />
          Разные истории.
        </span>
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
            <Link href="/workspace">
              <Icon name="home" size={16} />
              Обзор
            </Link>
            <Link href="/workspace#resumes" className={kind === 'resume' ? 'selected' : ''}>
              <Icon name="file-text" size={16} />
              Резюме
            </Link>
            <Link href="/workspace#projects">
              <Icon name="folder" size={16} />
              Проекты
            </Link>
            <Link href="/workspace#portfolios" className={kind === 'portfolio' ? 'selected' : ''}>
              <Icon name="panels-top-left" size={16} />
              Портфолио
            </Link>
            <div className="demo-account">
              <span className="initials">AM</span>
              <div>
                <b>Алекс Морган</b>
                <span>Пример профиля</span>
              </div>
            </div>
          </aside>
          <div className="demo-content">
            <div className="demo-heading">
              <div>
                <span className="mini-label">МОИ ДОКУМЕНТЫ</span>
                <h2>Ваша работа в деталях.</h2>
              </div>
              <Link href="/workspace" className="demo-add" aria-label="Создать свой документ">
                <Icon name="plus" size={18} />
              </Link>
            </div>
            <div className="demo-switch" aria-label="Вид демонстрационного документа">
              <button
                type="button"
                aria-pressed={kind === 'portfolio'}
                onClick={() => setKind('portfolio')}
              >
                Портфолио
              </button>
              <button
                type="button"
                aria-pressed={kind === 'resume'}
                onClick={() => setKind('resume')}
              >
                Резюме
              </button>
            </div>
            <div className="demo-document">
              <div className="demo-document-head">
                <div>
                  <span className="mini-label">
                    {kind === 'portfolio' ? 'ПОРТФОЛИО РАЗРАБОТЧИКА' : 'РЕЗЮМЕ РАЗРАБОТЧИКА'}
                  </span>
                  <h3>{content.profile.name}</h3>
                  <p>{content.profile.headline}</p>
                </div>
                <img
                  src="/images/demo-portrait.png"
                  alt="Фото вымышленного Алекс Морган"
                  width={58}
                  height={58}
                />
              </div>
              <p className="demo-bio">{content.profile.bio}</p>
              {kind === 'portfolio' ? (
                <div className="demo-projects">
                  {content.projects.slice(0, 2).map((project, index) => (
                    <div key={project.id}>
                      <div className={`demo-project-cover cover-${index}`}>
                        <span>{index === 0 ? 'Aa' : '</>'}</span>
                        <span>{index === 0 ? 'ДИЗАЙН-СИСТЕМА' : 'ИНСТРУМЕНТЫ РАЗРАБОТКИ'}</span>
                      </div>
                      <h4>{project.title}</h4>
                      <p>{project.description}</p>
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
                  </div>
                  <div>
                    <span className="mini-label">ТЕХНОЛОГИИ</span>
                    <TechnologyBadges items={content.skills.map((item) => item.name).slice(0, 4)} />
                  </div>
                </div>
              )}
              <Link className="demo-open" href={`/examples/${kind}`}>
                Открыть полный пример <span aria-hidden="true">↗</span>
              </Link>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
