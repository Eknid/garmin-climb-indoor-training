import Toybox.Lang;
class ClimbAttempt {
    var id; var mode; var startTimestamp; var endTimestamp = null;
    var detectionStartTimestamp; var detectionEndTimestamp = null;
    var durationMs = 0l; var startAltitude; var peakAltitude; var endAltitude = null;
    var heightGain = null; var peakAltitudeGain = null; var restBeforeMs;
    var relativeAltitude = null; var peakRelativeAltitude = null;
    var avgHeartRate = null; var maxHeartRate = null; var heartRateSamples = 0;
    var heartRateSum = 0l; var endReason = null;
    var outcome = 0; // 0 unrated, 1 success, 2 failed
    var wasAutoStarted; var wasAutoEnded = false; var valid = false;
    var _lastSample;
    var _peakHrSum = 0l; var _peakHrCount = 0; var _peakHrMax = null;
    var peakTimestamp = null;
    function initialize(attemptId, climbMode, now, altitude, rest, automatic, detectedAt) {
        id = attemptId; mode = climbMode; startTimestamp = now;
        detectionStartTimestamp = detectedAt; startAltitude = altitude;
        peakAltitude = altitude; peakTimestamp = altitude == null ? null : now;
        restBeforeMs = rest; wasAutoStarted = automatic; _lastSample = now;
    }
    function sample(now, altitude, hr) {
        if (now < _lastSample || endTimestamp != null) { return false; }
        _lastSample = now;
        var newPeak = false;
        if (altitude != null) {
            if (startAltitude == null) { startAltitude = altitude; peakAltitude = altitude; newPeak = true; }
            if (peakAltitude == null || altitude > peakAltitude) { peakAltitude = altitude; newPeak = true; }
            if (newPeak) { peakTimestamp = now; }
            endAltitude = altitude;
            relativeAltitude = altitude - startAltitude;
            peakAltitudeGain = (peakAltitude - startAltitude); heightGain = peakAltitudeGain;
            peakRelativeAltitude = peakAltitudeGain;
        } else { relativeAltitude = null; }
        if (hr != null && hr > 0) {
            heartRateSum += hr; heartRateSamples++;
            avgHeartRate = heartRateSum.toFloat() / heartRateSamples;
            if (maxHeartRate == null || hr > maxHeartRate) { maxHeartRate = hr; }
        }
        if (newPeak) {
            _peakHrSum = heartRateSum; _peakHrCount = heartRateSamples; _peakHrMax = maxHeartRate;
        }
        return true;
    }
    function finish(endAt, detectedAt, altitude, reason) {
        if (endTimestamp != null || endAt < startTimestamp || detectedAt < endAt) { return false; }
        sample(detectedAt, altitude, null);
        endTimestamp = endAt; detectionEndTimestamp = detectedAt; durationMs = endAt - startTimestamp;
        endReason = reason; wasAutoEnded = reason == C.AUTO_DESCENT || reason == C.AUTO_FULL;
        if (wasAutoEnded && endAt < detectedAt) {
            heartRateSum = _peakHrSum; heartRateSamples = _peakHrCount; maxHeartRate = _peakHrMax;
            avgHeartRate = heartRateSamples > 0 ? heartRateSum.toFloat() / heartRateSamples : null;
        }
        // Short failed boulder attempts still count. Only a zero-time accidental lap is cancelled.
        valid = durationMs > 0 || (heightGain != null && heightGain >= AppConstants.MIN_MANUAL_CLIMB_HEIGHT_M);
        if (!valid) { endReason = C.CANCELLED; }
        return true;
    }
    function toDictionary() as Lang.Dictionary {
        return {"id"=>id, "mode"=>mode, "startTimestamp"=>startTimestamp,
            "endTimestamp"=>endTimestamp, "detectionStartTimestamp"=>detectionStartTimestamp,
            "detectionEndTimestamp"=>detectionEndTimestamp, "durationMs"=>durationMs,
            "startAltitude"=>startAltitude, "peakAltitude"=>peakAltitude, "endAltitude"=>endAltitude,
            "peakTimestamp"=>peakTimestamp,
            "heightGain"=>heightGain, "peakAltitudeGain"=>peakAltitudeGain, "restBeforeMs"=>restBeforeMs,
            "avgHeartRate"=>avgHeartRate, "maxHeartRate"=>maxHeartRate, "heartRateSamples"=>heartRateSamples,
            "outcome"=>outcome, "endReason"=>endReason, "wasAutoStarted"=>wasAutoStarted, "wasAutoEnded"=>wasAutoEnded, "valid"=>valid};
    }
}
