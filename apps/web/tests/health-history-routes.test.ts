import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ownerView } from '../src/components/workspace';
import { editorSectionId } from '../src/components/content-editor';
import { healthEditorSection } from '../src/components/portfolio-health';
import { healthSections, type HealthSection } from '../src/lib/portfolio-health';

test('адреса здоровья и истории распознаются, чужие ведут на Главную', () => {
  assert.equal(ownerView('health'), 'health');
  assert.equal(ownerView('history'), 'history');
  assert.equal(ownerView('history/1731751200000-3f9a1c2b'), 'history/1731751200000-3f9a1c2b');
  assert.equal(ownerView('history/'), 'home');
  assert.equal(ownerView('history/a/b'), 'home');
  assert.equal(ownerView('history/<script>'), 'home');
  assert.equal(ownerView('health/x'), 'home');
});

test('каждый совет здоровья, кроме публикации, ведёт в существующий раздел редактора', () => {
  const editorIds = new Set([
    editorSectionId('profile'),
    editorSectionId('links'),
    editorSectionId('skills'),
    editorSectionId('featuredProjects'),
    editorSectionId('experience'),
    editorSectionId('education'),
  ]);
  const sections = Object.keys(healthSections) as HealthSection[];
  for (const section of sections.filter((item) => item !== 'publication'))
    assert.ok(
      editorIds.has(healthEditorSection[section as keyof typeof healthEditorSection]),
      section,
    );
  assert.equal('publication' in healthEditorSection, false);
});
