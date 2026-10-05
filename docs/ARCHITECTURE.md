# Architecture

This document describes the current implementation in `source/`. The host watch-app lifecycle enters through `ClimbApp`; `AppController` coordinates input, one-second sampling, sensors, detectors, domain transitions, FIT recording, persistence, and redraw. Detectors stay independent of WatchUi and return timestamped events. `ClimbStateMachine` and `SessionController` remain the authority for legal transitions and workout state.

## Session state machine

```mermaid
stateDiagram-v2
    [*] --> PRE_START
    PRE_START --> RESTING: START / native recording starts
    RESTING --> CLIMBING: BACK manual start
    RESTING --> CLIMBING: Auto start confirmed
    CLIMBING --> CLIMB_SUMMARY: BACK manual finish
    CLIMBING --> CLIMB_SUMMARY: Rope descent or Auto end confirmed
    CLIMBING --> END_MENU: START / request pause confirmation
    END_MENU --> CLIMBING: cancel / restore detector baseline and peak
    END_MENU --> PAUSED: confirm / finish climb and stop recording
    CLIMB_SUMMARY --> RESTING: timeout or BACK
    RESTING --> PAUSED: START / stop recording
    CLIMB_SUMMARY --> PAUSED: START / stop recording
    PAUSED --> RESTING: Resume / existing recording restarts
    PAUSED --> SESSION_SUMMARY: Save / native recording saves
    PAUSED --> [*]: confirmed Discard / native recording discarded
    SESSION_SUMMARY --> [*]: close
```

The displayed mode is the mode for the next climb; the active climb's mode is fixed at start. Auto detector sub-states (`WATCHING`, `POSSIBLE_START`, `CLIMBING`, `POSSIBLE_END`) are internal to `AutoClimbDetector`, not additional session states. Pause confirmation does not end a climb until accepted. A failed recorder operation must not be presented as a successful state transition.

## Component dependencies

```mermaid
flowchart TD
    Lifecycle[ClimbApp lifecycle] --> Controller[AppController]
    Button[ClimbDelegate input] --> Controller
    Controller --> State[ClimbStateMachine]
    State --> Domain[SessionController / ClimbAttempt]
    Controller --> Sensor[SensorService]
    Controller --> Filter[AltitudeFilter]
    Controller --> Rope[RopeEndDetector]
    Controller --> Auto[AutoClimbDetector]
    Controller --> Recorder[FitRecorder]
    Controller --> Store[SessionStore]
    Controller --> Settings[SettingsManager]
    Controller --> Stats[SessionStats]
    View[ClimbView and menus] --> Controller
    View --> Formatter[UiFormatter]
```

`ClimbView` and menus render controller/domain values and send user actions through the delegate. They do not detect climbs or own a recording session. `FitRecorder` serializes the session and developer fields but does not decide state transitions. `SensorService` gathers nullable sensor readings but does not classify movement. Pure detector classes consume timestamped filtered altitude and do not depend on UI APIs. `SessionStore` persists compact local history separately from the native FIT activity.

## Sensor, detector, and state flow

```mermaid
flowchart LR
    Tick[One-second AppController tick] --> Sensors[SensorService.sample]
    Sensors --> Raw[Timestamped raw altitude / nullable HR]
    Raw --> Filter[5-sample median then EMA]
    Filter --> Snapshot[Filtered altitude / null]
    Snapshot --> SessionSample[SessionController.sample]
    Snapshot --> Rope[RopeEndDetector for active Rope climb]
    Snapshot --> Auto[AutoClimbDetector in Auto mode]
    Rope --> Event[Peak endAt plus confirmation detectedAt]
    Auto --> Event
    Event --> Controller[AppController validates current mode and state]
    Controller --> Machine[ClimbStateMachine transition]
    Machine --> Domain[ClimbAttempt and session stats]
    Domain --> Recorder[FitRecorder lap / summary]
    Controller --> View[Refresh view]
```

Altitude remains unavailable until the filter has five consecutive valid readings after startup, null input, reset, or a gap over 2.5 seconds. Null is never treated as zero. Rope detection runs only during an active Rope climb. Auto watches only while its mode is selected and the session is resting or climbing. Menus suspend automatic evaluation. An accepted Auto start replays only retained HR samples at or after its logical candidate start into the new climb; session HR has already counted those samples, so replay does not change session aggregates.

## FIT recording flow

```mermaid
sequenceDiagram
    participant UI as User / Delegate
    participant C as AppController
    participant M as ClimbStateMachine + Domain
    participant F as FitRecorder
    participant G as ActivityRecording.Session
    UI->>C: START session
    C->>F: create or reuse / create fields / start
    F->>G: rock_climbing, generic sub-sport
    G-->>F: start result
    F-->>C: outcome
    C->>M: commit PRE_START to RESTING on success
    UI->>C: manual or confirmed automatic climb event
    C->>M: begin / finish with logical and detection timestamps
    M-->>C: completed ClimbAttempt
    C->>F: queue/publish climb metadata
    F->>G: setData then addLap
    G-->>F: lap result
    UI->>C: pause / resume
    C->>F: stop / restart existing session
    UI->>C: save while paused
    C->>F: publish summary / flush pending laps / save
    F->>G: stop if recording / save
    G-->>F: result
    F-->>C: release session only on success
```

The native lap boundary occurs when Garmin accepts `addLap`; the custom fields carry logical climb duration and can preserve peak-time semantics when automatic confirmation is later. The saved mixed-mode simulator fixture has been decoded: three climb laps, a final cleared implicit/rest lap, 22 registered developer fields, and a matching session summary. See [FIT_FIELDS.md](FIT_FIELDS.md). Failed pending laps remain queued for retry on resume and prevent save until flushed; recorder/session errors are shown through the controller.

## Lifecycle and storage

The controller runs one one-second timer while active. It stops timer and sensor work on inactivity, clears volatile readings and filter state, and resumes from fresh samples. If a climb is active, its domain and detector peak/baseline are preserved while trend continuity is broken. Inactive lifecycle cleanup does not call sensor APIs. App shutdown attempts to close or save a live recording and retains a failure message in logs if closure fails.

Properties hold small settings. Completed climb history is bounded to 256 attempts and stored in pages, with failed pages retained in a bounded in-memory retry queue. Native FIT is the shareable activity record; local history storage is independent. No persisted session is used to resurrect a native `ActivityRecording.Session` after process death.

## Validation evidence

Milestone status and latest counts are maintained in [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md). FIT schema and decoded artifact are documented in [FIT_FIELDS.md](FIT_FIELDS.md). Software-level simulator evidence does not replace physical-device sideload, Garmin Connect presentation review, or real-climbing threshold calibration.
