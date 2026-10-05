import Toybox.Test;
import Toybox.Lang;

(:test)
class ManualTestSettings extends SettingsManager {
    function initialize() { SettingsManager.initialize(); }
    function get(key) { return _defaults[key]; }
    function set(key, value) { if (!valid(key, value)) { return false; } _defaults[key] = value; return true; }
}

(:test)
class ManualTestClock {
    var timestamp = 100000l;
    function initialize() {}
    function now() { return timestamp; }
}
(:test)
class ManualTestTimer {
    var starts = 0; var stops = 0;
    function initialize() {}
    function start(callback, interval, repeat) { starts++; }
    function stop() { stops++; }
}
(:test)
class ManualTestSensors {
    var enabled = false; var altitude = null; var heartRate = null;
    function initialize() {}
    function start() { enabled = true; }
    function stop() { enabled = false; }
    function suspend() { enabled = false; }
    function sample(timestamp) as Lang.Dictionary { return {"timestamp"=>timestamp, "altitude"=>altitude, "heartRate"=>heartRate}; }
}
(:test)
class ManualTestStore {
    var attempts; var saved = false; var cleared = false;
    function initialize() { attempts = []; }
    function start(timestamp, mode) { return true; }
    function append(attempt) { attempts.add(attempt); return true; }
    function save(timestamp, stats) { saved = true; return true; }
    function clear() { cleared = true; return true; }
}
(:test)
class ManualTestRecorder {
    var session = null; var running = false; var laps = 0; var starts = 0; var saves = 0; var failSummary = false;
    var error = "Injected recording failure";
    var failStart = false; var failPause = false; var failResume = false; var failSave = false; var failDiscard = false; var failLap = false;
    function initialize() {}
    function startSession() { starts++; if (failStart) { return false; } session = true; running = true; return true; }
    function pauseSession() { if (failPause) { return false; } running = false; return true; }
    function resumeSession() { if (failResume) { return false; } running = true; return true; }
    function addClimb(attempt) {
        if (!attempt.valid) { return true; }
        Test.assert(running); // Lap must close before the recording is stopped.
        if (failLap) { return false; }
        laps++; return true;
    }
    function updateSummary(stats) { return !failSummary; }
    function saveSession() { saves++; if (failSave) { return false; } running = false; session = null; return true; }
    function discardSession() { if (failDiscard) { return false; } running = false; session = null; return true; }
}
(:test)
class ManualTestController extends AppController {
    var exited = false;
    function initialize() {
        AppController.initialize(); settings = new ManualTestSettings(); clock = new ManualTestClock(); recorder = new ManualTestRecorder();
        sensors = new ManualTestSensors(); store = new ManualTestStore(); _timer = new ManualTestTimer();
        sm = new ClimbStateMachine(C.ROPE); resetAuto(); ropeDetector = new RopeEndDetector(1); lastSnapshot = {"altitude"=>null, "heartRate"=>null};
    }
    function close() { stopUpdates(); sensors.stop(); _closed = true; exited = true; }
}

(:test)
function controllerManualAcceptance(logger) {
    var c = new ManualTestController();
    c.select(); Test.assertEqual(c.sm.state, C.RESTING); Test.assertEqual(c.recorder.starts, 1);
    c.clock.timestamp += 5000l; c.back(); c.resolveOutcome(1); Test.assertEqual(c.sm.state, C.CLIMBING);
    c.clock.timestamp += 6000l; c.back(); c.resolveOutcome(1); Test.assertEqual(c.sm.state, C.CLIMB_SUMMARY);
    c.resolveOutcome(1); Test.assertEqual(c.recorder.laps, 1); Test.assertEqual(c.store.attempts.size(), 1);
    c.back(); c.resolveOutcome(1); Test.assertEqual(c.sm.state, C.RESTING);
    Test.assert(c.changeMode(C.BOULDER)); c.back(); c.resolveOutcome(1);
    Test.assert(!c.changeMode(C.AUTO));
    Test.assertEqual(c.select(), "confirmPause"); Test.assertEqual(c.sm.state, C.END_MENU);
    Test.assert(c.cancelPause()); Test.assertEqual(c.sm.state, C.CLIMBING);
    c.clock.timestamp += 5000l; c.select(); Test.assert(c.confirmPause()); if (c.pendingOutcome != null) { c.resolveOutcome(1); Test.assert(c.pause()); }
    Test.assertEqual(c.sm.state, C.PAUSED); Test.assertEqual(c.recorder.laps, 2);
    Test.assertEqual(c.sm.lastClimb.endReason, C.SESSION_STOP);
    c.lastSnapshot["altitude"] = 100.0f;
    c.clock.timestamp += 10000l; Test.assert(c.resume()); Test.assert(c.altitude() == null); Test.assertEqual(c.sm.state, C.RESTING);
    Test.assertEqual(c.recorder.starts, 1); // Resume cannot create a second native session.
    Test.assertEqual(c.select(), "pauseMenu"); Test.assert(c.save());
    Test.assertEqual(c.sm.state, C.SESSION_SUMMARY); Test.assert(c.store.saved);
    Test.assert(!c._timerRunning); Test.assert(!c.sensors.enabled); Test.assert(c.recorder.session == null);
    var stats = c.statistics(); Test.assertEqual(stats["totalClimbs"], 2);
    Test.assertEqual(stats["ropeClimbs"], 1); Test.assertEqual(stats["boulderClimbs"], 1);
    c.select(); Test.assert(c.exited);
    return true;
}

(:test)
function controllerRecordingFailuresRecover(logger) {
    var c = new ManualTestController(); c.recorder.failStart = true;
    c.select(); Test.assertEqual(c.sm.state, C.PRE_START); Test.assert(c.error != null);
    c.recorder.failStart = false; c.select(); c.back(); c.resolveOutcome(1); c.clock.timestamp += 5000l;
    c.recorder.failLap = true; c.back(); c.resolveOutcome(1); Test.assertEqual(c.sm.session.climbs.size(), 1);
    Test.assert(c.error != null); c.back(); c.resolveOutcome(1);
    c.recorder.failPause = true; c.select(); Test.assertEqual(c.sm.state, C.RESTING);
    Test.assert(c.recorder.running); Test.assert(c.sensors.enabled);
    c.recorder.failPause = false; c.select(); Test.assertEqual(c.sm.state, C.PAUSED);
    c.recorder.failResume = true; Test.assert(!c.resume()); Test.assertEqual(c.sm.state, C.PAUSED);
    c.recorder.failSave = true; Test.assert(!c.save()); Test.assertEqual(c.sm.state, C.PAUSED);
    Test.assert(c.recorder.session != null); Test.assert(c._timerRunning);
    c.recorder.failSave = false; Test.assert(c.save()); Test.assertEqual(c.sm.state, C.SESSION_SUMMARY);
    return true;
}

(:test)
function controllerDiscardAndSensorCleanup(logger) {
    var c = new ManualTestController(); c.select(); c.back(); c.resolveOutcome(1); c.back(); c.resolveOutcome(1);
    Test.assertEqual(c.sm.lastClimb.endReason, C.CANCELLED); Test.assertEqual(c.recorder.laps, 0);
    c.back(); c.resolveOutcome(1); c.inactive(); Test.assert(!c.sensors.enabled); Test.assert(!c._timerRunning);
    c.active(); Test.assert(c.sensors.enabled); Test.assert(c._timerRunning);
    c.select(); c.recorder.failDiscard = true; Test.assert(!c.discard());
    Test.assert(!c.exited); Test.assert(c.recorder.session != null);
    c.recorder.failDiscard = false; Test.assert(c.discard()); Test.assert(c.exited);
    Test.assert(c.store.cleared); Test.assert(!c.store.saved); Test.assert(!c._timerRunning); Test.assert(!c.sensors.enabled);
    return true;
}

(:test)
function controllerRopeFilteredDescentAndBoulderOverride(logger) {
    var c = new ManualTestController(); c.select();
    c.sensors.altitude = 100.0; c.clock.timestamp += 1000l; c.tick(); c.back(); c.resolveOutcome(1);
    for (var i = 1; i <= 20; i++) {
        c.sensors.altitude = 100.0 + i; c.clock.timestamp += 1000l; c.tick();
        Test.assertEqual(c.sm.state, C.CLIMBING);
    }
    for (var p = 0; p < 8; p++) { c.clock.timestamp += 1000l; c.tick(); }
    for (var d = 1; d <= 12 && c.sm.state == C.CLIMBING; d++) {
        c.sensors.altitude = 120.0 - d; c.clock.timestamp += 1000l; c.tick();
    }
    Test.assertEqual(c.sm.state, C.CLIMB_SUMMARY);
    Test.assertEqual(c.sm.lastClimb.endReason, C.AUTO_DESCENT);
    Test.assert(c.sm.lastClimb.endTimestamp < c.sm.lastClimb.detectionEndTimestamp);
    c.resolveOutcome(1); Test.assertEqual(c.recorder.laps, 1); Test.assertEqual(c.store.attempts.size(), 1);
    c.back(); c.resolveOutcome(1); Test.assert(c.changeMode(C.BOULDER)); c.back(); c.resolveOutcome(1);
    for (var b = 0; b < 20; b++) {
        c.sensors.altitude = b < 10 ? 100.0 + b : 120.0 - b;
        c.clock.timestamp += 1000l; c.tick();
    }
    Test.assertEqual(c.sm.state, C.CLIMBING); c.back(); c.resolveOutcome(1);
    Test.assertEqual(c.sm.lastClimb.endReason, C.MANUAL); Test.assertEqual(c.recorder.laps, 2);
    c.back(); c.resolveOutcome(1); c.select(); Test.assert(c.discard());
    return true;
}

(:test)
function controllerPauseConfirmationKeepsPeakAligned(logger) {
    var c = new ManualTestController(); c.select(); c.sensors.altitude = 100.0;
    c.clock.timestamp += 1000l; c.tick(); c.back(); c.resolveOutcome(1);
    for (var i = 1; i <= 6; i++) {
        c.sensors.altitude = 100.0 + i; c.clock.timestamp += 1000l; c.tick();
    }
    Test.assertEqual(c.select(), "confirmPause");
    for (var m = 1; m <= 6; m++) {
        c.sensors.altitude = 106.0 + m; c.clock.timestamp += 1000l; c.tick();
    }
    Test.assertEqual(c.sm.state, C.END_MENU); Test.assert(c.cancelPause());
    Test.assertEqual(c.ropeDetector.peakAltitude, c.sm.session.currentClimb.peakAltitude);
    Test.assertEqual(c.ropeDetector.peakTimestamp, c.sm.session.currentClimb.peakTimestamp);
    Test.assertEqual(c.ropeDetector.descendingSamples, 0);
    c.select(); Test.assert(c.confirmPause()); if (c.pendingOutcome != null) { c.resolveOutcome(1); Test.assert(c.pause()); } Test.assert(c.discard()); return true;
}

(:test)
function controllerRopeRecoverySpikeNeverEndsClimb(logger) {
    for (var spikePosition = 0; spikePosition <= 1; spikePosition++) {
        var c = new ManualTestController(); c.select(); c.sensors.altitude = 100.0;
        for (var w = 0; w < 5; w++) { c.clock.timestamp += 1000l; c.tick(); }
        c.back(); c.resolveOutcome(1);
        for (var i = 1; i <= 20; i++) {
            c.sensors.altitude = 100.0 + i; c.clock.timestamp += 1000l; c.tick();
        }
        for (var p = 0; p < 8; p++) { c.clock.timestamp += 1000l; c.tick(); }
        Test.assert(c.ropeDetector.armed);
        c.sensors.altitude = null; c.clock.timestamp += 1000l; c.tick();
        Test.assert(c.sm.session.currentClimb.relativeAltitude == null);
        for (var r = 0; r < 12; r++) {
            c.sensors.altitude = r == spikePosition ? 150.0 : 120.0;
            c.clock.timestamp += 1000l; c.tick(); Test.assertEqual(c.sm.state, C.CLIMBING);
        }
        c.back(); c.resolveOutcome(1); Test.assertEqual(c.sm.lastClimb.endReason, C.MANUAL);
        c.back(); c.resolveOutcome(1); c.select(); Test.assert(c.discard());
    }
    return true;
}

(:test)
function controllerSummaryFailureNeverMarksIncompleteFitSaved(logger) {
    var c = new ManualTestController(); c.select(); c.back(); c.resolveOutcome(1); c.clock.timestamp += 5000l;
    c.recorder.failSummary = true; c.shutdown();
    Test.assertEqual(c.recorder.saves, 0); Test.assert(c.recorder.session != null);
    Test.assert(!c.recorder.running); Test.assert(!c.store.saved);
    Test.assert(!c._timerRunning); Test.assert(!c.sensors.enabled); Test.assert(c._closed);
    var explicit = new ManualTestController(); explicit.select(); explicit.select();
    explicit.recorder.failSummary = true; Test.assert(!explicit.save());
    Test.assertEqual(explicit.sm.state, C.PAUSED); Test.assertEqual(explicit.recorder.saves, 0);
    explicit.recorder.failSummary = false; Test.assert(explicit.save());
    Test.assertEqual(explicit.recorder.saves, 1); return true;
}

(:test)
class ControllerTrace {
    var c as ManualTestController;
    function initialize(controller as ManualTestController) { c = controller; }
    function feed(altitude, hr) {
        c.sensors.altitude = altitude; c.sensors.heartRate = hr;
        c.clock.timestamp += 1000l; c.tick();
    }
    function flat(altitude, seconds) { for (var i = 0; i < seconds; i++) { feed(altitude, 120); } }
}

(:test)
function controllerAutoStartEndHeartRateAndManualOverrides(logger) {
    var c = new ManualTestController(); Test.assert(c.changeMode(C.AUTO)); c.select();
    var trace = new ControllerTrace(c); trace.flat(100.0, 12);
    Test.assertEqual(c.sm.state, C.RESTING);
    for (var i = 1; i <= 24; i++) { trace.feed(100.0 + i * 0.5, 140); }
    Test.assertEqual(c.sm.state, C.CLIMBING); Test.assert(c.sm.session.currentClimb.wasAutoStarted);
    Test.assert(c.sm.session.currentClimb.startTimestamp < c.sm.session.currentClimb.detectionStartTimestamp);
    Test.assertEqual(c.sm.session.heartRateSamples, 36); // Candidate replay must not double overall HR.
    Test.assert(c.sm.session.currentClimb.heartRateSamples > 0);
    trace.flat(112.0, 8);
    for (var d = 1; d <= 15 && c.sm.state == C.CLIMBING; d++) { trace.feed(112.0 - d * 0.8, 130); }
    Test.assertEqual(c.sm.state, C.CLIMB_SUMMARY); Test.assertEqual(c.sm.lastClimb.endReason, C.AUTO_FULL);
    c.resolveOutcome(1); Test.assert(c.sm.lastClimb.wasAutoEnded); c.resolveOutcome(1); Test.assertEqual(c.recorder.laps, 1);
    c.back(); c.resolveOutcome(1); c.back(); c.resolveOutcome(1); Test.assertEqual(c.sm.state, C.CLIMBING);
    Test.assert(!c.sm.session.currentClimb.wasAutoStarted);
    trace.flat(100.0, 5); c.back(); c.resolveOutcome(1); Test.assertEqual(c.sm.lastClimb.endReason, C.MANUAL);
    Test.assertEqual(c.recorder.laps, 2); c.back(); c.resolveOutcome(1); c.select(); Test.assert(c.discard()); return true;
}

(:test)
function controllerAutoCannotStartUnderMenuOrAfterMissingSensors(logger) {
    var c = new ManualTestController(); c.changeMode(C.AUTO); c.select();
    var trace = new ControllerTrace(c); trace.flat(100.0, 8); c.setMenuOpen(true);
    for (var i = 1; i <= 20; i++) { trace.feed(100.0 + i, 120); }
    Test.assertEqual(c.sm.state, C.RESTING); c.setMenuOpen(false); trace.flat(120.0, 10);
    Test.assertEqual(c.sm.state, C.RESTING); trace.feed(null, null);
    trace.feed(150.0, null); trace.flat(120.0, 15);
    Test.assertEqual(c.sm.state, C.RESTING);
    c.back(); c.resolveOutcome(1); Test.assertEqual(c.sm.state, C.CLIMBING); trace.flat(120.0, 5);
    c.select(); trace.feed(125.0, 130); Test.assert(c.cancelPause());
    Test.assertEqual(c.autoDetector.rope.peakTimestamp, c.sm.session.currentClimb.peakTimestamp);
    c.select(); c.confirmPause(); if (c.pendingOutcome != null) { c.resolveOutcome(1); c.pause(); } c.discard(); return true;
}

(:test)
function controllerMenuCloseAndModeChangeRequireFreshBaseline(logger) {
    var c = new ManualTestController(); c.select(); var trace = new ControllerTrace(c);
    trace.flat(100.0, 8); c.setMenuOpen(true);
    for (var i = 1; i <= 12; i++) { trace.feed(100.0 + i, 120); }
    c.setMenuOpen(false); Test.assert(c.altitude() == null); c.back(); c.resolveOutcome(1);
    Test.assert(c.sm.session.currentClimb.startAltitude == null);
    trace.flat(112.0, 8); Test.assertEqual(c.sm.session.currentClimb.heightGain, 0.0);
    c.back(); c.resolveOutcome(1); c.back(); c.resolveOutcome(1); trace.flat(112.0, 8); Test.assert(c.changeMode(C.AUTO));
    Test.assert(c.altitude() == null); c.back(); c.resolveOutcome(1); Test.assert(c.sm.session.currentClimb.startAltitude == null);
    trace.flat(112.0, 5); c.select(); c.confirmPause(); if (c.pendingOutcome != null) { c.resolveOutcome(1); c.pause(); } c.discard(); return true;
}

(:test)
function controllerAutoManualFinishCannotReplayFilterRise(logger) {
    var c = new ManualTestController(); c.changeMode(C.AUTO); c.select();
    var trace = new ControllerTrace(c); trace.flat(100.0, 8); c.back(); c.resolveOutcome(1);
    for (var i = 1; i <= 8; i++) { trace.feed(100.0 + i * 2, 140); }
    c.back(); c.resolveOutcome(1); Test.assertEqual(c.sm.state, C.CLIMB_SUMMARY); c.back(); c.resolveOutcome(1);
    trace.flat(116.0, 15); Test.assertEqual(c.sm.state, C.RESTING);
    Test.assertEqual(c.sm.session.climbs.size(), 1); c.select(); c.discard(); return true;
}
