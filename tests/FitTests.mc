import Toybox.Test;
import Toybox.Lang;
import Toybox.FitContributor;

(:test)
class FakeFitField {
    var owner as FakeFitSession; var id;
    function initialize(parent, fieldId) { owner = parent; id = fieldId; }
    function setData(value) {
        Test.assert(value != null); owner.values[id] = value;
        if (owner.order.size() < 128) { owner.order.add("field_" + id); }
    }
}
(:test)
class FakeFitSession {
    var recording = false; var values as Lang.Dictionary; var definitions as Lang.Dictionary;
    var laps as Lang.Array; var order as Lang.Array; var saved as Lang.Dictionary;
    var failLaps = false; var failSave = false; var failDiscard = false; var failStart = false; var failStop = false;
    var starts = 0; var saves = 0; var lapCalls = 0;
    function initialize() { values = {}; definitions = {}; laps = []; order = []; saved = {}; }
    function createField(name, id, type, options) {
        Test.assert(!definitions.hasKey(id)); definitions[id] = {"name"=>name, "type"=>type, "options"=>options};
        return new FakeFitField(self, id);
    }
    function isRecording() { return recording; }
    function start() { starts++; if (failStart) { return false; } recording = true; return true; }
    function stop() { if (failStop) { return false; } recording = false; return true; }
    function snapshot() as Lang.Dictionary {
        var copy = {} as Lang.Dictionary; var keys = values.keys();
        for (var i = 0; i < keys.size(); i++) { copy[keys[i]] = values[keys[i]]; }
        return copy;
    }
    function addLap() {
        Test.assert(recording); lapCalls++;
        if (order.size() < 128) { order.add("lap"); }
        if (failLaps) { return false; }
        laps.add(snapshot()); return true;
    }
    function save() { saves++; if (failSave) { return false; } saved = snapshot(); return true; }
    function discard() { return !failDiscard; }
}
(:test)
class FakeFitRecorder extends FitRecorder {
    var backend as FakeFitSession;
    function initialize() { FitRecorder.initialize(); backend = new FakeFitSession(); }
    function createNativeSession() { return backend; }
}

(:test)
module FitTestHelpers {
function fitAttempt(id, mode, height, duration) {
    var attempt = new ClimbAttempt(id, mode, 0l, height == null ? null : 100.0, 2500l, false, 0l);
    attempt.finish(duration, duration, height == null ? null : 100.0 + height, C.MANUAL);
    return attempt;
}
}

(:test)
function fitSchemaIdsAndBudgets(logger) {
    var definitions = FitSchema.definitions(); var ids = {} as Lang.Dictionary; var lapBytes = 0; var sessionBytes = 0; var lapCount = 0; var sessionCount = 0; var stringBytes = 0;
    for (var i = 0; i < definitions.size(); i++) {
        var field = definitions[i] as Lang.Dictionary;
        Test.assert(!ids.hasKey(field["id"])); ids[field["id"]] = true;
        var size = field["type"] == FitContributor.DATA_TYPE_STRING ? field["count"] : (field["type"] == FitContributor.DATA_TYPE_UINT8 ? 1 :
            (field["type"] == FitContributor.DATA_TYPE_UINT16 ? 2 : 4));
        if (field["message"] == FitContributor.MESG_TYPE_LAP) { lapBytes += size; lapCount++; }
        else { sessionBytes += size; sessionCount++; }
        if (field["type"] == FitContributor.DATA_TYPE_STRING) { stringBytes += size; }
    }
    Test.assertEqual(lapBytes, FitSchema.LAP_BYTES); Test.assertEqual(sessionBytes, FitSchema.SESSION_BYTES);
    Test.assert(lapBytes < 256 && sessionBytes < 256);
    Test.assert(lapCount <= 16 && sessionCount <= 16); Test.assert(stringBytes <= 32); return true;
}

(:test)
function fitFieldsPrecedeLapAndMissingValuesAreExplicit(logger) {
    var fit = new FakeFitRecorder();
    Test.assert(!fit.addClimb(FitTestHelpers.fitAttempt(1, C.BOULDER, null, 5500l))); Test.assertEqual(fit.pendingCount(), 0);
    Test.assert(fit.startSession());
    fit.backend.order = [];
    var attempt = FitTestHelpers.fitAttempt(1, C.BOULDER, null, 5500l);
    Test.assert(fit.addClimb(attempt)); Test.assertEqual(fit.backend.laps.size(), 1);
    var lap = fit.backend.laps[0] as Lang.Dictionary;
    Test.assertEqual(lap[FitSchema.CLIMB_NUMBER], 1); Test.assertEqual(lap[FitSchema.CLIMB_MODE], C.BOULDER);
    Test.assertEqual(lap[FitSchema.CLIMB_HEIGHT], -1.0); Test.assertEqual(lap[FitSchema.CLIMB_AVG_HR], -1.0);
    Test.assertEqual(lap[FitSchema.CLIMB_MAX_HR], 65535); Test.assertEqual(lap[FitSchema.VALID_VALUES], 0);
    Test.assertEqual(lap[FitSchema.CLIMB_DURATION], 5.5); Test.assertEqual(lap[FitSchema.REST_BEFORE], 2.5);
    Test.assertEqual(fit.backend.order.size(), 14); Test.assertEqual(fit.backend.order[13], "lap");
    // Successful addLap keeps its values until the next lap/tail publication.
    Test.assertEqual(fit.backend.values[FitSchema.CLIMB_NUMBER], 1);
    Test.assert(fit.addClimb(attempt)); Test.assertEqual(fit.backend.laps.size(), 1);
    Test.assert(fit.addClimb(FitTestHelpers.fitAttempt(2, C.ROPE, null, 0l))); Test.assertEqual(fit.backend.laps.size(), 1);
    return true;
}

(:test)
function fitFailedLapRetriesInOrderAndPausedSaveCannotResume(logger) {
    var fit = new FakeFitRecorder(); fit.startSession(); fit.backend.failLaps = true;
    Test.assert(!fit.addClimb(FitTestHelpers.fitAttempt(1, C.ROPE, 10.0, 5000l)));
    Test.assert(!fit.addClimb(FitTestHelpers.fitAttempt(2, C.AUTO, 15.0, 6000l))); Test.assertEqual(fit.pendingCount(), 2);
    Test.assert(fit.pauseSession()); var starts = fit.backend.starts;
    Test.assert(!fit.saveSession()); Test.assertEqual(fit.backend.starts, starts); Test.assertEqual(fit.backend.saves, 0);
    Test.assert(fit.session != null); fit.backend.failLaps = false; Test.assert(fit.resumeSession());
    Test.assertEqual(fit.pendingCount(), 0); Test.assertEqual(fit.backend.laps.size(), 2);
    var first = fit.backend.laps[0] as Lang.Dictionary; var second = fit.backend.laps[1] as Lang.Dictionary;
    Test.assertEqual(first[FitSchema.ATTEMPT_ID], 1); Test.assertEqual(second[FitSchema.ATTEMPT_ID], 2);
    Test.assertEqual(first[FitSchema.CLIMB_NUMBER], 1); Test.assertEqual(second[FitSchema.CLIMB_NUMBER], 2);
    return true;
}

(:test)
function fitQueueCapacityAndResumeFailureState(logger) {
    var fit = new FakeFitRecorder(); fit.startSession(); fit.backend.failLaps = true;
    for (var i = 1; i <= AppConstants.MAX_HISTORY; i++) { Test.assert(!fit.addClimb(FitTestHelpers.fitAttempt(i, C.BOULDER, null, 5000l))); }
    Test.assertEqual(fit.pendingCount(), AppConstants.MAX_HISTORY);
    Test.assert(!fit.addClimb(FitTestHelpers.fitAttempt(257, C.BOULDER, null, 5000l)));
    Test.assertEqual(fit.pendingCount(), AppConstants.MAX_HISTORY);
    fit.pauseSession(); Test.assert(fit.resumeSession()); Test.assert(fit.backend.recording);
    Test.assertEqual(fit.pendingCount(), AppConstants.MAX_HISTORY);
    Test.assert(fit.discardSession()); Test.assert(fit.session == null); Test.assertEqual(fit.pendingCount(), 0); return true;
}

(:test)
function fitSummaryTailAndSaveFailurePreserveRecording(logger) {
    var fit = new FakeFitRecorder(); fit.startSession(); var domain = new SessionController(); domain.start(0l);
    domain.beginClimb(1000l, 100.0, C.ROPE, false, 1000l); domain.sample(2000l, 110.0, 140);
    var attempt = domain.finishClimb(6500l, 6500l, 108.0, C.MANUAL); fit.addClimb(attempt);
    domain.pause(9000l); Test.assert(fit.pauseSession()); Test.assert(fit.updateSummary(SessionStats.calculate(domain, 10000l)));
    fit.backend.failSave = true; Test.assert(!fit.saveSession()); Test.assert(fit.session != null);
    fit.backend.failSave = false; Test.assert(fit.saveSession()); Test.assert(fit.session == null);
    Test.assertEqual(fit.backend.saved[FitSchema.CLIMB_NUMBER], 0); Test.assertEqual(fit.backend.saved[FitSchema.VALID_VALUES], 0);
    Test.assertEqual(fit.backend.saved[FitSchema.TOTAL_CLIMBS], 1); Test.assertEqual(fit.backend.saved[FitSchema.ROPE_CLIMBS], 1);
    Test.assertEqual(fit.backend.saved[FitSchema.TOTAL_VERTICAL], 10.0);
    Test.assertEqual(fit.backend.saved[FitSchema.CLIMBING_TIME], 5.5);
    Test.assertEqual(fit.backend.saved[FitSchema.UNRATED], 1); return true;
}
