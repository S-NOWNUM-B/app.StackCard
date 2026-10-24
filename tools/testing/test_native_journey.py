import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

import native_journey


class NativeJourneyGuardTest(unittest.TestCase):
    demo = {"GCLOUD_PROJECT": "demo-stackcard-test",
            "FIRESTORE_EMULATOR_HOST": "127.0.0.1:8085",
            "FIREBASE_AUTH_EMULATOR_HOST": "127.0.0.1:9099"}

    def rejected(self, extra, env, message):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "report.json"
            result = subprocess.run(
                [sys.executable, str(Path(__file__).with_name("native_journey.py")),
                 "--device", "unused", "--output", str(output), *extra],
                env={**os.environ, **env}, text=True, capture_output=True,
                timeout=5,
            )
            self.assertEqual(result.returncode, 2)
            self.assertIn(message, result.stderr)
            self.assertFalse(output.exists())

    def test_live_project_is_rejected_before_native_or_backend_start(self):
        self.rejected([], {"GCLOUD_PROJECT": "stackcard-dev-snownumb"}, "GCLOUD_PROJECT must be demo-")

    def test_nonlocal_emulator_is_rejected(self):
        self.rejected([], {"GCLOUD_PROJECT": "demo-stackcard-test",
                           "FIRESTORE_EMULATOR_HOST": "example.com:8085"},
                      "FIRESTORE_EMULATOR_HOST must be 127.0.0.1")

    def test_restore_requires_original_id_and_safe_namespace(self):
        self.rejected(["--phase", "check"], {}, "check requires the original")
        self.rejected(["--run-id", "../ordinary-data"], {}, "32 lowercase hex")

    def test_missing_adb_is_rejected_before_backend_or_install(self):
        self.rejected(["--adb", "/missing-stackcard-adb"],
                      {"GCLOUD_PROJECT": "demo-stackcard-test",
                       "FIRESTORE_EMULATOR_HOST": "127.0.0.1:8085",
                       "FIREBASE_AUTH_EMULATOR_HOST": "127.0.0.1:9099"},
                      "Android adb not found")

    def test_ios_requires_specific_simulator_and_loopback_before_start(self):
        self.rejected(["--platform", "ios"], self.demo, "explicit device UUID")
        self.rejected(["--platform", "ios", "--host", "10.0.2.2"], self.demo, "loopback host")

    def test_ios_system_process_pair_uses_loopback_without_adb_reverse(self):
        self.process_pair("ios", system_actions=True)

    def test_process_pair_regenerates_debug_plugins_and_preserves_app_data(self):
        self.process_pair("android")

    def test_ios_process_pair_uses_booted_simulator_and_never_invokes_adb(self):
        self.process_pair("ios")

    def process_pair(self, platform, system_actions=None):
        if system_actions is None:
            system_actions = platform == "android"
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "report.json"
            adb = Path(directory) / "adb"
            adb.touch()
            run_id = "a" * 32
            backend = mock.Mock()
            backend.poll.return_value = None
            response = mock.MagicMock()
            response.__enter__.return_value.status = 200
            device = "E165C52B-76A3-4961-8730-2F5C12236CBC" if platform == "ios" else "emulator-test"

            def inventory(command, **kwargs):
                if command == ["xcrun", "simctl", "list", "devices", "booted", "--json"]:
                    return json.dumps({"devices": {"iOS": [{"udid": device}]}}).encode()
                self.assertEqual(platform, "android", "iOS must not invoke adb or reader reverse")
                if command[-1] == "get-state":
                    return b"device"
                self.assertEqual(command[-2:], ["reverse", "--list"])
                return b"emulator-test tcp:3800 tcp:3800\n"

            def execute(command, **kwargs):
                if command[:2] == ["flutter", "drive"]:
                    phase = next(part.split("=", 2)[2] for part in command
                                 if part.startswith("--dart-define=MAIN_PORTFOLIO_PHASE="))
                    for checkpoint in native_journey.EXPECTED[phase]:
                        kwargs["stdout"].write("STACKCARD_MAIN_JOURNEY:" + json.dumps({
                            "checkpoint": checkpoint, "phase": phase,
                            "pid": 101 if phase == "seed" else 202,
                        }) + "\n")
                return subprocess.CompletedProcess(command, 0)

            with mock.patch.dict(os.environ, self.demo), \
                    mock.patch.object(sys, "argv", ["native_journey.py", "--device", device,
                                                   "--platform", platform,
                                                   "--adb", str(adb), "--output", str(output),
                                                   "--run-id", run_id,
                                                   *(["--system-actions"] if system_actions else [])]), \
                    mock.patch.object(native_journey.socket, "socket"), \
                    mock.patch.object(native_journey.urllib.request, "urlopen", return_value=response), \
                    mock.patch.object(native_journey.subprocess, "check_output", side_effect=inventory), \
                    mock.patch.object(native_journey.subprocess, "Popen", return_value=backend), \
                    mock.patch.object(native_journey.subprocess, "run", side_effect=execute) as run:
                native_journey.main()

            commands = [call.args[0] for call in run.call_args_list]
            drives = [command for command in commands if command[:2] == ["flutter", "drive"]]
            self.assertEqual(len(drives), 2)
            for command in drives:
                self.assertNotIn("--no-pub", command)
                self.assertIn("--no-uninstall-first", command)
                self.assertIn("--keep-app-running", command)
                self.assertIn("--dart-define=RUN_MAIN_PORTFOLIO_ACCEPTANCE=true", command)
                self.assertEqual("--dart-define=RUN_NATIVE_SYSTEM_ACTIONS=true" in command, system_actions)
                self.assertIn(f"--dart-define=MAIN_PORTFOLIO_RUN_ID={run_id}", command)
                host = "127.0.0.1" if platform == "ios" else "10.0.2.2"
                self.assertIn(f"--dart-define=MAIN_PORTFOLIO_EMULATOR_HOST={host}", command)
            stops = [command for command in commands if command not in drives]
            stop = (["xcrun", "simctl", "terminate", device, "com.example.appStackcard"]
                    if platform == "ios" else [str(adb), "-s", device, "shell", "am", "force-stop", "dev.snownumb.stackcard"])
            self.assertEqual(stops, [stop] * 2)
            report = json.loads(output.read_text())
            self.assertEqual(report["status"], "passed")
            self.assertEqual(report["systemActions"], system_actions)
            self.assertEqual("native Share/Open" not in report["excluded"], system_actions)
            if platform == "android":
                self.assertEqual(report["readerReverse"]["cleanup"], "preserved existing mapping")
            else:
                self.assertEqual(report["readerReverse"], {"enabled": False, "created": False})
            backend.terminate.assert_called_once()
            backend.wait.assert_called_once_with(timeout=10)

    def test_blank_adb_reverse_inventory_has_no_mapping(self):
        with mock.patch.object(native_journey.subprocess, "check_output", return_value=b"\n"):
            self.assertIsNone(native_journey._reader_reverse_target("adb", "emulator-test"))

    def test_reader_reverse_created_and_verified_removed_after_native_failure(self):
        mapping = b"emulator-test tcp:3800 tcp:3800\n"
        with mock.patch.object(subprocess, "check_output", side_effect=[b"", mapping, mapping, b""]), \
                mock.patch.object(subprocess, "run") as execute:
            with self.assertRaisesRegex(RuntimeError, "native failed"):
                with native_journey.android_reader_reverse("adb", "emulator-test", True) as state:
                    self.assertTrue(state["created"])
                    raise RuntimeError("native failed")
        self.assertEqual([call.args[0] for call in execute.call_args_list], [
            ["adb", "-s", "emulator-test", "reverse", "--no-rebind", "tcp:3800", "tcp:3800"],
            ["adb", "-s", "emulator-test", "reverse", "--remove", "tcp:3800"],
        ])
        self.assertEqual(state["cleanup"], "removed own mapping")

    def test_foreign_reader_mapping_is_rejected_before_any_mutation_or_native_test(self):
        with mock.patch.object(subprocess, "check_output", return_value=b"emulator-test tcp:3800 tcp:9999\n"), \
                mock.patch.object(subprocess, "run") as execute:
            with self.assertRaisesRegex(RuntimeError, "already points elsewhere"):
                with native_journey.android_reader_reverse("adb", "emulator-test", True):
                    self.fail("Native/backend work must not start")
            execute.assert_not_called()

    def test_external_reader_mapping_change_is_left_untouched(self):
        with mock.patch.object(subprocess, "check_output", side_effect=[
                b"", b"emulator-test tcp:3800 tcp:3800\n", b"emulator-test tcp:3800 tcp:9999\n"]), \
                mock.patch.object(subprocess, "run") as execute:
            with self.assertRaisesRegex(RuntimeError, "changed externally"):
                with native_journey.android_reader_reverse("adb", "emulator-test", True) as state:
                    pass
            self.assertEqual(execute.call_count, 1)
            self.assertIn("--no-rebind", execute.call_args.args[0])
            self.assertEqual(state["cleanup"], "left changed mapping untouched")

    def test_existing_reader_mapping_survives_failure_and_creation_race_never_removes_it(self):
        mapping = b"emulator-test tcp:3800 tcp:3800\n"
        with mock.patch.object(subprocess, "check_output", return_value=mapping), \
                mock.patch.object(subprocess, "run") as execute:
            with self.assertRaisesRegex(RuntimeError, "native failed"):
                with native_journey.android_reader_reverse("adb", "emulator-test", True):
                    raise RuntimeError("native failed")
            execute.assert_not_called()
        with mock.patch.object(subprocess, "check_output", return_value=b""), \
                mock.patch.object(subprocess, "run", side_effect=subprocess.CalledProcessError(1, "adb")) as execute:
            with self.assertRaises(subprocess.CalledProcessError):
                with native_journey.android_reader_reverse("adb", "emulator-test", True):
                    self.fail("Native work must not start after a reverse creation race")
            self.assertEqual(execute.call_count, 1)
            self.assertIn("--no-rebind", execute.call_args.args[0])


if __name__ == "__main__":
    unittest.main()
