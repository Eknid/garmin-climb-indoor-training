import Toybox.Test;
import Toybox.Lang;

(:test)
function openingBackExitsWithoutRecording(logger) {
    var c = new ManualTestController(); c.back();
    Test.assert(c.exited); Test.assertEqual(c.recorder.starts, 0);
    Test.assert(c.recorder.session == null); Test.assert(!c.store.saved);
    return true;
}

(:test)
function outcomeWaitsForChoiceAndCountsShortFailure(logger) {
    var c = new ManualTestController(); c.changeMode(C.BOULDER); c.select(); c.back();
    c.clock.timestamp += 1000l; c.back();
    Test.assert(c.pendingOutcome != null); Test.assertEqual(c.recorder.laps, 0);
    Test.assertEqual(c.store.attempts.size(), 0);
    c.clock.timestamp += 30000l; c.tick(); c.back();
    Test.assertEqual(c.sm.state, C.CLIMB_SUMMARY); Test.assert(c.pendingOutcome != null);
    c.nextPage(); Test.assertEqual(c.outcomeSelection, 2); c.select();
    Test.assert(c.pendingOutcome == null); Test.assertEqual(c.recorder.laps, 1);
    var stored = c.store.attempts as Lang.Array;
    Test.assertEqual(stored[0].outcome, 2);
    Test.assert(!c.resolveOutcome(1)); Test.assertEqual(c.recorder.laps, 1);
    Test.assertEqual(c.statistics()["failures"], 1);
    Test.assertEqual(c.statistics()["boulderFailures"], 1);
    Test.assertEqual(c.statistics()["successPercent"], 0.0);
    c.back(); c.select(); c.discard(); return true;
}

(:test)
function pauseFinishesResultBeforeStoppingRecording(logger) {
    var c = new ManualTestController(); c.select(); c.back(); c.clock.timestamp += 5000l;
    c.select(); Test.assert(c.confirmPause());
    Test.assert(c.recorder.running); Test.assert(c.pendingOutcome != null);
    Test.assert(!c.save()); Test.assert(!c.discard());
    Test.assertEqual(c.select(), "pauseMenu");
    Test.assertEqual(c.sm.state, C.PAUSED); Test.assert(!c.recorder.running);
    Test.assertEqual(c.recorder.laps, 1); Test.assertEqual(c.statistics()["successes"], 1);
    Test.assert(c.save()); Test.assert(c.store.saved); return true;
}

(:test)
function forcedExitPreservesUnratedWithoutGuessingFailure(logger) {
    var c = new ManualTestController(); c.select(); c.back(); c.clock.timestamp += 5000l;
    c.back(); Test.assert(c.pendingOutcome != null); c.shutdown();
    Test.assertEqual(c.recorder.laps, 1); Test.assert(c.store.saved);
    Test.assertEqual(c.statistics()["unrated"], 1);
    Test.assertEqual(c.statistics()["failures"], 0);
    Test.assert(c.statistics()["successPercent"] == null); return true;
}

(:test)
function outcomeFitBreakdownAndLapRetry(logger) {
    var domain = new SessionController(); domain.start(0l);
    var fit = new FakeFitRecorder(); Test.assert(fit.startSession());
    for (var i = 1; i <= 3; i++) {
        domain.beginClimb(i * 10000l, null, i, false, i * 10000l);
        var attempt = domain.finishClimb(i * 10000l + 1000l, i * 10000l + 1000l, null, C.MANUAL);
        attempt.outcome = i == 2 ? 2 : 1;
        fit.backend.failLaps = i == 2;
        var recorded = fit.addClimb(attempt);
        if (i == 2) {
            Test.assert(!recorded); Test.assertEqual(fit.pendingCount(), 1);
            fit.backend.failLaps = false; Test.assert(fit.flushPending());
        } else { Test.assert(recorded); }
    }
    Test.assertEqual(fit.backend.laps.size(), 3);
    var failed = fit.backend.laps[1] as Lang.Dictionary; var succeeded = fit.backend.laps[0] as Lang.Dictionary;
    Test.assertEqual(failed[FitSchema.CLIMB_FAILURE], 1);
    Test.assertEqual(succeeded[FitSchema.CLIMB_SUCCESS], 1);
    var stats = SessionStats.calculate(domain, 31000l);
    Test.assertEqual(stats["successes"], 2); Test.assertEqual(stats["failures"], 1);
    Test.assertEqual(stats["successPercent"], 200.0 / 3);
    Test.assert(fit.updateSummary(stats)); Test.assert(fit.saveSession());
    Test.assertEqual(fit.backend.saved[FitSchema.SUCCESSES], 2);
    Test.assertEqual(fit.backend.saved[FitSchema.BOULDER_RESULTS].equals("0 / 1"), true);
    Test.assertEqual(fit.backend.saved[FitSchema.AUTO_RESULTS].equals("1 / 0"), true);
    Test.assertEqual(fit.backend.saved[FitSchema.CLIMB_SUCCESS], 0);
    Test.assertEqual(fit.backend.saved[FitSchema.CLIMB_FAILURE], 0);
    return true;
}

(:test)
function pageDotsTrackPagesAndResultChoices(logger) {
    var widths = [260, 280, 416, 454];
    for (var i = 0; i < widths.size(); i++) {
        var c = new ManualTestController(); var view = new ClimbView(c); var dc = new ViewTestDc(widths[i]);
        view.drawPage(dc); Test.assertEqual(dc.circles.size(), 0);
        Test.assert(dc.contains("INDOOR TRAINING"));
        c.select();
        for (var p = 0; p < 3; p++) {
            view.drawPage(dc); Test.assertEqual(dc.circles.size(), 3);
            Test.assert(dc.circles[p]); c.nextPage();
        }
        c.back(); view.drawPage(dc); Test.assertEqual(dc.circles.size(), 2);
        c.clock.timestamp += 5000l; c.back(); view.drawPage(dc);
        Test.assert(dc.contains("Attempt result")); Test.assert(dc.contains("> Success"));
        c.previousPage(); view.drawPage(dc); Test.assert(dc.contains("> Failed"));
        c.select(); c.back(); c.select(); c.save(); c.page = 2; view.drawPage(dc);
        Test.assert(dc.contains("RESULTS")); Test.assert(dc.contains("0%"));
        Test.assertEqual(dc.circles.size(), 3);
    }
    return true;
}
