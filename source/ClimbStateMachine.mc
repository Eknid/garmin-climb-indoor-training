class ClimbStateMachine {
    var state = C.PRE_START; var currentMode; var session as SessionController; var lastClimb as ClimbAttempt or Null = null; var summaryUntil = null;
    function initialize(mode) { currentMode = C.isMode(mode) ? mode : C.ROPE; session = new SessionController(); }
    function start(now) { if (state != C.PRE_START || !session.start(now)) { return false; } state = C.RESTING; return true; }
    function changeMode(mode) { if ((state != C.PRE_START && state != C.RESTING) || !C.isMode(mode)) { return false; } currentMode = mode; return true; }
    function beginClimb(now, alt, autoStarted, detectedAt) {
        if (state != C.RESTING || !session.beginClimb(now, alt, currentMode, autoStarted, detectedAt)) { return false; }
        state = C.CLIMBING; return true;
    }
    function finishClimb(endAt, detectedAt, alt, reason) {
        if (state != C.CLIMBING && state != C.END_MENU) { return null; }
        var result = session.finishClimb(endAt, detectedAt, alt, reason);
        if (result != null) { lastClimb = result; summaryUntil = detectedAt + AppConstants.SUMMARY_DURATION_MS; state = C.CLIMB_SUMMARY; }
        return result;
    }
    function back(now, alt) {
        if (state == C.RESTING) { beginClimb(now, alt, false, now); }
        else if (state == C.CLIMBING) { return finishClimb(now, now, alt, C.MANUAL); }
        else if (state == C.CLIMB_SUMMARY && session.acceptTime(now)) { state = C.RESTING; summaryUntil = null; }
        return null;
    }
    function requestPause() { if (state != C.CLIMBING) { return false; } state = C.END_MENU; return true; }
    function cancelPause() { if (state != C.END_MENU) { return false; } state = C.CLIMBING; return true; }
    function pause(now, alt) {
        if (state != C.RESTING && state != C.CLIMB_SUMMARY && state != C.CLIMBING && state != C.END_MENU) { return null; }
        if (!session.acceptTime(now)) { return null; }
        var result = null;
        if (state == C.CLIMBING || state == C.END_MENU) { result = finishClimb(now, now, alt, C.SESSION_STOP); }
        if (session.pause(now)) { state = C.PAUSED; summaryUntil = null; }
        return result;
    }
    function resume(now) { if (state != C.PAUSED || !session.resume(now)) { return false; } state = C.RESTING; return true; }
    function save(now) { if (state != C.PAUSED || !session.save(now)) { return false; } state = C.SESSION_SUMMARY; return true; }
    function tick(now) { if (state == C.CLIMB_SUMMARY && now >= summaryUntil && session.acceptTime(now)) { state = C.RESTING; summaryUntil = null; } }
}
