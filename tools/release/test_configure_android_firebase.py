import copy
import unittest

from configure_android_firebase import configured


class AndroidFirebaseConfigTest(unittest.TestCase):
    def setUp(self):
        self.sdk = {"client": [
            {"client_info": {"android_client_info": {"package_name": package},
                             "mobilesdk_app_id": app}, "api_key": [{"current_key": "old"}]}
            for package, app in [("legacy", "legacy-app"), ("selected", "new-app")]]}
        self.dart = """static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'old', appId: 'new-app',
  );
  static const FirebaseOptions ios = FirebaseOptions(apiKey: 'ios');
"""
        self.key = "AIza" + "A" * 35

    def test_only_selected_client_and_android_options_change(self):
        before = copy.deepcopy(self.sdk)
        sdk, dart = configured(self.sdk, self.dart, "selected", "new-app", self.key)
        self.assertEqual(self.sdk, before)
        self.assertEqual(sdk["client"][0], before["client"][0])
        self.assertEqual(sdk["client"][1]["api_key"], [{"current_key": self.key}])
        self.assertIn("FirebaseOptions(apiKey: 'ios')", dart)
        self.assertIn("appId: 'new-app'", dart)

    def test_foreign_app_or_generated_options_fail_before_mutation(self):
        before = copy.deepcopy(self.sdk)
        for package, app, dart in [("foreign", "new-app", self.dart),
                                   ("selected", "foreign", self.dart),
                                   ("selected", "new-app", self.dart.replace("'new-app'", "'foreign'"))]:
            with self.assertRaises(ValueError):
                configured(self.sdk, dart, package, app, self.key)
            self.assertEqual(self.sdk, before)

    def test_token_or_malformed_key_is_rejected(self):
        for key in ["oauth-token", "", self.key + "extra"]:
            with self.assertRaises(ValueError):
                configured(self.sdk, self.dart, "selected", "new-app", key)


if __name__ == "__main__":
    unittest.main()
