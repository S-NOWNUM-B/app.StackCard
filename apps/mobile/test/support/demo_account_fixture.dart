import 'package:app_stackcard/features/portfolio_draft/portfolio_draft.dart';

/// Учётные данные только для локального Auth Emulator; в реальном проекте не используются.
const demoAccountEmail = 'demo@stackcard.test';
const demoAccountPassword = 'DemoStackCard2026';

const demoAccountNotes =
    'Подготовить кейс по StackCard для собеседования.\n'
    'Обновить скриншоты проектов перед публикацией.';

final _created = DateTime.utc(2026, 9, 1, 9);
final _updated = DateTime.utc(2026, 10, 20, 18);

const _profile = PortfolioProfile(
  name: 'Алексей Смирнов',
  username: 'alexsmirnov',
  headline: 'Full-Stack Developer · Flutter, Kotlin, Next.js',
  bio:
      'Пять лет делаю продукты от идеи до релиза: мобильные приложения на '
      'Flutter, бэкенд на Kotlin и Spring Boot, веб на Next.js. Люблю чистую '
      'архитектуру, понятные интерфейсы и измеримый результат.\n'
      'Последние два года руковожу небольшой командой и отвечаю за качество '
      'релизов: CI, тесты и наблюдаемость.',
  locationText: 'Алматы, Казахстан',
  publishLocation: true,
);

const _skills = [
  Skill(id: 'skill-flutter', name: 'Flutter'),
  Skill(id: 'skill-dart', name: 'Dart'),
  Skill(id: 'skill-kotlin', name: 'Kotlin'),
  Skill(id: 'skill-spring', name: 'Spring Boot'),
  Skill(id: 'skill-typescript', name: 'TypeScript'),
  Skill(id: 'skill-react', name: 'React'),
  Skill(id: 'skill-next', name: 'Next.js'),
  Skill(id: 'skill-postgres', name: 'PostgreSQL'),
  Skill(id: 'skill-mongo', name: 'MongoDB'),
  Skill(id: 'skill-firebase', name: 'Firebase'),
  Skill(id: 'skill-docker', name: 'Docker'),
  Skill(id: 'skill-ci', name: 'GitHub Actions'),
];

const _experience = [
  Experience(
    id: 'exp-kaspi',
    role: 'Senior Mobile Developer',
    organization: 'FinTech Studio',
    period: '2024 — сейчас',
    description:
        'Веду мобильное приложение на Flutter с аудиторией 300 тыс. '
        'пользователей. Перевёл навигацию на GoRouter, сократил холодный '
        'старт на 35% и настроил релизы через CI.',
  ),
  Experience(
    id: 'exp-logistics',
    role: 'Full-Stack Developer',
    organization: 'Logistics Cloud',
    period: '2022 — 2024',
    description:
        'Разрабатывал сервисы на Kotlin и Spring Boot и кабинет клиента '
        'на Next.js. Спроектировал схему PostgreSQL для трекинга заказов.',
  ),
  Experience(
    id: 'exp-agency',
    role: 'Junior Frontend Developer',
    organization: 'Digital Agency',
    period: '2021 — 2022',
    description:
        'Верстал лендинги и админ-панели на React и TypeScript, '
        'покрывал компоненты тестами.',
  ),
];

const _education = [
  Education(
    id: 'edu-university',
    institution: 'Казахстанско-Британский технический университет',
    qualification: 'Бакалавр, информационные системы',
    period: '2017 — 2021',
    description: 'Дипломный проект — сервис бронирования с мобильным клиентом.',
  ),
  Education(
    id: 'edu-course',
    institution: 'Google Developer Courses',
    qualification: 'Flutter & Firebase',
    period: '2022',
    description: 'Курс по архитектуре Flutter-приложений и Firebase.',
  ),
];

const _links = [
  SocialLink(
    id: 'link-email',
    label: 'alex.smirnov@example.com',
    url: 'mailto:alex.smirnov@example.com',
    kind: SocialLinkKind.email,
    publishAllowed: true,
  ),
  SocialLink(
    id: 'link-phone',
    label: '+7 701 123 45 67',
    url: 'tel:+77011234567',
    kind: SocialLinkKind.phone,
    publishAllowed: true,
  ),
  SocialLink(
    id: 'link-telegram',
    label: '@alexsmirnov_dev',
    url: 'https://t.me/alexsmirnov_dev',
    kind: SocialLinkKind.telegram,
    publishAllowed: true,
  ),
  SocialLink(
    id: 'link-github',
    label: 'github.com/alexsmirnov',
    url: 'https://github.com/alexsmirnov',
    kind: SocialLinkKind.github,
    publishAllowed: true,
  ),
  SocialLink(
    id: 'link-linkedin',
    label: 'linkedin.com/in/alexsmirnov',
    url: 'https://www.linkedin.com/in/alexsmirnov',
    kind: SocialLinkKind.linkedin,
    publishAllowed: true,
  ),
  SocialLink(
    id: 'link-website',
    label: 'alexsmirnov.dev',
    url: 'https://alexsmirnov.dev',
    kind: SocialLinkKind.website,
    publishAllowed: true,
  ),
];

final _projects = [
  PortfolioProject(
    id: 'project-stackcard',
    title: 'StackCard',
    description:
        'Мобильное приложение для портфолио разработчика: импорт проектов '
        'из GitHub, PDF и публичная ссылка с QR-кодом.',
    contribution: 'Архитектура Flutter-клиента, синхронизация с Firestore и офлайн-режим.',
    technologies: const ['Flutter', 'Dart', 'Firebase', 'Riverpod'],
    repositoryUrl: 'https://github.com/alexsmirnov/stackcard',
    liveUrl: 'https://stackcard.example.com',
    featured: true,
    iconId: 'panels-top-left',
    updatedAt: _updated,
  ),
  PortfolioProject(
    id: 'project-tracker',
    title: 'Delivery Tracker',
    description:
        'Сервис отслеживания заказов в реальном времени с кабинетом клиента.',
    contribution: 'Бэкенд на Spring Boot, схема PostgreSQL и веб-кабинет.',
    technologies: const ['Kotlin', 'Spring Boot', 'PostgreSQL', 'Next.js'],
    repositoryUrl: 'https://github.com/alexsmirnov/delivery-tracker',
    liveUrl: 'https://tracker.example.com',
    featured: true,
    iconId: 'home',
    updatedAt: _updated,
  ),
  PortfolioProject(
    id: 'project-photo',
    title: 'Photo Journal',
    description: 'Приложение-дневник с фото, тегами и поиском по заметкам.',
    contribution: 'UI на Flutter, локальная база и экспорт в PDF.',
    technologies: const ['Flutter', 'Hive', 'MongoDB'],
    repositoryUrl: 'https://github.com/alexsmirnov/photo-journal',
    iconId: 'camera',
    updatedAt: _updated,
  ),
  PortfolioProject(
    id: 'project-docs',
    title: 'Docs Generator',
    description: 'CLI для генерации документации API из OpenAPI-схем.',
    contribution: 'Парсер схем, шаблоны и публикация через GitHub Actions.',
    technologies: const ['TypeScript', 'Node.js', 'Docker'],
    repositoryUrl: 'https://github.com/alexsmirnov/docs-generator',
    iconId: 'file-text',
    updatedAt: _updated,
  ),
];

final _base = PortfolioContent(
  profile: _profile,
  skills: _skills,
  experience: _experience,
  education: _education,
  links: _links,
);

/// Полностью заполненный workspace: база, библиотека, основное портфолио и резюме.
PortfolioContent demoAccountWorkspace() => PortfolioContent(
  profile: _profile,
  skills: _skills,
  experience: _experience,
  education: _education,
  links: _links,
  projects: _projects,
  githubUsername: 'alexsmirnov',
  mainPortfolioId: 'main-portfolio',
  personalization: const PortfolioPersonalization(
    status: PortfolioPersonalizationStatus.completed,
    step: 3,
  ),
  documents: [
    PortfolioDocument(
      id: 'main-portfolio',
      title: 'Портфолио',
      kind: PortfolioDocumentKind.portfolio,
      createdAt: _created,
      updatedAt: _updated,
      // Набор блоков как у редактора основного портфолио.
      content: _base.copyWith(blocks: mainPortfolioBlocks(_base)),
      baseSnapshot: _base,
      projects: [
        for (final project in _projects)
          PortfolioProjectAttachment(
            projectId: project.id,
            featured: project.featured,
          ),
      ],
    ),
    PortfolioDocument(
      id: 'resume-backend',
      title: 'Резюме Backend',
      kind: PortfolioDocumentKind.resume,
      createdAt: _created,
      updatedAt: _updated,
      content: _base.copyWith(
        profile: _profile.copyWith(headline: 'Backend Developer · Kotlin'),
      ),
      baseSnapshot: _base,
      projects: const [
        PortfolioProjectAttachment(projectId: 'project-tracker'),
        PortfolioProjectAttachment(projectId: 'project-docs'),
      ],
    ),
  ],
);
