import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

// Паритет токенов web со светлой палитрой и размерами mobile: значения читаются прямо из Dart,
// поэтому расхождение на любой стороне ломает тест. Палитру mobile менять нельзя, web подгоняется.
const css = readFileSync(new URL('../src/app/globals.css', import.meta.url), 'utf8');
const dir = new URL('../../mobile/lib/core/theme/', import.meta.url);
const colorsDart = readFileSync(new URL('stackcard_colors.dart', dir), 'utf8');
const tokensDart = readFileSync(new URL('stackcard_tokens.dart', dir), 'utf8');
const themeDart = readFileSync(new URL('stackcard_theme.dart', dir), 'utf8');

const lightBlock = colorsDart.slice(
  colorsDart.indexOf('static const light = StackCardColors('),
  colorsDart.indexOf('final Color background;'),
);
const dartColor = (name: string) => {
  const match = new RegExp(`\\b${name}:\\s*Color\\(0xFF([0-9A-Fa-f]{6})\\)`).exec(lightBlock);
  assert.ok(match, `в светлой палитре mobile нет ${name}`);
  return `#${match[1].toLowerCase()}`;
};
const root = css.slice(css.indexOf(':root {'), css.indexOf('}', css.indexOf(':root {')));
const cssVar = (name: string) => {
  const match = new RegExp(`${name}:\\s*(#[0-9A-Fa-f]{6}|\\d+px);`).exec(root);
  assert.ok(match, `в :root нет ${name}`);
  return match[1].toLowerCase();
};
const dartNumber = (name: string) => {
  const match = new RegExp(`static const double ${name} = (\\d+);`).exec(tokensDart);
  assert.ok(match, `в токенах mobile нет ${name}`);
  return Number(match[1]);
};
const rule = (selector: string) => {
  const start = css.indexOf(`\n${selector} {`);
  assert.ok(start >= 0, `нет правила ${selector}`);
  return css.slice(start, css.indexOf('}', start));
};

// web-переменная → роль в палитре mobile (по назначению, не по имени)
const colorRoles: Record<string, string> = {
  '--background': 'background',
  '--surface': 'surface',
  '--surface-elevated': 'surfaceElevated',
  '--primary': 'primary',
  '--on-primary': 'onPrimary',
  '--text': 'textPrimary',
  '--muted': 'textSecondary',
  '--border': 'border',
  '--outline': 'controlOutline',
  '--danger': 'error',
  '--success': 'success',
  '--focus': 'focus',
};

test('цвета web совпадают со светлой палитрой mobile по ролям', () => {
  for (const [variable, role] of Object.entries(colorRoles))
    assert.equal(cssVar(variable), dartColor(role), `${variable} ↔ ${role}`);
});

test('радиусы и размеры controls совпадают с mobile', () => {
  assert.equal(cssVar('--radius-sm'), `${dartNumber('small')}px`);
  assert.equal(cssVar('--radius'), `${dartNumber('medium')}px`);
  assert.equal(cssVar('--radius-lg'), `${dartNumber('large')}px`);
  assert.match(rule('.button'), new RegExp(`min-height: ${dartNumber('touchTarget')}px`));
  assert.match(
    rule('.field input,\n.field textarea,\nselect'),
    new RegExp(`min-height: ${dartNumber('inputHeight')}px`),
  );
});

test('шрифт кнопки web равен labelLarge mobile', () => {
  const match = /labelLarge: _text\((\d+),/.exec(themeDart);
  assert.ok(match, 'в теме mobile нет labelLarge');
  assert.match(rule('.button'), new RegExp(`font-size: ${match[1]}px`));
});

test('кольцо фокуса web чёрное (ink), как у mobile', () => {
  assert.equal(cssVar('--focus'), dartColor('focus'));
  assert.match(rule(':focus-visible'), /outline: 2px solid var\(--focus\)/);
});

// Контраст WCAG: текст ≥ 4.5, не текстовые границы controls и фокус ≥ 3
function luminance(hex: string) {
  const channel = [1, 3, 5].map((index) => {
    const value = parseInt(hex.slice(index, index + 2), 16) / 255;
    return value <= 0.03928 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * channel[0] + 0.7152 * channel[1] + 0.0722 * channel[2];
}
const contrast = (a: string, b: string) => {
  const [high, low] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (high + 0.05) / (low + 0.05);
};

test('пары текст и фон проходят WCAG AA на основных поверхностях', () => {
  const background = cssVar('--background');
  const elevated = cssVar('--surface-elevated');
  for (const surface of [background, elevated]) {
    assert.ok(contrast(cssVar('--text'), surface) >= 4.5, `text на ${surface}`);
    assert.ok(contrast(cssVar('--muted'), surface) >= 4.5, `muted на ${surface}`);
    assert.ok(contrast(cssVar('--danger'), surface) >= 4.5, `danger на ${surface}`);
  }
  assert.ok(contrast(cssVar('--success'), background) >= 4.5, 'success на белом');
  assert.ok(contrast(cssVar('--on-primary'), cssVar('--primary')) >= 4.5, 'текст кнопки');
  assert.ok(contrast(cssVar('--outline'), background) >= 3, 'граница controls');
  assert.ok(contrast(cssVar('--focus'), background) >= 3, 'кольцо фокуса');
});
