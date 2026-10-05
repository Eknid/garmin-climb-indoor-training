import Toybox.Activity;
import Toybox.ActivityRecording;
import Toybox.FitContributor;
import Toybox.Lang;
import Toybox.System;

class FitRecorder {
    var session = null; var error = null;
    var _fields as Lang.Dictionary; var _pending as Lang.Array;
    var _fieldsReady = false; var _completedCount = 0; var _lastQueuedId = 0;
    function initialize() { _fields = {}; _pending = []; }
    function fail(message, ex) {
        error = message;
        if (ex != null) { System.println("FIT: " + message + " / " + ex); }
        return false;
    }
    function createNativeSession() {
        return ActivityRecording.createSession({:name=>"Climb Indoor Training", :sport=>Activity.SPORT_ROCK_CLIMBING, :subSport=>Activity.SUB_SPORT_GENERIC});
    }
    function createFields() {
        var definitions = FitSchema.definitions();
        for (var i = 0; i < definitions.size(); i++) {
            var definition = definitions[i] as Lang.Dictionary;
            var id = definition["id"];
            if (!_fields.hasKey(id)) {
                var options = {:mesgType=>definition["message"], :units=>definition["units"]};
                if (definition.hasKey("count")) { options[:count] = definition["count"]; }
                _fields[id] = session.createField(definition["name"], id, definition["type"], options);
            }
        }
        clearLapValues();
        _fieldsReady = true;
    }
    function startSession() {
        error = null;
        try {
            if (session == null) { session = createNativeSession(); }
            if (!_fieldsReady) { createFields(); }
            if (session.isRecording() || session.start()) { return true; }
        } catch (ex) { return fail("Unable to start recording", ex); }
        return fail("Unable to start recording", null);
    }
    function pendingCount() { return _pending.size(); }
    function publishClimb(attempt, number) {
        var valid = 0;
        if (attempt.heightGain != null) { valid |= 1; }
        if (attempt.avgHeartRate != null) { valid |= 2; }
        if (attempt.maxHeartRate != null) { valid |= 4; }
        _fields[FitSchema.CLIMB_NUMBER].setData(number);
        _fields[FitSchema.CLIMB_MODE].setData(attempt.mode);
        _fields[FitSchema.CLIMB_HEIGHT].setData(FitSchema.numberOrUnknown(attempt.heightGain));
        _fields[FitSchema.CLIMB_DURATION].setData(FitSchema.seconds(attempt.durationMs));
        _fields[FitSchema.REST_BEFORE].setData(FitSchema.seconds(attempt.restBeforeMs));
        _fields[FitSchema.END_REASON].setData(attempt.endReason);
        _fields[FitSchema.CLIMB_AVG_HR].setData(FitSchema.numberOrUnknown(attempt.avgHeartRate));
        _fields[FitSchema.CLIMB_MAX_HR].setData(attempt.maxHeartRate == null ? FitSchema.UNKNOWN_HR : attempt.maxHeartRate);
        _fields[FitSchema.ATTEMPT_ID].setData(attempt.id);
        _fields[FitSchema.VALID_VALUES].setData(valid);
        _fields[FitSchema.CLIMB_SUCCESS].setData(attempt.outcome == 1 ? 1 : 0);
        _fields[FitSchema.CLIMB_FAILURE].setData(attempt.outcome == 2 ? 1 : 0);
        _fields[FitSchema.CLIMB_RATED].setData(attempt.outcome == 0 ? 0 : 1);
    }
    function clearLapValues() {
        _fields[FitSchema.CLIMB_NUMBER].setData(0); _fields[FitSchema.CLIMB_MODE].setData(0);
        _fields[FitSchema.CLIMB_HEIGHT].setData(FitSchema.UNKNOWN_FLOAT);
        _fields[FitSchema.CLIMB_DURATION].setData(0.0); _fields[FitSchema.REST_BEFORE].setData(0.0);
        _fields[FitSchema.END_REASON].setData(0); _fields[FitSchema.CLIMB_AVG_HR].setData(FitSchema.UNKNOWN_FLOAT);
        _fields[FitSchema.CLIMB_MAX_HR].setData(FitSchema.UNKNOWN_HR);
        _fields[FitSchema.CLIMB_SUCCESS].setData(0); _fields[FitSchema.CLIMB_FAILURE].setData(0); _fields[FitSchema.CLIMB_RATED].setData(0);
        _fields[FitSchema.ATTEMPT_ID].setData(0); _fields[FitSchema.VALID_VALUES].setData(0);
    }
    function flushPending() {
        if (_pending.size() == 0) { return true; }
        try {
            if (session == null || !session.isRecording()) { return fail("Laps pending. Resume to retry.", null); }
            while (_pending.size() > 0) {
                var entry = _pending[0] as Lang.Dictionary;
                publishClimb(entry["attempt"], entry["number"]);
                if (!session.addLap()) { return fail("Climb kept; lap pending", null); }
                _pending.remove(_pending[0]);
            }
            error = null; return true;
        } catch (ex) { return fail("Climb kept; lap pending", ex); }
    }
    function addClimb(attempt) {
        if (attempt == null || !attempt.valid) { return true; }
        if (session == null) { return fail("No recording for climb", null); }
        if (attempt.id <= _lastQueuedId) { return flushPending(); }
        if (_pending.size() >= AppConstants.MAX_HISTORY) { return fail("Lap queue full; save history first", null); }
        _completedCount++; _lastQueuedId = attempt.id;
        _pending.add({"attempt"=>attempt, "number"=>_completedCount});
        return flushPending();
    }
    function pauseSession() {
        error = null;
        try {
            if (session == null) { return fail("No recording to pause", null); }
            if (session.isRecording()) { flushPending(); if (!session.stop()) { return fail("Unable to pause recording", null); } }
            return true;
        } catch (ex) { return fail("Unable to pause recording", ex); }
    }
    function resumeSession() {
        error = null;
        try {
            if (session == null || !session.start()) { return fail("Unable to resume recording", null); }
            // Recording has resumed even if an individual lap still fails.
            flushPending(); return true;
        } catch (ex) { return fail("Unable to resume recording", ex); }
    }
    function updateSummary(stats as Lang.Dictionary) {
        if (!_fieldsReady) { return fail("Recording fields unavailable", null); }
        try {
            _fields[FitSchema.TOTAL_CLIMBS].setData(stats["totalClimbs"]);
            _fields[FitSchema.ROPE_CLIMBS].setData(stats["ropeClimbs"]);
            _fields[FitSchema.BOULDER_CLIMBS].setData(stats["boulderClimbs"]);
            _fields[FitSchema.AUTO_CLIMBS].setData(stats["autoClimbs"]);
            _fields[FitSchema.TOTAL_VERTICAL].setData(stats["totalVerticalGain"].toFloat());
            _fields[FitSchema.MAX_HEIGHT].setData(FitSchema.numberOrUnknown(stats["maxClimbHeight"]));
            _fields[FitSchema.CLIMBING_TIME].setData(FitSchema.seconds(stats["totalClimbingTime"]));
            _fields[FitSchema.REST_TIME].setData(FitSchema.seconds(stats["totalRestTime"]));
            _fields[FitSchema.ELAPSED_TIME].setData(FitSchema.seconds(stats["elapsedMs"]));
            _fields[FitSchema.SUCCESSES].setData(stats["successes"]);
            _fields[FitSchema.FAILURES].setData(stats["failures"]);
            _fields[FitSchema.SUCCESS_PERCENT].setData(FitSchema.numberOrUnknown(stats["successPercent"]));
            _fields[FitSchema.UNRATED].setData(stats["unrated"]);
            _fields[FitSchema.ROPE_RESULTS].setData(stats["ropeSuccesses"] + " / " + stats["ropeFailures"]);
            _fields[FitSchema.BOULDER_RESULTS].setData(stats["boulderSuccesses"] + " / " + stats["boulderFailures"]);
            _fields[FitSchema.AUTO_RESULTS].setData(stats["autoSuccesses"] + " / " + stats["autoFailures"]);
            return true;
        } catch (ex) { return fail("Unable to write activity summary", ex); }
    }
    function release() { session = null; _fields = {}; _pending = []; _fieldsReady = false; _completedCount = 0; _lastQueuedId = 0; }
    function saveSession() {
        error = null;
        try {
            if (session == null) { return fail("No recording to save", null); }
            if (_pending.size() > 0 && !flushPending()) { return false; }
            if (session.isRecording() && !session.stop()) { return fail("Unable to stop recording", null); }
            // Tag the final implicit/rest lap; validate this ordering in exported FIT.
            clearLapValues();
            if (session.save()) { release(); return true; }
        } catch (ex) { return fail("Unable to save; try again", ex); }
        return fail("Unable to save; try again", null);
    }
    function discardSession() {
        error = null;
        try {
            if (session == null) { return true; }
            if (session.isRecording() && !session.stop()) { return fail("Unable to stop recording", null); }
            if (session.discard()) { release(); return true; }
        } catch (ex) { return fail("Unable to discard; try again", ex); }
        return fail("Unable to discard; try again", null);
    }
}
