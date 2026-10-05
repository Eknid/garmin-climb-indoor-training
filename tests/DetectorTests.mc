import Toybox.Test;
import Toybox.Lang;

(:test)
module DetectorTestHelpers {
    function near(actual, expected) { Test.assert(actual != null && (actual-expected).abs() < 0.001); }
}

(:test)
function altitudeMedianEmaAndSpike(logger) {
    var filter = new AltitudeFilter(); Test.assert(filter.update(0l, 10.0) == null);
    Test.assert(filter.update(1000l, 10.0) == null); Test.assert(filter.update(2000l, 100.0) == null);
    Test.assert(filter.update(3000l, 10.0) == null); DetectorTestHelpers.near(filter.update(4000l, 10.0), 10.0);
    DetectorTestHelpers.near(filter.update(5000l, 20.0), 10.0);
    DetectorTestHelpers.near(filter.update(6000l, 20.0), 13.5);
    DetectorTestHelpers.near(filter.update(7000l, 20.0), 15.775);
    return true;
}

(:test)
function altitudeNullGapAndReversedTime(logger) {
    var filter = new AltitudeFilter();
    for (var i = 0; i < 5; i++) { filter.update(i*1000l, 10.0); }
    Test.assert(filter.update(-1l, 20.0) == null); DetectorTestHelpers.near(filter.filteredAltitude, 10.0);
    Test.assert(filter.update(5000l, null) == null); Test.assert(filter.filteredAltitude == null);
    for (var j = 6; j < 10; j++) { Test.assert(filter.update(j*1000l, 40.0) == null); }
    DetectorTestHelpers.near(filter.update(10000l, 40.0), 40.0);
    for (var k = 14; k < 18; k++) { Test.assert(filter.update(k*1000l, 80.0) == null); }
    DetectorTestHelpers.near(filter.update(18000l, 80.0), 80.0);
    Test.assert(filter.update(17000l, 100.0) == null); DetectorTestHelpers.near(filter.filteredAltitude, 80.0);
    filter.reset(); Test.assert(filter.filteredAltitude == null);
    for (var n = 0; n < 4; n++) { Test.assert(filter.update(n*1000l, 2.0) == null); }
    DetectorTestHelpers.near(filter.update(4000l, 2.0), 2.0); return true;
}

(:test)
function ropeCleanAscentDescentAndLogicalPeak(logger) {
    var detector = new RopeEndDetector(1); detector.start(0l, 100.0);
    for (var i = 1; i <= 6; i++) { Test.assert(detector.update(i*1000l, 100.0+i) == null); }
    Test.assert(detector.armed); Test.assertEqual(detector.peakTimestamp, 6000l);
    Test.assert(detector.update(7000l, 106.0) == null);
    Test.assertEqual(detector.peakTimestamp, 6000l);
    Test.assert(detector.update(8000l, 105.0) == null);
    Test.assert(detector.update(9000l, 104.0) == null);
    var event = detector.update(10000l, 103.0) as Lang.Dictionary;
    Test.assert(event != null); Test.assertEqual(event["endAt"], 6000l);
    Test.assertEqual(event["detectedAt"], 10000l); Test.assert(detector.triggered);
    Test.assert(detector.update(11000l, 102.0) == null); return true;
}

(:test)
function ropeNoiseLowClimbSpikeAndRebound(logger) {
    var detector = new RopeEndDetector(1); detector.start(0l, 100.0);
    for (var i = 1; i <= 20; i++) {
        Test.assert(detector.update(i*1000l, 100.0 + (i%2)*0.3) == null);
    }
    Test.assert(!detector.armed);
    detector.start(0l, 100.0); detector.update(1000l, 104.0);
    Test.assert(detector.update(2000l, 90.0) == null);
    for (var j = 3; j <= 10; j++) { Test.assert(detector.update(j*1000l, 90.0) == null); }
    Test.assert(!detector.triggered);
    detector.start(0l, 100.0);
    for (var k = 1; k <= 6; k++) { detector.update(k*1000l, 100.0+k); }
    detector.update(7000l, 105.0); detector.update(8000l, 104.0);
    Test.assert(detector.update(9000l, 105.0) == null); Test.assertEqual(detector.descendingSamples, 0);
    Test.assert(detector.update(10000l, 104.0) == null);
    Test.assert(detector.update(11000l, 103.0) == null);
    Test.assert(detector.update(12000l, 102.0) != null); return true;
}

(:test)
function ropeMissingAndLongGapBreakContinuity(logger) {
    var detector = new RopeEndDetector(1); detector.start(0l, null);
    for (var i = 1; i <= 6; i++) { detector.update(i*1000l, 99.0+i); }
    detector.update(7000l, 104.0); detector.update(8000l, 103.0);
    Test.assert(detector.update(9000l, null) == null); Test.assert(detector.armed);
    Test.assertEqual(detector.descendingSamples, 0);
    Test.assert(detector.update(10000l, 100.0) == null);
    Test.assert(detector.update(11000l, 99.0) == null);
    Test.assert(detector.update(12000l, 98.0) == null);
    Test.assert(detector.update(13000l, 97.0) != null);
    detector.start(0l, 100.0); detector.update(1000l, 106.0);
    detector.update(2000l, 105.0); detector.update(3000l, 104.0);
    Test.assert(detector.update(10000l, 90.0) == null);
    Test.assert(detector.update(11000l, 90.0) == null);
    Test.assert(detector.update(12000l, 90.0) == null);
    Test.assert(detector.update(9000l, 80.0) == null);
    Test.assertEqual(detector.peakTimestamp, 1000l); Test.assert(!detector.triggered); return true;
}

(:test)
function ropePresetsAndMinimumDuration(logger) {
    var normal = new RopeEndDetector(1); var conservative = new RopeEndDetector(0); var sensitive = new RopeEndDetector(2);
    Test.assert(conservative.thresholds["armGain"] > normal.thresholds["armGain"]);
    Test.assert(sensitive.thresholds["endDrop"] < normal.thresholds["endDrop"]);
    normal.start(0l, 100.0); normal.update(1000l, 105.0);
    normal.update(2000l, 104.0); normal.update(3000l, 103.0);
    Test.assert(normal.update(4000l, 102.0) == null);
    Test.assert(normal.update(5000l, 101.0) == null);
    normal.update(6000l, 106.0); normal.update(7000l, 105.0); normal.update(8000l, 104.0);
    Test.assert(normal.update(9000l, 103.0) != null);
    return true;
}

(:test)
function automaticHeartRateStopsAtStrictPeak(logger) {
    var attempt = new ClimbAttempt(1, C.ROPE, 0l, 100.0, 0l, false, 0l);
    attempt.sample(1000l, 104.0, 100); attempt.sample(2000l, 106.0, 120);
    attempt.sample(3000l, 106.0, 180); attempt.sample(4000l, 105.0, 200);
    Test.assert(attempt.finish(2000l, 5000l, 103.0, C.AUTO_DESCENT));
    Test.assertEqual(attempt.heartRateSamples, 2); DetectorTestHelpers.near(attempt.avgHeartRate, 110.0);
    Test.assertEqual(attempt.maxHeartRate, 120); Test.assertEqual(attempt.peakTimestamp, 2000l);
    var manual = new ClimbAttempt(2, C.ROPE, 0l, 100.0, 0l, false, 0l);
    manual.sample(1000l, 104.0, 100); manual.sample(2000l, 103.0, 200);
    manual.finish(5000l, 5000l, 100.0, C.MANUAL);
    Test.assertEqual(manual.heartRateSamples, 2); DetectorTestHelpers.near(manual.avgHeartRate, 150.0);
    var missing = new ClimbAttempt(3, C.ROPE, 0l, 100.0, 0l, false, 0l);
    missing.sample(1000l, 105.0, 120); missing.sample(2000l, null, 130);
    Test.assert(missing.relativeAltitude == null); DetectorTestHelpers.near(missing.peakRelativeAltitude, 5.0);
    DetectorTestHelpers.near(missing.heightGain, 5.0); DetectorTestHelpers.near(missing.peakAltitude, 105.0); return true;
}

(:test)
function ropeStalledTrendCannotAgeIntoEnding(logger) {
    var detector = new RopeEndDetector(1); detector.start(0l, 100.0);
    for (var i = 1; i <= 6; i++) { detector.update(i*1000l, 100.0+i); }
    detector.update(7000l, 105.0); detector.update(8000l, 104.0);
    Test.assert(detector.update(9000l, 104.0) == null);
    Test.assert(detector.update(10000l, 104.0) == null);
    Test.assertEqual(detector.descendingSamples, 0); Test.assertEqual(detector.descentDurationMs, 0l);
    Test.assert(detector.update(11000l, 103.0) == null);
    Test.assertEqual(detector.descendingSamples, 1);
    Test.assert(detector.update(12000l, 102.0) == null);
    Test.assert(detector.update(13000l, 101.0) != null);
    return true;
}

(:test)
function specifiedConservativeTraceMatrix(logger) {
    var detector = new RopeEndDetector(1); detector.start(0l, 100.0);
    // Twenty-meter continuous ascent must never end itself.
    for (var i = 1; i <= 20; i++) { Test.assert(detector.update(i*1000l, 100.0+i) == null); }
    Test.assert(detector.update(21000l, 119.5) == null);
    Test.assert(detector.update(22000l, 120.0) == null);
    Test.assert(detector.update(23000l, 118.5) == null);
    Test.assert(detector.update(24000l, 120.0) == null);
    Test.assert(!detector.triggered);
    // A low ascent cannot arm even with four meters of later descent.
    detector.start(0l, 100.0);
    detector.update(1000l, 101.0); detector.update(2000l, 102.0);
    for (var j = 3; j <= 6; j++) { Test.assert(detector.update(j*1000l, 104.0-j) == null); }
    Test.assert(!detector.armed);
    // Noisy plateau and one brief three-meter low sample preserve the climb.
    detector.start(0l, 100.0);
    for (var k = 1; k <= 10; k++) { Test.assert(detector.update(k*1000l, 100.0+k) == null); }
    for (var n = 11; n <= 30; n++) {
        Test.assert(detector.update(n*1000l, n%2 == 0 ? 110.5 : 109.5) == null);
    }
    Test.assert(detector.update(31000l, 107.5) == null);
    Test.assert(detector.update(32000l, 110.5) == null);
    Test.assert(!detector.triggered); return true;
}

(:test)
function confirmationReseedsStrictPeakWithoutStaleTrend(logger) {
    var climb = new ClimbAttempt(1, C.ROPE, 0l, 100.0, 0l, false, 0l);
    var detector = new RopeEndDetector(1); detector.start(0l, 100.0);
    for (var i = 1; i <= 6; i++) {
        climb.sample(i*1000l, 100.0+i, 100); detector.update(i*1000l, 100.0+i);
    }
    // The model sees a new peak while a confirmation view suppresses detection.
    climb.sample(7000l, 109.0, 120); climb.sample(8000l, 108.0, 130);
    Test.assert(detector.resumeFromClimb(climb, 8000l));
    Test.assertEqual(detector.peakTimestamp, 7000l); DetectorTestHelpers.near(detector.peakAltitude, 109.0);
    Test.assertEqual(detector.descendingSamples, 0);
    Test.assert(detector.update(9000l, 107.0) == null);
    Test.assert(detector.update(10000l, 106.0) == null);
    Test.assert(detector.update(11000l, 105.0) == null);
    var event = detector.update(12000l, 104.0) as Lang.Dictionary;
    Test.assert(event != null); Test.assertEqual(event["endAt"], 7000l);
    return true;
}

(:test)
function filteredRecoverySpikesNeverManufactureDescent(logger) {
    for (var spikeIndex = 0; spikeIndex < 5; spikeIndex++) {
        var filter = new AltitudeFilter(); var detector = new RopeEndDetector(1);
        for (var i = 0; i < 5; i++) { filter.update(i*1000l, 100.0); }
        detector.start(4000l, filter.filteredAltitude);
        for (var j = 5; j <= 24; j++) {
            Test.assert(detector.update(j*1000l, filter.update(j*1000l, 96.0+j)) == null);
        }
        Test.assert(detector.armed);
        Test.assert(detector.update(25000l, filter.update(25000l, null)) == null);
        for (var k = 0; k < 5; k++) {
            var now = 26000l + k*1000l;
            var filtered = filter.update(now, k == spikeIndex ? 140.0 : 110.0);
            if (k < 4) { Test.assert(filtered == null); }
            else { DetectorTestHelpers.near(filtered, 110.0); }
            Test.assert(detector.update(now, filtered) == null);
        }
        for (var n = 31; n <= 36; n++) {
            Test.assert(detector.update(n*1000l, filter.update(n*1000l, 110.0)) == null);
        }
        Test.assert(!detector.triggered);
    }
    return true;
}
