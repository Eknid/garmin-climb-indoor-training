import Toybox.Sensor;
import Toybox.Lang;
import Toybox.System;

class SensorService {
    var enabled = false; var _active = true;
    function initialize() {}
    function start() {
        _active = true; enabled = true;
        try { Sensor.setEnabledSensors([Sensor.SENSOR_HEARTRATE]); }
        catch (ex) { System.println("Sensors unavailable: " + ex); }
    }
    // Garmin disables the physical sensors while the app is inactive.
    function suspend() { _active = false; enabled = false; }
    function stop() {
        enabled = false;
        if (!_active) { return; }
        try { Sensor.enableSensorEvents(null); Sensor.setEnabledSensors([]); }
        catch (ex) { System.println("Sensor cleanup: " + ex); }
    }
    function sample(timestamp) as Lang.Dictionary {
        var snapshot = {"timestamp"=>timestamp, "altitude"=>null, "heartRate"=>null, "acceleration"=>null, "pressure"=>null};
        if (!enabled) { return snapshot; }
        try {
            var info = Sensor.getInfo();
            snapshot["altitude"] = info.altitude;
            snapshot["heartRate"] = info.heartRate;
            snapshot["pressure"] = info.pressure;
        } catch (ex) { System.println("Sensor sample: " + ex); }
        return snapshot;
    }
}
