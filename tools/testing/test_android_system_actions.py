import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import android_system_actions


class AndroidSystemActionsTest(unittest.TestCase):
    def run_stages(self, stages, dump_failures=0, statuses=None):
        url = 'http://127.0.0.1:3800/d/' + 'a' * 32
        current = {'stage': '', 'url': url, 'dumpReady': False, 'failures': dump_failures}

        def execute(command, **kwargs):
            if command[0] == 'swift':
                return current['url']
            if command[-3:-1] == ['uiautomator', 'dump']:
                if current['failures']:
                    current['failures'] -= 1
                    current['dumpReady'] = False
                    return b'ERROR: null root node returned by UiTestAutomationBridge'
                current['dumpReady'] = True
                return b'UI hierchary dumped to: /sdcard/stackcard-system.xml'
            if command[-1] == '/sdcard/stackcard-system.xml':
                self.assertTrue(current['dumpReady'], 'Stale XML read after failed uiautomator dump')
                return (f'<hierarchy><node text="{current["url"]}"/>'
                        '<node text="Native saved author"/></hierarchy>').encode()
            if command[-3:] == ['dumpsys', 'activity', 'activities']:
                activity = ('ChooserActivity' if current['stage'] == 'share'
                            else 'org.chromium.webview_shell/.MainActivity')
                return f'mResumedActivity: {activity}'.encode()
            return b''

        def server(_address, handler):
            def serve():
                for index, item in enumerate(stages):
                    stage, selected_url = item if isinstance(item, tuple) else (item, url)
                    current['stage'] = stage
                    current['url'] = selected_url
                    request = object.__new__(handler)
                    request.path = f'/{stage}?url={selected_url}'
                    request.wfile = io.BytesIO()
                    request.send_response = mock.Mock()
                    request.end_headers = mock.Mock()
                    request.do_GET()
                    expected_status = statuses[index] if statuses else 200
                    request.send_response.assert_called_once_with(expected_status)
                    self.assertEqual(request.wfile.getvalue(), b'PASS' if expected_status == 200 else b'FAIL')

            return mock.Mock(serve_forever=serve)

        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'report.json'
            response = mock.Mock()
            response.read.return_value = b'Native saved author'
            with mock.patch.dict(os.environ, {
                    'GCLOUD_PROJECT': 'demo-stackcard-test',
                    'FIRESTORE_EMULATOR_HOST': '127.0.0.1:8085',
                    'FIREBASE_AUTH_EMULATOR_HOST': '127.0.0.1:9099'}), \
                    mock.patch.object(sys, 'argv', ['android_system_actions.py', '--adb', 'adb',
                                                   '--device', 'emulator-test', '--output', str(output)]), \
                    mock.patch.object(android_system_actions, 'HTTPServer', side_effect=server), \
                    mock.patch.object(android_system_actions, 'urlopen', return_value=response), \
                    mock.patch.object(subprocess, 'check_output', side_effect=execute):
                android_system_actions.main()
            return json.loads(output.read_text())

    def test_failure_sticks_even_after_later_ordered_requests(self):
        report = self.run_stages(['share', 'card', 'share', 'open'], statuses=[500, 500, 500, 500])
        self.assertEqual(report['status'], 'failed')
        self.assertEqual(report['checkpoints'], [])

    def test_three_ordered_stages_for_the_same_document_pass(self):
        report = self.run_stages(['card', 'share', 'open'])
        self.assertEqual(report['status'], 'passed')
        self.assertFalse(report['recipientSelected'])
        self.assertEqual({item['stage'] for item in report['checkpoints']}, {'card', 'share', 'open'})

    def test_repeated_stage_fails_without_replacing_earlier_proof(self):
        report = self.run_stages(['card', 'card', 'share', 'open'], statuses=[200, 500, 500, 500])
        self.assertEqual(report['status'], 'failed')
        self.assertEqual([item['stage'] for item in report['checkpoints']], ['card'])

    def test_order_cannot_skip_native_share(self):
        report = self.run_stages(['card', 'open'], statuses=[200, 500])
        self.assertEqual(report['status'], 'failed')
        self.assertEqual([item['stage'] for item in report['checkpoints']], ['card'])

    def test_changed_document_fails_without_overwriting_first_url(self):
        first = 'http://127.0.0.1:3800/d/' + 'a' * 32
        changed = first.replace('a' * 32, 'b' * 32)
        report = self.run_stages(['card', ('share', changed), 'open'], statuses=[200, 500, 500])
        self.assertEqual(report['status'], 'failed')
        self.assertEqual(report['url'], first)
        self.assertEqual([item['stage'] for item in report['checkpoints']], ['card'])

    def test_null_root_retries_without_reading_previous_xml(self):
        report = self.run_stages(['card', 'share'], dump_failures=1)
        self.assertEqual(report['status'], 'running')
        self.assertEqual([item['stage'] for item in report['checkpoints']], ['card', 'share'])

    def test_chrome_accepts_only_exact_url_in_observed_address_bar(self):
        url = 'http://127.0.0.1:3800/d/' + 'a' * 32
        resumed = ['mResumedActivity: ActivityRecord{123 u0 com.android.chrome/ChromeTabbedActivity t1}']
        for value in [url, url.removeprefix('http://')]:
            xml = (f'<hierarchy><node resource-id="com.android.chrome:id/url_bar" '
                   f'package="com.android.chrome" text="{value}"/>'
                   '<node text="Native saved author"/></hierarchy>')
            self.assertEqual(android_system_actions.verify_browser_open(xml, resumed, url), 'Chrome')
        for value, resource in [(url + '/foreign', 'com.android.chrome:id/url_bar'),
                                ('prefix' + url, 'com.android.chrome:id/url_bar'),
                                (url, 'com.android.chrome:id/page_content')]:
            xml = (f'<hierarchy><node resource-id="{resource}" package="com.android.chrome" '
                   f'text="{value}"/><node text="Native saved author"/></hierarchy>')
            with self.subTest(value=value, resource=resource), self.assertRaises(AssertionError):
                android_system_actions.verify_browser_open(xml, resumed, url)

    def test_browser_allowlist_author_and_privacy_still_required(self):
        url = 'http://127.0.0.1:3800/d/' + 'a' * 32
        resumed = ['topResumedActivity=ActivityRecord{123 u0 org.chromium.webview_shell/.Main t1}']
        xml = f'<hierarchy><node text="{url}"/><node text="Native saved author"/></hierarchy>'
        self.assertEqual(android_system_actions.verify_browser_open(xml, resumed, url),
                         'AOSP Chromium WebView shell')
        for tree, activity in [
                (xml, ['mResumedActivity: com.android.chrome.evil/.Main']),
                (xml.replace('Native saved author', 'Chrome first run'), resumed),
                (xml.replace('Native saved author', 'Native saved author PRIVATE_EDITOR_BUFFER'), resumed),
                (xml.replace('Native saved author', 'Native saved author PRIVATE_SAVED_NOTE'), resumed)]:
            with self.assertRaises(AssertionError):
                android_system_actions.verify_browser_open(tree, activity, url)


if __name__ == '__main__':
    unittest.main()
