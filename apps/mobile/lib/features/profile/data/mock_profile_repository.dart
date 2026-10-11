import '../domain/profile.dart';
import '../domain/profile_repository.dart';

class MockProfileRepository implements ProfileRepository {
  @override
  Future<Profile> getProfile() async => _profile;

  final _profile = Profile(
    name: 'Алекс Морган',
    handle: 'alex-dev-demo',
    role: 'Разработчик Flutter и веб-приложений',
    location: 'Алматы, Казахстан',
    initials: 'АМ',
    about:
        'Создаю понятные цифровые продукты: от небольших мобильных приложений '
        'до интерфейсов для веба. Люблю чистую типографику, продуманные детали '
        'и код, который легко поддерживать.',
    skills: [
      'Flutter',
      'Dart',
      'React',
      'TypeScript',
      'Firebase',
      'Git',
      'Figma',
      'Дизайн интерфейсов',
    ],
    readiness: ProfileReadiness(completedBlocks: 4, totalBlocks: 5),
    experience: const ProfileHighlight(
      title: 'Фронтенд-разработчик',
      details: 'Студия «Пример» · 2024–2026',
    ),
    education: const ProfileHighlight(
      title: 'Программная инженерия',
      details: 'Пример учебного профиля · 2023–2027',
    ),
  );
}
