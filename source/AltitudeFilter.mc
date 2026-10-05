import Toybox.Lang;

// A bounded median rejects isolated spikes; EMA smooths the remaining signal.
class AltitudeFilter {
    var filteredAltitude = null;
    var _samples as Lang.Array;
    var _lastTimestamp = null;
    function initialize() { _samples = []; }
    function reset() { _samples = []; filteredAltitude = null; _lastTimestamp = null; }
    function update(now, raw) {
        if (now < 0 || (_lastTimestamp != null && now < _lastTimestamp)) { return null; }
        if (raw == null) {
            _samples = []; filteredAltitude = null; _lastTimestamp = now; return null;
        }
        if (_lastTimestamp != null && now - _lastTimestamp > AppConstants.SENSOR_GAP_MS) {
            _samples = []; filteredAltitude = null;
        }
        _lastTimestamp = now;
        _samples.add(raw);
        if (_samples.size() > AppConstants.ALTITUDE_MEDIAN_SAMPLES) { _samples.remove(_samples[0]); }
        // Partial windows can turn one recovery spike into a synthetic descent.
        if (_samples.size() < AppConstants.ALTITUDE_MEDIAN_SAMPLES) { return null; }
        var sorted = [];
        for (var i = 0; i < _samples.size(); i++) {
            sorted.add(_samples[i]);
            var j = sorted.size() - 1;
            while (j > 0 && sorted[j] < sorted[j-1]) {
                var temporary = sorted[j]; sorted[j] = sorted[j-1]; sorted[j-1] = temporary; j--;
            }
        }
        var middle = (sorted.size() / 2).toNumber();
        var median = sorted.size() % 2 == 0 ? (sorted[middle-1] + sorted[middle]) / 2.0 : sorted[middle];
        filteredAltitude = filteredAltitude == null ? median :
            filteredAltitude + AppConstants.ALTITUDE_EMA_ALPHA * (median - filteredAltitude);
        return filteredAltitude;
    }
}
