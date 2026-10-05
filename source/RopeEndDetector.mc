import Toybox.Lang;

class RopeEndDetector {
    var armed = false; var baselineAltitude = null; var peakAltitude = null;
    var peakTimestamp = null; var relativeAltitude = null; var peakRelativeAltitude = 0.0;
    var descendingSamples = 0; var descentDurationMs = 0l; var triggered = false;
    var thresholds as Lang.Dictionary;
    var _startTimestamp = null; var _lastTimestamp = null; var _previousAltitude = null;
    var _descentAt = null; var _lastInputTimestamp = null;
    var _lastDescentTimestamp = null;
    function initialize(preset) { thresholds = presetThresholds(preset); }
    function presetThresholds(preset) as Lang.Dictionary {
        if (preset == 0) {
            return {"armGain"=>AppConstants.ROPE_CONSERVATIVE_ARM_GAIN_M,
                "endDrop"=>AppConstants.ROPE_CONSERVATIVE_DROP_M,
                "descentMs"=>AppConstants.ROPE_CONSERVATIVE_DESCENT_MS};
        }
        if (preset == 2) {
            return {"armGain"=>AppConstants.ROPE_SENSITIVE_ARM_GAIN_M,
                "endDrop"=>AppConstants.ROPE_SENSITIVE_DROP_M,
                "descentMs"=>AppConstants.ROPE_END_MIN_DESCENT_MS};
        }
        return {"armGain"=>AppConstants.ROPE_ARM_GAIN_M,
            "endDrop"=>AppConstants.ROPE_END_DROP_FROM_PEAK_M,
            "descentMs"=>AppConstants.ROPE_END_MIN_DESCENT_MS};
    }
    function breakTrend() {
        _previousAltitude = null; _lastTimestamp = null; _descentAt = null; _lastDescentTimestamp = null;
        descendingSamples = 0; descentDurationMs = 0l;
    }
    function reset() {
        armed = false; baselineAltitude = null; peakAltitude = null; peakTimestamp = null;
        relativeAltitude = null; peakRelativeAltitude = 0.0; triggered = false;
        _startTimestamp = null; _lastInputTimestamp = null; breakTrend();
    }
    function start(now, baseline) {
        reset();
        if (now < 0) { return false; }
        _startTimestamp = now; _lastInputTimestamp = now;
        baselineAltitude = baseline; peakAltitude = baseline; peakTimestamp = now;
        if (baseline != null) { relativeAltitude = 0.0; _previousAltitude = baseline; _lastTimestamp = now; }
        return true;
    }
    // Confirmation screens keep sampling the model, but defer automatic ending.
    function resumeFromClimb(climb as ClimbAttempt, now) {
        if (now < climb.startTimestamp || climb.endTimestamp != null ||
            (_lastInputTimestamp != null && now < _lastInputTimestamp)) { return false; }
        start(climb.startTimestamp, climb.startAltitude);
        peakAltitude = climb.peakAltitude; peakTimestamp = climb.peakTimestamp;
        peakRelativeAltitude = climb.peakRelativeAltitude == null ? 0.0 : climb.peakRelativeAltitude;
        relativeAltitude = climb.relativeAltitude;
        armed = peakRelativeAltitude >= thresholds["armGain"];
        _lastInputTimestamp = now; breakTrend(); return true;
    }
    function update(now, altitude) as Lang.Dictionary or Null {
        if (_startTimestamp == null || triggered || now < _startTimestamp ||
            (_lastInputTimestamp != null && now <= _lastInputTimestamp)) { return null; }
        var gap = _lastInputTimestamp != null && now - _lastInputTimestamp > AppConstants.SENSOR_GAP_MS;
        _lastInputTimestamp = now;
        if (altitude == null) { relativeAltitude = null; breakTrend(); return null; }
        if (gap) { breakTrend(); }
        if (baselineAltitude == null) { baselineAltitude = altitude; peakAltitude = altitude; peakTimestamp = now; }
        relativeAltitude = altitude - baselineAltitude;
        if (peakAltitude == null || altitude > peakAltitude) {
            peakAltitude = altitude; peakTimestamp = now;
            peakRelativeAltitude = peakAltitude - baselineAltitude;
            _descentAt = null; _lastDescentTimestamp = null; descendingSamples = 0; descentDurationMs = 0l;
        }
        if (peakRelativeAltitude >= thresholds["armGain"]) { armed = true; }
        if (_previousAltitude != null) {
            if (_lastDescentTimestamp != null && now - _lastDescentTimestamp > AppConstants.ROPE_DESCENT_MAX_STALL_MS) {
                _descentAt = null; _lastDescentTimestamp = null; descendingSamples = 0;
            }
            var change = altitude - _previousAltitude;
            if (change <= -AppConstants.ROPE_DESCENT_STEP_M) {
                if (_descentAt == null) { _descentAt = _lastTimestamp; }
                descendingSamples++;
                _lastDescentTimestamp = now;
            } else if (change > AppConstants.ROPE_DESCENT_REBOUND_M) {
                _descentAt = null; _lastDescentTimestamp = null; descendingSamples = 0;
            }
            descentDurationMs = _descentAt == null ? 0l : now - _descentAt;
        }
        _previousAltitude = altitude; _lastTimestamp = now;
        if (armed && peakTimestamp - _startTimestamp >= AppConstants.ROPE_END_MIN_VALID_CLIMB_MS &&
            peakAltitude - altitude >= thresholds["endDrop"] &&
            descendingSamples >= AppConstants.ROPE_END_MIN_DESCENT_SAMPLES &&
            descentDurationMs >= thresholds["descentMs"]) {
            triggered = true;
            return {"endAt"=>peakTimestamp, "detectedAt"=>now, "peakAltitude"=>peakAltitude};
        }
        return null;
    }
}
