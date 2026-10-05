# Climb — Garmin Connect IQ Watch App

## 0. Mission

Build a complete Garmin Connect IQ Watch App for climbing, initially targeting the user's Garmin fēnix 8.

The app replaces the default Garmin climbing interaction with a workflow inspired by Garmin Strength activities:

- `START/STOP` controls the overall climbing session.
- `BACK/LAP` starts and finishes an individual climb.
- Each climb behaves similarly to a "set".
- The user may switch between climbing modes during the same overall activity.
- Rope climbing supports automatic detection of the end of a climb by detecting descent.
- Boulder climbing uses explicit manual start/finish.
- Auto mode attempts to detect both climb start and climb finish automatically.
- Every climb is persisted as structured data and, where appropriate, represented as a FIT lap.
- The overall activity must remain a normal Garmin-recorded activity that can be saved and synced to Garmin Connect.

The implementation must be production-quality enough to sideload onto a real fēnix 8 and test during a climbing session.

Do not stop after scaffolding or prototyping. Implement the complete application described here.

---

# 1. Autonomous execution rules

Codex owns the complete implementation.

Do not ask the user implementation questions unless progress is technically impossible without information that cannot be discovered from the repository, installed Garmin SDK, local device definitions, or Garmin documentation.

When something is ambiguous:

1. choose the safest reasonable behavior;
2. document the decision in `docs/DECISIONS.md`;
3. continue implementation;
4. prefer configurable constants over hard-coded assumptions.

Never invent Garmin Connect IQ API names.

Before using an unfamiliar Garmin API:

1. inspect the installed Connect IQ SDK;
2. inspect official SDK samples if relevant;
3. verify the API signature against the installed SDK/docs;
4. only then implement it.

The installed SDK is the source of truth for compilation.

The app must compile after every integration milestone.

Do not leave TODOs for functionality required by this specification.

Experimental behavior is allowed only for Auto detection accuracy, not for the basic application lifecycle.

---

# 2. Agent strategy

Use multiple agents where parallelism is safe.

## Model assignment

### Sol

Use Sol for:

- architecture;
- state-machine design;
- climbing detection algorithms;
- FIT semantics;
- concurrency/lifecycle reasoning;
- difficult Garmin API integration issues;
- code review;
- debugging non-obvious bugs;
- final system validation.

Sol should not spend time on repetitive resource creation or mechanical refactoring unless needed to resolve a blocker.

### Terra

Use Terra for:

- production implementation;
- UI views;
- controllers;
- input handling;
- FIT recorder implementation;
- sensor-service implementation once architecture is specified;
- unit tests;
- integration tests;
- refactoring;
- build fixes.

Terra is the default implementation agent.

### Luna

Use Luna for:

- repository inventory;
- generating resources and strings;
- documentation;
- constants;
- simple model classes;
- repetitive test fixtures;
- scripts;
- formatting;
- checking manifests;
- simple compilation-fix loops.

Luna must not independently redesign architecture or detection algorithms.

---

# 3. Recommended agent roles

Create these logical roles.

## Agent A — Orchestrator

**Model:** Sol

Responsibilities:

- inspect repository;
- inspect installed Garmin SDK;
- determine exact target product identifiers;
- maintain task graph;
- enforce file ownership;
- integrate work;
- run build/test gates;
- resolve conflicts;
- perform final review.

This agent owns final architectural decisions.

---

## Agent B — State Machine + Detection

**Model:** Sol

Own:

- `ClimbStateMachine`
- `AltitudeFilter`
- `RopeEndDetector`
- `AutoClimbDetector`
- synthetic altitude trace test cases

Do not touch UI files unless required for interface definitions.

---

## Agent C — Recording + Domain

**Model:** Terra

Own:

- `SessionController`
- `FitRecorder`
- climb/session domain models
- session statistics
- persistence integration

---

## Agent D — UI + Input

**Model:** Terra

Own:

- views;
- delegates;
- menus;
- screen navigation;
- button behavior;
- display formatting.

---

## Agent E — Tests + Validation

**Model:** Terra

Own:

- Run No Evil unit tests;
- synthetic sensor traces;
- state-transition tests;
- recording lifecycle tests;
- regression tests;
- simulator validation checklist.

Agent E should review behavior but not rewrite production architecture without Orchestrator approval.

---

## Agent F — Build + Resources + Docs

**Model:** Luna

Own:

- manifest;
- strings/resources;
- settings resources;
- README;
- hardware testing instructions;
- developer documentation;
- build helper scripts where useful.

---

# 4. Parallel execution plan

Use worktrees or isolated branches if supported.

Otherwise enforce strict file ownership.

## Wave 0 — inspection

Run in parallel:

### Luna
Inventory:

- repository contents;
- installed tools;
- Connect IQ SDK version;
- current project structure;
- existing tests;
- existing manifest;
- available fēnix 8 product definitions.

### Sol
Verify:

- Garmin API compatibility;
- minimum suitable Connect IQ API level;
- Watch App capabilities;
- required permissions;
- FIT field strategy.

Merge findings into:

```text
docs/ENVIRONMENT.md
docs/DECISIONS.md
```

No feature implementation starts until this inspection is complete.

---

## Wave 1 — foundation

Parallel:

### Terra / Domain
Implement domain models and session statistics.

### Terra / UI
Implement initial views and navigation shell.

### Luna
Implement resources, strings, manifest adjustments and settings skeleton.

### Sol
Implement state-machine interfaces and detection interfaces.

Integration gate:

```text
BUILD MUST PASS
UNIT TEST DISCOVERY MUST PASS
APP MUST LAUNCH IN SIMULATOR
```

---

## Wave 2 — core session implementation

Parallel:

### Terra
ActivityRecording/FIT session lifecycle.

### Terra
Input controller.

### Sol
Manual climbing state machine.

### Terra
UI binding against state machine.

Integration gate:

```text
Start session
Start climb
Finish climb
Start another climb
Pause session
Resume session
Save session
Discard session
```

must work in simulator.

---

## Wave 3 — climbing modes

Parallel:

### Terra
Boulder mode.

### Sol
Rope auto-end detector.

### Terra
Mode-selection UI.

### Test agent
Synthetic altitude traces.

Integration gate:

```text
ROPE manual start + auto/manual finish
BOULDER manual start + manual finish
mode switching between climbs
```

must pass.

---

## Wave 4 — Auto mode

### Sol
Design and implement detector.

### Terra
Integrate detector.

### Test agent
Run synthetic scenarios and edge cases.

Auto mode remains marked `Experimental` in UI if necessary, but must be functional.

---

## Wave 5 — FIT + summary + polish

Parallel:

### Terra
FIT developer fields.

### Terra
summary screen.

### Luna
documentation and sideload instructions.

### Test agent
full regression.

Then Sol performs final code review.

---

# 5. Technology constraints

Use:

```text
Garmin Connect IQ
Monkey C
Watch App
Toybox.ActivityRecording
Toybox.FitContributor
Toybox.Sensor
Toybox.Timer
Toybox.WatchUi
Toybox.Test
```

Target the user's fēnix 8.

Do not hardcode an assumed fēnix 8 product identifier. Discover the exact IDs from the installed Garmin SDK.

If supporting all fēnix 8 variants requires no meaningful complexity, support them all.

The minimum Connect IQ API version should be selected after inspecting all APIs used. Prefer the lowest version that supports the required functionality, but compatibility with fēnix 8 matters more than unnecessary legacy-device support.

The Garmin APIs currently expose:

```text
Activity.SPORT_ROCK_CLIMBING
Activity.SUB_SPORT_INDOOR_CLIMBING
Activity.SUB_SPORT_BOULDERING
```

For mixed-mode sessions, record the overall activity as:

```text
SPORT_ROCK_CLIMBING
SUB_SPORT_GENERIC
```

because individual climbs within one session may have different modes.

Do not change the FIT activity's overall sport every time the user switches modes.

---

# 6. Required permissions

At minimum verify and configure the permissions required for:

```text
Fit
Sensor
```

Add additional permissions only if actually required by the implementation.

Do not request Positioning merely to obtain altitude unless testing proves it necessary.

Prefer `Sensor.getInfo().altitude` for the core relative-altitude algorithm.

All nullable sensor values must be handled safely.

No sensor reading may be assumed to exist.

---

# 7. Product terminology

Use these terms consistently.

## Session

The complete climbing workout.

Example:

```text
18:10 → 20:03
```

## Climb

One individual ascent/attempt.

Equivalent conceptually to a Strength "set".

## Rest

Time between the end of one climb and start of the next climb.

## Mode

Mode assigned to one climb.

Supported values:

```text
ROPE
BOULDER
AUTO
```

## End reason

Possible values:

```text
MANUAL
AUTO_DESCENT
AUTO_FULL
SESSION_STOP
CANCELLED
```

---

# 8. Primary state machine

Implement the application using an explicit state machine.

Do not encode state implicitly in UI classes.

Required states:

```text
PRE_START
RESTING
CLIMBING
CLIMB_SUMMARY
PAUSED
SESSION_SUMMARY
END_MENU
```

Optional internal Auto detection substates may be separate.

Legal transitions:

```text
PRE_START
    START
        -> RESTING

RESTING
    BACK/LAP
        -> CLIMBING

    MENU -> mode/settings menu

    START/STOP
        -> PAUSED

CLIMBING
    BACK/LAP
        -> CLIMB_SUMMARY

    AUTO END EVENT
        -> CLIMB_SUMMARY

    START/STOP
        -> confirmation
        -> terminate climb with SESSION_STOP
        -> PAUSED

CLIMB_SUMMARY
    timeout
        -> RESTING

    BACK/LAP
        -> RESTING immediately

PAUSED
    START/STOP
        -> RESTING

    Save
        -> SESSION_SUMMARY

    Discard
        -> terminate app cleanly

SESSION_SUMMARY
    close
        -> exit app
```

Invalid transitions must be ignored safely.

State transitions must be unit-tested.

---

# 9. Input behavior

Use device-independent behavior APIs wherever possible.

## START/STOP / Select

Mapped conceptually to `onSelect()` where appropriate.

### PRE_START

Starts overall activity.

### RESTING

Opens session pause/end control.

### CLIMBING

Must not silently stop the whole session.

Show confirmation:

```text
Pause session?

Current climb
will be ended.

Confirm
Cancel
```

If confirmed:

```text
finish current climb
endReason = SESSION_STOP
pause recording
```

### PAUSED

Resume session.

---

## BACK/LAP

Mapped to Back behavior.

### RESTING

Start a new climb.

### CLIMBING

Finish current climb manually.

### CLIMB_SUMMARY

Dismiss summary immediately.

### Menu screens

Behave as normal navigation Back.

---

## UP/DOWN

Use previous/next page behavior.

While climbing:

```text
Page 1 -> primary climb metrics
Page 2 -> secondary metrics
```

While resting:

optional second session-statistics page.

---

## MENU

Only available when not actively climbing.

During RESTING:

```text
Mode
Settings
About/debug if debug build
```

Do not allow changing climb mode during an active climb.

---

# 10. Modes

Mode belongs to the **next climb**, not the overall session.

The active mode must be visible on the REST screen.

Changing mode affects only future climbs.

Existing climb records never change.

---

# 11. ROPE mode

ROPE behavior:

```text
BACK/LAP
    -> manually start climb

while climbing:
    monitor altitude

if reliable descent detected:
    -> automatic climb finish

BACK/LAP:
    -> manual fallback finish
```

Automatic finish is only armed after sufficient upward movement.

The app must not auto-finish a climb due to normal small vertical fluctuations.

---

# 12. BOULDER mode

Initial production behavior:

```text
BACK/LAP -> start
BACK/LAP -> finish
```

No automatic finish.

Still record:

```text
duration
relative altitude gain
peak altitude gain
heart-rate statistics
rest before climb
```

Altitude is informational only.

---

# 13. AUTO mode

AUTO attempts to detect:

```text
climb start
climb end
```

BACK/LAP remains available as manual override.

AUTO must expose sufficient debug information in development builds to tune it.

Do not depend on accelerometer data for correctness.

Accelerometer data may be used as a corroborating signal if supported and reliable.

The altitude signal remains the primary detector in v1.

---

# 14. Data model

Create a `ClimbAttempt` model approximately equivalent to:

```text
id
mode
startTimestamp
endTimestamp
detectionStartTimestamp
durationMs

startAltitude
peakAltitude
endAltitude
heightGain

restBeforeMs

avgHeartRate
maxHeartRate
heartRateSamples

endReason

wasAutoStarted
wasAutoEnded
valid
```

Do not persist a large per-second sensor history inside every `ClimbAttempt`.

Sensor traces used for debugging should use a separate bounded buffer or debug logger.

---

# 15. Session model

Maintain:

```text
sessionStartTimestamp
sessionEndTimestamp
sessionPausedDuration

currentMode

climbs[]

totalClimbs
ropeClimbs
boulderClimbs
autoClimbs

totalClimbingTime
totalRestTime
totalVerticalGain

maxClimbHeight

averageHeartRate
maxHeartRate
```

Statistics must be derived deterministically from climb/session data where possible.

Avoid duplicated mutable counters if they can become inconsistent.

---

# 16. Sensor service

Create a dedicated abstraction.

Example conceptual interface:

```text
SensorService
    start()
    stop()
    getLatestSnapshot()
    subscribe(callback)
```

A snapshot should expose:

```text
timestamp
altitude?
heartRate?
acceleration?
pressure?
```

Use nullable values.

Primary sensor tick:

```text
1000 ms
```

Use `Sensor.getInfo()` for standard altitude and HR sampling.

Do not use high-frequency accelerometer sampling by default.

If Auto mode uses accelerometer:

- activate it only while needed;
- disable it when leaving Auto;
- aggregate high-frequency data immediately into a small movement score;
- do not retain huge arrays.

Battery use matters.

---

# 17. Altitude representation

Never use absolute altitude directly for climb height.

At climb start:

```text
relativeAltitude = filteredAltitude - climbBaseline
```

Maintain:

```text
baselineAltitude
filteredAltitude
relativeAltitude
peakRelativeAltitude
```

All user-facing climb height values are relative to the climb baseline.

---

# 18. Altitude filtering

Raw barometric altitude is noisy.

Implement a small filtering pipeline.

Recommended starting implementation:

```text
raw sample
    ↓
5-sample rolling median
    ↓
EMA
    ↓
filtered altitude
```

Suggested initial EMA:

```text
alpha = 0.35
```

Make parameters constants/settings rather than scattering magic numbers.

The detector must be independently unit-testable without Garmin Sensor APIs.

Input:

```text
(timestamp, altitude)
```

Output:

```text
filtered altitude
```

---

# 19. Rope auto-end algorithm

This is safety-critical from a UX perspective: false endings are much worse than failing to auto-end.

Use conservative detection.

Initial configurable defaults:

```text
ROPE_ARM_GAIN_M = 3.0
ROPE_END_DROP_FROM_PEAK_M = 2.5
ROPE_END_MIN_DESCENT_SECONDS = 3
ROPE_END_MIN_VALID_CLIMB_SECONDS = 5
```

Exact values may be adjusted based on synthetic tests.

Algorithm:

```text
start climb manually

baseline = current filtered altitude
peak = 0

for each altitude sample:
    relative = filtered - baseline

    if relative > peak:
        peak = relative
        peakTimestamp = timestamp

    if peak >= ROPE_ARM_GAIN_M:
        detector becomes ARMED

    if ARMED:
        drop = peak - relative

        if drop >= ROPE_END_DROP_FROM_PEAK_M
           and descending trend has persisted long enough:
               emit AUTO_END
```

A single low sample must never end the climb.

Require a consistent negative trend.

When automatic ending is triggered, the logical climb end time should be the recorded `peakTimestamp`, not the later detection timestamp.

Therefore:

```text
detectedAt = 18:42:35
peakAt     = 18:42:31

climb.endTimestamp = 18:42:31
```

However, FIT `addLap()` may physically happen at detection time.

Our custom climb duration must use the logical timestamp.

---

# 20. Auto-start algorithm

AUTO mode requires a separate state machine:

```text
WATCHING
POSSIBLE_START
CLIMBING
POSSIBLE_END
```

Maintain a slowly moving resting baseline while `WATCHING`.

Suggested starting thresholds:

```text
AUTO_CANDIDATE_GAIN_M = 1.2
AUTO_CONFIRM_GAIN_M = 2.0
AUTO_START_WINDOW_SECONDS = 8
AUTO_MIN_UPWARD_SLOPE_MPS = 0.12
```

Conceptual logic:

```text
WATCHING

filtered altitude begins consistently increasing
    ↓

gain from resting baseline >= candidate threshold
    ↓

POSSIBLE_START
record candidateStartTimestamp
record candidateStartAltitude

if continued upward trend and confirmation threshold reached
    ↓

CLIMBING

logical start = candidateStartTimestamp
baseline = candidateStartAltitude
```

If confirmation fails:

```text
POSSIBLE_START -> WATCHING
```

Once Auto enters CLIMBING, use the same conservative descent detector as ROPE.

`endReason = AUTO_FULL`.

BACK/LAP:

- while WATCHING: manually start climb;
- while CLIMBING: manually finish climb.

If a climb was manually started while mode is AUTO:

```text
wasAutoStarted = false
```

Auto finish may still occur.

---

# 21. Optional movement score

Implement only if straightforward on target hardware.

Accelerometer may provide corroboration:

```text
movementScore
```

Possible calculation:

```text
magnitude = sqrt(x² + y² + z²)
dynamic = abs(magnitude - 1g)
aggregate RMS / mean over short window
```

Do not make start/end detection depend solely on this value.

The app must work when accelerometer information is unavailable.

---

# 22. False-start handling

If a climb is manually started and manually finished almost immediately, do not create junk records.

Suggested defaults:

```text
MIN_MANUAL_CLIMB_DURATION_SECONDS = 3
MIN_MANUAL_CLIMB_HEIGHT_M = 0.5
```

If both duration and height are below threshold:

```text
mark as cancelled
do not add to climb totals
do not create normal completed climb lap
show "Climb cancelled"
```

Be conservative: a legitimate low-height boulder attempt should not accidentally be deleted merely because altitude data is noisy.

Duration should therefore be the primary false-start criterion.

---

# 23. Heart-rate metrics

During each active climb:

```text
collect valid HR samples
sum
count
max
```

At climb end:

```text
avgHeartRate = sum / count
maxHeartRate = max
```

Do not retain every HR sample after metrics are calculated unless needed for debug.

If no heart-rate sample exists:

```text
avgHeartRate = null
maxHeartRate = null
```

UI must display `--`.

---

# 24. Overall FIT activity

Use Garmin ActivityRecording.

Create one recording session for the whole workout.

Conceptually:

```text
ActivityRecording.createSession({
    name: "Climb",
    sport: SPORT_ROCK_CLIMBING,
    subSport: SUB_SPORT_GENERIC
})
```

Start recording when overall session starts.

Do not create a new FIT activity for every climb.

---

# 25. FIT laps

One valid completed climb should map to one lap where practical.

At valid climb completion:

```text
populate lap developer fields
session.addLap()
```

Validate actual generated FIT behavior in simulator/device output.

If Garmin FIT semantics require field values to be set in a specific order relative to `addLap()`, follow the SDK behavior and add a test/validation step.

Never assume ordering without checking generated FIT output.

---

# 26. FIT developer fields

Use compact numeric fields.

Avoid unnecessary strings.

Suggested per-lap fields:

```text
climb_number
climb_mode
climb_height
climb_duration
rest_before
end_reason
```

Possible encoding:

```text
climb_mode
1 = ROPE
2 = BOULDER
3 = AUTO

end_reason
1 = MANUAL
2 = AUTO_DESCENT
3 = AUTO_FULL
4 = SESSION_STOP
```

Suggested types:

```text
climb_number    UINT16
climb_mode      UINT8
climb_height    FLOAT
climb_duration  UINT32
rest_before     UINT32
end_reason      UINT8
```

Use units:

```text
m
s
```

Also add session-level developer fields if useful:

```text
total_climbs
rope_climbs
boulder_climbs
auto_climbs
total_vertical
```

Stay well below FIT developer-field size limits.

---

# 27. FIT field IDs

Define every field ID once in a central constants file.

Example:

```text
FIELD_CLIMB_NUMBER = 0
FIELD_CLIMB_MODE = 1
FIELD_CLIMB_HEIGHT = 2
FIELD_CLIMB_DURATION = 3
FIELD_REST_BEFORE = 4
FIELD_END_REASON = 5
...
```

Never duplicate IDs.

Create tests/assertions for uniqueness if practical.

---

# 28. Session lifecycle

Create explicit lifecycle functions:

```text
createSession()
startSession()
pauseSession()
resumeSession()
saveSession()
discardSession()
```

Guarantees:

- only one ActivityRecording Session reference;
- save/discard releases references;
- timers stop before final save/discard;
- sensors are disabled/unsubscribed cleanly;
- app cannot create a second active FIT recording accidentally.

Handle failed Garmin API calls gracefully.

---

# 29. App lifecycle

Implement Garmin lifecycle methods correctly.

On activation:

```text
restore active app state where appropriate
restart UI refresh
re-enable required sensors
```

On inactive/background transitions:

```text
do not corrupt session state
respect Garmin sensor restrictions
```

Do not assume timers/sensors behave normally while inactive.

No climb may be silently fabricated because the app temporarily became inactive.

---

# 30. Persistence

Persist only useful settings/state.

Use app properties for:

```text
last selected climbing mode
algorithm threshold settings if user-configurable
debug settings
```

Do not attempt to persist an active ActivityRecording session across a full app/device failure unless Garmin officially supports the required semantics.

Keep recovery logic simple and safe.

---

# 31. Screens

## Screen A — PRE_START

Display:

```text
CLIMB

Mode
ROPE

0 climbs

START
Start Session
```

Menu allows mode selection/settings.

Remember previous mode.

---

# 32. Screen B — RESTING

Primary display:

```text
ROPE          REST

      04:12

Climbs           7
Vertical       93 m

Last
14.8 m        1:34

BACK/LAP
START CLIMB
```

Requirements:

- mode clearly visible;
- rest timer visually dominant;
- previous climb summary visible;
- total climbs;
- total vertical.

If no previous climb exists:

```text
Last -- 
```

---

# 33. RESTING secondary page

Display:

```text
SESSION

Elapsed       1:03:12
Climbing        18:42
Rest            44:30

Rope                5
Boulder             2
Auto                0

HR                 128
```

Use Up/Down to switch.

---

# 34. Screen C — CLIMBING primary

```text
ROPE       CLIMB #8

       01:03

      ↑ 12.4 m

HR            157

BACK/LAP
FINISH
```

Requirements:

- time is largest value;
- climb height second-largest;
- current mode and climb number;
- HR;
- obvious manual-finish hint.

For Auto mode:

```text
AUTO
```

must be highly visible.

---

# 35. CLIMBING secondary

```text
CLIMB #8

Peak         12.7 m
Current      12.4 m

HR              157
Max HR          163

Rest before    4:12
```

During descent:

```text
Current
```

may drop while Peak remains stable.

---

# 36. Screen D — CLIMB SUMMARY

Show for approximately 4 seconds.

Example:

```text
CLIMB #8

     1:34
    ↑14.8 m

Max HR 163

AUTO END
```

Possible footer:

```text
MANUAL
AUTO END
AUTO
SESSION END
```

BACK/LAP dismisses immediately.

At timeout:

```text
-> RESTING
```

---

# 37. Screen E — MODE selection

Accessible only from RESTING/PRE_START.

```text
NEXT CLIMB

> ROPE
  BOULDER
  AUTO
```

AUTO should display:

```text
AUTO (Experimental)
```

until real-world testing proves it sufficiently reliable.

Selecting a mode updates `currentMode`.

Do not start a climb from the menu automatically.

---

# 38. Screen F — PAUSE / END

On session START/STOP:

```text
SESSION PAUSED

Resume
Save
Discard
```

Default highlighted action:

```text
Resume
```

Discard must require confirmation.

Save should not require unnecessary confirmation.

---

# 39. Screen G — SESSION SUMMARY

Display:

```text
SUMMARY

Time          2:14:03
Climbs             18

Rope               10
Boulder             6
Auto                2

Climbing         27:42
Rest           1:46:21

Vertical          184m
Max climb        21.3m

Avg HR             128
Max HR             174
```

Then exit cleanly.

---

# 40. UI requirements

Target round fēnix 8 display first.

Use Garmin system fonts unless there is a strong reason otherwise.

Requirements:

- readable at arm's length;
- high contrast;
- avoid tiny text;
- avoid decorative UI;
- prioritize timer/height;
- respect round-screen clipping;
- no unnecessary animations.

Support touch only as a bonus.

Physical buttons are primary.

---

# 41. Haptics / alerts

If available without complexity:

On manual/automatic climb start:

```text
short confirmation vibration
```

On automatic climb end:

```text
distinct confirmation vibration
```

Do not use excessive vibration.

This is optional if API/device complexity creates risk.

---

# 42. Settings

Initial settings should remain small.

Expose:

```text
Auto End Sensitivity
    Conservative
    Normal
    Sensitive

Auto Start Sensitivity
    Conservative
    Normal
    Sensitive

Summary Duration
    2 / 4 / 6 sec
```

Map sensitivity presets to internal thresholds.

Do not initially expose ten individual tuning parameters to normal users.

In debug builds, raw numeric thresholds may be exposed.

---

# 43. Architecture

Prefer separation like:

```text
source/
    ClimbApp.mc
    ClimbView.mc
    ClimbDelegate.mc

    AppController.mc
    ClimbStateMachine.mc
    SessionController.mc

    ClimbAttempt.mc
    SessionStats.mc
    AppEnums.mc
    AppConstants.mc

    SensorService.mc
    AltitudeFilter.mc
    RopeEndDetector.mc
    AutoClimbDetector.mc

    FitRecorder.mc

    UiFormatter.mc
    SettingsManager.mc
```

Exact filenames may change if Monkey C/project conventions make another structure cleaner.

Keep these conceptual boundaries.

---

# 44. Dependency direction

Preferred:

```text
UI
 ↓
AppController
 ↓
StateMachine
 ↓
Domain
```

Services:

```text
SensorService
FitRecorder
SettingsManager
```

must be injected or referenced through clear interfaces.

Detection algorithms must not depend on UI.

UI must not contain climbing detection logic.

FIT recorder must not decide state transitions.

---

# 45. Controller responsibilities

`AppController` coordinates:

```text
input
state machine
sensors
recording
UI refresh
```

It should be the integration point rather than making `ClimbView` a god object.

---

# 46. State machine responsibilities

`ClimbStateMachine` owns:

```text
current state
legal transitions
current climb lifecycle
mode locking during climb
summary transition
pause semantics
```

It should emit events/effects rather than directly drawing views.

---

# 47. Sensor service responsibilities

`SensorService` owns:

```text
sensor enablement
sampling
null handling
sample timestamps
optional acceleration aggregation
```

It should not decide whether a climb ended.

---

# 48. Detector responsibilities

`RopeEndDetector` receives only normalized data.

Example:

```text
update(timestamp, relativeAltitude)
```

It emits:

```text
NONE
ARMED
AUTO_END
```

`AutoClimbDetector` similarly receives sensor data and produces domain events.

This makes both detectors testable with synthetic traces.

---

# 49. Timer strategy

Avoid many independent timers.

Prefer:

```text
one 1-second application tick
```

for:

```text
UI timer values
sensor polling
detector updates
rest timer
summary timeout
```

Use additional timer(s) only when technically necessary.

Garmin devices have limits on simultaneous timers.

---

# 50. Time calculations

Do not increment counters every second as the source of truth.

Store timestamps.

Calculate:

```text
duration = now - startTimestamp
```

This avoids timer drift and missed timer callbacks.

Use the periodic tick only to refresh displays.

---

# 51. Simulation-friendly architecture

All algorithms should work without a physical watch.

Provide synthetic traces such as:

```text
flat
steady ascent
ascent + short dip + ascent
ascent + real descent
noisy plateau
boulder-height ascent
barometer drift
```

The test system should be able to feed these directly into detectors.

---

# 52. Required Rope detector tests

At minimum:

```text
steady 20m ascent
    -> no auto end

20m ascent + 0.5m dip
    -> no auto end

20m ascent + 1.5m dip
    -> no auto end

20m ascent + 3m sustained descent
    -> auto end

2m ascent + 4m descent
    -> no auto end because detector never armed

10m ascent + noisy ±0.5m plateau
    -> no auto end

10m ascent + brief 3m spike down then recovery
    -> must reject if descent persistence requirement not met
```

---

# 53. Required Auto detector tests

At minimum:

```text
flat noise
    -> WATCHING

slow pressure drift
    -> WATCHING

short +1m movement
    -> no climb

steady +3m movement
    -> auto start

auto-started climb + real descent
    -> auto end

candidate ascent followed by return to baseline
    -> cancel candidate

manual override while watching
    -> start climb manually

manual finish during auto climb
    -> finish normally
```

---

# 54. State-machine tests

Cover every legal transition and important illegal transition.

Examples:

```text
PRE_START + BACK -> no climb

PRE_START + START -> RESTING

RESTING + BACK -> CLIMBING

CLIMBING + BACK -> CLIMB_SUMMARY

CLIMB_SUMMARY timeout -> RESTING

RESTING mode change -> success

CLIMBING mode change -> rejected

CLIMBING + session pause confirmation -> PAUSED

PAUSED + resume -> RESTING
```

---

# 55. Session statistic tests

Verify:

```text
rest before first climb
multiple rests
mixed modes
cancelled attempts
auto-ended climbs
session-stop climb
total vertical
max height
HR average
missing HR values
```

---

# 56. FIT validation

Do not consider FIT support complete merely because code compiles.

Generate a sample recorded activity.

Validate:

```text
activity saves
activity is SPORT_ROCK_CLIMBING
laps exist
developer fields exist
developer-field values correspond to climbs
session summary fields exist where expected
file is readable by Garmin tooling
```

Use Garmin Monkey Graph/FIT tooling where available.

Document exact validation procedure.

---

# 57. Simulator acceptance flow

Automate as much as practical, otherwise document a repeatable manual simulator script.

Scenario:

```text
Launch app

Mode = ROPE

START
BACK
simulate climb
BACK

switch mode -> BOULDER
BACK
BACK

switch mode -> AUTO
simulate auto trace

Pause
Resume

Save
```

Expected:

```text
3 valid climbs
correct modes
correct statistics
no crashes
FIT saved
```

---

# 58. Device build acceptance

Produce a side-loadable `.prg`.

The project must support:

```text
Monkey C: Build for Device
```

for the target fēnix 8.

The generated artifact must be suitable for copying to:

```text
GARMIN/APPS
```

Do not require Connect IQ Store publication.

---

# 59. Hardware validation plan

Codex cannot physically climb with the watch, but it must prepare the app for this test.

Create:

```text
docs/HARDWARE_TEST.md
```

Test sequence:

```text
1. Sideload app.
2. Start session.
3. Run Boulder manual start/end.
4. Confirm buttons.
5. Confirm HR.
6. Confirm relative altitude.
7. Run Rope manual start.
8. Ascend.
9. Descend.
10. Check automatic finish.
11. Repeat multiple times.
12. Test false descent.
13. Mix Rope/Boulder.
14. Save.
15. Sync to Garmin Connect.
16. Inspect laps/custom metrics.
```

Include a section for recording observed detector failures.

---

# 60. Debug mode

Create compile-time or development-only diagnostics.

Useful values:

```text
rawAltitude
filteredAltitude
relativeAltitude
peakAltitude
dropFromPeak
detectorState
autoStartState
movementScore
```

Do not clutter production UI.

Debug logging should make it possible to understand why a climb started or ended.

---

# 61. Detector trace logging

Provide an optional lightweight trace mechanism for real-world tuning.

Avoid storing unbounded history.

Recommended:

```text
bounded circular buffer
```

containing recent samples.

If exporting traces from Connect IQ is impractical, at minimum print useful data through development logs during simulator testing.

Do not block initial release on sophisticated telemetry.

---

# 62. Error handling

The app must not crash when:

```text
altitude is null
heart rate is null
sensor permission unavailable
sensor temporarily stops updating
FIT session cannot start
addLap fails
save fails
timer fires late
app is resumed after inactivity
```

Present a concise user error where needed.

Log detailed developer information.

---

# 63. Memory constraints

Garmin apps run under constrained memory.

Avoid:

```text
large sample histories
large object graphs
duplicated strings
high-frequency raw accelerometer storage
unbounded climb arrays
```

A normal workout containing at least 100 climbs must remain safe.

If climb-history size becomes relevant, store only compact completed-climb summaries.

---

# 64. Performance constraints

Normal operation should use approximately one main update per second.

UI drawing must not perform heavy calculations.

Filtering/detection should be O(1) per incoming sample, except tiny bounded rolling windows.

Do not sort large arrays on every tick.

A 5-sample median may use a small copy/sort because the input is bounded.

---

# 65. Battery constraints

Avoid GPS unless necessary.

Use barometer/sensor altitude from `Sensor.getInfo()`.

Avoid continuous high-frequency accelerometer when not needed.

Stop sensors/timers when the session finishes.

---

# 66. Recommended implementation milestones

## M0 — Environment

Deliver:

```text
project builds
target device configured
tests runnable
```

## M1 — Manual app

Deliver:

```text
start overall session
manual climb start
manual climb end
save/discard
basic UI
```

## M2 — Boulder

Deliver:

```text
manual boulder workflow
climb stats
rest timer
summary
```

## M3 — Rope

Deliver:

```text
altitude filtering
peak detection
auto end
manual fallback
```

## M4 — Mixed mode

Deliver:

```text
switch mode between climbs
mode persisted per climb
mode statistics
```

## M5 — FIT

Deliver:

```text
laps
developer fields
validated FIT
```

## M6 — Auto

Deliver:

```text
auto start
auto end
manual overrides
```

## M7 — Device-ready

Deliver:

```text
production UI
settings
docs
tests
side-load build
```

---

# 67. Build gates

At the end of every milestone:

```text
compile
run all unit tests
launch simulator
run milestone smoke test
```

If anything fails:

```text
fix before starting next milestone
```

Never accumulate known compilation failures.

---

# 68. Code-review gates

Sol must review after:

```text
M1
M3
M5
M6
M7
```

Review focus:

### M1
state architecture and lifecycle.

### M3
auto-end correctness and false-positive risk.

### M5
FIT semantics.

### M6
Auto detection.

### M7
overall maintainability, memory, battery and UX.

---

# 69. Reviewer rules

Reviewer must inspect actual code and tests.

Do not approve based only on implementer summary.

Reviewer may require rework if:

```text
business logic is in View
state is implicit
Garmin APIs were guessed
detectors cannot be unit-tested
sensor nulls are unsafe
FIT values are inconsistent
timers leak
state transitions are ambiguous
```

---

# 70. Acceptance criteria — functional

The implementation is complete only when all are true:

```text
[ ] App launches on fēnix 8 simulator.
[ ] App builds for physical fēnix 8.
[ ] START begins one overall FIT activity.
[ ] START/STOP controls overall session.
[ ] BACK/LAP starts individual climb.
[ ] BACK/LAP finishes individual climb.
[ ] Mode can change between climbs.
[ ] Mode cannot change during climb.
[ ] Boulder works fully manually.
[ ] Rope auto-end works on deterministic descent traces.
[ ] Rope manual fallback always works.
[ ] Auto mode detects valid synthetic climbs.
[ ] Auto mode rejects flat/noisy traces.
[ ] Rest timer works.
[ ] Climb summaries work.
[ ] Session summary works.
[ ] Heart rate gracefully handles missing data.
[ ] Altitude gracefully handles missing data.
[ ] Each valid climb produces expected FIT metadata/lap.
[ ] Save produces a valid activity.
[ ] Discard does not save an activity.
[ ] No timer/sensor leaks after exit.
[ ] Full test suite passes.
```

---

# 71. Acceptance criteria — UX

```text
[ ] Current mode visible before climb.
[ ] Climbing state obvious at a glance.
[ ] Rest state obvious at a glance.
[ ] Main timer readable.
[ ] Height readable.
[ ] User never needs touch screen for core workflow.
[ ] No accidental mode change while climbing.
[ ] Auto ending visibly confirms what happened.
[ ] Manual controls remain available when automation fails.
```

---

# 72. Acceptance criteria — architecture

```text
[ ] Explicit state machine.
[ ] Sensor logic separated from detector logic.
[ ] Detector logic separated from UI.
[ ] FIT logic separated from UI.
[ ] Detection thresholds centralized.
[ ] Domain models contain no Garmin rendering logic.
[ ] Core algorithms unit-tested with synthetic data.
```

---

# 73. Deliverables

Repository must contain:

```text
working source code
manifest.xml
resource files
settings
unit tests
README.md
docs/ARCHITECTURE.md
docs/DECISIONS.md
docs/DETECTION_ALGORITHM.md
docs/FIT_FIELDS.md
docs/HARDWARE_TEST.md
docs/SIDELOAD.md
```

Also produce:

```text
dist/<app-name>.prg
```

when local tooling permits device build.

Do not commit private Garmin developer keys.

---

# 74. README requirements

README should include:

```text
Purpose
Features
Supported modes
Controls
Architecture overview
SDK prerequisites
How to build
How to run simulator
How to run tests
How to build for device
How to sideload onto fēnix 8
Current Auto-mode limitations
```

---

# 75. Architecture documentation

`docs/ARCHITECTURE.md` must contain diagrams in Mermaid.

Include at least:

```text
state machine
component dependency graph
sensor -> detector -> state-machine flow
FIT recording flow
```

---

# 76. Detection documentation

`docs/DETECTION_ALGORITHM.md` must explain:

```text
raw altitude
filtering
relative baseline
peak detection
arming
descent detection
logical vs physical end timestamp
Auto candidate start
Auto confirmation
false-positive prevention
all tuning constants
```

This document should be sufficient to tune thresholds after real climbing tests.

---

# 77. Decisions log

Whenever Codex encounters an implementation choice not explicitly specified here, record:

```text
Date
Decision
Alternatives
Reason
Impact
```

in:

```text
docs/DECISIONS.md
```

Do not interrupt autonomous execution for minor decisions.

---

# 78. Suggested first implementation sequence

The Orchestrator should execute approximately:

```text
1. Inspect repository and SDK.
2. Create/update Watch App project.
3. Configure target fēnix 8 + permissions.
4. Implement domain enums/models.
5. Implement state machine.
6. Implement ActivityRecording lifecycle.
7. Implement one-second app tick.
8. Implement sensor abstraction.
9. Implement manual climb workflow.
10. Implement core UI.
11. Add tests.
12. Implement Boulder.
13. Implement altitude filter.
14. Implement Rope detector.
15. Implement Rope auto-end.
16. Implement mode switching.
17. Implement FIT fields/laps.
18. Validate FIT.
19. Implement Auto detector.
20. Add sensitivity presets.
21. Implement session summary.
22. Run regression suite.
23. Perform Sol architecture/reliability review.
24. Build .prg.
25. Produce hardware-test instructions.
```

---

# 79. Important non-goals for initial release

Do not add unless all required features are already complete:

```text
route names
route grades
wall database
cloud backend
mobile companion app
social features
leaderboards
online accounts
GPS route mapping
touch-first UX
training plans
```

Those can be future versions.

---

# 80. Future-ready extension points

Do not implement them now, but architecture should not prevent:

```text
grade
route name
attempt success/failure
fall marker
indoor/outdoor mode
route project history
automatic boulder detection
training metrics
climbing-specific recovery metrics
external phone companion
```

---

# 81. Final autonomous validation

Before declaring completion, the Orchestrator must independently verify:

```text
git diff
build output
all test results
simulator smoke test
manifest permissions
target products
FIT behavior
resource usage warnings
unhandled TODO/FIXME markers
dead debug code
documentation
```

Search repository for:

```text
TODO
FIXME
HACK
throw
NotImplemented
placeholder
```

Any occurrence associated with required functionality must be resolved.

---

# 82. Final report format

When finished, Codex should report:

```text
IMPLEMENTATION COMPLETE

Target:
- Garmin fēnix 8 ...

Implemented:
- Session recording
- Rope
- Boulder
- Auto
- FIT fields
- UI
- Tests
...

Tests:
- X passed
- 0 failed

Build:
- simulator: PASS
- device build: PASS

Artifact:
- path/to/app.prg

Hardware validation still required:
- real-world Rope threshold calibration
- real-world Auto threshold calibration

Important tuning constants:
- ...
```

Do not claim Rope/Auto physical accuracy until tested on the real watch.

Compilation and deterministic synthetic tests are sufficient for software completion; physical climbing validation is a separate calibration gate.

---

# 83. Definition of Done

The task is done when Codex has produced a complete, compiled, tested Garmin Connect IQ Watch App that can be sideloaded onto the target fēnix 8 and supports:

```text
one climbing session
multiple climbs
mixed Rope/Boulder/Auto modes
manual Back/Lap controls
Rope automatic descent detection
Auto start/end detection
relative altitude
heart rate
rest timing
climb summaries
session summary
FIT recording
FIT laps/custom fields
save/discard
settings
tests
documentation
device build
```

The only intentionally unresolved work after software completion may be tuning algorithm thresholds using real climbing data from the user's physical fēnix 8.