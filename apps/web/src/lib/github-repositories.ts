import { ContractError, normalizeGitHubUsername, safeHttpUrl, type GitHubSource } from './model';
export type GitHubPage = { repositories: GitHubSource[]; hasNext: boolean; page: number };
export function parseGitHubRepository(raw: unknown): GitHubSource {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw))
    throw new ContractError('Некорректный ответ GitHub.');
  const r = raw as Record<string, unknown>;
  for (const key of ['id', 'stargazers_count', 'forks_count'])
    if (!Number.isSafeInteger(r[key]) || (r[key] as number) < (key === 'id' ? 1 : 0))
      throw new ContractError('Некорректный ответ GitHub.');
  for (const key of ['name', 'full_name', 'html_url', 'updated_at'])
    if (typeof r[key] !== 'string' || !(r[key] as string))
      throw new ContractError('Некорректный ответ GitHub.');
  if (
    (r.name as string).length > 120 ||
    (r.full_name as string).length > 300 ||
    !safeHttpUrl(r.html_url as string) ||
    typeof r.fork !== 'boolean' ||
    typeof r.archived !== 'boolean' ||
    !(r.description === null || typeof r.description === 'string') ||
    !(r.language === null || typeof r.language === 'string') ||
    (typeof r.description === 'string' && r.description.length > 4000) ||
    (typeof r.language === 'string' && r.language.length > 60) ||
    !Number.isFinite(Date.parse(r.updated_at as string))
  )
    throw new ContractError('Некорректный ответ GitHub.');
  return {
    repositoryId: r.id as number,
    name: r.name as string,
    fullName: r.full_name as string,
    htmlUrl: r.html_url as string,
    description: r.description as string | null,
    language: r.language as string | null,
    stars: r.stargazers_count as number,
    forks: r.forks_count as number,
    isFork: r.fork,
    archived: r.archived,
    updatedAt: new Date(r.updated_at as string).toISOString(),
  };
}
export async function loadGitHubPage(
  username: string,
  page: number,
  signal: AbortSignal,
  fetcher: typeof fetch = fetch,
): Promise<GitHubPage> {
  const canonical = normalizeGitHubUsername(username);
  if (!canonical || !Number.isSafeInteger(page) || page < 1 || page > 100)
    throw new ContractError('Некорректный GitHub-профиль.');
  const response = await fetcher(
    `https://api.github.com/users/${encodeURIComponent(canonical)}/repos?per_page=100&sort=updated&type=owner&page=${page}`,
    {
      headers: { Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28' },
      signal,
    },
  );
  if (!response.ok) {
    const reset = response.headers.get('x-ratelimit-reset');
    throw new Error(
      response.status === 403 || response.status === 429
        ? `GitHub ограничил запросы. Повторите позднее${reset && Number.isFinite(Number(reset)) ? ` — после ${new Date(Number(reset) * 1000).toLocaleTimeString('ru')}` : ''}.`
        : response.status === 404
          ? 'GitHub-профиль не найден.'
          : 'Не удалось загрузить репозитории. Повторите попытку.',
    );
  }
  const raw = await response.json();
  if (!Array.isArray(raw) || raw.length > 100)
    throw new ContractError('Некорректный ответ GitHub.');
  const repositories = raw.map(parseGitHubRepository);
  if (new Set(repositories.map((r) => r.repositoryId)).size !== repositories.length)
    throw new ContractError('GitHub вернул повторяющиеся репозитории.');
  return { repositories, page, hasNext: /rel="next"/.test(response.headers.get('link') ?? '') };
}
export const gitHubCacheKey = (owner: string, username: string) =>
  `stackcard.github-repositories.${encodeURIComponent(owner)}.${normalizeGitHubUsername(username)}`;
export function readGitHubCache(
  storage: Pick<Storage, 'getItem'>,
  owner: string,
  username: string,
): GitHubPage[] {
  try {
    const raw = JSON.parse(storage.getItem(gitHubCacheKey(owner, username)) ?? 'null');
    if (
      !raw ||
      raw.version !== 1 ||
      raw.owner !== owner ||
      raw.username !== normalizeGitHubUsername(username) ||
      !Array.isArray(raw.pages) ||
      raw.pages.length > 100
    )
      return [];
    return raw.pages.map((p: GitHubPage, i: number) => {
      if (
        p.page !== i + 1 ||
        typeof p.hasNext !== 'boolean' ||
        !Array.isArray(p.repositories) ||
        p.repositories.length > 100
      )
        throw new ContractError();
      for (const r of p.repositories) {
        parseGitHubRepository({
          id: r.repositoryId,
          name: r.name,
          full_name: r.fullName,
          html_url: r.htmlUrl,
          description: r.description,
          language: r.language,
          stargazers_count: r.stars,
          forks_count: r.forks,
          fork: r.isFork,
          archived: r.archived,
          updated_at: r.updatedAt,
        });
      }
      return p;
    });
  } catch {
    return [];
  }
}
export function writeGitHubCache(
  storage: Pick<Storage, 'setItem'>,
  owner: string,
  username: string,
  pages: GitHubPage[],
): void {
  storage.setItem(
    gitHubCacheKey(owner, username),
    JSON.stringify({ version: 1, owner, username: normalizeGitHubUsername(username), pages }),
  );
}
