#!/usr/bin/env python3
"""Build, run, and inspect a Garmin Connect IQ Monkey C project."""

from __future__ import annotations

import argparse
import json
import os
import re
import socket
import subprocess
import sys
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DEVICE = "fenix847mm"
SIMULATOR_HOST = "127.0.0.1"
SIMULATOR_PORT = 1234
SDK_SUPPORT_ROOTS = (
    Path.home() / "Library/Application Support/Garmin/ConnectIQ",
    Path.home() / ".Garmin/ConnectIQ",
)


def sdk_is_complete(path: Path) -> bool:
    """Reject partial SDK Manager installs and arbitrary documentation copies."""
    bin_dir = path / "bin"
    return all(
        (bin_dir / required).is_file()
        for required in ("monkeyc", "monkeybrains.jar", "compilerInfo.xml", "version.txt")
    )


def sdk_candidates(explicit: str | None) -> Iterable[Path]:
    if explicit:
        yield Path(explicit).expanduser()
        return
    env_sdk = os.environ.get("CIQ_SDK")
    if env_sdk:
        yield Path(env_sdk).expanduser()
    for support in SDK_SUPPORT_ROOTS:
        # SDK Manager keeps SDK versions in its Sdks directory. A root can also
        # be set directly by current-sdk.cfg on some installations.
        current_cfg = support / "current-sdk.cfg"
        if current_cfg.is_file():
            try:
                configured = Path(current_cfg.read_text(encoding="utf-8").strip()).expanduser()
                if configured:
                    yield configured
            except OSError:
                pass
        for sdk in sorted((support / "Sdks").glob("*"), reverse=True):
            if sdk.is_dir():
                yield sdk
    yield Path("/private/tmp/garmin-sdk")


def locate_sdk(explicit: str | None) -> tuple[Path | None, list[tuple[Path, bool]]]:
    checked: list[tuple[Path, bool]] = []
    seen: set[str] = set()
    for candidate in sdk_candidates(explicit):
        candidate = candidate.resolve()
        identity = str(candidate)
        if identity in seen:
            continue
        seen.add(identity)
        complete = sdk_is_complete(candidate)
        checked.append((candidate, complete))
        if complete:
            return candidate, checked
        if explicit:
            break
    return None, checked


def locate_device(sdk: Path, device: str) -> tuple[Path | None, list[Path]]:
    roots: list[Path] = [sdk / "Devices"]
    roots.extend(support / "Devices" for support in SDK_SUPPORT_ROOTS)
    checked: list[Path] = []
    for root in roots:
        profile = root / device
        checked.append(profile)
        compiler_profile = profile / "compiler.json"
        simulator_profile = profile / "simulator.json"
        if compiler_profile.is_file() and simulator_profile.is_file():
            try:
                metadata = json.loads(compiler_profile.read_text(encoding="utf-8"))
                json.loads(simulator_profile.read_text(encoding="utf-8"))
            except (OSError, json.JSONDecodeError):
                continue
            if metadata.get("deviceId") == device:
                return profile, checked
    return None, checked


def key_path(explicit: str | None) -> Path | None:
    value = explicit or os.environ.get("CIQ_KEY")
    return Path(value).expanduser().resolve() if value else None


def key_ready(path: Path | None) -> bool:
    return bool(path and path.is_file() and os.access(path, os.R_OK))


def project_ready() -> bool:
    return (ROOT / "manifest.xml").is_file() and (ROOT / "monkey.jungle").is_file()


def simulator_ready() -> bool:
    try:
        with socket.create_connection((SIMULATOR_HOST, SIMULATOR_PORT), timeout=0.5):
            return True
    except OSError:
        return False


def fail(message: str, code: int = 2) -> int:
    print(f"error: {message}", file=sys.stderr)
    return code


def runtime(args: argparse.Namespace, *, needs_key: bool, needs_project: bool = True):
    sdk, checked_sdks = locate_sdk(args.sdk)
    if sdk is None:
        if checked_sdks:
            paths = ", ".join(f"{p} (incomplete)" for p, _ in checked_sdks)
            return None, None, None, fail(f"no complete Connect IQ SDK found; checked {paths}")
        return None, None, None, fail("no Connect IQ SDK found; set --sdk or CIQ_SDK")

    device_profile, checked_profiles = locate_device(sdk, args.device)
    if device_profile is None:
        searched = ", ".join(str(p) for p in checked_profiles)
        return sdk, None, None, fail(
            f"device '{args.device}' is not installed (requires official compiler.json and "
            f"simulator.json under Devices/<device>); checked {searched}. Install it with SDK Manager."
        )

    key = key_path(getattr(args, "key", None))
    if needs_key and not key_ready(key):
        return sdk, device_profile, key, fail(
            "a readable developer key is required; pass --key PATH or set CIQ_KEY (key contents are never displayed)"
        )
    if needs_project and not project_ready():
        return sdk, device_profile, key, fail("project root must contain manifest.xml and monkey.jungle")
    return sdk, device_profile, key, 0


def compiler_args(sdk: Path, device: str, key: Path, output: Path, *, tests: bool = False,
                  release: bool = False) -> list[str]:
    command = [
        str(sdk / "bin/monkeyc"),
        "-f", str(ROOT / "monkey.jungle"),
        "-d", device,
        "-y", str(key),
        "-o", str(output),
    ]
    if tests:
        command.append("-t")
    if release:
        command.append("-r")
    return command


def call(command: list[str], *, cwd: Path = ROOT) -> int:
    try:
        # Never echo argv: it contains the private-key path and need not be logged.
        return subprocess.run(command, cwd=cwd, check=False).returncode
    except OSError as exc:
        return fail(f"could not start SDK command ({exc.strerror or exc.__class__.__name__})")


def output_for(device: str, release: bool) -> Path:
    if release:
        return ROOT / "dist" / f"Climb-{device}.prg"
    return ROOT / "bin" / f"Climb-{device}.prg"


def command_build(args: argparse.Namespace) -> int:
    sdk, _, key, status = runtime(args, needs_key=True)
    if status:
        return status
    output = output_for(args.device, args.release)
    output.parent.mkdir(parents=True, exist_ok=True)
    command = compiler_args(sdk, args.device, key, output, release=args.release)
    result = call(command)
    if result == 0:
        print(f"Build output: {output.relative_to(ROOT)}")
    return result


def command_test(args: argparse.Namespace) -> int:
    sdk, _, key, status = runtime(args, needs_key=True)
    if status:
        return status
    if not simulator_ready():
        return fail(
            f"Connect IQ simulator is not listening on {SIMULATOR_HOST}:{SIMULATOR_PORT}; "
            "launch the simulator for this SDK first. Existing simulator processes are left untouched."
        )
    output = ROOT / "bin" / f"Climb-{args.device}-tests.prg"
    output.parent.mkdir(parents=True, exist_ok=True)
    result = call(compiler_args(sdk, args.device, key, output, tests=True))
    if result:
        return result
    command = [str(sdk / "bin/monkeydo"), str(output), args.device, "-t"]
    if args.test_name:
        command.append(args.test_name)
    try:
        run = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, check=False)
    except OSError as exc:
        return fail(f"could not start SDK test runner ({exc.strerror or exc.__class__.__name__})")
    output_text = "\n".join(part for part in (run.stdout, run.stderr) if part)
    if output_text:
        print(output_text, end="" if output_text.endswith("\n") else "\n")

    summary = re.search(
        r"\b(PASSED|FAILED)\s*\(passed=(\d+),\s*failed=(\d+),\s*errors=(\d+)\)",
        output_text,
    )
    ran = re.search(r"\bRan (\d+) tests?\b", output_text)
    if not summary or not ran or "RESULTS" not in output_text:
        return fail("Run No Evil did not report a complete authoritative RESULTS summary", run.returncode or 1)
    passed, failed, errors = (int(summary.group(i)) for i in (2, 3, 4))
    if int(ran.group(1)) != passed + failed + errors or passed == 0:
        return fail("Run No Evil result counts are inconsistent or no tests ran", 1)
    if summary.group(1) != "PASSED" or failed != 0 or errors != 0:
        return fail(f"Run No Evil reported {passed} passed, {failed} failed, {errors} errors", 1)

    return 0


def command_run(args: argparse.Namespace) -> int:
    sdk, _, _, status = runtime(args, needs_key=False)
    if status:
        return status
    if not simulator_ready():
        return fail(
            f"Connect IQ simulator is not listening on {SIMULATOR_HOST}:{SIMULATOR_PORT}; "
            "launch the simulator for this SDK first. Existing simulator processes are left untouched."
        )
    app = args.prg or output_for(args.device, args.release)
    if not app.is_absolute():
        app = (ROOT / app).resolve()
    if not app.is_file():
        return fail(f"compiled app not found: {app}; run `python3 tools/ciq.py build` first")
    return call([str(sdk / "bin/monkeydo"), str(app), args.device])


def command_doctor(args: argparse.Namespace) -> int:
    sdk, checked_sdks = locate_sdk(args.sdk)
    print(f"Project files: {'ready' if project_ready() else 'pending (manifest.xml and/or monkey.jungle missing)'}")
    if sdk:
        version = (sdk / "bin/version.txt").read_text(encoding="utf-8").strip()
        print(f"SDK: ready ({version}) at {sdk}")
    else:
        print("SDK: unavailable (no complete SDK found)")
        for path, complete in checked_sdks:
            print(f"  checked: {path} ({'complete' if complete else 'incomplete'})")
    if sdk:
        profile, checked_profiles = locate_device(sdk, args.device)
        print(f"Device {args.device}: {'ready' if profile else 'missing official device profile'}")
        for checked in checked_profiles:
            print(f"  profile: {checked}")
    key = key_path(args.key)
    if key_ready(key):
        print(f"Developer key: readable at {key} (contents not inspected)")
    elif key:
        print(f"Developer key: configured path is missing or unreadable ({key})")
    else:
        print("Developer key: not configured (use --key or CIQ_KEY)")
    print(f"Simulator port {SIMULATOR_PORT}: {'listening' if simulator_ready() else 'not listening'}")
    ready = bool(sdk and locate_device(sdk, args.device)[0] and key_ready(key) and project_ready())
    print(f"Build prerequisites: {'ready' if ready else 'pending'}")
    return 0 if ready else 1


def add_common(parser: argparse.ArgumentParser, *, key: bool = False) -> None:
    parser.add_argument("--sdk", help="Connect IQ SDK root (overrides CIQ_SDK and discovery)")
    parser.add_argument("--device", default=DEFAULT_DEVICE, help=f"installed device ID (default: {DEFAULT_DEVICE})")
    if key:
        parser.add_argument("--key", help="developer key path (or set CIQ_KEY); key contents are never shown")


def make_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build and run the Climb Connect IQ app")
    subparsers = parser.add_subparsers(dest="command", required=True)

    doctor = subparsers.add_parser("doctor", help="report SDK, device, signing, and project readiness")
    add_common(doctor, key=True)
    doctor.set_defaults(handler=command_doctor)

    build = subparsers.add_parser("build", help="compile a development or signed release PRG")
    add_common(build, key=True)
    build.add_argument("--release", action="store_true", help="strip debug symbols and write dist/Climb-<device>.prg")
    build.set_defaults(handler=command_build)

    run = subparsers.add_parser("run", help="run an existing PRG in an already-running simulator")
    add_common(run)
    run.add_argument("--prg", type=Path, help="PRG path (default: bin/Climb-<device>.prg)")
    run.add_argument("--release", action="store_true", help="run dist/Climb-<device>.prg")
    run.set_defaults(handler=command_run)

    test = subparsers.add_parser("test", help="compile Run No Evil tests and run them in the simulator")
    add_common(test, key=True)
    test.add_argument("--test-name", help="optional Run No Evil class or method name")
    test.set_defaults(handler=command_test)
    return parser


def main() -> int:
    parser = make_parser()
    args = parser.parse_args()
    return args.handler(args)


if __name__ == "__main__":
    raise SystemExit(main())
