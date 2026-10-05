import Toybox.Lang;

// Experimental altitude-only classification. The primary session owns commits.
class AutoClimbDetector {
    var state = "WATCHING"; var rope as RopeEndDetector;
    var thresholds as Lang.Dictionary;
    var baselineAltitude = null; var candidateStartTimestamp = null;
    var candidateStartAltitude = null; var candidateGain = 0.0; var upwardSlope = null;
    var _previousAltitude = null; var _previousTimestamp = null; var _lastInputTimestamp = null;
    var _riseAt = null; var _riseAltitude = null; var _upwardSamples = 0; var _lastUpwardTimestamp = null;
    function initialize(startPreset, endPreset) {
        thresholds = presetThresholds(startPreset); rope = new RopeEndDetector(endPreset);
    }
    function presetThresholds(preset) as Lang.Dictionary {
        if (preset == 0) {
            return {"candidateGain"=>AppConstants.AUTO_CONSERVATIVE_CANDIDATE_M,
                "confirmGain"=>AppConstants.AUTO_CONSERVATIVE_CONFIRM_M,
                "minimumSlope"=>AppConstants.AUTO_CONSERVATIVE_SLOPE_MPS};
        }
        if (preset == 2) {
            return {"candidateGain"=>AppConstants.AUTO_SENSITIVE_CANDIDATE_M,
                "confirmGain"=>AppConstants.AUTO_SENSITIVE_CONFIRM_M,
                "minimumSlope"=>AppConstants.AUTO_SENSITIVE_SLOPE_MPS};
        }
        return {"candidateGain"=>AppConstants.AUTO_CANDIDATE_GAIN_M,
            "confirmGain"=>AppConstants.AUTO_CONFIRM_GAIN_M,
            "minimumSlope"=>AppConstants.AUTO_MIN_UPWARD_SLOPE_MPS};
    }
    function clearCandidate() {
        candidateStartTimestamp = null; candidateStartAltitude = null; candidateGain = 0.0;
        _riseAt = null; _riseAltitude = null; _upwardSamples = 0; _lastUpwardTimestamp = null;
    }
    function reset() {
        state = "WATCHING"; baselineAltitude = null; clearCandidate(); upwardSlope = null;
        _previousAltitude = null; _previousTimestamp = null; _lastInputTimestamp = null; rope.reset();
    }
    function breakTrend() {
        clearCandidate(); upwardSlope = null; _previousAltitude = null; _previousTimestamp = null;
        if (state.equals("CLIMBING") || state.equals("POSSIBLE_END")) { state = "CLIMBING"; rope.breakTrend(); }
        else { state = "WATCHING"; baselineAltitude = null; }
    }
    function beginManual(now, altitude) {
        if (now < 0 || (_lastInputTimestamp != null && now < _lastInputTimestamp)) { return false; }
        reset(); state = "CLIMBING"; baselineAltitude = altitude; _lastInputTimestamp = now;
        return rope.start(now, altitude);
    }
    function resumeFromClimb(climb as ClimbAttempt, now) {
        if (_lastInputTimestamp != null && now < _lastInputTimestamp) { return false; }
        if (!rope.resumeFromClimb(climb, now)) { return false; }
        state = "CLIMBING"; baselineAltitude = climb.startAltitude; clearCandidate();
        upwardSlope = null; _previousAltitude = null; _previousTimestamp = null; _lastInputTimestamp = now;
        return true;
    }
    function update(now, altitude) as Lang.Dictionary or Null {
        if (now < 0 || (_lastInputTimestamp != null && now <= _lastInputTimestamp)) { return null; }
        var gap = _lastInputTimestamp != null && now - _lastInputTimestamp > AppConstants.SENSOR_GAP_MS;
        _lastInputTimestamp = now;
        if (altitude == null) { breakTrend(); return null; }
        if (gap) { breakTrend(); }
        if (state.equals("CLIMBING") || state.equals("POSSIBLE_END")) {
            var ending = rope.update(now, altitude);
            state = rope.descendingSamples > 0 ? "POSSIBLE_END" : "CLIMBING";
            if (ending != null) {
                return {"kind"=>"end", "endAt"=>ending["endAt"], "detectedAt"=>ending["detectedAt"], "peakAltitude"=>ending["peakAltitude"]};
            }
            return null;
        }
        if (baselineAltitude == null || _previousAltitude == null) {
            baselineAltitude = altitude; _previousAltitude = altitude; _previousTimestamp = now; return null;
        }
        var change = altitude - _previousAltitude;
        upwardSlope = change / ((now - _previousTimestamp).toFloat() / 1000.0);
        if ((_riseAt != null && now - _riseAt > AppConstants.AUTO_START_WINDOW_MS) ||
            (_lastUpwardTimestamp != null && now - _lastUpwardTimestamp > AppConstants.AUTO_MAX_UPWARD_STALL_MS) ||
            change < -AppConstants.AUTO_CANCEL_DROP_M) {
            clearCandidate(); state = "WATCHING";
        }
        if (upwardSlope >= thresholds["minimumSlope"]) {
            if (_riseAt == null) { _riseAt = _previousTimestamp; _riseAltitude = _previousAltitude; }
            _upwardSamples++; _lastUpwardTimestamp = now;
        }
        if (_riseAt != null) { candidateGain = altitude - _riseAltitude; }
        if (state.equals("WATCHING") && _riseAt != null && candidateGain >= thresholds["candidateGain"] && _upwardSamples >= AppConstants.AUTO_MIN_UPWARD_SAMPLES) {
            state = "POSSIBLE_START"; candidateStartTimestamp = now; candidateStartAltitude = altitude;
        }
        if (state.equals("POSSIBLE_START") && candidateGain >= thresholds["confirmGain"] &&
            now > candidateStartTimestamp &&
            upwardSlope >= thresholds["minimumSlope"] && _upwardSamples >= AppConstants.AUTO_MIN_UPWARD_SAMPLES) {
            var startAt = candidateStartTimestamp; var startAltitude = candidateStartAltitude;
            state = "CLIMBING"; baselineAltitude = startAltitude;
            rope.start(startAt, startAltitude); rope.update(now, altitude);
            _previousAltitude = altitude; _previousTimestamp = now;
            return {"kind"=>"start", "startAt"=>startAt, "detectedAt"=>now, "startAltitude"=>startAltitude};
        }
        if (state.equals("WATCHING") && _riseAt == null) {
            baselineAltitude += AppConstants.AUTO_BASELINE_ALPHA * (altitude - baselineAltitude);
        }
        _previousAltitude = altitude; _previousTimestamp = now; return null;
    }
}
