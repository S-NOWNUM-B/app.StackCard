"""Два native запуска в demo Emulator Suite; без deploy и обычного app storage."""

import argparse
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socket
import subprocess
import time
import urllib.request


EXPECTED = {
    "seed": {"registration_optional4steps_scoped_save_offline_outbox"},
    "check": {
        "new_process_auth_hive_exact_outbox_restore",
        "reconnect_actual_sdk_server_ack_cloud7",
        "saved_basis_actual_pdf",
        "authenticated_http_publish_anonymous_sdk_timestamp_card",
        "native_card_render_qr_copy_bridge",
        "private_save_does_not_republish",
        "native_uid_switch_hides_card_and_denies_previous_owner",
        "anonymous_private_denial_uid_local_isolation",
        "http_unpublish_removes_public_snapshot_and_open_qr",
        "trusted_delete_reconciles_saved_workspace",
    },
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--platform", choices=("android", "ios"), default="android")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--run-id", default=None)
    parser.add_argument("--phase", choices=("both", "check"), default="both")
    parser.add_argument("--adb", default=os.environ.get("ADB"))
    parser.add_argument("--host", choices=("10.0.2.2", "127.0.0.1", "localhost"))
    args = parser.parse_args()
    run = args.run_id or secrets.token_hex(16)
    if not re.fullmatch(r"[0-9a-f]{32}", run):
        parser.error("run-id must contain 32 lowercase hex characters")
    if args.phase == "check" and args.run_id is None:
        parser.error("check requires the original --run-id")
    for key, value in {
        "GCLOUD_PROJECT": "demo-stackcard-test",
        "FIRESTORE_EMULATOR_HOST": "127.0.0.1:8085",
        "FIREBASE_AUTH_EMULATOR_HOST": "127.0.0.1:9099",
    }.items():
        if os.environ.get(key) != value:
            parser.error(f"{key} must be {value}")
    root = Path(__file__).resolve().parents[2]
    host = args.host or ("127.0.0.1" if args.platform == "ios" else "10.0.2.2")
    if args.platform == "ios":
        if host == "10.0.2.2":
            parser.error("iOS simulator requires a loopback host")
        if not re.fullmatch(r"[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}", args.device):
            parser.error("iOS simulator requires an explicit device UUID")
        devices = json.loads(subprocess.check_output(
            ["xcrun", "simctl", "list", "devices", "booted", "--json"], timeout=15))
        if not any(device["udid"].lower() == args.device.lower()
                   for runtime in devices["devices"].values() for device in runtime):
            parser.error("iOS simulator is not booted")
        stop = ["xcrun", "simctl", "terminate", args.device, "com.example.appStackcard"]
    else:
        adb = args.adb or shutil.which("adb")
        if not adb:
            properties = root / "apps/mobile/android/local.properties"
            if properties.exists():
                sdk = next((line[8:] for line in properties.read_text().splitlines()
                            if line.startswith("sdk.dir=")), "")
                if sdk:
                    adb = str(Path(sdk) / "platform-tools/adb")
        if not adb or not Path(adb).is_file():
            parser.error("Android adb not found: pass --adb, set ADB or configure sdk.dir")
        if subprocess.check_output([adb, "-s", args.device, "get-state"], timeout=10).strip() != b"device":
            parser.error("Android device is not ready")
        stop = [adb, "-s", args.device, "shell", "am", "force-stop", "com.example.app_stackcard"]
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    # Не подключаться к случайному уже работающему backend.
    with socket.socket() as probe:
        probe.bind(("127.0.0.1", 3810))
    env = {
        **os.environ,
        "FUNCTIONS_EMULATOR": "true",
        "BACKEND_PORT": "3810",
        "PUBLIC_WEB_ORIGIN": "http://127.0.0.1:3800",
        "PUBLIC_STORAGE_BUCKET": "",
        "CONTACT_APP_CHECK_APP_ID": "",
        "CONTACT_RATE_HMAC_KEY": "",
    }
    report = {
        "status": "failed", "project": "demo-stackcard-test",
        "device": args.device, "platform": args.platform, "runId": run,
        "scope": "native SDK/controller/Card UI with local Auth/Firestore and HTTP backend",
        "phases": [], "checkpoints": [],
        "excluded": [f"{'iOS' if args.platform == 'android' else 'Android'} acceptance", "physical camera QR scan", "native Share/Open",
                     "production hosting", "system picker permission denial", "full UI onboarding/import"],
    }
    with output.with_suffix(".api.log").open("w") as backend_log:
        backend = subprocess.Popen(
            ["node", "src/server.mjs"], cwd=root / "firebase/functions",
            env=env, stdout=backend_log, stderr=subprocess.STDOUT,
        )
        try:
            deadline = time.monotonic() + 30
            while True:
                if backend.poll() is not None:
                    raise RuntimeError("Local backend exited before readiness")
                try:
                    with urllib.request.urlopen("http://127.0.0.1:3810/health", timeout=1) as response:
                        if response.status == 200:
                            break
                except OSError:
                    if time.monotonic() >= deadline:
                        raise TimeoutError("Local backend readiness deadline")
                    time.sleep(0.1)
            phases = ["seed", "check"] if args.phase == "both" else ["check"]
            for phase in phases:
                log = output.with_suffix(f".{phase}.log")
                command = [
                    "flutter", "drive", "--no-pub", "--no-uninstall-first", "--no-dds",
                    "--keep-app-running",
                    "--driver=test_driver/integration_test.dart",
                    "--target=integration_test/main_portfolio_runtime_test.dart",
                    "-d", args.device,
                    "--dart-define=RUN_MAIN_PORTFOLIO_ACCEPTANCE=true",
                    f"--dart-define=MAIN_PORTFOLIO_PHASE={phase}",
                    f"--dart-define=MAIN_PORTFOLIO_RUN_ID={run}",
                    f"--dart-define=MAIN_PORTFOLIO_EMULATOR_HOST={host}",
                ]
                print(f"Native journey {phase}; runId={run}; log={log}", flush=True)
                with log.open("w") as stream:
                    result = subprocess.run(command, cwd=root / "apps/mobile", env=env,
                                            stdout=stream, stderr=subprocess.STDOUT, timeout=720)
                text = log.read_text()
                checkpoints = [json.loads(item) for item in re.findall(
                    r"STACKCARD_MAIN_JOURNEY:(\{[^\n]+\})", text)]
                report["phases"].append({"phase": phase, "exitCode": result.returncode})
                report["checkpoints"].extend(checkpoints)
                if (result.returncode != 0
                        or {item["checkpoint"] for item in checkpoints} != EXPECTED[phase]
                        or any(item["phase"] != phase for item in checkpoints)):
                    raise RuntimeError(f"Native {phase} failed; inspect {log}")
                # Сначала сохраняем результат: уже упавший процесс нельзя terminate.
                # keep-app-running сохраняет data; завершаем успешный процесс без uninstall/clear.
                subprocess.run(stop, check=True, timeout=15)
            if args.phase == "both":
                pids = {item["pid"] for item in report["checkpoints"]}
                if len(pids) != 2:
                    raise RuntimeError("Expected two distinct native processes")
            report["status"] = "passed"
        finally:
            backend.terminate()
            try:
                backend.wait(timeout=10)
            except subprocess.TimeoutExpired:
                backend.kill()
                backend.wait()
            output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"Native journey passed: {output}")


if __name__ == "__main__":
    main()
