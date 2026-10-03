import '../domain/profile.dart';
import '../domain/profile_repository.dart';

class MockProfileRepository implements ProfileRepository {
  @override
  Future<Profile> getProfile() async => _profile;

  final _profile = Profile(
    name: 'Alex Morgan',
    handle: 'alex-dev-demo',
    role: 'Flutter & Web Developer',
    location: 'Алматы, Казахстан',
    initials: 'AM',
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
      'UI Design',
    ],
    readiness: ProfileReadiness(completedBlocks: 4, totalBlocks: 5),
    experience: const ProfileHighlight(
      title: 'Frontend Developer',
      details: 'Studio Example · 2024–2026',
    ),
    education: const ProfileHighlight(
      title: 'Software Engineering',
      details: 'Пример учебного профиля · 2023–2027',
    ),
  );
}
