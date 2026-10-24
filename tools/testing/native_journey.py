"""Два native запуска в demo Emulator Suite; без deploy и обычного app storage."""

import argparse
from contextlib import contextmanager
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


def _reader_reverse_target(adb, device):
    lines = subprocess.check_output([adb, "-s", device, "reverse", "--list"], timeout=10).decode().splitlines()
    targets = []
    for line in lines:
        if not line.strip():
            continue
        parts = line.split()
        if len(parts) != 3:
            raise RuntimeError("Unexpected adb reverse inventory; mappings unchanged")
        if parts[1] == "tcp:3800":
            targets.append(parts[2])
    if len(targets) > 1:
        raise RuntimeError("Ambiguous reader reverse mapping; mappings unchanged")
    return targets[0] if targets else None


@contextmanager
def android_reader_reverse(adb, device, enabled):
    state = {"enabled": enabled, "created": False}
    if not enabled:
        yield state
        return
    previous = _reader_reverse_target(adb, device)
    state.update({"before": previous, "remote": "tcp:3800", "target": "tcp:3800"})
    if previous not in (None, "tcp:3800"):
        raise RuntimeError("Reader reverse tcp:3800 already points elsewhere; mappings unchanged")
    if previous is None:
        subprocess.run([adb, "-s", device, "reverse", "--no-rebind", "tcp:3800", "tcp:3800"],
                       check=True, timeout=10, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        state["created"] = True
    try:
        if _reader_reverse_target(adb, device) != "tcp:3800":
            raise RuntimeError("Reader reverse setup could not be verified")
        yield state
    finally:
        if state["created"]:
            current = _reader_reverse_target(adb, device)
            if current not in (None, "tcp:3800"):
                state["cleanup"] = "left changed mapping untouched"
                raise RuntimeError("Reader reverse changed externally; mapping left untouched")
            if current is not None:
                state["cleanup"] = "remove failed"
                subprocess.run([adb, "-s", device, "reverse", "--remove", "tcp:3800"],
                               check=True, timeout=10, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
                if _reader_reverse_target(adb, device) is not None:
                    state["cleanup"] = "mapping present after own removal"
                    raise RuntimeError("Reader reverse removal could not be verified; no further mutation")
                state["cleanup"] = "removed own mapping"
            else:
                state["cleanup"] = "already absent"
        else:
            state["cleanup"] = "preserved existing mapping"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--platform", choices=("android", "ios"), default="android")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--run-id", default=None)
    parser.add_argument("--phase", choices=("both", "check"), default="both")
    parser.add_argument("--adb", default=os.environ.get("ADB"))
    parser.add_argument("--host", choices=("10.0.2.2", "127.0.0.1", "localhost"))
    parser.add_argument("--system-actions", action="store_true",
                        help="Native Card/QR/Share/Open через отдельный platform host coordinator на port3811")
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
    adb = None
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
        stop = [adb, "-s", args.device, "shell", "am", "force-stop", "dev.snownumb.stackcard"]
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
        "systemActions": args.system_actions,
        "scope": "native SDK/controller/Card UI with local Auth/Firestore and HTTP backend",
        "phases": [], "checkpoints": [],
        "excluded": [f"{'iOS' if args.platform == 'android' else 'Android'} acceptance", "physical camera QR scan",
                     "production hosting", "system picker permission denial", "full UI onboarding/import"],
    }
    if not args.system_actions:
        report["excluded"].append("native Share/Open")
    try:
        with android_reader_reverse(adb, args.device, args.system_actions and args.platform == "android") as reverse:
            report["readerReverse"] = reverse
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
                        # Pub также обновляет native registrant: после release нужны dev plugins.
                        command = [
                            "flutter", "drive", "--no-uninstall-first", "--no-dds",
                            "--keep-app-running",
                            "--driver=test_driver/integration_test.dart",
                            "--target=integration_test/main_portfolio_runtime_test.dart",
                            "-d", args.device,
                            "--dart-define=RUN_MAIN_PORTFOLIO_ACCEPTANCE=true",
                            f"--dart-define=MAIN_PORTFOLIO_PHASE={phase}",
                            f"--dart-define=MAIN_PORTFOLIO_RUN_ID={run}",
                            f"--dart-define=MAIN_PORTFOLIO_EMULATOR_HOST={host}",
                        ]
                        if args.system_actions:
                            command.append("--dart-define=RUN_NATIVE_SYSTEM_ACTIONS=true")
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
    except Exception:
        report["status"] = "failed"
        raise
    finally:
        output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n")
    print(f"Native journey passed: {output}")


if __name__ == "__main__":
    main()
