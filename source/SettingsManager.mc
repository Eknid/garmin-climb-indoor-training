import Toybox.Lang;
import Toybox.Application;
import Toybox.System;

class SettingsManager {
    var _defaults as Lang.Dictionary;
    function initialize() {
        _defaults = {"lastMode"=>1, "endSensitivity"=>1, "startSensitivity"=>1, "summarySeconds"=>4, "debug"=>false};
    }
    function valid(key, value) {
        if (!(key instanceof Lang.String)) { return false; }
        if (key.equals("lastMode")) { return C.isMode(value); }
        if (key.equals("endSensitivity") || key.equals("startSensitivity")) { return value == 0 || value == 1 || value == 2; }
        if (key.equals("summarySeconds")) { return value == 2 || value == 4 || value == 6; }
        if (key.equals("debug")) { return value == true || value == false; }
        return false;
    }
    function get(key) {
        var value = null;
        try { value = Application.Properties.getValue(key); }
        catch (ex) { System.println("Settings read: " + ex); }
        return valid(key, value) ? value : _defaults[key];
    }
    function set(key, value) {
        if (!valid(key, value)) { return false; }
        try { Application.Properties.setValue(key, value); return true; }
        catch (ex) { System.println("Settings write: " + ex); return false; }
    }
}
