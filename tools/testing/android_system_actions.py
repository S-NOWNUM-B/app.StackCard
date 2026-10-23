"""Local Android Card/QR/Share/Open coordinator; never sends to a recipient."""

import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import subprocess
import threading
import time
from urllib.parse import parse_qs, urlparse
from urllib.request import urlopen
import xml.etree.ElementTree as ET


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--adb', required=True)
    parser.add_argument('--device', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    for key, value in {'GCLOUD_PROJECT': 'demo-stackcard-test',
                       'FIRESTORE_EMULATOR_HOST': '127.0.0.1:8085',
                       'FIREBASE_AUTH_EMULATOR_HOST': '127.0.0.1:9099'}.items():
        if os.environ.get(key) != value:
            parser.error(f'{key} must be {value}')
    root = Path(__file__).resolve().parents[2]
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    report = {'status': 'waiting', 'device': args.device,
              'scope': 'Android emulator native channels and local anonymous Next SSR',
              'physicalCamera': 'not available; screenshot independently decoded by Vision',
              'recipientSelected': False, 'checkpoints': []}
    lock = threading.Lock()

    def adb(*command):
        return subprocess.check_output([args.adb, '-s', args.device, *command], timeout=20)

    def screen(stage):
        file = output.with_name(f'{output.stem}-{stage}.png')
        file.write_bytes(adb('exec-out', 'screencap', '-p'))
        return file

    def dump():
        adb('shell', 'uiautomator', 'dump', '/sdcard/stackcard-system.xml')
        return adb('shell', 'cat', '/sdcard/stackcard-system.xml').decode()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            try:
                path = urlparse(self.path)
                stage = path.path[1:]
                url = parse_qs(path.query)['url'][0]
                parsed = urlparse(url)
                assert parsed.scheme == 'http' and parsed.netloc == '127.0.0.1:3800'
                assert parsed.path.startswith('/d/') and len(parsed.path) == 35
                assert not parsed.query and not parsed.fragment
                if stage == 'card':
                    screenshot = screen(stage)
                    decoded = subprocess.check_output(
                        ['swift', str(root / 'tools/testing/qr_decode.swift'), str(screenshot), url],
                        text=True, timeout=60).strip()
                    assert decoded == url
                    html = urlopen(url, timeout=20).read().decode()
                    assert 'Native saved author' in html
                    assert all(s not in html for s in ['PRIVATE_EDITOR_BUFFER', 'PRIVATE_SAVED_NOTE'])
                    result = {'stage': stage, 'decodedExactUrl': url,
                              'anonymousHttp200': True, 'privateMarkersAbsent': True}
                elif stage == 'share':
                    deadline = time.monotonic() + 20
                    while True:
                        xml = dump()
                        texts = [n.attrib.get('text', '') for n in ET.fromstring(xml).iter('node')]
                        if url in texts:
                            break
                        if time.monotonic() > deadline:
                            raise AssertionError('Exact URL missing from native share sheet')
                        time.sleep(.25)
                    screenshot = screen(stage)
                    output.with_name(f'{output.stem}-share.xml').write_text(xml)
                    activity = adb('shell', 'dumpsys', 'activity', 'activities').decode()
                    resumed = [line for line in activity.splitlines() if 'mResumedActivity:' in line or 'topResumedActivity=' in line]
                    assert any('ChooserActivity' in line for line in resumed), resumed
                    adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
                    result = {'stage': stage, 'exactPreviewText': url,
                              'androidChooser': True, 'resumedActivity': resumed, 'cancelledWithoutRecipient': True}
                elif stage == 'open':
                    deadline = time.monotonic() + 30
                    while True:
                        xml = dump()
                        if 'Native saved author' in xml:
                            break
                        if time.monotonic() > deadline:
                            raise AssertionError('Anonymous portfolio missing from Android browser')
                        time.sleep(.25)
                    screenshot = screen(stage)
                    output.with_name(f'{output.stem}-open.xml').write_text(xml)
                    activity = adb('shell', 'dumpsys', 'activity', 'activities').decode()
                    resumed = [line for line in activity.splitlines() if 'mResumedActivity:' in line or 'topResumedActivity=' in line]
                    assert any('org.chromium.webview_shell' in line for line in resumed), resumed
                    texts = [n.attrib.get('text', '') for n in ET.fromstring(xml).iter('node')]
                    assert url in texts, 'Exact URL missing from foreground browser'
                    assert 'PRIVATE_EDITOR_BUFFER' not in xml
                    adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
                    result = {'stage': stage, 'browser': 'AOSP Chromium WebView shell',
                              'anonymousNativeReader': True, 'resumedActivity': resumed, 'url': url}
                else:
                    raise AssertionError('Unknown stage')
                result['screenshot'] = screenshot.name
                with lock:
                    report['checkpoints'].append(result)
                    report['status'] = 'passed' if len(report['checkpoints']) == 3 else 'running'
                    output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + '\n')
                body, status = b'PASS', 200
                print(f'ANDROID_SYSTEM {stage} PASS', flush=True)
            except Exception as error:
                report['status'] = 'failed'
                report['error'] = str(error)
                output.write_text(json.dumps(report, indent=2) + '\n')
                body, status = b'FAIL', 500
                print(f'ANDROID_SYSTEM FAIL {error}', flush=True)
            self.send_response(status)
            self.end_headers()
            self.wfile.write(body)

    server = HTTPServer(('127.0.0.1', 3811), Handler)
    print('ANDROID_SYSTEM ready 127.0.0.1:3811', flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
