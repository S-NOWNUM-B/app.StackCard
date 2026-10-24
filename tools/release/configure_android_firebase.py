"""Согласует публичный Android API key после официального FlutterFire configure."""

import argparse
import json
from pathlib import Path
import re


def configured(sdk, dart, package, app_id, key):
    if not re.fullmatch(r"AIza[A-Za-z0-9_-]{35}", key):
        raise ValueError("Invalid public Firebase API key")
    clients = [c for c in sdk["client"]
               if c["client_info"]["android_client_info"]["package_name"] == package]
    if len(clients) != 1 or clients[0]["client_info"]["mobilesdk_app_id"] != app_id:
        raise ValueError("SDK appId/package mismatch; configuration unchanged")
    pattern = r"(static const FirebaseOptions android = FirebaseOptions\()(.*?)(\n  \);)"
    matches = list(re.finditer(pattern, dart, re.S))
    if len(matches) != 1 or re.findall(r"appId: '([^']+)'", matches[0][2]) != [app_id]:
        raise ValueError("Dart Android appId mismatch; configuration unchanged")
    body, count = re.subn(r"apiKey: '[^']+'", f"apiKey: '{key}'", matches[0][2])
    if count != 1:
        raise ValueError("Unexpected generated Dart options")
    # Другие native clients и iOS options не меняются.
    result = json.loads(json.dumps(sdk))
    selected = next(c for c in result["client"]
                    if c["client_info"]["android_client_info"]["package_name"] == package)
    selected["api_key"] = [{"current_key": key}]
    match = matches[0]
    return result, dart[:match.start(2)] + body + dart[match.end(2):]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package", required=True)
    parser.add_argument("--app-id", required=True)
    parser.add_argument("--key-file", required=True, type=Path,
                        help="JSON keyString из API Keys getKeyString; не OAuth credentials")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    native = root / "apps/mobile/android/app/google-services.json"
    options = root / "apps/mobile/lib/firebase_options.dart"
    sdk, dart = configured(json.loads(native.read_text()), options.read_text(),
                           args.package, args.app_id, json.loads(args.key_file.read_text())["keyString"])
    native.write_text(json.dumps(sdk, indent=2) + "\n")
    options.write_text(dart)
    print("Selected Android native/Dart public key aligned; other clients unchanged.")


if __name__ == "__main__":
    main()
