import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from check_imports import dark_palette_errors, technology_icons_evidence


class TechnologyIntegrityTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.mobile = Path(self.temporary.name)
        self.base = self.mobile / 'assets/icons/technology'
        (self.base / 'simple-icons').mkdir(parents=True)
        (self.mobile / 'assets/icons/LICENSE-SIMPLE-ICONS.txt').write_text('CC0')
        self.svg = self.base / 'simple-icons/test.svg'
        self.manifest = {
            'project': 'Simple Icons', 'commit': 'a' * 40, 'license': 'CC0-1.0',
            'icons': [{'slug': 'test', 'sourceUrl':
                       f'https://raw.githubusercontent.com/simple-icons/simple-icons/{"a" * 40}/icons/test.svg'}],
        }
        self.write(b'<svg xmlns="http://www.w3.org/2000/svg"><path d="M0 0"/></svg>')

    def write(self, data):
        self.svg.write_bytes(data)
        self.manifest['icons'][0].update(bytes=len(data), sha256=hashlib.sha256(data).hexdigest())
        self.save_manifest()

    def save_manifest(self):
        (self.base / 'SIMPLE-ICONS-MANIFEST.json').write_text(json.dumps(self.manifest))

    def test_pinned_vector_passes_and_modified_bytes_fail(self):
        self.assertEqual(technology_icons_evidence(self.mobile), 1)
        self.svg.write_bytes(self.svg.read_bytes() + b' ')
        with self.assertRaisesRegex(ValueError, 'bytes/hash drift'):
            technology_icons_evidence(self.mobile)

    def test_even_matching_hash_does_not_allow_active_or_external_svg(self):
        for payload in [b'<svg><script/></svg>', b'<svg><image href="https://example.com/a"/></svg>']:
            self.write(payload)
            with self.assertRaises(ValueError):
                technology_icons_evidence(self.mobile)

    def test_inventory_rejects_unlisted_missing_and_duplicate_icons(self):
        extra = self.svg.with_name('extra.svg')
        extra.write_bytes(self.svg.read_bytes())
        with self.assertRaisesRegex(ValueError, 'inventory'):
            technology_icons_evidence(self.mobile)
        extra.unlink()
        self.manifest['icons'].append(self.manifest['icons'][0].copy())
        self.save_manifest()
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            technology_icons_evidence(self.mobile)
        self.manifest['icons'].pop()
        self.save_manifest()
        self.svg.unlink()
        with self.assertRaises(OSError):
            technology_icons_evidence(self.mobile)

    def test_provenance_and_path_traversal_fail(self):
        self.manifest['icons'][0]['slug'] = '../test'
        self.save_manifest()
        with self.assertRaisesRegex(ValueError, 'slug'):
            technology_icons_evidence(self.mobile)
        self.manifest['icons'][0]['slug'] = 'test'
        self.manifest['icons'][0]['sourceUrl'] = 'https://example.com/test.svg'
        self.save_manifest()
        with self.assertRaisesRegex(ValueError, 'source drift'):
            technology_icons_evidence(self.mobile)


class DarkPaletteGateTest(unittest.TestCase):
    LIGHT = 'static const light = StackCardColors(\n  background: Color(0xFFFFFFFF),\n  textMuted: Color(0xFF71717A),\n);\n'
    DARK = 'static const dark = StackCardColors(\n  background: Color(0xFF0E0E10),\n  textMuted: Color(0xFF9A9AA4),\n);\n'
    THEME = ('static final light = _build(Brightness.light, StackCardColors.light);\n'
             'static final dark = _build(Brightness.dark, StackCardColors.dark);\n')

    def test_separate_complete_palette_passes_without_matching_light(self):
        self.assertEqual(dark_palette_errors(self.LIGHT + self.DARK, self.THEME), [])

    def test_alias_of_light_fails(self):
        errors = dark_palette_errors(self.LIGHT + 'static const dark = light;\n', self.THEME)
        self.assertTrue(any('separate palette' in error for error in errors))

    def test_missing_and_unknown_tokens_fail(self):
        short = self.DARK.replace('  textMuted: Color(0xFF9A9AA4),\n', '')
        self.assertTrue(any('lacks tokens: textMuted' in e for e in dark_palette_errors(self.LIGHT + short, self.THEME)))
        extra = self.DARK.replace('  background', '  invented: Color(0xFF000000),\n  background')
        self.assertTrue(any('unknown tokens: invented' in e for e in dark_palette_errors(self.LIGHT + extra, self.THEME)))

    def test_themes_must_use_their_own_palettes(self):
        theme = self.THEME.replace('Brightness.dark, StackCardColors.dark', 'Brightness.dark, StackCardColors.light')
        self.assertTrue(dark_palette_errors(self.LIGHT + self.DARK, theme))


if __name__ == '__main__':
    unittest.main()
