import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class CrashlyticsSymbolsTest(unittest.TestCase):
    script = Path(__file__).resolve().parents[2] / "apps/mobile/ios/Runner/upload_crashlytics_symbols.sh"

    def test_both_spm_locations_preserve_paths_and_propagate_upload_failure(self):
        for flutter_build in (True, False):
            with self.subTest(flutter_build=flutter_build), tempfile.TemporaryDirectory() as directory:
                root = Path(directory) / "Build with spaces"
                build = root if flutter_build else root / "Build/Products"
                sdk = root / "SourcePackages/checkouts/firebase-ios-sdk/Crashlytics"
                sdk.mkdir(parents=True)
                output = root / "arguments.json"
                upload = sdk / "upload-symbols"
                upload.write_text(
                    "#!/usr/bin/env python3\nimport json,os,sys\n"
                    "open(os.environ['SYMBOLS_TEST_OUTPUT'],'w').write(json.dumps(sys.argv[1:]))\n"
                    "sys.exit(7)\n"
                )
                upload.chmod(0o755)
                env = {**os.environ, "BUILD_DIR": str(build),
                       "TARGET_BUILD_DIR": str(root / "Products"),
                       "UNLOCALIZED_RESOURCES_FOLDER_PATH": "Runner.app",
                       "DWARF_DSYM_FOLDER_PATH": str(root / "Symbols"),
                       "DWARF_DSYM_FILE_NAME": "Runner.app.dSYM",
                       "SYMBOLS_TEST_OUTPUT": str(output)}
                result = subprocess.run(["/bin/sh", str(self.script)], env=env,
                                        capture_output=True, timeout=5)
                self.assertEqual(result.returncode, 7)
                self.assertEqual(json.loads(output.read_text()), [
                    "-gsp", str(root / "Products/Runner.app/GoogleService-Info.plist"),
                    "-p", "ios", str(root / "Symbols/Runner.app.dSYM")])

    def test_missing_sdk_fails_before_upload(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run(["/bin/sh", str(self.script)],
                                    env={**os.environ, "BUILD_DIR": directory},
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 1)
            self.assertIn("resolve Firebase packages", result.stderr)


if __name__ == "__main__":
    unittest.main()
