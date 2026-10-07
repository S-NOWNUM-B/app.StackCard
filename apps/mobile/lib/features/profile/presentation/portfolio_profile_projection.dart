import '../../portfolio_draft/portfolio_draft.dart';
import '../domain/profile.dart';

/// Проекция working draft для существующих обзорных экранов.
Profile projectPortfolioProfile(PortfolioContent content) {
  final profile = content.profile;
  final completion = calculatePortfolioCompletion(content);
  final words = profile.name.trim().split(RegExp(r'\s+'));
  final initials = words
      .where((word) => word.isNotEmpty)
      .take(2)
      .map((word) => word.runes.first)
      .map(String.fromCharCode)
      .join()
      .toUpperCase();
  final experience = content.experience.firstOrNull;
  final education = content.education.firstOrNull;
  return Profile(
    name: profile.name,
    handle: profile.username.isEmpty ? '' : '@${profile.username}',
    role: profile.headline,
    location: profile.locationText,
    initials: initials.isEmpty ? '?' : initials,
    avatarPath: profile.avatarPath,
    avatarUrl: profile.avatarUrl,
    about: profile.bio,
    skills: content.skills.map((skill) => skill.name).toList(),
    readiness: ProfileReadiness(
      completedBlocks: completion.completedSteps,
      totalBlocks: completion.totalSteps,
    ),
    experience: experience == null
        ? null
        : ProfileHighlight(
            title: experience.role,
            details: [
              experience.organization,
              experience.period,
            ].where((value) => value.isNotEmpty).join(' · '),
          ),
    education: education == null
        ? null
        : ProfileHighlight(
            title: education.qualification,
            details: [
              education.institution,
              education.period,
            ].where((value) => value.isNotEmpty).join(' · '),
          ),
  );
}
