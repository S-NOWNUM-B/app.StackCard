import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
const root = new URL('../../../', import.meta.url);
const publicRoot = new URL('../public/', import.meta.url);
const manifest = JSON.parse(readFileSync(new URL('asset-sources.json', publicRoot), 'utf8')) as {
  assets: { path: string; source: string; sha256: string }[];
  demoPortrait: { path: string; sha256: string };
};
const hash = (bytes: Buffer) => createHash('sha256').update(bytes).digest('hex');
test('Brand A/font/icon runtime files preserve the imported original source bytes', () => {
  assert.equal(manifest.assets.length, 37);
  for (const entry of manifest.assets) {
    assert.equal(hash(readFileSync(new URL(entry.path, publicRoot))), entry.sha256, entry.path);
    assert.equal(hash(readFileSync(new URL(entry.source, root))), entry.sha256, entry.source);
  }
  const svg = readFileSync(
    new URL('branding/stackcard-v2-wordmark-accent.svg', publicRoot),
    'utf8',
  );
  assert.match(svg, /viewBox="0 0 350 48"/);
  assert.equal(
    hash(readFileSync(new URL(manifest.demoPortrait.path, publicRoot))),
    manifest.demoPortrait.sha256,
  );
});
test('every literal UI icon resolves to a local licensed asset and original typography is local', () => {
  for (const name of [
    'home',
    'file-text',
    'folder',
    'panels-top-left',
    'settings',
    'search',
    'image',
    'user-round',
    'chevron-down',
  ]) {
    assert.match(readFileSync(new URL(`icons/lucide/${name}.svg`, publicRoot), 'utf8'), /<svg/);
  }
  const css = readFileSync(new URL('../src/app/globals.css', import.meta.url), 'utf8');
  assert.match(css, /Manrope-Regular\.ttf/);
  assert.equal(css.includes('fonts.googleapis.com'), false);
  assert.match(
    readFileSync(new URL('licenses/Manrope_OFL.txt', publicRoot), 'utf8'),
    /SIL OPEN FONT LICENSE/,
  );
});
