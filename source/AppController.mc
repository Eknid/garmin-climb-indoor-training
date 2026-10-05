import Toybox.Lang;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

class AppController {
    var sm; var settings; var lastSnapshot as Lang.Dictionary; var error = null; var page = 0;
    var pendingOutcome = null; var outcomeSelection = 1; var _pauseAfterOutcome = false;
    var recorder; var sensors; var store; var clock;
    var altitudeFilter as AltitudeFilter; var ropeDetector as RopeEndDetector;
    var _statistics as Lang.Dictionary = {};
    var autoDetector as AutoClimbDetector; var _autoHistory as Lang.Array;
    var _timer; var _timerRunning = false; var _active = true; var _menuOpen = false; var _closed = false;
    function initialize() {
        settings = new SettingsManager(); sm = new ClimbStateMachine(settings.get("lastMode"));
        recorder = new FitRecorder(); sensors = new SensorService(); store = new SessionStore(); clock = new AppClock();
        _timer = new Timer.Timer(); altitudeFilter = new AltitudeFilter();
        ropeDetector = new RopeEndDetector(settings.get("endSensitivity"));
        autoDetector = new AutoClimbDetector(settings.get("startSensitivity"), settings.get("endSensitivity")); _autoHistory = [];
        lastSnapshot = {"timestamp"=>now(), "altitude"=>null, "heartRate"=>null, "pressure"=>null, "acceleration"=>null};
        updateStatistics();
    }
    function now() { return clock.now(); }
    function updateStatistics() { _statistics = SessionStats.calculate(sm.session, now()); }
    function statistics() as Lang.Dictionary { return _statistics; }
    function startUpdates() {
        if (_closed || !_active || _timerRunning) { return; }
        _timer.start(method(:tick), 1000, true); _timerRunning = true;
    }
    function stopUpdates() { if (_timerRunning) { _timer.stop(); _timerRunning = false; } }
    function refresh() { updateStatistics(); WatchUi.requestUpdate(); }
    function altitude() { return lastSnapshot["altitude"]; }
    function tick() {
        if (_closed || !_active) { return; }
        var timestamp = now();
        if (sm.state != C.PRE_START && sm.state != C.PAUSED && sm.state != C.SESSION_SUMMARY) {
            lastSnapshot = sensors.sample(timestamp) as Lang.Dictionary;
            lastSnapshot["rawAltitude"] = lastSnapshot["altitude"];
            lastSnapshot["altitude"] = altitudeFilter.update(timestamp, lastSnapshot["rawAltitude"]);
            sm.session.sample(timestamp, altitude(), lastSnapshot["heartRate"]);
            if (debugEnabled()) { traceSample(timestamp); }
            if (sm.state == C.CLIMBING && !_menuOpen && sm.session.currentClimb.mode == C.ROPE) {
                var event = ropeDetector.update(timestamp, altitude());
                if (event != null) {
                    completed(sm.finishClimb(event["endAt"], event["detectedAt"], altitude(), C.AUTO_DESCENT));
                    page = 0;
                }
            }
            if (!_menuOpen && sm.currentMode == C.AUTO && (sm.state == C.RESTING || sm.state == C.CLIMBING)) {
                if (sm.state == C.RESTING) {
                    _autoHistory.add({"timestamp"=>timestamp, "altitude"=>altitude(), "heartRate"=>lastSnapshot["heartRate"]});
                    if (_autoHistory.size() > AppConstants.AUTO_HISTORY_SAMPLES) { _autoHistory.remove(_autoHistory[0]); }
                }
                var automatic = autoDetector.update(timestamp, altitude());
                if (automatic != null && automatic["kind"].equals("start")) {
                    if (sm.beginClimb(automatic["startAt"], automatic["startAltitude"], true, automatic["detectedAt"])) {
                        // Rest samples already contributed to session HR. Replay only
                        // into the newly backdated climb, never into session totals.
                        for (var i = 0; i < _autoHistory.size(); i++) {
                            var sample = _autoHistory[i] as Lang.Dictionary;
                            if (sample["timestamp"] >= automatic["startAt"]) {
                                sm.session.currentClimb.sample(sample["timestamp"], sample["altitude"], sample["heartRate"]);
                            }
                        }
                        _autoHistory = []; page = 0;
                        if (debugEnabled()) { System.println("AUTO start logical=" + automatic["startAt"] + " detected=" + automatic["detectedAt"]); }
                    } else { autoDetector.reset(); _autoHistory = []; }
                } else if (automatic != null && automatic["kind"].equals("end")) {
                    completed(sm.finishClimb(automatic["endAt"], automatic["detectedAt"], altitude(), C.AUTO_FULL)); page = 0;
                }
            }
        }
        if (pendingOutcome == null) { sm.tick(timestamp); } refresh();
    }
    function select() {
        error = null;
        var timestamp = now();
        if (pendingOutcome != null) {
            var pauseAfter = _pauseAfterOutcome;
            resolveOutcome(outcomeSelection);
            if (pauseAfter && pause()) { return "pauseMenu"; }
            return null;
        }
        if (sm.state == C.PRE_START) {
            if (!recorder.startSession()) { error = recorder.error; refresh(); return null; }
            if (!sm.start(timestamp)) { recorder.discardSession(); error = "Unable to start session"; refresh(); return null; }
            if (!store.start(timestamp, sm.currentMode)) { error = "Local history unavailable"; }
            sensors.start(); startUpdates(); page = 0; refresh();
        } else if (sm.state == C.RESTING || sm.state == C.CLIMB_SUMMARY) {
            if (pause()) { return "pauseMenu"; }
        } else if (sm.state == C.CLIMBING) {
            if (sm.requestPause()) { refresh(); return "confirmPause"; }
        } else if (sm.state == C.PAUSED) { resume(); }
        else if (sm.state == C.SESSION_SUMMARY) { close(); return "exit"; }
        return null;
    }
    function back() {
        error = null;
        if (sm.state == C.PRE_START || sm.state == C.SESSION_SUMMARY) { close(); return; }
        if (pendingOutcome != null) { refresh(); return; }
        if (sm.state == C.RESTING && !sm.session.canStartClimb()) { error = "Session full. Save first."; refresh(); return; }
        var before = sm.state;
        var attempt = sm.back(now(), altitude());
        if (before == C.RESTING && sm.state == C.CLIMBING) {
            ropeDetector = new RopeEndDetector(settings.get("endSensitivity"));
            ropeDetector.start(sm.session.currentClimb.startTimestamp, altitude());
            if (sm.currentMode == C.AUTO) { autoDetector.beginManual(now(), altitude()); _autoHistory = []; }
        }
        completed(attempt); page = 0; refresh();
    }
    function completed(attempt) {
        if (attempt == null) { return; }
        if (debugEnabled()) {
            System.println("CLIMB end id=" + attempt.id + " mode=" + attempt.mode +
                " logical=" + attempt.endTimestamp + " detected=" + attempt.detectionEndTimestamp +
                " height=" + traceValue(attempt.heightGain) + " reason=" + attempt.endReason);
        }
        clearSnapshot();
        if (attempt.valid) {
            pendingOutcome = attempt; outcomeSelection = 1;
        } else { persistAttempt(attempt); }
        if (sm.state == C.CLIMB_SUMMARY) { sm.summaryUntil = now() + settings.get("summarySeconds") * 1000; }
    }
    function persistAttempt(attempt) {
        if (!store.append(attempt)) { error = "Local history unavailable"; }
        if (!recorder.addClimb(attempt)) { error = recorder.error; }
    }
    function resolveOutcome(outcome) {
        if (pendingOutcome == null || (outcome != 1 && outcome != 2)) { return false; }
        pendingOutcome.outcome = outcome;
        persistAttempt(pendingOutcome); pendingOutcome = null; _pauseAfterOutcome = false;
        sm.summaryUntil = now() + settings.get("summarySeconds") * 1000;
        refresh(); return true;
    }
    function pause() {
        if (pendingOutcome != null || (sm.state != C.RESTING && sm.state != C.CLIMB_SUMMARY)) { return false; }
        var timestamp = now(); var attempt = sm.pause(timestamp, altitude());
        if (sm.state != C.PAUSED) { return false; }
        completed(attempt);
        if (!recorder.pauseSession()) { sm.resume(timestamp); error = recorder.error; refresh(); return false; }
        sensors.stop(); clearSnapshot(); page = 0; refresh(); return true;
    }
    function confirmPause() {
        if (sm.state != C.END_MENU) { return false; }
        completed(sm.finishClimb(now(), now(), altitude(), C.SESSION_STOP));
        if (pendingOutcome != null) { _pauseAfterOutcome = true; page = 0; refresh(); return true; }
        return pause();
    }
    function cancelPause() {
        var result = sm.cancelPause();
        if (result && sm.session.currentClimb != null) {
            ropeDetector.resumeFromClimb(sm.session.currentClimb, now());
            if (sm.currentMode == C.AUTO) { autoDetector.resumeFromClimb(sm.session.currentClimb, now()); }
        }
        refresh(); return result;
    }
    function resume() {
        if (sm.state != C.PAUSED) { return false; }
        error = null;
        if (!recorder.resumeSession()) { error = recorder.error; refresh(); return false; }
        if (!sm.resume(now())) { recorder.pauseSession(); error = "Unable to resume session"; refresh(); return false; }
        clearSnapshot(); sensors.start(); startUpdates(); page = 0; refresh(); return true;
    }
    function save() {
        if (sm.state != C.PAUSED) { return false; }
        error = null; stopUpdates(); sensors.stop();
        if (!recorder.updateSummary(statistics())) { error = recorder.error; startUpdates(); refresh(); return false; }
        if (!recorder.saveSession()) { error = recorder.error; startUpdates(); refresh(); return false; }
        var timestamp = now(); sm.save(timestamp); updateStatistics();
        if (!store.save(timestamp, statistics())) { error = "Saved; local history failed"; }
        page = 0; refresh(); return true;
    }
    function discard() {
        if (sm.state != C.PAUSED) { return false; }
        error = null; stopUpdates(); sensors.stop();
        if (!recorder.discardSession()) { error = recorder.error; startUpdates(); refresh(); return false; }
        store.clear(); close(); return true;
    }
    function close() { stopUpdates(); sensors.stop(); _closed = true; System.exit(); }
    function clearSnapshot() {
        lastSnapshot["altitude"] = null; lastSnapshot["heartRate"] = null; lastSnapshot["rawAltitude"] = null;
        altitudeFilter.reset(); ropeDetector.breakTrend(); _autoHistory = [];
        if (sm.session.currentClimb != null) {
            sm.session.currentClimb.relativeAltitude = null;
            if (sm.currentMode == C.AUTO) { autoDetector.resumeFromClimb(sm.session.currentClimb, now()); }
        } else { autoDetector.reset(); }
    }
    function debugEnabled() { return AppConstants.DEBUG_BUILD && settings.get("debug"); }
    function traceValue(value) { return value == null ? "null" : value.toString(); }
    function traceSample(timestamp) {
        var attempt = sm.session.currentClimb;
        var detector = sm.currentMode == C.AUTO ? autoDetector.rope : ropeDetector;
        var drop = attempt == null || attempt.peakRelativeAltitude == null || attempt.relativeAltitude == null ? null : attempt.peakRelativeAltitude - attempt.relativeAltitude;
        System.println("TRACE t=" + timestamp + " mode=" + sm.currentMode +
            " raw=" + traceValue(lastSnapshot["rawAltitude"]) + " filtered=" + traceValue(altitude()) +
            " relative=" + traceValue(attempt == null ? null : attempt.relativeAltitude) +
            " peak=" + traceValue(attempt == null ? null : attempt.peakRelativeAltitude) +
            " drop=" + traceValue(drop) + " hr=" + traceValue(lastSnapshot["heartRate"]) +
            " armed=" + detector.armed + " descending=" + detector.descendingSamples +
            " auto=" + autoDetector.state);
    }
    function pageCount() {
        if (pendingOutcome != null) { return 1; }
        if (sm.state == C.RESTING || sm.state == C.SESSION_SUMMARY) { return 3; }
        if (sm.state == C.CLIMBING) { return debugEnabled() ? 3 : 2; }
        return 1;
    }
    function previousPage() { if (pendingOutcome != null) { outcomeSelection = outcomeSelection == 1 ? 2 : 1; refresh(); return; } page = (page + pageCount() - 1) % pageCount(); refresh(); }
    function nextPage() { if (pendingOutcome != null) { outcomeSelection = outcomeSelection == 1 ? 2 : 1; refresh(); return; } page = (page + 1) % pageCount(); refresh(); }
    function menuAllowed() { return sm.state == C.PRE_START || sm.state == C.RESTING; }
    function resetAuto() {
        autoDetector = new AutoClimbDetector(settings.get("startSensitivity"), settings.get("endSensitivity")); _autoHistory = [];
    }
    function setMenuOpen(value) {
        _menuOpen = value;
        if (sm.state == C.RESTING) {
            resetAuto();
            // Menu movement must not leave a delayed EMA rise that starts a
            // climb when the menu closes. Require a fresh median warmup.
            altitudeFilter.reset();
            lastSnapshot["altitude"] = null;
        }
    }
    function changeMode(mode) {
        if (!sm.changeMode(mode)) { return false; }
        if (!settings.set("lastMode", mode)) { error = "Mode changed; setting not saved"; }
        resetAuto();
        if (sm.state == C.RESTING) { clearSnapshot(); }
        page = 0; refresh(); return true;
    }
    function changeSetting(key, value) {
        if (!menuAllowed()) { return false; }
        var result = settings.set(key, value);
        if (!result) { error = "Unable to save setting"; }
        if (key != null && (key.equals("startSensitivity") || key.equals("endSensitivity"))) {
            resetAuto();
            if (sm.state == C.RESTING) { clearSnapshot(); }
        }
        refresh(); return result;
    }
    function active() { _active = true; if (_closed) { return; } if (sm.state != C.PRE_START && sm.state != C.PAUSED && sm.state != C.SESSION_SUMMARY) { sensors.start(); } startUpdates(); refresh(); }
    function inactive() { _active = false; stopUpdates(); sensors.suspend(); clearSnapshot(); }
    function shutdown() {
        stopUpdates(); sensors.stop();
        if (_closed || recorder.session == null) { return; }
        if (sm.state == C.PRE_START) { recorder.discardSession(); return; }
        var timestamp = now();
        // Forced shutdown cannot ask for a result: preserve an explicit unrated attempt.
        if (pendingOutcome != null) { persistAttempt(pendingOutcome); pendingOutcome = null; }
        if (sm.state == C.CLIMBING || sm.state == C.END_MENU) { completed(sm.finishClimb(timestamp, timestamp, altitude(), C.SESSION_STOP)); }
        if (pendingOutcome != null) { persistAttempt(pendingOutcome); pendingOutcome = null; }
        sm.pause(timestamp, altitude());
        recorder.pauseSession();
        updateStatistics();
        if (!recorder.updateSummary(statistics())) {
            System.println("Exit summary: " + recorder.error);
            recorder.pauseSession(); _closed = true; return;
        }
        if (recorder.saveSession()) { sm.save(timestamp); updateStatistics(); store.save(timestamp, statistics()); }
        else { System.println("Exit recording: " + recorder.error); }
        _closed = true;
    }
}
