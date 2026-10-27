// Cutover задаёт оператор только после подтверждённого закрытия legacy Storage writes.
export function readMediaCutover(value) {
  if (value === undefined || value === null || value === '') return null;
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/.test(value)
      || !Number.isFinite(Date.parse(value)) || new Date(value).toISOString() !== value) {
    throw new Error('configuration-required');
  }
  return Date.parse(value);
}

export function isFirestoreOnlyAccount({ cutoff, creationTime, draft, account, publications = [], operations = [] }) {
  if (!Number.isFinite(cutoff) || typeof creationTime !== 'string'
      || !Number.isFinite(Date.parse(creationTime)) || Date.parse(creationTime) < cutoff
      || draft?.schemaVersion !== 7 || !draft.content || account?.username
      || Object.hasOwn(draft.content, 'legacyMainSnapshot')) return false;
  const content = draft.content;
  if (!Array.isArray(content.documents) || content.documents.length > 1
      || (content.documents.length === 1 && content.documents[0].id !== content.mainPortfolioId)
      || (content.projects ?? []).some((project) => project.imagePaths?.length)) return false;
  // Pending без media/cleanup не оставляет Storage bytes: lock запрещает её finish,
  // а deleteAccount помечает её failed и удаляет её publicDocument.
  return !publications.some((publication) => publication.mediaPaths?.length)
    && !operations.some((operation) => operation.media?.length || operation.cleanupPaths?.length);
}

export function workspaceAvatarPaths(content) {
  const paths = [content.profile?.avatarPath];
  for (const document of content.documents ?? []) {
    paths.push(document.content?.profile?.avatarPath, document.baseSnapshot?.profile?.avatarPath);
  }
  return [...new Set(paths.filter((path) => typeof path === 'string' && path))];
}
