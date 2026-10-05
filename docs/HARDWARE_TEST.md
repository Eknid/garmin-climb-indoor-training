# Hardware test plan

## Current status

No physical-watch test has been completed. SDK 9.2.0 and all five official fēnix 8 profiles are installed. The trace-updated source passed 50 tests with zero failures/errors/warnings and all five release builds completed without warnings. Startup smoke checks passed on all five current profiles; the main release also ran for more than 30 seconds without errors. Rope and Auto thresholds still require physical calibration; Auto is altitude-only and can mistake stairs, elevators, or pressure changes for climbing.

The user previously confirmed that the app screen is visible in the simulator. Automated visual capture is unavailable because operating-system automation permissions continue to deny the capture flow, despite being enabled. This is not physical-watch validation.

Record the exact watch variant, firmware, app build, date, and observations for each real session. Do not describe Rope or Auto accuracy as validated until it has been tested during real climbing. Keep normal belay and descent safety practices; the app is a workout logger, not a safety device.

## Before the session

- [ ] Confirm the exact watch variant and match it to an SDK product ID.
- [ ] Record firmware and release app build identifiers.
- [ ] Confirm the app is installed and launches.
- [ ] Check battery, free storage, and requested Fit, Sensor, and FitContributor permissions.
- [ ] Check whether heart rate and altitude are available; note missing or delayed samples.
- [ ] Use an appropriate safe climbing setup with a partner/belay where required.

## Manual Boulder and session lifecycle

- [ ] Start one overall session with START/STOP.
- [ ] Start a Boulder climb with BACK/LAP.
- [ ] Check climb timer, relative altitude, and heart rate when available.
- [ ] Finish with BACK/LAP and verify the climb summary and rest timer.
- [ ] Change mode between attempts and verify the previous attempt keeps its original mode.
- [ ] Pause while resting, resume, and confirm active elapsed-time behavior.
- [ ] While climbing, cancel the session-stop confirmation once; verify the climb continues.
- [ ] Confirm session stop, then save and inspect the session summary.
- [ ] Repeat a session and discard it; verify no activity is saved.

## Rope end detection

M3 simulator integration passed; this section checks real-world calibration after a device release is available.

- [ ] Select Rope and start manually with BACK/LAP.
- [ ] Ascend past the selected arming gain, then descend steadily; record the logical peak end time and later detection time.
- [ ] Verify automatic finish is not triggered before sufficient ascent and descent persistence.
- [ ] Try a brief dip and recovery; verify it does not finish early.
- [ ] Try a descent trend that stalls/rebounds; verify the detector waits or resets its evidence.
- [ ] Try missing altitude samples and a pause/confirmation interruption; verify manual finish remains available and the detector recovers safely.
- [ ] Finish another Rope climb manually with BACK/LAP.
- [ ] Repeat with Conservative, Normal, and Sensitive presets and note false endings/missed endings.

## Activity and FIT checks

- [ ] Save a mixed Rope/Boulder session and sync it to Garmin Connect.
- [ ] Verify the overall activity appears as a rock-climbing activity with the expected laps.
- [ ] Inspect lap ordering/durations against observed climbs and note that the FIT lap is added when an automatic descent is confirmed.
- [ ] Verify Garmin Connect displays the custom fields and lap ordering as expected on the actual watch and after sync; simulator FIT validation is complete, but no physical-device presentation check has occurred.

## Auto mode

Auto start/end detection is experimental. Perform these checks only after installing a verified release build and use a safe climbing setup:

- [ ] Try a flat/noisy trace, a short ascent/return, and a sustained climb.
- [ ] Verify valid starts and real descents are detected, while flat noise and short candidates are rejected.
- [ ] Verify BACK/LAP manual overrides work in watching and climbing states.
- [ ] Record false starts, missed starts, early finishes, and missed finishes with timestamps/debug traces.

## Results log

| Date/time | Watch model / firmware | App build | Mode/scenario | Expected | Observed | Detector/debug notes |
|---|---|---|---|---|---|---|
| Pending | Pending | Pending | Pending | Pending | No hardware run yet | Pending |

For detector failures, capture raw and filtered altitude, relative altitude, peak/drop values, selected preset, detector state, and logical/detection timestamps. Development builds can expose this data through the `DIAGNOSTICS` climbing page and 1 Hz `TRACE` simulator logs. They are enabled only when `AppConstants.DEBUG_BUILD` and the debug setting are both true; production builds keep diagnostics disabled. A trace line is printed before detector evaluation, so its state/counters are those entering that tick. Accepted Auto starts and completed climbs get separate event logs with logical and detection timestamps; completion also records height and reason. Build and validate the current production artifacts before physical testing. Physical threshold calibration remains a separate task after software validation.
