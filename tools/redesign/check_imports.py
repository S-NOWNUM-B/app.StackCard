#!/usr/bin/env python3
"""Проверка импортированных Design v2 assets и source map без сети и запуска app."""

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import struct
import sys
import xml.etree.ElementTree as ET


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def svg_evidence(data):
    text = data.decode('utf-8')
    if re.search(r'<!DOCTYPE|<!ENTITY|@import', text, re.I):
        raise ValueError('DOCTYPE/entity/external CSS is not a vector asset')
    root = ET.fromstring(text)
    if root.tag.split('}')[-1] != 'svg':
        raise ValueError('Root is not SVG')
    forbidden = {'script', 'image', 'foreignObject', 'audio', 'video',
                 'animate', 'animateMotion', 'animateTransform', 'set'}
    for node in root.iter():
        if node.tag.split('}')[-1] in forbidden:
            raise ValueError('Raster/script/animation element')
        for attr, value in node.attrib.items():
            attr = attr.split('}')[-1].lower()
            if attr.startswith('on') or attr == 'src':
                raise ValueError('Event handler or external source')
            if attr == 'href' and not value.startswith('#'):
                raise ValueError('Nonlocal href')
        for value in [node.text or '', *node.attrib.values()]:
            for target in re.findall(r'url\s*\(\s*[\"\']?([^\)\"\']+)', value, re.I):
                if not target.strip().startswith('#'):
                    raise ValueError('Nonlocal CSS url')
    return {'viewBox': root.get('viewBox'), 'width': root.get('width'),
            'height': root.get('height'), 'elements': sum(1 for _ in root.iter()),
            'vectorOnly': True}


def flutter_render_evidence(source_data, render_data):
    """Допустима только inline-форма исходной заливки без изменения геометрии."""
    evidence = svg_evidence(render_data)
    source = ET.fromstring(source_data)
    render = ET.fromstring(render_data)
    if source.tag != render.tag or source.attrib != render.attrib:
        raise ValueError('Flutter render root attributes/viewBox differ from source')
    polygons = [node for node in source if node.tag.split('}')[-1] == 'polygon']
    rendered = list(render)
    if len(polygons) != 3 or len(rendered) != 3:
        raise ValueError('Flutter render must preserve all3 source polygons')
    for node in render.iter():
        if node.tag.split('}')[-1] == 'style' or 'class' in node.attrib:
            raise ValueError('Flutter render retains unsupported stylesheet/class')
    for original, actual in zip(polygons, rendered):
        expected = {key: value for key, value in original.attrib.items() if key != 'class'}
        expected.update(fill='#fff', opacity='0.72')
        if (original.get('class') != 'cls-1' or original.tag != actual.tag
                or actual.attrib != expected or len(actual)):
            raise ValueError('Flutter render polygon geometry/order/fill/opacity drift')
    return {**evidence, 'sourceGeometryPreserved': True, 'polygonCount': 3,
            'fill': '#fff', 'opacity': '0.72'}


def font_evidence(data):
    if data[:4] != b'\x00\x01\x00\x00':
        raise ValueError('Expected static TrueType sfnt')
    count = struct.unpack_from('>H', data, 4)[0]
    tables = {}
    for index in range(count):
        name, _, offset, size = struct.unpack_from('>4sIII', data, 12 + index * 16)
        if offset + size > len(data):
            raise ValueError('Font table beyond file')
        tables[name.decode('ascii')] = data[offset:offset + size]
    if 'fvar' in tables:
        raise ValueError('Variable font substituted for approved static font')
    weight = struct.unpack_from('>H', tables['OS/2'], 4)[0]
    fs_type = struct.unpack_from('>H', tables['OS/2'], 8)[0]
    cmap = tables['cmap']
    subtables = []
    for index in range(struct.unpack_from('>H', cmap, 2)[0]):
        platform, encoding, offset = struct.unpack_from('>HHI', cmap, 4 + index * 8)
        if platform == 0 or (platform == 3 and encoding in (1, 10)):
            subtables.append(cmap[offset:])

    def glyph(subtable, codepoint):
        format_id = struct.unpack_from('>H', subtable)[0]
        if format_id == 12:
            for index in range(struct.unpack_from('>I', subtable, 12)[0]):
                start, end, first = struct.unpack_from('>III', subtable, 16 + index * 12)
                if start <= codepoint <= end:
                    return first + codepoint - start
        elif format_id == 4 and codepoint <= 0xffff:
            segments = struct.unpack_from('>H', subtable, 6)[0] // 2
            starts = 14 + segments * 2 + 2
            deltas = starts + segments * 2
            offsets = deltas + segments * 2
            for index in range(segments):
                start = struct.unpack_from('>H', subtable, starts + index * 2)[0]
                end = struct.unpack_from('>H', subtable, 14 + index * 2)[0]
                if not start <= codepoint <= end:
                    continue
                delta = struct.unpack_from('>h', subtable, deltas + index * 2)[0]
                relative = struct.unpack_from('>H', subtable, offsets + index * 2)[0]
                if relative == 0:
                    return (codepoint + delta) & 0xffff
                location = offsets + index * 2 + relative + (codepoint - start) * 2
                mapped = struct.unpack_from('>H', subtable, location)[0]
                return (mapped + delta) & 0xffff if mapped else 0
        return 0

    required = [*range(0x41, 0x5b), *range(0x61, 0x7b),
                *range(0x410, 0x450), 0x401, 0x451]
    missing = [hex(cp) for cp in required if not any(glyph(table, cp) for table in subtables)]
    if missing:
        raise ValueError('Missing Latin/Russian glyphs: ' + ', '.join(missing))
    return {'weight': weight, 'static': True, 'fsType': fs_type,
            'latinRussianCodepoints': len(required), 'nativeRenderingVerified': False}


def validate(repo, require_brand=True):
    mobile = repo / 'apps/mobile'
    manifest_path = mobile / 'assets/design_v2/source-manifest.json'
    manifest = json.loads(manifest_path.read_text())
    errors, files = [], []

    def check(condition, message):
        if not condition:
            errors.append(message)

    def project_path(base, relative):
        target = (base / relative).resolve()
        if not target.is_relative_to(base.resolve()):
            raise ValueError('Source manifest path escapes its project: ' + relative)
        return target

    entries = manifest['entries']
    canonical = [x for x in entries if x['kind'] != 'brand-svg']
    brands = [x for x in entries if x['kind'] == 'brand-svg']
    derivatives = manifest.get('renderDerivatives', [])
    check(len(canonical) == 31, 'Expected31 shared asset/license/notice records')
    check(len(brands) == 9 if require_brand else len(brands) in (0, 9), 'Expected9 Brand A records')
    check(len({x['assetPath'] for x in entries}) == len(entries), 'Duplicate asset paths')
    check(sum(x['kind'] == 'font' for x in entries) == manifest['fontCount'] == 4, 'Expected4 fonts')
    check(sum(x['kind'] == 'svg' for x in entries) == manifest['svgCount'] == 23, 'Expected23 canonical SVGs')
    check(sum(x['kind'] in ('license', 'notice') for x in entries) == manifest['licenseAndNoticeCount'] == 4, 'Expected4 license/notice files')
    check(len(derivatives) == manifest.get('renderDerivativeSvgCount') == 1, 'Expected1 Flutter render derivative')
    check(manifest.get('totalSvgCount') == 23 + len(brands) + len(derivatives), 'Total SVG count drift')
    check({x['weight'] for x in entries if x['kind'] == 'font'} == {400, 600, 700, 800}, 'Font weight records drift')
    expected_mains = {
        '100:10': ('110:282', 'mark', 'Accent'),
        '110:276': ('110:282', 'mark', 'Ink'),
        '110:279': ('110:282', 'mark', 'Paper'),
        '111:269': ('111:284', 'wordmark', 'Accent'),
        '111:274': ('111:284', 'wordmark', 'Ink'),
        '111:279': ('111:284', 'wordmark', 'Paper'),
        '111:285': ('111:297', 'app-icon', 'Accent'),
        '111:289': ('111:297', 'app-icon', 'MonoDark'),
        '111:293': ('111:297', 'app-icon', 'MonoLight'),
    }
    if require_brand or brands:
        check({x['figmaMainId'] for x in brands} == set(expected_mains), 'Unapproved/missing Brand A mains')
    pubspec = (mobile / 'pubspec.yaml').read_text()
    declarations = set(re.findall(r'^\s*-\s+(assets/[^\s]+)\s*$', pubspec, re.M))

    def registered(path):
        return path in declarations or str(Path(path).parent).rstrip('/') + '/' in declarations

    for entry in entries:
        path = entry['assetPath']
        before_errors = len(errors)
        try:
            data = project_path(mobile, path).read_bytes()
            check(len(data) == entry['bytes'] and sha256(data) == entry['sha256'], 'Source bytes/hash drift: ' + path)
            if entry['kind'] == 'font':
                evidence = font_evidence(data)
                check(evidence['weight'] == entry['weight'] and evidence['fsType'] == 0, 'Font OS/2 drift: ' + path)
                check(entry['sourceCommit'] == '6f81ebecdf65e4463b798cc07b16a4f8d5216917', 'Font commit drift')
                family = dict([(400, 'Regular'), (600, 'SemiBold'), (700, 'Bold'), (800, 'ExtraBold')])[entry['weight']]
                check(re.search(r'asset:\s*assets/fonts/Manrope-' + family + r'\.ttf\s*\n\s*weight:\s*' + str(entry['weight']), pubspec) is not None, 'Font pubspec weight missing: ' + path)
            elif entry['kind'] in ('svg', 'brand-svg'):
                evidence = svg_evidence(data)
                check(registered(path), 'Asset pubspec entry missing: ' + path)
                check(entry.get('vectorOnly') is True and entry.get('geometryReconstructed') is False, 'Missing original-vector provenance: ' + path)
                if entry['kind'] == 'brand-svg':
                    check((entry['figmaSetId'], entry['family'], entry['variant']) == expected_mains.get(entry['figmaMainId']), 'Brand A family/main drift: ' + path)
                    check(entry.get('originalMainComponent') is True and entry.get('raster') is False, 'Brand A source flags drift: ' + path)
                    check(entry['sourcePageId'] == '99:7' and entry['viewBox'] == evidence['viewBox'], 'Brand A source page/viewBox drift')
                    dimensions = entry['dimensions']
                    check(dimensions['width'] > 0 and dimensions['height'] > 0, 'Missing Brand A source dimensions')
                    check(entry['exportSettings'] == {'format': 'SVG_STRING', 'svgOutlineText': True, 'svgIdAttribute': True, 'svgSimplifyStroke': False, 'contentsOnly': True, 'colorProfile': 'SRGB'}, 'Brand A export settings drift')
                    if entry['family'] == 'wordmark':
                        font = entry['fontSource']
                        check('<text' not in data.decode('utf-8') and font['characters'] == 'StackCard', 'Wordmark source outline/text drift')
                        check(font['fontSize'] == 36 and font['lineHeight'] == {'unit': 'PIXELS', 'value': 44}, 'Wordmark source metrics drift')
                        check(bool(font['fontSegments']) and all(x['family'] == 'Noto Sans' and x['style'] == 'ExtraBold' for x in font['fontSegments']), 'Wordmark font exception drift')
            else:
                check(registered(path), 'License/notice pubspec entry missing: ' + path)
            files.append({'path': path, 'status': 'PASS' if len(errors) == before_errors else 'FAIL'})
        except (OSError, ValueError, KeyError, ET.ParseError, struct.error) as error:
            errors.append(path + ': ' + str(error))
            files.append({'path': path, 'status': 'FAIL'})

    # Runtime compatibility хранится отдельно от неизменённых canonical entries.
    source_path = 'assets/icons/technology/flutter.svg'
    render_path = 'assets/icons/technology/flutter.render.svg'
    check([x.get('assetPath') for x in derivatives] == [render_path], 'Unapproved/missing render derivative')
    check(manifest['technologyRendering']['flutter'].get('renderAssetPath') == render_path, 'Flutter render selection drift')
    canonical_paths = {x['assetPath']: x for x in entries}
    for derivative in derivatives:
        path = derivative.get('assetPath', '')
        before_errors = len(errors)
        try:
            check(path not in canonical_paths, 'Render derivative duplicates canonical asset: ' + path)
            check(derivative['sourceAssetPath'] == source_path, 'Unexpected render derivative source')
            original = canonical_paths[source_path]
            source_data = project_path(mobile, source_path).read_bytes()
            data = project_path(mobile, path).read_bytes()
            check(derivative['sourceSha256'] == original['sha256'] == sha256(source_data)
                  == 'e84889cedbe669bf58daa0fc69dcf73a238d4dbc772b8cf1ab48743224690a2e', 'Flutter canonical source hash drift')
            check(len(data) == derivative['bytes'] and sha256(data) == derivative['sha256'], 'Render bytes/hash drift: ' + path)
            check(derivative['transformation'] == 'inline-css-presentation-attributes'
                  and derivative['cssSelector'] == '.cls-1'
                  and derivative['presentationAttributes'] == {'fill': '#fff', 'opacity': '0.72'}, 'Flutter derivative transformation drift')
            check(all(derivative.get(key) is True for key in
                      ('geometryPreserved', 'canonicalSourcePreserved', 'vectorOnly'))
                  and derivative.get('raster') is False, 'Flutter derivative provenance drift')
            check(all(derivative[key] == original[key] for key in
                      ('sourceUrl', 'sourceArchivePath', 'figmaMainId', 'license')), 'Flutter derivative source/license drift')
            check(registered(path), 'Render pubspec entry missing: ' + path)
            evidence = flutter_render_evidence(source_data, data)
            files.append({'path': path, 'status': 'PASS' if len(errors) == before_errors else 'FAIL',
                          'renderDerivative': True, **evidence})
        except (OSError, ValueError, KeyError, ET.ParseError) as error:
            errors.append(path + ': ' + str(error))
            files.append({'path': path, 'status': 'FAIL', 'renderDerivative': True})

    ofl = (mobile / 'assets/fonts/Manrope_OFL.txt').read_text()
    lucide = (mobile / 'assets/icons/LICENSE-LUCIDE.txt').read_text()
    simple = (mobile / 'assets/icons/LICENSE-SIMPLE-ICONS.txt').read_text()
    check('Copyright 2018 The Manrope Project Authors' in ofl and 'SIL OPEN FONT LICENSE Version 1.1' in ofl, 'Manrope copyright/OFL missing')
    check('ISC License' in lucide and 'The MIT License (MIT)' in lucide and 'Copyright (c) 2013-present Cole Bemis' in lucide, 'ISC/MIT notices missing')
    check('CC0 1.0 Universal' in simple or 'Creative Commons' in simple, 'CC0 notice missing')
    check(manifest['brandA']['nativeAppIconPackagingVerified'] is False and manifest['nativeFontRenderingVerified'] is False, 'Unverified native claims')

    registry_meta = manifest['designRegistry']
    registry_bytes = project_path(repo, registry_meta['path']).read_bytes()
    check(sha256(registry_bytes) == registry_meta['sha256'], 'Registry source hash drift')
    design = json.loads(registry_bytes)
    check(set(design) == {'fileKey', 'sourceExportSha256', 'variables', 'styles'}, 'Registry must contain source metadata only')
    check(design['fileKey'] == manifest['sourceFileKey'] == '3YhNUPDIJJWB39NSBxbRr6', 'Unexpected Figma source file')
    check(design['sourceExportSha256'] == registry_meta['sourceExportSha256'], 'Original export hash drift')
    check(len(design['variables']) == registry_meta['variableCount'] == 98 and len(design['styles']) == registry_meta['textStyleCount'] == 10, 'Registry98/10 counts drift')
    variables = {x['id']: x for x in design['variables']}
    styles = {x['id']: x for x in design['styles']}
    check(len(variables) == 98 and len(styles) == 10, 'Registry duplicate IDs')
    maps = manifest['runtimeSourceMap']
    check(len(maps['colorRoles']) == 30 and len(maps['textStyles']) == 10 and len(maps['numericTokens']) == 19, 'Runtime source-map counts drift')
    check({x['sourceId'] for x in maps['colorRoles']} == {x['id'] for x in design['variables'] if x['name'].startswith('color/')}, 'Color mapping is incomplete')
    check({x['sourceId'] for x in maps['textStyles']} == set(styles), 'Style mapping is incomplete')
    check({x['sourceId'] for x in maps['numericTokens']} == {x['id'] for x in design['variables'] if x['type'] == 'FLOAT' and not x['name'].startswith('typography/')}, 'Numeric mapping is incomplete')
    colors_text = (mobile / 'lib/core/theme/stackcard_colors.dart').read_text()
    theme_text = (mobile / 'lib/core/theme/stackcard_theme.dart').read_text()
    token_text = (mobile / 'lib/core/theme/stackcard_tokens.dart').read_text()
    check(re.search(r"fontFamily:\s*'Manrope'", theme_text) is not None, 'UI font family drift')
    for mode in ('Dark', 'Light'):
        block = re.search(r'static const ' + mode.lower() + r'\s*=\s*StackCardColors\((.*?)\n\s*\);', colors_text, re.S)
        fields = dict(re.findall(r'(\w+):\s*Color\(0x([0-9a-fA-F]{8})\)', block[1] if block else ''))
        for row in maps['colorRoles']:
            variable = variables[row['sourceId']]
            check(variable['name'] == 'color/' + row['runtimeField'], 'Color field mapping drift')
            color = variable['values'][mode]
            expected = f"{round(color['alpha'] * 255):02X}" + color['hex'].lstrip('#').upper()
            check(fields.get(row['runtimeField'], '').upper() == expected, mode + ' color mismatch: ' + row['runtimeField'])
    actual_styles = {role: [float(size), int(weight), float(height), float(tracking)] for role, size, weight, height, tracking in re.findall(r'(\w+):\s*_text\(([\d.]+),\s*FontWeight.w(\d+),\s*([\d.]+),\s*(-?[\d.]+)\)', theme_text)}
    for row in maps['textStyles']:
        style = styles[row['sourceId']]
        check(style['font']['family'] == 'Manrope', 'Non-Manrope source style')
        expected = [style['size'], style['font']['variationSettings']['wght'], style['lineHeight']['value'] / style['size'], style['letterSpacing']['value']]
        for role in row['runtimeTextThemeRoles']:
            actual = actual_styles.get(role)
            check(actual is not None and all(math.isclose(a, b, abs_tol=1e-6, rel_tol=0) for a, b in zip(actual or [], expected)), 'Style mismatch: ' + role)
    for row in maps['numericTokens']:
        api, name = row['runtimeSymbol'].split('.')
        block = re.search(r'abstract final class ' + api + r'\s*\{(.*?)\n\}', token_text, re.S)
        regex = r'\b' + name + r'\s*=\s*' + (r'Duration\(milliseconds:\s*(\d+)\)' if row['unit'] == 'milliseconds' else r'([\d.]+)')
        actual = re.search(regex, block[1] if block else '')
        check(actual is not None and float(actual[1]) == variables[row['sourceId']]['values']['Value'], 'Numeric mismatch: ' + row['runtimeSymbol'])
    return {'status': 'FAIL' if errors else 'PASS', 'fonts': 4, 'canonicalSvgs': 23,
            'brandASvgs': len(brands), 'renderDerivativeSvgs': len(derivatives),
            'totalSvgs': 23 + len(brands) + len(derivatives), 'licenseNoticeFiles': 4,
            'sourceVariables': len(variables), 'sourceTextStyles': len(styles),
            'mappedColors': 30, 'mappedStyles': 10, 'mappedNumeric': 19,
            'fileChecks': files, 'errors': errors, 'pending': [], 'repositoryMutated': False,
            'nativeAppIconPackagingVerified': False, 'nativeFontRenderingVerified': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo-root', type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument('--require-brand', action='store_true')
    parser.add_argument('--require-imported', action='store_true', help='Совместимый strict flag; файлы всегда проверяются по факту')
    args = parser.parse_args()
    try:
        result = validate(args.repo_root.resolve(), require_brand=args.require_brand)
    except (OSError, ValueError, KeyError, ET.ParseError, struct.error) as error:
        result = {'status': 'FAIL', 'errors': [str(error)], 'repositoryMutated': False}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    sys.exit(0 if result['status'] == 'PASS' else 1)
