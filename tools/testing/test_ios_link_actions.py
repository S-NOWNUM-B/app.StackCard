import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest import mock
from urllib.parse import urlencode

import ios_link_actions


class IOSLinkActionsTest(unittest.TestCase):
    url = 'http://127.0.0.1:3800/d/' + 'a' * 32
    device = 'E165C52B-76A3-4961-8730-2F5C12236CBC'

    def test_request_accepts_only_one_exact_synthetic_loopback_document(self):
        self.assertEqual(ios_link_actions.parse_stage('/card?' + urlencode({'url': self.url})), ('card', self.url))
        bad_urls = [self.url + '?x=1', self.url + '#fragment', self.url.replace('127.0.0.1', 'localhost'),
                    self.url.replace('http:', 'https:'), self.url.replace('/d/', '/private/'),
                    self.url[:-1] + 'G', self.url.replace('127.0.0.1', 'secret@127.0.0.1')]
        targets = ['/unknown?' + urlencode({'url': self.url}),
                   '/card?' + urlencode({'url': self.url}) + '&url=' + self.url,
                   '/card?' + urlencode({'url': self.url, 'extra': 'x'}),
                   'http://127.0.0.1:3811/card?' + urlencode({'url': self.url})]
        targets += ['/card?' + urlencode({'url': url}) for url in bad_urls]
        for target in targets:
            with self.subTest(target=target), self.assertRaises((ValueError, KeyError)):
                ios_link_actions.parse_stage(target)

    def test_share_requires_xctest_success_and_exact_clipboard_without_disclosing_foreign_value(self):
        with tempfile.TemporaryDirectory() as folder:
            coordinator = ios_link_actions.Coordinator(self.device, Path(folder) / 'result.json', Path(folder) / 'dd')
            coordinator.url = self.url
            coordinator.report['checkpoints'] = [{'stage': 'card'}]
            with mock.patch.object(coordinator, 'xctest', return_value={}) as xctest, \
                    mock.patch.object(ios_link_actions.subprocess, 'check_output', return_value=b'ordinary private clipboard'):
                with self.assertRaises(RuntimeError) as error:
                    coordinator.stage('share', self.url)
            self.assertNotIn('ordinary private clipboard', str(error.exception))
            self.assertEqual(coordinator.report['checkpoints'], [{'stage': 'card'}])
            xctest.assert_called_once_with('share', self.url)

    def test_url_only_clipboard_requires_secure_paste_readback_proof(self):
        with tempfile.TemporaryDirectory() as folder:
            coordinator = ios_link_actions.Coordinator(self.device, Path(folder) / 'result.json', Path(folder) / 'dd')
            coordinator.url = self.url
            coordinator.report['checkpoints'] = [{'stage': 'card'}]
            with mock.patch.object(coordinator, 'xctest', return_value={}), \
                    mock.patch.object(ios_link_actions.subprocess, 'check_output', return_value=b''):
                with self.assertRaisesRegex(RuntimeError, 'exact synthetic URL'):
                    coordinator.stage('share', self.url)
            self.assertEqual(len(coordinator.report['checkpoints']), 1)
            with mock.patch.object(coordinator, 'xctest', return_value={'securePasteVerified': True}), \
                    mock.patch.object(ios_link_actions.subprocess, 'check_output', return_value=b''):
                coordinator.stage('share', self.url)
            entry = coordinator.report['checkpoints'][-1]
            self.assertEqual(entry['clipboardRepresentation'], 'SafariSecurePaste')
            self.assertFalse(entry['plainTextAvailable'])
            self.assertEqual(entry['exactCopiedUrl'], self.url)

    def test_copy_tap_marker_without_typed_url_marker_never_passes(self):
        with tempfile.TemporaryDirectory() as folder:
            coordinator = ios_link_actions.Coordinator(self.device, Path(folder) / 'result.json', Path(folder) / 'dd')

            def execute(command, **kwargs):
                kwargs['stdout'].write('STACKCARD_IOS_LINK:SHARE_PASS\n')
                process = mock.Mock()
                process.wait.return_value = 0
                return process

            with mock.patch.object(ios_link_actions.subprocess, 'Popen', side_effect=execute):
                with self.assertRaisesRegex(RuntimeError, 'did not pass'):
                    coordinator.xctest('share', self.url)

    def test_three_distinct_ordered_stages_with_same_document_are_required(self):
        with tempfile.TemporaryDirectory() as folder:
            coordinator = ios_link_actions.Coordinator(self.device, Path(folder) / 'result.json', Path(folder) / 'dd')
            with self.assertRaisesRegex(ValueError, 'in order'):
                coordinator.stage('open', self.url)
            coordinator.url = self.url
            coordinator.report['checkpoints'] = [{'stage': 'card'}]
            with self.assertRaisesRegex(ValueError, 'Repeated'):
                coordinator.stage('card', self.url)
            with self.assertRaisesRegex(ValueError, 'changed'):
                coordinator.stage('share', self.url.replace('a' * 32, 'b' * 32))
            with mock.patch.object(coordinator, 'xctest', return_value={'xcresult': 'test.xcresult', 'securePasteVerified': True}), \
                    mock.patch.object(ios_link_actions.subprocess, 'check_output', return_value=self.url.encode()):
                coordinator.stage('share', self.url)
                self.assertEqual(coordinator.report['status'], 'running')
                coordinator.stage('open', self.url)
            self.assertEqual(json.loads(coordinator.output.read_text())['status'], 'passed')

    def test_card_requires_exact_qr_and_anonymous_privacy_before_any_pass(self):
        with tempfile.TemporaryDirectory() as folder:
            coordinator = ios_link_actions.Coordinator(self.device, Path(folder) / 'result.json', Path(folder) / 'dd')
            with mock.patch.object(ios_link_actions.subprocess, 'run'), \
                    mock.patch.object(ios_link_actions.subprocess, 'check_output', return_value='wrong synthetic QR'), \
                    mock.patch.object(ios_link_actions, 'build_opener') as opener:
                with self.assertRaisesRegex(RuntimeError, 'QR'):
                    coordinator.stage('card', self.url)
                opener.assert_not_called()
            response = mock.MagicMock()
            response.__enter__.return_value.status = 200
            response.__enter__.return_value.read.return_value = b'Native saved author PRIVATE_SAVED_NOTE'
            with mock.patch.object(ios_link_actions.subprocess, 'run'), \
                    mock.patch.object(ios_link_actions.subprocess, 'check_output', return_value=self.url), \
                    mock.patch.object(ios_link_actions, 'build_opener') as opener:
                opener.return_value.open.return_value = response
                with self.assertRaisesRegex(RuntimeError, 'privacy'):
                    coordinator.stage('card', self.url)
            self.assertEqual(coordinator.report['checkpoints'], [])
            self.assertNotEqual(coordinator.report['status'], 'passed')

    def test_xctest_exit_zero_without_selected_test_marker_never_passes(self):
        with tempfile.TemporaryDirectory() as folder:
            coordinator = ios_link_actions.Coordinator(self.device, Path(folder) / 'result.json', Path(folder) / 'dd')
            with mock.patch.object(ios_link_actions.subprocess, 'Popen') as popen:
                popen.return_value.wait.return_value = 0
                with self.assertRaisesRegex(RuntimeError, 'did not pass'):
                    coordinator.xctest('share', self.url)

    def test_xctest_uses_selected_simulator_bounded_selector_and_exact_url(self):
        with tempfile.TemporaryDirectory() as folder:
            coordinator = ios_link_actions.Coordinator(self.device, Path(folder) / 'result.json', Path(folder) / 'dd')

            def execute(command, **kwargs):
                kwargs['stdout'].write('STACKCARD_IOS_LINK:OPEN_PASS\n')
                self.assertTrue(kwargs['start_new_session'])
                self.assertIn(f'platform=iOS Simulator,id={self.device}', command)
                self.assertIn(f'LINK_URL={self.url}', command)
                self.assertIn('-only-testing:SystemActionsTests/SystemActionsTests/testNativeLinkOpen', command)
                self.assertIn('STACKCARD_IOS_ACTION=linkOpen', command)
                self.assertNotIn('CODE_SIGNING_ALLOWED=YES', command)
                process = mock.Mock()
                process.wait.return_value = 0
                return process

            with mock.patch.object(ios_link_actions.subprocess, 'Popen', side_effect=execute):
                result = coordinator.xctest('open', self.url)
            self.assertEqual(result['xcresult'], 'result-open.xcresult')


    def test_xctest_timeout_cleans_only_owned_host_group_and_runner(self):
        with tempfile.TemporaryDirectory() as folder:
            coordinator = ios_link_actions.Coordinator(self.device, Path(folder) / 'result.json', Path(folder) / 'dd')
            process = mock.Mock(pid=54321)
            process.wait.side_effect = [subprocess.TimeoutExpired('xcodebuild', 75), 0, 0]
            with mock.patch.object(ios_link_actions.subprocess, 'Popen', return_value=process), \
                    mock.patch.object(ios_link_actions.os, 'killpg') as kill, \
                    mock.patch.object(ios_link_actions.subprocess, 'run') as cleanup:
                with self.assertRaisesRegex(RuntimeError, 'deadline'):
                    coordinator.xctest('share', self.url)
            self.assertEqual([call.args[0] for call in kill.call_args_list], [54321, 54321])
            self.assertEqual(cleanup.call_args.args[0], ['xcrun', 'simctl', 'terminate', self.device,
                                                       'dev.snownumb.stackcard.systemactions.xctrunner'])
            self.assertEqual(cleanup.call_args.kwargs['timeout'], 5)
            self.assertEqual(coordinator.report['checkpoints'], [])


if __name__ == '__main__':
    unittest.main()
