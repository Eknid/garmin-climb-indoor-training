import Toybox.System;
import Toybox.Time;

// Wall timestamps advance by measured monotonic deltas, including late ticks.
class AppClock {
    var _epoch; var _ticks; var _elapsed = 0l;
    function initialize() {
        _epoch = Time.now().value().toLong() * 1000l;
        _ticks = System.getTimer().toLong();
    }
    function now() {
        var ticks = System.getTimer().toLong();
        var delta = ticks - _ticks;
        if (delta < 0) { delta += 4294967296l; }
        _elapsed += delta; _ticks = ticks;
        return _epoch + _elapsed;
    }
}
