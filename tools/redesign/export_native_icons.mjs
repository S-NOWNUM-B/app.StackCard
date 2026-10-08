#!/usr/bin/env node
// macOS zsh/bash: SHARP_MODULE_ROOT=/path/to/node_modules node tools/redesign/export_native_icons.mjs [--check]
// Источник не изменяется; --check проверяет размеры, непрозрачность и точный повтор экспорта.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { basename, dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const sharp = require(process.env.SHARP_MODULE_ROOT
  ? join(process.env.SHARP_MODULE_ROOT, 'sharp') : 'sharp');
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const checkOnly = process.argv.includes('--check');
assert(process.argv.slice(2).every((arg) => arg === '--check'), 'Unknown argument');

const sourceManifestPath = 'apps/mobile/assets/design_v2/source-manifest.json';
const manifestPath = 'docs/redesign/source/native-app-icons.json';
const sourcePath = 'apps/mobile/assets/branding/design_v2/stackcard-v2-app-icon-accent.svg';
const sourceManifest = JSON.parse(await readFile(join(root, sourceManifestPath), 'utf8'));
const sourceEntry = sourceManifest.entries.find((entry) =>
  entry.assetPath === 'assets/branding/design_v2/stackcard-v2-app-icon-accent.svg');
assert(sourceEntry?.kind === 'brand-svg' && sourceEntry.family === 'app-icon');
const source = await readFile(join(root, sourcePath));
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
assert.equal(sha256(source), sourceEntry.sha256, 'Pinned source digest changed');
assert.equal(source.length, sourceEntry.bytes, 'Pinned source size changed');
assert.equal(sourceEntry.viewBox, '0 0 108 108', 'Unexpected source geometry');
const background = source.toString('utf8').match(/<path\b[^>]*\bfill="(#[0-9a-fA-F]{6})"/u)?.[1];
assert.equal(background, '#070708', 'Unexpected source background');

const androidDirectory = 'apps/mobile/android/app/src/main/res';
const targets = Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })
  .map(([density, size]) => ({
    platform: 'android',
    path: `${androidDirectory}/mipmap-${density}/ic_launcher.png`,
    size,
    opaque: false,
  }));
const iosDirectory = 'apps/mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset';
const iosContentsPath = `${iosDirectory}/Contents.json`;
const iosContentsBytes = await readFile(join(root, iosContentsPath));
const iosContents = JSON.parse(iosContentsBytes);
const iosTargets = new Map();
for (const item of iosContents.images) {
  assert.equal(basename(item.filename), item.filename, 'Unsafe AppIcon filename');
  const [width, height] = item.size.split('x').map(Number);
  const scale = Number(item.scale.replace(/x$/u, ''));
  const size = width * scale;
  assert(width === height && Number.isSafeInteger(size) && size > 0 && size <= 1024,
    'Unsupported AppIcon size');
  assert(!iosTargets.has(item.filename) || iosTargets.get(item.filename).size === size,
    'Conflicting AppIcon filename size');
  iosTargets.set(item.filename, {
    platform: 'ios', path: `${iosDirectory}/${item.filename}`, size, opaque: true,
  });
}
targets.push(...iosTargets.values());
targets.sort((a, b) => a.path < b.path ? -1 : a.path > b.path ? 1 : 0);

const outputs = [];
for (const target of targets) {
  let render = sharp(source, { density: Math.max(72, 72 * target.size / 108) })
    .resize(target.size, target.size, { fit: 'fill' });
  // iOS требует opaque PNG; прозрачные углы заполняются тем же исходным фоном.
  if (target.opaque) render = render.flatten({ background }).removeAlpha();
  const bytes = await render.png({ compressionLevel: 9, adaptiveFiltering: false }).toBuffer();
  const metadata = await sharp(bytes).metadata();
  assert.equal(metadata.width, target.size);
  assert.equal(metadata.height, target.size);
  assert.equal(metadata.format, 'png');
  assert.equal(metadata.hasAlpha, !target.opaque, 'Unexpected platform alpha');
  if (target.opaque) {
    const stats = await sharp(bytes).stats();
    assert.equal(stats.isOpaque, true, 'iOS icon must be opaque');
  }
  if (checkOnly) {
    assert((await readFile(join(root, target.path))).equals(bytes),
      `Export drift: ${target.path}`);
  } else {
    await writeFile(join(root, target.path), bytes);
  }
  outputs.push({
    platform: target.platform,
    path: target.path,
    width: target.size,
    height: target.size,
    bytes: bytes.length,
    sha256: sha256(bytes),
    hasAlpha: metadata.hasAlpha,
  });
}

const manifest = {
  schemaVersion: 1,
  source: {
    path: sourcePath,
    sha256: sourceEntry.sha256,
    figmaMainId: sourceEntry.figmaMainId,
    sourceUrl: sourceEntry.sourceUrl,
    originalSourceManifest: sourceManifestPath,
    originalBytesPreserved: true,
  },
  generator: {
    path: 'tools/redesign/export_native_icons.mjs',
    sharp: sharp.versions.sharp,
    vips: sharp.versions.vips,
    png: sharp.versions.png,
  },
  iosContents: { path: iosContentsPath, sha256: sha256(iosContentsBytes) },
  conversion: {
    android: 'Scale original SVG to existing mipmap size; preserve source alpha/fills/geometry.',
    ios: 'Scale original SVG; flatten transparent corners on original #070708 background; RGB PNG.',
    markGeometryChanged: false,
    tintApplied: false,
    splashChanged: false,
  },
  evidence: {
    rasterDimensionsAndAlphaChecked: true,
    nativeBuildVerified: false,
    nativeLaunchVerified: false,
    visualAcceptanceVerified: false,
  },
  outputs,
};
const report = `${JSON.stringify(manifest, null, 2)}\n`;
if (checkOnly) {
  assert.equal(await readFile(join(root, manifestPath), 'utf8'), report,
    'Native icon provenance manifest drift');
} else {
  await writeFile(join(root, manifestPath), report);
}
console.log(`${checkOnly ? 'Checked' : 'Exported'} ${outputs.length} native AppIcons; pinned source preserved; iOS PNGs opaque.`);
