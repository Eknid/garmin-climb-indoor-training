# Build and simulator commands

## Current status

`tools/ciq.py` provides SDK discovery, readiness checks, development/release builds, simulator runs, and Run No Evil test invocation. Climb Indoor Training passes the current 57-test suite; see [training-tests.log](../validation/training-tests.log). Final signed releases for all five profiles and production/private-beta IQ packages are in `dist`; [training-builds.log](../validation/training-builds.log), [training-package.log](../validation/training-package.log), and [artifacts.json](../validation/artifacts.json) record their build evidence. The latest mixed FIT fixture validates type/outcome summaries and 66.7% success exactly; see [FIT_FIELDS.md](FIT_FIELDS.md). Older `tests.log`/`launches.json` describe the earlier M0–M7 baseline. Physical calibration and Garmin Connect sync testing remain; use [CONNECT_SETUP.md](CONNECT_SETUP.md) for the beta setup.

The working SDK 9.2.0 is `/private/tmp/garmin-sdk`; SDK Manager's managed copy is under `~/Library/Application Support/Garmin/ConnectIQ/Sdks`. All five fēnix 8 device profiles are installed under `~/Library/Application Support/Garmin/ConnectIQ/Devices`. The wrapper requires official `compiler.json` and `simulator.json` files for the selected device. It never fabricates or substitutes device profiles.

## Prerequisites

- Python 3.
- A complete Garmin Connect IQ SDK installation. Discovery checks `--sdk`, `CIQ_SDK`, SDK Manager's managed `Sdks` directories, then `/private/tmp/garmin-sdk`. A usable SDK must contain `bin/monkeyc`, `bin/monkeybrains.jar`, `bin/compilerInfo.xml`, and `bin/version.txt`.
- The official device profile (`Devices/<device>/compiler.json` and `simulator.json`). The default is `fenix847mm` (fēnix 8 47mm/51mm AMOLED). Other SDK documented IDs are `fenix843mm`, `fenix8solar47mm`, `fenix8solar51mm`, and `fenix8pro47mm`.
- A readable developer signing key. Provide `--key /path/to/developer_key` or set `CIQ_KEY` to its path. The key must stay outside the repository. The helper does not print its contents or echo compiler arguments.
- A project root containing `manifest.xml` and `monkey.jungle`.

## Commands

Check the local setup (the doctor exits nonzero while required build prerequisites are missing):

```sh
python3 tools/ciq.py doctor
python3 tools/ciq.py doctor --device fenix8solar47mm --key "$CIQ_KEY"
```

Compile a development build to `bin/Climb-<device>.prg`:

```sh
export CIQ_KEY="$HOME/path/to/developer_key"
python3 tools/ciq.py build
python3 tools/ciq.py build --device fenix843mm
```

Compile a signed release build with debug information stripped to `dist/Climb-<device>.prg`:

```sh
python3 tools/ciq.py build --release
```

When SDK discovery does not select the desired install, set `CIQ_SDK` or pass `--sdk`:

```sh
python3 tools/ciq.py doctor --sdk "$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks/connectiq-sdk-mac-9.2.0-2026-06-09-92a1605b2"
python3 tools/ciq.py build --sdk "$CIQ_SDK"
```

The run command expects the simulator to already be listening on `127.0.0.1:1234`; it uses `monkeydo` and does not start or restart the simulator engine:

```sh
python3 tools/ciq.py run
python3 tools/ciq.py run --release
python3 tools/ciq.py run --prg path/to/app.prg
```

Compile with the SDK's test flag and run Run No Evil tests in the already-running simulator:

```sh
python3 tools/ciq.py test
python3 tools/ciq.py test --test-name altitudeMedianEmaAndSpike
```

For a fresh full Run No Evil run, fully quit Connect IQ Simulator and restart it before running the test command. Native `ActivityRecording` state may outlive a test/app run in the simulator; a fresh simulator process prevents an earlier open native session from contaminating the next recording fixture. Then make sure the engine is listening on port 1234.

For any command, `--help` works before the project exists:

```sh
python3 tools/ciq.py --help
python3 tools/ciq.py build --help
```

## Output and safety

- Development PRGs are written under `bin/`; release PRGs are written under `dist/`.
- Test compilation produces `bin/Climb-<device>-tests.prg`.
- `run` and `test` leave an existing simulator engine running and report a clear error if port 1234 is unavailable.
- `doctor` reports whether a key path is readable, without reading or printing key contents.
- Never commit the signing key or generated artifacts unless a separate release workflow explicitly requires them.

The earlier 50-test baseline included native recording and FIT fixture coverage, Auto start/end and manual-override scenarios, view/controller integration, 100-climb storage persistence/readback, and Rope detector/filter regressions. Measured domain memory was 145,368 bytes at 100 climbs and 236,512 bytes at 256. `System.getSystemStats().usedMemory` reported 101,776 bytes of RAM after the native 100-climb storage/readback test; that figure is not the application's storage capacity. Rope and Auto thresholds have not been calibrated on real climbs. Five release PRGs have been rebuilt from the current source, which also adds seven UI/outcome regression tests; physical-watch sideload has not been verified.
