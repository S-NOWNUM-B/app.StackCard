import 'dart:typed_data';

import 'document_publication.dart';

enum DeveloperCardFailureKind {
  unpublished,
  unavailable,
  unknown,
  invalidData,
  stale,
}

final class DeveloperCardFailure implements Exception {
  const DeveloperCardFailure(this.kind);
  final DeveloperCardFailureKind kind;
}

/// Только permanent URL из подтверждённого inventory, без private параметров.
Uri developerCardPublicUrl(DocumentPublication publication) {
  final url = publication.shareableUrl;
  if (url == null) {
    throw const DeveloperCardFailure(DeveloperCardFailureKind.unpublished);
  }
  final local = const {
    'localhost',
    '127.0.0.1',
    '10.0.2.2',
    '::1',
  }.contains(url.host);
  if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(publication.publicId) ||
      publication.version < 1 ||
      url.toString().length > 1024 ||
      RegExp(r'[\s\x00-\x1f\x7f\\]').hasMatch(url.toString()) ||
      !(url.scheme == 'https' || (url.scheme == 'http' && local)) ||
      url.host.isEmpty ||
      url.userInfo.isNotEmpty ||
      url.authority.contains('@') ||
      url.port < 1 ||
      url.port > 65535 ||
      url.hasQuery ||
      url.hasFragment ||
      url.path != '/d/${publication.publicId}') {
    throw const DeveloperCardFailure(DeveloperCardFailureKind.invalidData);
  }
  return url;
}

/// Узкая read model опубликованного snapshot; private draft здесь не участвует.
final class DeveloperCard {
  DeveloperCard({
    required DocumentPublication publication,
    required this.title,
    required this.name,
    required this.headline,
    required this.username,
    required Iterable<String> technologies,
    this.avatarSource = '',
    Uint8List? avatarBytes,
  }) : publicId = publication.publicId,
       version = publication.version,
       url = developerCardPublicUrl(publication),
       technologies = List.unmodifiable(technologies),
       avatarBytes = avatarBytes == null
           ? null
           : Uint8List.fromList(avatarBytes).asUnmodifiableView();

  final String publicId, title, name, headline, username, avatarSource;
  final int version;
  final Uri url;
  final List<String> technologies;
  final Uint8List? avatarBytes;
}

abstract interface class DeveloperCardRepository {
  String get ownerUid;
  Stream<DeveloperCard> watch(DocumentPublication publication);
}
