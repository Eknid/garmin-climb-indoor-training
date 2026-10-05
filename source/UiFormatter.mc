import Toybox.Lang;
module UiFormatter {
    function timer(ms) {
        if (ms == null) { return "--:--"; }
        var s = (ms / 1000).toNumber();
        if (s < 0) { s = 0; }
        if (s >= 3600) { return (s / 3600).toNumber().format("%d") + ":" + ((s / 60).toNumber() % 60).format("%02d") + ":" + (s % 60).format("%02d"); }
        return (s / 60).toNumber().format("%02d") + ":" + (s % 60).format("%02d");
    }
    function height(v) { return v == null ? "-- m" : v.format("%.1f") + " m"; }
    function hr(v) { return v == null || v <= 0 ? "--" : v.toNumber().format("%d"); }
    function mode(v) { return v == 2 ? "BOULDER" : (v == 3 ? "AUTO" : "ROPE"); }
    function reason(v) { return v == 2 ? "AUTO END" : (v == 3 ? "AUTO" : (v == 4 ? "SESSION END" : (v == 5 ? "CANCELLED" : "MANUAL"))); }
    function preset(v) { return v == 0 ? "Conservative" : (v == 2 ? "Sensitive" : "Normal"); }
}
