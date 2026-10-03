class Profile {
  Profile({
    required this.name,
    required this.handle,
    required this.role,
    required this.location,
    required this.initials,
    required this.about,
    required List<String> skills,
    required this.readiness,
    this.experience,
    this.education,
  }) : skills = List.unmodifiable(skills);

  final String name;
  final String handle;
  final String role;
  final String location;
  final String initials;
  final String about;
  final List<String> skills;
  final ProfileReadiness readiness;
  final ProfileHighlight? experience;
  final ProfileHighlight? education;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;
}

class ProfileHighlight {
  const ProfileHighlight({required this.title, required this.details});

  final String title;
  final String details;
}

// Снимок для UI: demo counters либо вычисленная domain-полнота working draft.
class ProfileReadiness {
  ProfileReadiness({required this.completedBlocks, required this.totalBlocks}) {
    if (totalBlocks <= 0 ||
        completedBlocks < 0 ||
        completedBlocks > totalBlocks) {
      throw ArgumentError('Некорректное число заполненных блоков');
    }
  }

  final int completedBlocks;
  final int totalBlocks;

  double get fraction => completedBlocks / totalBlocks;
  int get percent => (fraction * 100).round();
}
