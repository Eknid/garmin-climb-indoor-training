import Toybox.Test;
import Toybox.System;

(:test)
function controllerNativeMixedAcceptance(logger) {
    var c = new ManualTestController(); c.recorder = new FitRecorder();
    var timing = new NativeFitTiming(); var trace = new ControllerTrace(c);
    try {
        c.select(); Test.assertEqual(c.sm.state, C.RESTING);
        trace.flat(100.0, 8); c.back(); c.resolveOutcome(1);
        for (var i = 1; i <= 20; i++) { trace.feed(100.0 + i * 0.5, 140); }
        timing.waitMilliseconds(2100); c.back(); c.resolveOutcome(1);
        Test.assertEqual(c.sm.lastClimb.mode, C.ROPE); c.back(); c.resolveOutcome(1);
        Test.assert(c.changeMode(C.BOULDER)); c.back(); c.resolveOutcome(1); trace.flat(null, 5);
        timing.waitMilliseconds(2100); c.back(); c.resolveOutcome(1);
        Test.assertEqual(c.sm.lastClimb.mode, C.BOULDER); c.back(); c.resolveOutcome(1);
        Test.assert(c.changeMode(C.AUTO)); trace.flat(100.0, 12);
        for (var a = 1; a <= 24; a++) { trace.feed(100.0 + a * 0.5, 150); }
        Test.assertEqual(c.sm.state, C.CLIMBING);
        Test.assert(c.sm.session.currentClimb.wasAutoStarted);
        trace.flat(112.0, 8); timing.waitMilliseconds(2100);
        for (var d = 1; d <= 20 && c.sm.state == C.CLIMBING; d++) { trace.feed(112.0 - d * 0.8, 130); }
        Test.assertEqual(c.sm.state, C.CLIMB_SUMMARY);
        Test.assertEqual(c.sm.lastClimb.endReason, C.AUTO_FULL); c.resolveOutcome(1); c.back(); c.resolveOutcome(1);
        c.select(); Test.assertEqual(c.sm.state, C.PAUSED);
        c.clock.timestamp += 6000l; Test.assert(c.resume()); trace.flat(100.0, 5);
        c.select(); timing.waitMilliseconds(2100); Test.assert(c.save());
        var stats = c.statistics();
        Test.assertEqual(stats["totalClimbs"], 3);
        Test.assertEqual(stats["ropeClimbs"], 1); Test.assertEqual(stats["boulderClimbs"], 1);
        Test.assertEqual(stats["autoClimbs"], 1); Test.assert(c.recorder.session == null);
        Test.assert(!c._timerRunning); Test.assert(!c.sensors.enabled);
        logger.debug("Mixed controller acceptance saved three real FIT climb laps; memory=" + System.getSystemStats().usedMemory);
    } catch (ex) { c.recorder.discardSession(); throw ex; }
    return true;
}
