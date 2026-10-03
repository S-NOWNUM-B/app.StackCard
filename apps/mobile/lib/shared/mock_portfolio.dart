/// Демонстрационный контент для UI foundation, без аккаунта и хранилища.
class DemoProject {
  const DemoProject({
    required this.title,
    required this.description,
    required this.technologies,
    required this.symbol,
    required this.category,
    required this.source,
    required this.featured,
    required this.details,
  });

  final String title;
  final String description;
  final List<String> technologies;
  final String symbol;
  final String category;
  final String source;
  final bool featured;
  final String details;

  bool get isFromGitHub => source == 'GitHub';
}

abstract final class DemoPortfolio {
  static const name = 'Alex Morgan';
  static const handle = 'alex-dev-demo';
  static const role = 'Flutter & Web Developer';
  static const location = 'Алматы, Казахстан';
  static const initials = 'AM';
  static const completion = 0.8;
  static const about =
      'Создаю понятные цифровые продукты: от небольших мобильных приложений '
      'до интерфейсов для веба. Люблю чистую типографику, продуманные детали '
      'и код, который легко поддерживать.';
  static const skills = [
    'Flutter',
    'Dart',
    'React',
    'TypeScript',
    'Firebase',
    'Git',
    'Figma',
    'UI Design',
  ];

  static const projects = [
    DemoProject(
      title: 'Atlas UI Kit',
      description: 'Набор компонентов для спокойных и удобных интерфейсов.',
      technologies: ['Flutter', 'Dart', 'UI Design'],
      symbol: 'A',
      category: 'Design system',
      source: 'GitHub',
      featured: true,
      details:
          'Демонстрационный кейс библиотеки компонентов: карточки, формы, '
          'навигация и две темы. В примере показаны задачи дизайна и реализации '
          'интерфейса; репозиторий к приложению не подключён.',
    ),
    DemoProject(
      title: 'Pocket Tasks',
      description: 'Небольшой планировщик, который помогает держать фокус.',
      technologies: ['Flutter', 'Dart', 'Firebase'],
      symbol: 'P',
      category: 'Mobile app',
      source: 'Вручную',
      featured: true,
      details:
          'Пример мобильного проекта с лаконичным списком задач, приоритетами '
          'и обзором недели. Это иллюстрация оформления кейса в портфолио, '
          'а не установленное или доступное для скачивания приложение.',
    ),
    DemoProject(
      title: 'Readme Studio',
      description:
          'Редактор структуры README для небольших open source проектов.',
      technologies: ['React', 'TypeScript'],
      symbol: 'R',
      category: 'Web tool',
      source: 'GitHub',
      featured: false,
      details:
          'Пример веб-инструмента с блоками описания проекта и предпросмотром '
          'документа. Карточка демонстрирует, как может выглядеть импортированный '
          'проект после ручной редакции владельцем.',
    ),
    DemoProject(
      title: 'Weather Notes',
      description: 'Погода и короткие заметки о городе в одном интерфейсе.',
      technologies: ['Flutter', 'Dart'],
      symbol: 'W',
      category: 'Side project',
      source: 'Вручную',
      featured: false,
      details:
          'Демонстрационный side project для практики экранов, состояний '
          'и работы с данными. Сетевые запросы и определение геопозиции '
          'в текущей версии StackCard отсутствуют.',
    ),
  ];
}
