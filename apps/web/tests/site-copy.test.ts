import assert from 'node:assert/strict';
import test from 'node:test';
import { exampleDocumentContent } from '../src/components/document-view';
import { generateMetadata } from '../src/app/d/[publicId]/page';

// Правило владельца: в конце текстов сайта нет точки.
test('demo document texts have no trailing period', () => {
  const content = exampleDocumentContent('portfolio');
  const texts = [
    content.profile.bio,
    content.profile.headline,
    ...content.projects.map((project) => project.description),
  ].filter(Boolean);
  assert.ok(texts.length > 0);
  for (const text of texts) assert.ok(!/[.…]$/.test(text), `trailing period: ${text}`);
});

test('public page fallback metadata description has no trailing period', async () => {
  const metadata = await generateMetadata({
    params: Promise.resolve({ publicId: 'not-a-valid-id' }),
  });
  assert.ok(typeof metadata.description === 'string' && metadata.description.length > 0);
  assert.ok(!/[.…]$/.test(metadata.description as string));
});
