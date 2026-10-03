import 'package:app_stackcard/features/profile/data/mock_profile_repository.dart';
import 'package:app_stackcard/features/profile/profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Mock profile exposes the existing read-only demo', () async {
    final profile = await MockProfileRepository().getProfile();
    expect(profile.name, 'Alex Morgan');
    expect(profile.firstName, 'Alex');
    expect(profile.skills, hasLength(8));
    expect(profile.readiness.fraction, 0.8);
    expect(profile.experience?.title, 'Frontend Developer');
    expect(() => profile.skills.add('Other'), throwsUnsupportedError);
  });

  test('Profile isolates skills from caller mutation', () {
    final skills = ['Dart'];
    final profile = Profile(
      name: '  Sam Lee  ',
      handle: 'sam',
      role: 'Developer',
      location: '',
      initials: 'SL',
      about: '',
      skills: skills,
      readiness: ProfileReadiness(completedBlocks: 0, totalBlocks: 5),
    );
    skills.clear();
    expect(profile.skills, ['Dart']);
    expect(profile.firstName, 'Sam');
    expect(profile.readiness.percent, 0);
  });

  test('Readiness rejects invalid snapshots and supports full completion', () {
    expect(
      () => ProfileReadiness(completedBlocks: 1, totalBlocks: 0),
      throwsArgumentError,
    );
    expect(
      () => ProfileReadiness(completedBlocks: 6, totalBlocks: 5),
      throwsArgumentError,
    );
    expect(
      () => ProfileReadiness(completedBlocks: -1, totalBlocks: 5),
      throwsArgumentError,
    );
    expect(ProfileReadiness(completedBlocks: 5, totalBlocks: 5).percent, 100);
  });
}
