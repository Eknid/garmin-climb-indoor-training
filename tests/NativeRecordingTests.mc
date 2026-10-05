import Toybox.Test;
import Toybox.System;

(:test)
class NativeFitTiming {
    // Test-only pacing: this simulator rejects repeated same-second lap events.
    function waitMilliseconds(milliseconds) {
        var start = System.getTimer().toLong();
        var elapsed = 0l;
        while (elapsed < milliseconds) {
            elapsed = System.getTimer().toLong() - start;
            if (elapsed < 0) { elapsed += 4294967296l; }
        }
    }
}

(:test)
function nativeRecordingLifecycle(logger) {
    var fit = new FitRecorder();
    var timing = new NativeFitTiming(); timing.waitMilliseconds(2100);
    try {
    Test.assert(fit.startSession()); Test.assert(fit.session != null); Test.assert(fit.session.isRecording());
    var nativeSession = fit.session;
    Test.assert(fit.pauseSession()); Test.assert(!fit.session.isRecording());
    Test.assert(fit.resumeSession()); Test.assert(fit.session == nativeSession);
    nativeSession = null;
    var attempt = new ClimbAttempt(1, C.BOULDER, 0l, null, 0l, false, 0l);
    Test.assert(attempt.finish(5000l, 5000l, null, C.MANUAL));
    Test.assert(fit.addClimb(attempt));
    var domain = new SessionController(); domain.start(0l);
    domain.beginClimb(0l, null, C.BOULDER, false, 0l); domain.finishClimb(5000l, 5000l, null, C.MANUAL);
    Test.assert(fit.updateSummary(SessionStats.calculate(domain, 5000l)));
    Test.assert(fit.saveSession()); Test.assert(fit.session == null);
    timing.waitMilliseconds(2100);
    Test.assert(fit.startSession()); Test.assert(fit.discardSession()); Test.assert(fit.session == null);
    } catch (ex) { fit.discardSession(); throw ex; }
    return true;
}

// Run this test alone immediately before exporting the simulator's last FIT.
(:test)
function nativeFitMixedFixture(logger) {
    var fit = new FitRecorder(); var domain = new SessionController(); domain.start(0l);
    var timing = new NativeFitTiming();
    // Close any native session stranded by an earlier failed fixture, then
    // recreate fields against a fresh session. createSession returns the open
    // session if one already exists (official SDK contract).
    try {
    fit.session = fit.createNativeSession(); Test.assert(fit.discardSession());
    timing.waitMilliseconds(2100);
    Test.assert(fit.startSession());
    timing.waitMilliseconds(2100);
    domain.beginClimb(2000l, 100.0, C.ROPE, false, 2000l);
    domain.sample(5000l, 110.0, 120); domain.sample(10000l, 115.0, 160);
    var attempt = domain.finishClimb(14500l, 14500l, 114.0, C.MANUAL); attempt.outcome = 1; Test.assert(fit.addClimb(attempt));
    timing.waitMilliseconds(2100);
    domain.beginClimb(20000l, null, C.BOULDER, false, 20000l);
    attempt = domain.finishClimb(24000l, 24000l, null, C.MANUAL); attempt.outcome = 2; Test.assert(fit.addClimb(attempt));
    // A mid-workout native stop/resume must not duplicate climb metadata.
    Test.assert(domain.pause(24000l)); Test.assert(fit.pauseSession());
    timing.waitMilliseconds(2100);
    Test.assert(domain.resume(30000l)); Test.assert(fit.resumeSession());
    domain.beginClimb(36000l, 100.0, C.AUTO, true, 38000l);
    domain.sample(41000l, 108.0, 150); domain.sample(44000l, 112.0, 170);
    domain.sample(46000l, 109.0, 180);
    timing.waitMilliseconds(2100);
    attempt = domain.finishClimb(44000l, 48000l, 108.0, C.AUTO_FULL); attempt.outcome = 1; Test.assert(fit.addClimb(attempt));
    timing.waitMilliseconds(2100);
    domain.pause(51000l); Test.assert(fit.pauseSession());
    Test.assert(fit.updateSummary(SessionStats.calculate(domain, 51000l)));
    Test.assert(fit.saveSession()); Test.assert(fit.session == null);
    } catch (ex) {
        logger.error("Native fixture failed: " + fit.error);
        fit.discardSession(); throw ex;
    }
    logger.debug("Export last FIT: modes 1,2,3; heights 15,-1,12; durations 12.5,4,8; rests 2,5.5,6; total 3/27m.");
    return true;
}
