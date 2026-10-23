// Контрактный мост: настоящий web parser + trusted projection, без Firestore/network.
import assert from 'node:assert/strict';
import { readFileSync, writeFileSync } from 'node:fs';
import { Timestamp } from 'firebase/firestore';
import { decodeDraft, mainDocument, resolveDocument, validateWorkspace } from '../src/lib/model.ts';
import { parsePublicDocument } from '../src/lib/public-document.ts';
import {
  permanentPublicId,
  projectPublicDocument,
} from '../../../firebase/functions/src/projection.mjs';

const [input, output] = process.argv.slice(2);
assert(input && output, 'Expected cloud7 input and projection output');
const raw = JSON.parse(readFileSync(input, 'utf8'));
const draft = decodeDraft(
  { ...raw, updatedAt: Timestamp.fromDate(new Date(raw.updatedAt)) },
  'owner',
);
const workspace = validateWorkspace(draft.content, 'owner');
const main = mainDocument(workspace);
assert(main);
assert.equal(workspace.documents.length, 1);
assert.equal(workspace.personalization.status, 'completed');
const publicId = permanentPublicId('owner', main.id);
const projection = projectPublicDocument(workspace, main.id, 'owner', publicId, 1, raw.mutationId);
assert.deepEqual(projection.media, []);
const publicDocument = { ...projection.publicDocument, publishedAt: '2026-10-21T00:00:00.000Z' };
const parsed = parsePublicDocument(publicDocument, publicId);
assert(parsed);
assert.equal(parsed.content.profile.name, resolveDocument(workspace, main).profile.name);
assert.equal(parsed.content.projects.length, 2);
assert(!JSON.stringify(publicDocument).includes('PRIVATE_'));
writeFileSync(
  output,
  JSON.stringify({
    cloud: { ...raw, content: workspace },
    publicDocument,
    publication: {
      documentId: main.id,
      publicId,
      version: 1,
      url: `https://portfolio.example/d/${publicId}`,
    },
  }),
);
