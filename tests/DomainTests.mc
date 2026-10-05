import Toybox.Test;
import Toybox.Lang;
import Toybox.System;

(:test)
function manualStateTransitions(logger) {
    var sm = new ClimbStateMachine(C.ROPE);
    Test.assertEqual(sm.state, C.PRE_START);
    Test.assert(!sm.resume(0l)); Test.assert(!sm.save(0l));
    Test.assert(sm.back(0l, null) == null);
    Test.assert(sm.start(1000l)); Test.assert(!sm.start(1000l));
    Test.assert(sm.changeMode(C.BOULDER)); Test.assert(!sm.changeMode(99));
    sm.back(2000l, null); Test.assertEqual(sm.state, C.CLIMBING);
    Test.assert(!sm.changeMode(C.ROPE)); Test.assert(!sm.save(3000l));
    Test.assert(sm.requestPause()); Test.assertEqual(sm.state, C.END_MENU);
    Test.assert(sm.back(3000l, null) == null); Test.assert(!sm.requestPause());
    Test.assert(sm.cancelPause()); Test.assert(!sm.cancelPause());
    var climb = sm.back(6000l, null);
    Test.assert(climb.valid); Test.assertEqual(climb.mode, C.BOULDER);
    Test.assertEqual(sm.state, C.CLIMB_SUMMARY);
    sm.tick(9999l); Test.assertEqual(sm.state, C.CLIMB_SUMMARY);
    sm.tick(10000l); Test.assertEqual(sm.state, C.RESTING);
    sm.pause(11000l, null); Test.assertEqual(sm.state, C.PAUSED);
    Test.assert(!sm.changeMode(C.AUTO)); Test.assert(sm.resume(16000l));
    sm.back(17000l, 10.0); Test.assert(sm.requestPause());
    climb = sm.pause(21000l, 12.0);
    Test.assertEqual(climb.endReason, C.SESSION_STOP); Test.assertEqual(sm.state, C.PAUSED);
    Test.assert(sm.save(22000l)); Test.assert(!sm.resume(23000l));
    Test.assertEqual(sm.state, C.SESSION_SUMMARY);
    return true;
}

(:test)
function mixedModesPausesHeartRateAndRest(logger) {
    var sm = new ClimbStateMachine(C.ROPE); sm.start(0l);
    sm.back(1000l, 100.0); sm.session.sample(2000l, 102.0, 120);
    sm.session.sample(3000l, 105.0, 160); var first = sm.back(5000l, 104.0);
    Test.assertEqual(first.restBeforeMs, 1000l); Test.assertEqual(first.heightGain, 5.0);
    Test.assertEqual(first.avgHeartRate, 140.0); Test.assertEqual(first.maxHeartRate, 160);
    sm.back(5000l, null); sm.pause(6000l, null); sm.resume(16000l);
    Test.assert(sm.changeMode(C.BOULDER)); sm.back(17000l, null);
    var second = sm.back(21000l, null);
    Test.assert(second.valid); Test.assert(second.avgHeartRate == null);
    Test.assert(second.heightGain == null); Test.assertEqual(second.restBeforeMs, 2000l);
    var stats = SessionStats.calculate(sm.session, 21000l);
    Test.assertEqual(stats["totalClimbs"], 2); Test.assertEqual(stats["ropeClimbs"], 1);
    Test.assertEqual(stats["boulderClimbs"], 1); Test.assertEqual(stats["autoClimbs"], 0);
    Test.assertEqual(stats["totalClimbingTime"], 8000l); Test.assertEqual(stats["elapsedMs"], 11000l);
    Test.assertEqual(stats["totalRestTime"], 3000l); Test.assertEqual(stats["averageHeartRate"], 140.0);
    Test.assertEqual(stats["maxHeartRate"], 160); Test.assertEqual(stats["totalVerticalGain"], 5.0);
    var storedSecond = second.toDictionary() as Lang.Dictionary;
    Test.assertEqual(storedSecond["mode"], C.BOULDER);
    sm.back(21000l, null); sm.session.sample(22000l, null, 100);
    var restingStats = SessionStats.calculate(sm.session, 22000l) as Lang.Dictionary;
    Test.assertEqual(restingStats["averageHeartRate"], 380.0 / 3);
    return true;
}

(:test)
function falseStartsAndTimeReversal(logger) {
    var sm = new ClimbStateMachine(C.ROPE); Test.assert(!sm.start(-1l)); sm.start(0l);
    sm.back(1000l, null); var cancelled = sm.back(1000l, null);
    Test.assert(!cancelled.valid); Test.assertEqual(cancelled.endReason, C.CANCELLED);
    Test.assertEqual(SessionStats.calculate(sm.session, 2000l)["totalClimbs"], 0);
    sm.back(2000l, null); sm.back(3000l, 10.0);
    Test.assertEqual(sm.session.currentClimb.restBeforeMs, 3000l);
    Test.assert(sm.back(2500l, 20.0) == null); Test.assertEqual(sm.state, C.CLIMBING);
    Test.assert(!sm.session.sample(2500l, 100.0, 200));
    var shortHigh = sm.back(4000l, 11.0); Test.assert(shortHigh.valid);
    sm.back(4000l, null); sm.back(5000l, null);
    var lowLong = sm.back(8000l, null); Test.assert(lowLong.valid);
    Test.assertEqual(lowLong.durationMs, 3000l);
    return true;
}

(:test)
function boundedHistoryAndHundredClimbs(logger) {
    var sm = new ClimbStateMachine(C.ROPE); sm.start(0l); var now = 0l;
    for (var i = 0; i < AppConstants.MAX_HISTORY; i++) {
        Test.assert(sm.session.canStartClimb());
        Test.assert(sm.beginClimb(now, null, false, now)); now += 3000l;
        var attempt = sm.finishClimb(now, now, null, C.MANUAL); Test.assert(attempt.valid);
        sm.back(now, null);
        if (i == 99) {
            Test.assertEqual(SessionStats.calculate(sm.session, now)["totalClimbs"], 100);
            logger.debug("History 100 usedMemory=" + System.getSystemStats().usedMemory);
        }
    }
    logger.debug("History 256 usedMemory=" + System.getSystemStats().usedMemory);
    Test.assert(!sm.session.canStartClimb()); Test.assert(!sm.beginClimb(now, null, false, now));
    Test.assertEqual(sm.state, C.RESTING); Test.assertEqual(sm.session.climbs.size(), AppConstants.MAX_HISTORY);
    var cancelledMachine = new ClimbStateMachine(C.ROPE); cancelledMachine.start(0l); now = 0l;
    for (var j = 0; j < AppConstants.MAX_HISTORY; j++) {
        cancelledMachine.back(now, null);
        var cancelled = cancelledMachine.back(now, null); Test.assert(!cancelled.valid);
        cancelledMachine.back(now, null);
    }
    Test.assert(!cancelledMachine.session.canStartClimb());
    Test.assertEqual(SessionStats.calculate(cancelledMachine.session, now)["totalClimbs"], 0);
    return true;
}

(:test)
function automaticLogicalTimesAndSummaryPause(logger) {
    var sm = new ClimbStateMachine(C.AUTO); sm.start(0l);
    Test.assert(sm.beginClimb(1000l, 10.0, true, 3000l));
    sm.session.sample(5000l, 20.0, null);
    var climb = sm.finishClimb(5000l, 8000l, 15.0, C.AUTO_FULL);
    Test.assertEqual(climb.durationMs, 4000l); Test.assertEqual(climb.detectionEndTimestamp, 8000l);
    Test.assert(climb.wasAutoStarted); Test.assert(climb.wasAutoEnded);
    sm.pause(9000l, null); Test.assertEqual(sm.state, C.PAUSED);
    sm.resume(10000l); Test.assertEqual(sm.session.restMs(10000l), 4000l);
    Test.assertEqual(SessionStats.calculate(sm.session, 10000l)["autoClimbs"], 1);
    return true;
}

(:test)
function invalidTransitionsAreIgnored(logger) {
    var sm = new ClimbStateMachine(C.ROPE);
    Test.assert(!sm.session.canStartClimb());
    Test.assert(!sm.session.sample(999999l, null, 100));
    Test.assert(!sm.requestPause()); Test.assert(!sm.cancelPause());
    Test.assert(sm.pause(0l, null) == null); Test.assertEqual(sm.state, C.PRE_START);
    Test.assert(sm.finishClimb(0l, 0l, null, C.MANUAL) == null);
    sm.start(0l);
    Test.assert(!sm.resume(1l)); Test.assert(!sm.requestPause()); Test.assert(!sm.save(1l));
    Test.assert(sm.beginClimb(1000l, null, false, 1000l));
    Test.assert(!sm.beginClimb(2000l, null, false, 2000l));
    Test.assert(sm.finishClimb(500l, 3000l, null, C.MANUAL) == null);
    Test.assertEqual(sm.state, C.CLIMBING);
    Test.assertEqual(sm.session.climbs.size(), 0);
    sm.finishClimb(5000l, 5000l, null, C.MANUAL);
    Test.assert(!sm.changeMode(C.AUTO)); Test.assert(!sm.requestPause());
    Test.assert(!sm.cancelPause()); Test.assert(!sm.resume(6000l)); Test.assert(!sm.save(6000l));
    sm.back(6000l, null); Test.assertEqual(sm.state, C.RESTING);
    sm.pause(7000l, null);
    Test.assert(!sm.session.sample(999999l, null, 100));
    Test.assert(sm.back(8000l, null) == null); Test.assert(!sm.beginClimb(8000l, null, false, 8000l));
    Test.assert(!sm.start(8000l)); Test.assert(!sm.requestPause()); Test.assert(!sm.cancelPause());
    sm.pause(8000l, null); Test.assertEqual(sm.state, C.PAUSED);
    Test.assert(!sm.resume(6000l)); Test.assert(sm.save(9000l));
    Test.assert(!sm.start(10000l)); Test.assert(!sm.save(10000l)); Test.assert(!sm.changeMode(C.AUTO));
    Test.assert(!sm.beginClimb(10000l, null, false, 10000l));
    sm.tick(20000l); Test.assertEqual(sm.state, C.SESSION_SUMMARY);
    return true;
}
