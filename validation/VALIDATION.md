# Software validation — 2026-10-04

Climb completed its M0–M7 software gates using Connect IQ SDK 9.2.0 and the official fēnix 8 profiles. Physical installation, Garmin Connect sync, and real-climb detector calibration have not been performed.

| Check | Evidence | Result |
| --- | --- | --- |
| Full Run No Evil suite in a fresh simulator | [tests.log](tests.log) | 50 passed, 0 failed, 0 errors; compile successful without warnings |
| Signed release builds, all five profiles | [builds.log](builds.log), [artifacts.json](artifacts.json) | PASS; no compiler warnings |
| Production startup, all five profiles | [launches.json](launches.json) | No runtime errors during six-second startup checks |
| Main fēnix 8 production launch | [launch.log](launch.log) | Remained attached and running for more than 30 seconds without error output |
| Exact mixed-mode FIT fixture, including pause/resume | [mixed-climbs.fit](mixed-climbs.fit), [mixed-climbs.json](mixed-climbs.json) | CRC/integrity PASS; 22 fields; three climb laps and one cleared tail; all expected values match |
| Controller acceptance with real FIT recorder | [acceptance.fit](acceptance.fit), [acceptance.json](acceptance.json) | Manual Rope/Boulder, detected Auto start/end, pause/resume/save; three climbs with modes 1/2/3 and matching totals |
| Real local history persistence | `storageHundredClimbsPersistAndReadBack` in full suite | 100 climbs written and read back through Application.Storage |
| Bounded domain history | `boundedHistoryAndHundredClimbs` in full suite | 100 and 256 climbs; further attempts safely rejected |
| Editor and resource configuration | [project-audit.json](project-audit.json) | JSON/XML parse checks passed; no required TODO/FIXME/HACK/placeholder implementation remains |

RAM samples from the test image were 145,368 bytes at 100 domain climbs, 236,512 bytes at 256 domain climbs, and 101,776 bytes during the native 100-climb persistence/readback test. The latter is RAM use, not the size of stored history. Official profiles allow 786,432 bytes for a Watch App. These samples are observations, not a peak-memory guarantee.

Independent Sol reviews approved the detector/controller continuity changes and M6/M7 UI behavior after inspection of actual source and the passing regression results. Regression coverage includes separately allocated string selectors, safe confirmation defaults, mode locking, manual overrides, stale-filter prevention after menus and completion, missing sensors, recording failures, and cleanup.

The workspace started empty without Git metadata. [source-diff.log](source-diff.log) compares the new source against an empty directory; the final audit records project file hashes. Private signing keys are stored outside the project and are absent from the deliverables.

Production screenshot capture remains unavailable because macOS denied automation access. The user previously confirmed that the Climb screen was visible. Startup checks and behavioral tests do not establish pixel-level layout verification or physical-watch detector accuracy.

Fully quit and relaunch the simulator before repeating the complete native-recording suite or recapturing a FIT fixture. SDK simulator state can retain activity data across earlier runs. The build/test helper checks authoritative test counts and does not silently restart the simulator.


## UI correction from supplied screenshots

The later page-rendering change removes opaque text backgrounds that erased headings beneath number-font padding, and removes page-level button instructions. The focused rendering-contract test passed across all normal states/pages at four screen sizes; see [ui-fix-tests.log](ui-fix-tests.log). The original 50-test full suite above predates this UI change; the new rendering test is an additional test in the current suite. All five release builds passed without warnings after the correction; the updated main release was launched in the simulator. This regression checks drawing calls and page content, not screenshot pixels.


## Launcher icon update — 2026-10-05

The exact user-supplied PNG is retained in `resources/drawables/launcher_icon.png` and referenced by all launcher resource variants. Garmin's compiler applies the native profile sizes. All five release builds passed without warnings; current binary hashes are in [artifacts.json](artifacts.json). This resource-only update does not change application logic.

## Climb Indoor Training update (2026-10-05)

The renamed app adds pre-start BACK exit, page dots, mandatory outcome choice, overall success rate, and per-type saved results. [training-tests.log](training-tests.log) reports 57 passed, 0 failed, 0 errors. New coverage includes short failed attempts, outcome-before-pause ordering, forced-exit unrated handling, field capacity and retry, and four display sizes.

[training-mixed-climbs.fit](training-mixed-climbs.fit) / [training-mixed-climbs.json](training-mixed-climbs.json) are the version-2 golden recording: 29 fields, three attributed climb laps, one cleared tail, Rope success / Boulder failure / Auto success, and 66.7% overall success. Garmin’s official decoder validates CRC, all exact fixture values, totals, outcomes, and readable per-type pairs. Original M0–M7 recordings/logs above remain historical.

Final five-profile builds are recorded in [training-builds.log](training-builds.log); production/private beta packages in [training-package.log](training-package.log). Current sizes/hashes are in [artifacts.json](artifacts.json). Garmin Connect Mobile rendering is not verified: the app must first be uploaded/installed through Connect IQ so Garmin has its FIT display metadata. See [CONNECT_SETUP.md](../docs/CONNECT_SETUP.md). No account upload, public release, or physical-watch installation occurred.
