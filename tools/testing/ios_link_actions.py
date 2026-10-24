"""Loopback-only iOS Simulator Card/QR/Share/Open acceptance coordinator."""

import argparse
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
import os
from pathlib import Path
import re
import signal
import subprocess
from urllib.parse import parse_qs, urlsplit
from urllib.request import HTTPRedirectHandler, build_opener


DEMO = {'GCLOUD_PROJECT': 'demo-stackcard-test',
        'FIRESTORE_EMULATOR_HOST': '127.0.0.1:8085',
        'FIREBASE_AUTH_EMULATOR_HOST': '127.0.0.1:9099'}
UUID = r'[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}'
PUBLIC_URL = r'http://127\.0\.0\.1:3800/d/[0-9a-f]{32}'


def parse_stage(target):
    path = urlsplit(target)
    query = parse_qs(path.query, strict_parsing=True, keep_blank_values=True)
    if (path.scheme or path.netloc or path.fragment or path.path not in {'/card', '/share', '/open'}
            or set(query) != {'url'} or len(query['url']) != 1
            or not re.fullmatch(PUBLIC_URL, query['url'][0])):
        raise ValueError('Expected one exact loopback synthetic document URL and known stage')
    return path.path[1:], query['url'][0]


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Coordinator:
    def __init__(self, device, output, derived_data):
        self.device, self.output, self.derived_data = device, output, derived_data
        self.root = Path(__file__).resolve().parents[2]
        self.report = {'status': 'waiting', 'device': device,
                       'scope': 'iOS Simulator native channels and anonymous local Next SSR',
                       'physicalCamera': 'not checked; screenshot decoded independently by Vision',
                       'recipientSelected': False, 'checkpoints': []}
        self.url = None

    def save(self):
        self.output.write_text(json.dumps(self.report, indent=2, ensure_ascii=False) + '\n')

    def xctest(self, stage, url):
        action = 'linkShare' if stage == 'share' else 'linkOpen'
        selector = 'testNativeLinkShare' if stage == 'share' else 'testNativeLinkOpen'
        marker = f'STACKCARD_IOS_LINK:{stage.upper()}_PASS'
        bundle = self.output.with_name(f'{self.output.stem}-{stage}.xcresult')
        log = self.output.with_name(f'{self.output.stem}-{stage}.xctest.log')
        if bundle.exists() or log.exists():
            raise RuntimeError('Use a fresh output prefix for native XCTest artifacts')
        command = ['xcodebuild', 'test', '-project',
                   str(self.root / 'tools/testing/ios_system_actions/SystemActions.xcodeproj'),
                   '-scheme', 'SystemActions', '-destination', f'platform=iOS Simulator,id={self.device}',
                   '-derivedDataPath', str(self.derived_data), '-resultBundlePath', str(bundle),
                   '-parallel-testing-enabled', 'NO', '-maximum-test-execution-time-allowance', '45',
                   f'-only-testing:SystemActionsTests/SystemActionsTests/{selector}',
                   'STACKCARD_IOS_SYSTEM_ACTIONS=YES', f'STACKCARD_IOS_ACTION={action}', f'LINK_URL={url}']
        with log.open('x') as stream:
            process = subprocess.Popen(command, stdout=stream, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                code = process.wait(timeout=75)
            except subprocess.TimeoutExpired:
                # Завершаем только нашу host process group и наш отдельный XCTest runner.
                # Testmanager может запускать Simulator runner вне host process group.
                for sig, seconds in ((signal.SIGTERM, 3), (signal.SIGKILL, 2)):
                    try:
                        os.killpg(process.pid, sig)
                    except ProcessLookupError:
                        pass
                    try:
                        process.wait(timeout=seconds)
                    except subprocess.TimeoutExpired:
                        continue
                try:
                    subprocess.run(['xcrun', 'simctl', 'terminate', self.device,
                                    'dev.snownumb.stackcard.systemactions.xctrunner'],
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=5)
                except subprocess.TimeoutExpired:
                    pass
                raise RuntimeError('Native XCTest deadline; own process group/runner cleanup requested') from None
        lines = log.read_text().splitlines()
        if (code != 0 or marker not in lines
                or (stage == 'share' and 'STACKCARD_IOS_LINK:SHARE_PAYLOAD_URL_PASS' not in lines)):
            raise RuntimeError(f'Native {stage} XCTest did not pass; inspect its local XCTest log')
        result = {'xcresult': bundle.name, 'xctestLog': log.name}
        if stage == 'share':
            result['securePasteVerified'] = True
        return result

    def stage(self, stage, url):
        if stage not in {"card", "share", "open"} or not re.fullmatch(PUBLIC_URL, url):
            raise ValueError("Expected an exact synthetic native stage")
        completed = [item['stage'] for item in self.report['checkpoints']]
        if self.report['status'] == 'failed' or stage in completed:
            raise ValueError('Repeated or previously failed native stage')
        if stage != ('card', 'share', 'open')[len(completed)]:
            raise ValueError('Native stages must be card, share, open in order')
        if self.url is not None and self.url != url:
            raise ValueError('The synthetic document URL changed between stages')
        self.url = url
        entry = {'stage': stage}
        if stage == 'card':
            screenshot = self.output.with_name(f'{self.output.stem}-card.png')
            subprocess.run(['xcrun', 'simctl', 'io', self.device, 'screenshot', str(screenshot)],
                           check=True, timeout=15, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            decoded = subprocess.check_output(
                ['swift', str(self.root / 'tools/testing/qr_decode.swift'), str(screenshot), url],
                text=True, timeout=60).strip()
            if decoded != url:
                raise RuntimeError('QR does not encode the exact synthetic document URL')
            with build_opener(NoRedirect).open(url, timeout=10) as response:
                html = response.read(2 * 1024 * 1024 + 1)
                if response.status != 200 or len(html) > 2 * 1024 * 1024:
                    raise RuntimeError('Anonymous local document response failed')
            if (b'Native saved author' not in html
                    or any(marker in html for marker in (b'PRIVATE_EDITOR_BUFFER', b'PRIVATE_SAVED_NOTE'))):
                raise RuntimeError('Anonymous local author/privacy assertion failed')
            entry.update(screenshot=screenshot.name, decodedExactUrl=url,
                         anonymousHttp200=True, privateMarkersAbsent=True)
        else:
            entry.update(self.xctest(stage, url))
            if stage == 'share':
                clipboard = subprocess.check_output(['xcrun', 'simctl', 'pbpaste', self.device], timeout=10)
                if entry.get('securePasteVerified') is not True or (clipboard and clipboard != url.encode()):
                    raise RuntimeError('Native Copy did not place the exact synthetic URL on the Simulator clipboard')
                entry.update(exactCopiedUrl=url, recipientSelected=False,
                             clipboardRepresentation='SafariSecurePaste', plainTextAvailable=bool(clipboard))
            else:
                entry.update(exactSafariUrl=url, anonymousNativeReader=True, privateMarkersAbsent=True)
        self.report['checkpoints'].append(entry)
        self.report['status'] = 'passed' if len(self.report['checkpoints']) == 3 else 'running'
        self.save()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--device', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--derived-data', type=Path, default=Path('/private/tmp/stackcard-ios-system-actions'))
    args = parser.parse_args()
    for key, value in DEMO.items():
        if os.environ.get(key) != value:
            parser.error(f'{key} must be {value}')
    if not re.fullmatch(UUID, args.device):
        parser.error('An explicit iOS Simulator UUID is required')
    devices = json.loads(subprocess.check_output(
        ['xcrun', 'simctl', 'list', 'devices', 'booted', '--json'], timeout=15))
    if not any(item['udid'].lower() == args.device.lower()
               for runtime in devices['devices'].values() for item in runtime):
        parser.error('The selected Simulator is not booted')
    output = args.output.resolve()
    if output.exists():
        parser.error('Use a fresh output path')
    output.parent.mkdir(parents=True, exist_ok=True)
    coordinator = Coordinator(args.device, output, args.derived_data.resolve())

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_args):
            pass

        def do_GET(self):
            try:
                if self.client_address[0] != '127.0.0.1' or self.headers.get('Host') != '127.0.0.1:3811':
                    raise ValueError('Only the explicit loopback coordinator origin is allowed')
                stage, url = parse_stage(self.path)
                coordinator.stage(stage, url)
                status, body = 200, b'PASS'
                print(f'IOS_SYSTEM {stage} PASS', flush=True)
            except Exception as error:
                coordinator.report.update(status='failed', error=type(error).__name__)
                coordinator.save()
                status, body = 500, b'FAIL'
                print(f'IOS_SYSTEM FAIL {type(error).__name__}: {error}', flush=True)
            self.send_response(status)
            self.end_headers()
            self.wfile.write(body)

    server = HTTPServer(('127.0.0.1', 3811), Handler)
    coordinator.save()
    print('IOS_SYSTEM ready 127.0.0.1:3811', flush=True)
    try:
        server.serve_forever()
    finally:
        server.server_close()


if __name__ == '__main__':
    main()
