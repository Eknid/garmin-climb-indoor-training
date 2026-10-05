module C {
    const ROPE = 1; const BOULDER = 2; const AUTO = 3;
    const PRE_START = 0; const RESTING = 1; const CLIMBING = 2;
    const CLIMB_SUMMARY = 3; const PAUSED = 4; const SESSION_SUMMARY = 5; const END_MENU = 6;
    const MANUAL = 1; const AUTO_DESCENT = 2; const AUTO_FULL = 3; const SESSION_STOP = 4; const CANCELLED = 5;
    function isMode(mode) { return mode == ROPE || mode == BOULDER || mode == AUTO; }
}
