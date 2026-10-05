# Altitude detection

The detector input is filtered barometric altitude. Rope and Auto share the five-sample median plus EMA filter, but use separate detector logic. Boulder remains manual. Auto mode is experimental; altitude thresholds have not been calibrated during physical climbs. BACK/LAP remains available to start and finish attempts manually. Attempts shorter than 3,000 ms are invalid only when height is unavailable or below 0.5 m; these attempts are marked cancelled and do not produce a normal completed-climb lap.

## Sample path and filter

`AppController` samples `Sensor.getInfo()` on a 1-second tick through `SensorService`, retaining nullable altitude, heart rate, pressure, and acceleration. Detectors consume filtered altitude and timestamps; heart rate contributes to climb summaries but is not a detection input.

`AltitudeFilter` buffers five consecutive non-null samples, sorts that bounded window, and selects the median. It outputs no filtered value until the window is full after startup, reset, missing altitude, or a sample gap over 2,500 ms. The first output initializes the EMA; later outputs use:

```text
filtered = median                                      on filter initialization
filtered = filtered + 0.35 * (median - filtered)      on later samples
```

An isolated spike in any of the five window positions is rejected by the median. A null or long gap clears the filter window and EMA; negative time movement is rejected. Null is never substituted with zero.

## Relative altitude and peak

For a manually started Rope or Boulder attempt, `ClimbAttempt` starts from the current filtered altitude if available; otherwise, the first valid sample establishes its altitude baseline. For automatically started Auto attempts, the baseline is the altitude at the logical Auto start timestamp described below. The domain tracks:

```text
relative altitude = current filtered altitude - climb start altitude
peak gain = highest filtered altitude - climb start altitude
peak time = first timestamp at a strict new high
```

Equal values do not move the peak timestamp. When altitude is missing, current relative height becomes unavailable while the established peak and height remain. Attempt duration and height use logical start/end times, not the later detector-confirmation times.

## Rope automatic finish

Rope starts manually. Its detector arms only after the peak gain reaches the selected threshold. A descent can finish the attempt only when the detector is armed, the drop from peak reaches the selected threshold, the logical peak is at least 5,000 ms after climb start, at least three qualifying descending steps were observed, and the descent duration threshold was met. A step qualifies when altitude change is `<= -0.05 m`. A rebound `> 0.15 m` clears descent evidence; no qualifying down step within 1,500 ms expires the trend. A new strict peak also clears descent evidence.

| Auto End Sensitivity | Arm gain | Drop from peak | Confirmed descent duration |
|---|---:|---:|---:|
| Conservative | 4.0 m | 3.0 m | 4,000 ms |
| Normal | 3.0 m | 2.5 m | 3,000 ms |
| Sensitive | 2.5 m | 2.0 m | 3,000 ms |

The detector emits `endAt` equal to the peak timestamp and `detectedAt` equal to the later sample that confirms descent. Thus displayed duration ends at the logical peak; Garmin's `addLap()` is called at confirmation time. Heart-rate aggregates are restored to the samples captured at the peak for a delayed automatic finish. BACK/LAP manually finishes regardless of arming or altitude availability.

## Auto start and finish

`AutoClimbDetector` watches while the selected mode is Auto and the workout is resting or climbing. Its internal start flow is `WATCHING` → `POSSIBLE_START` → `CLIMBING`; the reused Rope detector reports an ending trend as `POSSIBLE_END` and then emits the confirmed end. Auto detects altitude movement only; no accelerometer or movement score is used.

### Candidate and confirmation rules

While watching, a resting baseline follows altitude using `baseline += 0.05 * (altitude - baseline)`, but only when there is no candidate rise in progress. The detector calculates slope as `(currentAltitude - previousAltitude) / elapsedSeconds` from consecutive filtered-altitude samples. A sample is an upward sample if its slope is at least the selected minimum. Candidate gain is measured from the first sample before the first qualifying upward slope (`_riseAltitude`), not from the adaptive resting baseline. At least three qualifying upward samples and the candidate-gain threshold are required to enter `POSSIBLE_START`.

When `POSSIBLE_START` is first entered, the current sample's timestamp and altitude are captured as the logical start. This intentionally happens after the candidate threshold is reached, rather than backdating the climb to the first upward sample. Confirmation still compares total gain from the original resting-ascent onset (`_riseAltitude`) against the larger confirm-gain threshold. On confirmation, the climb's relative-height baseline is the candidate-start altitude, so height excludes the initial gain before candidate entry. A bounded 12-sample history lets the controller replay heart-rate samples at or after that logical start into the climb without counting them a second time in session HR totals.

The confirmation requires all of the following:

1. Total gain from the first upward-slope origin is at least the selected confirmation threshold.
2. Confirmation arrives on a later sample than candidate entry (`now > candidateStartTimestamp`).
3. The current slope still meets the selected minimum upward slope.
4. At least three qualifying upward samples have been observed.

Threshold comparisons use `>=`, so equality reaches candidate/confirmation thresholds. The 8-second rise window is measured from the first qualifying upward-slope origin. Candidate state is cleared if that window expires, if qualifying ascent stalls for more than 1,500 ms, or if a single sample drops more than 0.15 m (`change < -0.15 m`). Missing altitude and gaps over 2,500 ms break candidate continuity. These gates reject flat noise, slow baseline drift, short movement, and a candidate that returns toward its resting altitude.

### Auto Start Sensitivity presets

| Auto Start Sensitivity | Candidate gain | Confirmation gain | Minimum upward slope |
|---|---:|---:|---:|
| Conservative | 1.5 m | 2.5 m | 0.15 m/s |
| Normal | 1.2 m | 2.0 m | 0.12 m/s |
| Sensitive | 1.0 m | 1.8 m | 0.10 m/s |

Once Auto confirms a start, the same climb's Auto end uses the Rope detector with the separately selected Auto End Sensitivity preset. It emits the peak timestamp as logical `endAt` and confirmation sample as `detectedAt`. BACK/LAP can manually start Auto while watching and manually finish an active attempt at any time.

Auto is altitude-only, so stairs, elevators, or rapid barometric pressure changes may look like climbing. Slow climbs, short climbs, and climbs that never meet the configured candidate/confirmation gain may be missed. The 5-sample filter warmup plus candidate and confirmation gates delay automatic starts; descent persistence delays automatic finishes. Manual BACK/LAP overrides remain available while automation watches or climbs. Treat Auto as an experimental workout aid until tested on the user's watch and calibrated with real climbing traces.

### Auto timing decision

The recorded start is the point where the candidate threshold is attained, not the first upward sample. This makes start height and duration correspond to the confirmed candidate stage and avoids backdating an attempt through uncertain early movement. The detector still uses total gain from resting-ascent onset to confirm the movement. As a consequence, climb relative height excludes pre-candidate gain; only heart-rate history from the logical start onward is replayed into that climb. This accepted behavior is also recorded in [DECISIONS.md](DECISIONS.md).

## Constants and lifecycle behavior

Shared filter and recovery constants: median window `5`; EMA alpha `0.35`; sensor gap `2,500 ms`.

Rope detector constants: minimum valid peak time `5,000 ms`; minimum descending samples `3`; descending step `0.05 m`; rebound reset `0.15 m`; maximum descent stall `1,500 ms`. Preset-specific arm/drop/descent values are listed above.

Auto detector constants: history `12` samples; normal candidate/confirm gain `1.2/2.0 m`; normal minimum slope `0.12 m/s`; candidate window `8,000 ms`; baseline alpha `0.05`; minimum upward samples `3`; upward stall `1,500 ms`; cancellation drop `0.15 m`. Conservative and sensitive overrides are listed in the preset table.

The controller suppresses automatic evaluation while a menu is open. While resting, opening menus resets Auto history and altitude-filter EMA state and clears the displayed filtered sample; leaving the menu requires a fresh five-sample window. Completed attempts, mode changes, and sensitivity changes also clear the altitude snapshot/filter before detection continues, preventing stale EMA ascent from becoming a delayed Auto start. Pause/resume and inactive lifecycle clear volatile samples and trend continuity; if a climb is active, its domain start/peak are retained and detectors resume from that attempt. Manual controls remain usable if altitude is missing or automation fails.

## Development diagnostics

Diagnostics are development-only. Both `AppConstants.DEBUG_BUILD` and the persisted `debug` setting must be true; `DEBUG_BUILD` is false in production artifacts, so the setting alone cannot enable trace output or the diagnostics page. In an enabled development build, `System.println` emits one `TRACE` line per active-session tick with timestamp, mode, raw and filtered altitude, relative height, peak, drop, current HR, armed state, descending-step count, and Auto detector state. The trace is written before that tick's detector update, so detector counters/state show the state entering the current tick. After an Auto start is accepted, an event log records logical start and detected-at timestamps; after an attempt completes, another log records logical end and detected-at timestamps, height, and reason. These logs are not retained in an unbounded history.

The climbing view adds a third page in diagnostic builds. Use UP/DOWN to reach `DIAGNOSTICS`, which shows raw/filtered altitude, relative height, peak/drop, and the current detector state (including `NO ALTITUDE`, `UNARMED`, `DESCENDING`, or Auto's internal state). This page appears only while climbing. Production builds omit it. See the [hardware procedure](HARDWARE_TEST.md) for recording a trace during calibration.

## Validation and calibration

M3 Rope behavior and experimental M6 Auto integration passed their software gates and reviews. The current source passed 50 tests with zero failures/errors and zero compiler warnings; all five signed release builds and startup checks also passed. Synthetic and simulator results do not establish real-world thresholds. Record false starts, missed starts, false endings, and missed endings in [HARDWARE_TEST.md](HARDWARE_TEST.md) before tuning presets.
