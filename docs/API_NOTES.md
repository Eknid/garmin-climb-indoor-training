# Verified Garmin APIs

Inspected SDK 9.2.0 (`2026-06-09-92a1605b2`) at `/private/tmp/garmin-sdk`, including `doc/Toybox`, `samples/RecordSample`, `samples/Sensor`, `samples/MoxyField`, and `bin/monkeydo`. Installed docs are the compilation reference.

## Recording

`ActivityRecording.createSession(options) as Session` accepts `:name`, `:sport`, and `:subSport`. Name is required; Garmin suggests at most 15 characters. Only one unclosed session exists: creating another returns the existing session. `Session.start()`, `stop()`, `save()`, `discard()`, `addLap()`, and `isRecording()` all return Boolean and date from API 1.0.0. Check return values before advancing application state. Save/discard close the session; clear application references only after successful closure. The official RecordSample stops before saving and saves during `onStop` cleanup. Resume uses the existing session's `start`, never `createSession`.

Use `Activity.SPORT_ROCK_CLIMBING` (31, API 3.2.0) and `Activity.SUB_SPORT_GENERIC` (0, API 3.2.0) for mixed sessions. `SUB_SPORT_INDOOR_CLIMBING` (68) and `SUB_SPORT_BOULDERING` (69) date from 4.1.6, but are not needed for the generic mixed session. These constants exist in the installed SDK. Deprecated constants under ActivityRecording should be avoided. Recording requires manifest permission `Fit`.

[Recording API](https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording.html), [Session API](https://developer.garmin.com/connect-iq/api-docs/Toybox/ActivityRecording/Session.html), [Activity constants](https://developer.garmin.com/connect-iq/api-docs/Toybox/Activity.html).

## FIT developer data and ordering

`Session.createField(name, fieldId, type, options) as FitContributor.Field` dates from 1.3.0. Options include `:mesgType`, `:units`, `:count`, and `:nativeNum`. Use `MESG_TYPE_LAP` for climb attributes and `MESG_TYPE_SESSION` for aggregates. Apps have a 256-byte budget per message. `Field.setData(input) as Void` requires the declared type and replaces pending data; writing is deferred until the next appropriate FIT message. The official MoxyField sample updates lap values continuously and resets aggregates after its lap callback.

Publish completed climb fields before calling `addLap()` while recording. Preserve them until the lap has been generated; do not immediately zero them afterward. Publish session aggregates before stop/save. `addLap()` accepts no timestamp, so automatic logical peak timestamps require custom fields. FIT native lap boundaries cannot be retroactively backdated through this API. The docs do not promise an exact synchronization contract between `setData` and `addLap`; verify attribution in exported simulator FIT and on hardware.

Rest periods exist in the normal recording. A lap closed only at climb end includes elapsed time since the previous boundary, including rest. Custom logical climb duration/rest fields are authoritative. Adding a boundary at climb start creates explicit rest laps, including a possible cancelled attempt interval; choose and document this tradeoff rather than assuming one native lap per valid climb.

[Field API](https://developer.garmin.com/connect-iq/api-docs/Toybox/FitContributor/Field.html).

## Sensors

`Sensor.getInfo() as Sensor.Info` (1.0.0) is explicitly suitable for periodic Timer polling. `Info.altitude as Float or Null` is meters above mean sea level, derived from barometer preferentially, then GPS; a device with no GPS uses barometer. `heartRate as Number or Null` is BPM. `pressure as Float or Null` is calibrated sea-level pressure, not necessarily local ambient pressure. `accel` uses millig units. Guard every nullable value. Permission is `Sensor`; Positioning is not necessary solely for barometric altitude.

`setEnabledSensors(Array<SensorType>)` returns the available requested sensor types. `enableSensorEvents(listener or null) as Void` produces 1 Hz updates from enabled sensors (1.0.0). Polling through a 1000 ms Timer avoids duplicate event sampling. `enableSensorType` and `disableSensorType` return Boolean (3.2.0). Do not change sensor state while inactive: SDK docs say enabled sensors are automatically disabled when inactive and reenabled when active.

[Sensor API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Sensor.html), [Sensor.Info](https://developer.garmin.com/connect-iq/api-docs/Toybox/Sensor/Info.html).

## Lifecycle and minimum API

`AppBase.onStart(state as Dictionary or Null) as Void`, `getInitialView()`, and `onStop(state as Dictionary or Null) as Void` execute in that order; cleanup belongs in onStop. `onActive(state)` and `onInactive(state)` (4.2.3) cover fēnix 8 multitasking. Inactive means hidden by the system with limited system resource access. Stop application sampling/detection while inactive, reset detector trend history on return, and preserve the recording/session model. Do not use a view's `onHide` as app termination: menus also hide views.

Recommended minimum API is 4.2.3 when using these multitasking callbacks. No Background or Positioning permission is required for this design.

[AppBase API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Application/AppBase.html).

## Tests and simulator FIT export

Toybox.Test dates from 2.1.0. Test functions use `(:test)`, accept a logger, and return Boolean. `Test.assert(Boolean)` and `Test.assertEqual(value1, value2)` throw on failure; equality checks both type and value. Compile with `--unit-test` (or installed compiler shorthand after checking help). The installed macOS script requires `monkeydo executable device_id -t [test_name]`, not Windows `/t`. Start simulator with `bin/connectiq` first. Tests are omitted from production exports.

Official Garmin material describes Simulation → FIT Data → Save Fit Session. Confirm the current SDK menu visually, save the app session first, then export and decode the generated FIT. No supported Monkey C API directly exports a FIT file to the host.

[Test API](https://developer.garmin.com/connect-iq/api-docs/Toybox/Test.html), [unit test instructions](https://developer.garmin.com/connect-iq/core-topics/unit-testing/), [Garmin simulator FIT example](https://developer.garmin.com/downloads/connect-iq/wearable-programming-for-the-active-lifestyle.pdf).
