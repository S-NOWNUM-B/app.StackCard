import 'package:app_stackcard/features/portfolio_draft/domain/document_publication.dart';

const publicId = '0123456789abcdef0123456789abcdef';
DocumentPublication publication({
  String id = publicId,
  int version = 1,
  DocumentPublicationVisibility visibility =
      DocumentPublicationVisibility.published,
  String? url,
}) => DocumentPublication(
  documentId: 'main',
  publicId: id,
  version: version,
  visibility: visibility,
  sourceMutationId: 'published-mutation',
  url: Uri.parse(url ?? 'https://portfolio.example/d/$id'),
);
Map<String, dynamic> publicCardFixture() => {
  'schemaVersion': 2,
  'publicId': publicId,
  'version': 1,
  'kind': 'portfolio',
  'title': 'Опубликованная карточка',
  'attachedResumePublicId': null,
  'publishedAt': '2026-10-21T00:00:00Z',
  'content': {
    'profile': {
      'name': 'Анна Ёлкина',
      'username': 'anna-dev',
      'headline': 'Flutter developer',
      'bio': '',
      'locationText': '',
      'avatarUrl': '',
    },
    'skills': [
      {'id': 'flutter', 'name': 'Flutter'},
    ],
    'projects': [
      {
        'visible': true,
        'technologies': ['Flutter', 'TypeScript'],
      },
    ],
    'experience': [],
    'education': [],
    'links': [],
    'resumeText': '',
    'theme': 'light',
    'blocks': [
      for (final kind in ['profile', 'skills', 'featuredProjects'])
        {'kind': kind, 'visible': true},
    ],
  },
};
