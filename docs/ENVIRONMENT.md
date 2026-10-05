# Development environment

Inventory and status recorded on 2026-10-04. The active, verified Garmin Connect IQ SDK 9.2.0 is `/private/tmp/garmin-sdk`. SDK Manager also has a managed 9.2.0 installation at `/Users/eknid.mucollari/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2`.

## Tooling and target profiles

| Item | Verified state |
| --- | --- |
| Monkey C compiler | `/private/tmp/garmin-sdk/bin/monkeyc`; SDK 9.2.0 compiler invocation succeeds with OpenJDK 25.0.1. |
| Simulator | Universal arm64/x86_64 simulator at `/private/tmp/garmin-sdk/bin/ConnectIQ.app/Contents/MacOS/simulator`. Production startup smoke passed on all five current profiles; the `fenix847mm` release also remained running for over 30 seconds without error logs. The user previously confirmed the app screen is visible; OS automation permissions still prevent automated screenshot capture. Simulator engine uses TCP port 1234. |
| Test runner | `/private/tmp/garmin-sdk/bin/monkeydo`; it can return exit code 1 even when Run No Evil reports a clean pass. The project helper parses the authoritative `RESULTS PASSED` summary and pass/fail/error counts. Fresh full run for the trace-updated source: 50 passed, 0 failed, 0 errors, zero compiler warnings. |
| Java | `/usr/bin/java`, OpenJDK `25.0.1` (build `2025-10-21`). |
| Signing key | `$HOME/.garmin-climb/developer_key.der`, RSA-4096 PKCS#8 DER, file mode `0600` in a mode `0700` directory, outside the repository. Use `CIQ_KEY` or `--key`; never commit or expose key contents. |
| Build tools | `tools/ciq.py` supports `doctor`, `build`, `run`, and `test`; `.vscode/tasks.json` calls the CLI without storing a local key path. |

SDK Manager device profiles are installed at `/Users/eknid.mucollari/Library/Application Support/Garmin/ConnectIQ/Devices`. All five fēnix 8 products have the official `compiler.json` and `simulator.json` files. The device metadata reports Connect IQ API level 6.0.3 and a 786,432-byte Watch App memory limit. The helper checks official profiles and will fail if they are absent or malformed.

| Product ID | Device Reference entry |
| --- | --- |
| `fenix843mm` | fēnix 8 43mm |
| `fenix847mm` | fēnix 8 47mm / 51mm AMOLED; reference also groups tactix 8 and quatix 8 models |
| `fenix8solar47mm` | fēnix 8 Solar 47mm |
| `fenix8solar51mm` | fēnix 8 Solar 51mm; reference also groups tactix 8 Solar 51mm |
| `fenix8pro47mm` | fēnix 8 Pro 47mm / 51mm and MicroLED; reference also groups quatix 8 Pro |

## Verified project status

- M0 environment and project foundation: complete.
- M0 through M2: complete; manual session, climb, Boulder, pause/resume, save/discard, and recording lifecycle flows passed.
- M3 Rope altitude end detection: complete. Production compile and simulator launch passed with zero warnings; independent Sol review approved it.
- M4 manual mixed-mode flow: complete; modes can be assigned between climbs in one session.
- Run No Evil: fresh full run 50 passed, 0 failed, 0 errors, zero compiler warnings. Coverage includes native recording lifecycle and mixed-mode acceptance, Auto start/end/manual overrides, view/controller integration, FIT fixture recording, detector/filter regressions, and 100-climb storage persistence/readback.
- Storage regression: an injected failure at the page boundary was exercised; 256 attempts remained persisted in bounded 16-entry pages. Snapshot-clearing and sensor cleanup after suspension regressions also passed. Measured domain memory was 145,368 bytes at 100 climbs and 236,512 bytes at 256; system RAM after the native 100-climb storage test was 101,776 bytes.
- M5 custom FIT developer fields: complete; the saved three-climb mixed-mode simulator FIT passed the decoder, expected-value, CRC, and cleared-tail checks. See [FIT_FIELDS.md](FIT_FIELDS.md).
- M6 Auto start/end detection: complete as software; the feature remains experimental until physically calibrated.
- M7 software gate: full suite and five trace-updated signed release builds complete with zero warnings. Current-source startup smokes passed on all five profiles. The `fenix847mm` production PRG launched for over 30 seconds with no error logs.
- User-confirmed simulator screen visibility is available, but automated screenshot proof remains blocked by OS automation permissions.
- No real-watch sideload or physical climbing calibration has been completed.

See [BUILD.md](BUILD.md) for commands and [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for milestone status.
