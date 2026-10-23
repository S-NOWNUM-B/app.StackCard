import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class NativeJourneyGuardTest(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
