import Toybox.Lang;
class SessionController {
    var climbs as Lang.Array<ClimbAttempt>; var currentClimb as ClimbAttempt or Null = null; var sessionStartTimestamp = null;
    var sessionEndTimestamp = null; var sessionPausedDuration = 0l;
    var heartRateSum = 0l; var heartRateSamples = 0; var maxHeartRate = null;
    var _pausedAt = null; var _lastTime = null; var _restAt = null; var _restPauseBase = 0l;
    function initialize() { climbs = []; }
    function acceptTime(now) {
        if (now < 0 || (_lastTime != null && now < _lastTime)) { return false; }
        _lastTime = now; return true;
    }
    function start(now) {
        if (sessionStartTimestamp != null || !acceptTime(now)) { return false; }
        sessionStartTimestamp = now; _restAt = now; return true;
    }
    function canStartClimb() { return sessionStartTimestamp != null && currentClimb == null && climbs.size() < AppConstants.MAX_HISTORY && _pausedAt == null && sessionEndTimestamp == null; }
    function beginClimb(now, altitude, mode, automatic, detectedAt) {
        if (!C.isMode(mode) || !canStartClimb() || now < sessionStartTimestamp || now < _restAt || detectedAt < now || !acceptTime(detectedAt)) { return false; }
        currentClimb = new ClimbAttempt(climbs.size()+1, mode, now, altitude, restMs(now), automatic, detectedAt);
        return true;
    }
    function sample(now, altitude, hr) {
        if (_pausedAt != null || sessionEndTimestamp != null || sessionStartTimestamp == null || !acceptTime(now)) { return false; }
        if (hr != null && hr > 0) {
            heartRateSum += hr; heartRateSamples++;
            if (maxHeartRate == null || hr > maxHeartRate) { maxHeartRate = hr; }
        }
        if (currentClimb != null) { return currentClimb.sample(now, altitude, hr); }
        return true;
    }
    function finishClimb(endAt, detectedAt, altitude, reason) {
        if (currentClimb == null || endAt < currentClimb.startTimestamp || detectedAt < endAt || !acceptTime(detectedAt) || !currentClimb.finish(endAt, detectedAt, altitude, reason)) { return null; }
        var result = currentClimb; climbs.add(result); currentClimb = null;
        if (result.valid) { _restAt = endAt; _restPauseBase = sessionPausedDuration; }
        return result;
    }
    function pause(now) {
        if (_pausedAt != null || sessionStartTimestamp == null || currentClimb != null || !acceptTime(now)) { return false; }
        _pausedAt = now; return true;
    }
    function resume(now) {
        if (_pausedAt == null || !acceptTime(now)) { return false; }
        sessionPausedDuration += now - _pausedAt; _pausedAt = null; return true;
    }
    function save(now) {
        if (_pausedAt == null || sessionEndTimestamp != null || !acceptTime(now)) { return false; }
        sessionPausedDuration += now - _pausedAt; _pausedAt = null; sessionEndTimestamp = now; return true;
    }
    function elapsedMs(now) {
        if (sessionStartTimestamp == null) { return 0l; }
        var end = sessionEndTimestamp != null ? sessionEndTimestamp : now;
        if (_pausedAt != null) { end = _pausedAt; }
        return end < sessionStartTimestamp ? 0l : end - sessionStartTimestamp - sessionPausedDuration;
    }
    function restMs(now) {
        if (_restAt == null) { return 0l; }
        var end = _pausedAt != null ? _pausedAt : now;
        var rest = end - _restAt - (sessionPausedDuration - _restPauseBase);
        return rest < 0 ? 0l : rest;
    }
}
