import '../domain/project.dart';
import '../domain/projects_repository.dart';

/// Демонстрационный источник без сети, аккаунта и хранилища.
final class MockProjectsRepository implements ProjectsRepository {
  const MockProjectsRepository();

  @override
  Future<List<Project>> getProjects() async => _projects;

  static final _projects = List<Project>.unmodifiable([
    Project(
      title: 'Atlas UI Kit',
      description: 'Набор компонентов для спокойных и удобных интерфейсов.',
      technologies: ['Flutter', 'Dart', 'Дизайн интерфейсов'],
      symbol: 'A',
      category: 'Дизайн-система',
      source: ProjectSource.github,
      featured: true,
      details:
          'Демонстрационный кейс библиотеки компонентов: карточки, формы, '
          'навигация и светлая тема. В примере показаны задачи дизайна и реализации '
          'интерфейса; репозиторий к приложению не подключён.',
    ),
    Project(
      title: 'Pocket Tasks',
      description: 'Небольшой планировщик, который помогает держать фокус.',
      technologies: ['Flutter', 'Dart', 'Firebase'],
      symbol: 'P',
      category: 'Мобильное приложение',
      source: ProjectSource.manual,
      featured: true,
      details:
          'Пример мобильного проекта с лаконичным списком задач, приоритетами '
          'и обзором недели. Это иллюстрация оформления кейса в портфолио, '
          'а не установленное или доступное для скачивания приложение.',
    ),
    Project(
      title: 'Readme Studio',
      description: 'Редактор структуры README для небольших открытых проектов.',
      technologies: ['React', 'TypeScript'],
      symbol: 'R',
      category: 'Веб-инструмент',
      source: ProjectSource.github,
      featured: false,
      details:
          'Пример веб-инструмента с блоками описания проекта и предпросмотром '
          'документа. Карточка демонстрирует, как может выглядеть импортированный '
          'проект после ручной редакции владельцем.',
    ),
    Project(
      title: 'Weather Notes',
      description: 'Погода и короткие заметки о городе в одном интерфейсе.',
      technologies: ['Flutter', 'Dart'],
      symbol: 'W',
      category: 'Личный проект',
      source: ProjectSource.manual,
      featured: false,
      details:
          'Демонстрационный личный проект для практики экранов, состояний '
          'и работы с данными. Пример оформления проекта в StackCard.',
    ),
  ]);
}
