import Toybox.Test;
import Toybox.Lang;

(:test)
function autoFlatNoiseDriftAndOneMeterNeverStart(logger) {
    var detector = new AutoClimbDetector(1, 1);
    for (var i = 0; i < 60; i++) { Test.assert(detector.update(i*1000l, 100.0 + (i%2)*0.2) == null); }
    Test.assertEqual(detector.state, "WATCHING"); detector.reset();
    for (var j = 0; j < 120; j++) { Test.assert(detector.update(j*1000l, 100.0 + j*0.05) == null); }
    Test.assertEqual(detector.state, "WATCHING"); detector.reset(); detector.update(0l, 100.0);
    for (var k = 1; k <= 5; k++) { Test.assert(detector.update(k*1000l, 100.0 + k*0.2) == null); }
    for (var n = 6; n < 20; n++) { Test.assert(detector.update(n*1000l, 101.0) == null); }
    Test.assertEqual(detector.state, "WATCHING"); return true;
}

(:test)
function autoSteadyThreeMeterStartAndLogicalDescentEnd(logger) {
    var detector = new AutoClimbDetector(1, 1); detector.update(0l, 100.0);
    Test.assert(detector.update(1000l, 100.5) == null); Test.assert(detector.update(2000l, 101.0) == null);
    Test.assert(detector.update(3000l, 101.5) == null); Test.assertEqual(detector.state, "POSSIBLE_START");
    var start = detector.update(4000l, 102.0) as Lang.Dictionary;
    Test.assertEqual(start["kind"], "start"); Test.assertEqual(start["startAt"], 3000l);
    Test.assertEqual(start["detectedAt"], 4000l); DetectorTestHelpers.near(start["startAltitude"], 101.5);
    Test.assertEqual(detector.state, "CLIMBING"); DetectorTestHelpers.near(detector.rope.peakAltitude, 102.0);
    Test.assertEqual(detector.rope.peakTimestamp, 4000l);
    for (var i = 5; i <= 10; i++) { Test.assert(detector.update(i*1000l, 100.0 + i*0.5) == null); }
    Test.assert(detector.update(11000l, 105.0) == null);
    Test.assert(detector.update(12000l, 104.0) == null); Test.assertEqual(detector.state, "POSSIBLE_END");
    Test.assert(detector.update(13000l, 103.0) == null);
    var end = detector.update(14000l, 102.0) as Lang.Dictionary;
    Test.assertEqual(end["kind"], "end"); Test.assertEqual(end["endAt"], 10000l);
    Test.assertEqual(end["detectedAt"], 14000l); Test.assert(detector.update(15000l, 101.0) == null);
    detector.reset(); Test.assertEqual(detector.state, "WATCHING"); return true;
}

(:test)
function autoCandidateCancelAndStall(logger) {
    var detector = new AutoClimbDetector(1, 1); detector.update(0l, 100.0);
    detector.update(1000l, 100.5); detector.update(2000l, 101.0); detector.update(3000l, 101.5);
    Test.assertEqual(detector.state, "POSSIBLE_START");
    Test.assert(detector.update(4000l, 101.0) == null); Test.assertEqual(detector.state, "WATCHING");
    Test.assert(detector.candidateStartTimestamp == null);
    detector.reset(); detector.update(0l, 100.0); detector.update(1000l, 100.5);
    detector.update(2000l, 101.0); detector.update(3000l, 101.5);
    Test.assert(detector.update(4000l, 101.5) == null); Test.assert(detector.update(5000l, 101.5) == null);
    Test.assertEqual(detector.state, "WATCHING"); Test.assert(detector.candidateStartTimestamp == null);
    // A single large step followed by a plateau cannot satisfy three upward samples.
    detector.reset(); detector.update(0l, 100.0); Test.assert(detector.update(1000l, 105.0) == null);
    for (var i = 2; i <= 12; i++) { Test.assert(detector.update(i*1000l, 105.0) == null); }
    detector.reset(); detector.update(0l, 100.0); detector.update(1000l, 101.0);
    detector.update(2000l, 102.0);
    Test.assert(detector.update(3000l, 103.0) == null); Test.assertEqual(detector.state, "POSSIBLE_START");
    Test.assert(detector.update(4000l, 104.0) != null);
    return true;
}

(:test)
function autoNullGapAndTimeReversalCancelCandidates(logger) {
    var detector = new AutoClimbDetector(1, 1); detector.update(0l, 100.0);
    detector.update(1000l, 100.5); detector.update(2000l, 101.0); detector.update(3000l, 101.5);
    Test.assert(detector.update(2000l, 120.0) == null); Test.assertEqual(detector.state, "POSSIBLE_START");
    Test.assert(detector.update(4000l, null) == null); Test.assertEqual(detector.state, "WATCHING");
    Test.assert(detector.update(5000l, 110.0) == null); Test.assert(detector.candidateStartTimestamp == null);
    detector.reset(); detector.update(0l, 100.0); detector.update(1000l, 100.5);
    detector.update(2000l, 101.0); detector.update(3000l, 101.5);
    Test.assert(detector.update(10000l, 120.0) == null); Test.assertEqual(detector.state, "WATCHING");
    Test.assert(detector.candidateStartTimestamp == null); Test.assert(!detector.beginManual(9000l, 120.0));
    Test.assert(detector.update(-1l, 130.0) == null); return true;
}

(:test)
function autoManualOverrideAndMissingActiveAltitude(logger) {
    var detector = new AutoClimbDetector(1, 1); detector.update(0l, 100.0);
    detector.update(1000l, 100.5); detector.update(2000l, 101.0); detector.update(3000l, 101.5);
    Test.assert(detector.beginManual(3000l, 101.5)); Test.assertEqual(detector.state, "CLIMBING");
    Test.assert(detector.candidateStartTimestamp == null); DetectorTestHelpers.near(detector.rope.baselineAltitude, 101.5);
    detector.reset(); Test.assert(detector.beginManual(0l, 100.0));
    for (var i = 1; i <= 6; i++) { detector.update(i*1000l, 100.0+i); }
    Test.assert(detector.update(7000l, null) == null); Test.assertEqual(detector.state, "CLIMBING");
    Test.assert(detector.rope.armed); Test.assertEqual(detector.rope.peakTimestamp, 6000l);
    Test.assert(detector.update(8000l, 90.0) == null); Test.assert(detector.update(9000l, 90.0) == null);
    Test.assert(detector.update(10000l, 90.0) == null);
    Test.assert(detector.update(11000l, 89.0) == null); Test.assert(detector.update(12000l, 88.0) == null);
    var end = detector.update(13000l, 87.0) as Lang.Dictionary;
    Test.assertEqual(end["endAt"], 6000l); return true;
}

(:test)
function autoFilteredAscentRecoveryAndConfirmationReseed(logger) {
    var filter = new AltitudeFilter(); var detector = new AutoClimbDetector(1, 1);
    var starts = 0; var logicalStart = null;
    for (var i = 0; i < 10; i++) { Test.assert(detector.update(i*1000l, filter.update(i*1000l, 100.0)) == null); }
    for (var j = 10; j < 26; j++) {
        var event = detector.update(j*1000l, filter.update(j*1000l, 100.0 + (j-9)*0.5));
        if (event != null) { Test.assertEqual(event["kind"], "start"); starts++; logicalStart = event["startAt"]; }
    }
    Test.assertEqual(starts, 1); Test.assert(logicalStart >= 9000l);
    Test.assert(detector.update(26000l, filter.update(26000l, null)) == null);
    for (var k = 27; k < 32; k++) {
        Test.assert(detector.update(k*1000l, filter.update(k*1000l, k == 28 ? 140.0 : 110.0)) == null);
    }
    for (var n = 32; n < 37; n++) { Test.assert(detector.update(n*1000l, filter.update(n*1000l, 110.0)) == null); }
    var climb = new ClimbAttempt(1, C.AUTO, 9000l, 100.0, 0l, true, 14000l);
    climb.sample(40000l, 115.0, 120); Test.assert(detector.resumeFromClimb(climb, 41000l));
    Test.assertEqual(detector.rope.peakTimestamp, 40000l); DetectorTestHelpers.near(detector.rope.peakAltitude, 115.0);
    Test.assertEqual(detector.rope.descendingSamples, 0); return true;
}

(:test)
function autoPresetsAndStartWindowBound(logger) {
    var normal = new AutoClimbDetector(1, 1); var conservative = new AutoClimbDetector(0, 0); var sensitive = new AutoClimbDetector(2, 2);
    Test.assert(conservative.thresholds["confirmGain"] > normal.thresholds["confirmGain"]);
    Test.assert(sensitive.thresholds["minimumSlope"] < normal.thresholds["minimumSlope"]);
    normal.update(0l, 100.0);
    // Just above slope threshold still cannot exceed the bounded confirmation window.
    for (var i = 1; i <= 30; i++) { Test.assert(normal.update(i*1000l, 100.0 + i*0.13) == null); }
    normal.reset(); normal.update(0l, 100.0);
    for (var j = 1; j <= 8; j++) {
        var event = normal.update(j*1000l, 100.0 + j*0.3);
        if (event != null) { Test.assert(event["detectedAt"] - event["startAt"] <= AppConstants.AUTO_START_WINDOW_MS); return true; }
    }
    Test.assert(false); return false;
}
