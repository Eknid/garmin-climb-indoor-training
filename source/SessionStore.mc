import Toybox.Lang;
import Toybox.Application;
import Toybox.System;

// The latest workout is retained in bounded pages, independently of FIT.
class SessionStore {
    var _pending as Lang.Dictionary;
    var _page as Lang.Array; var _index = 0; var _count = 0; var _header as Lang.Dictionary or Null;
    function initialize() { _page = []; _pending = {}; }
    function clear() {
        try {
            for (var i = 0; i < 16; i++) { Application.Storage.deleteValue("climb_page_" + i); }
            Application.Storage.deleteValue("climb_session");
            return true;
        } catch (ex) { System.println("History cleanup: " + ex); return false; }
    }
    function start(timestamp, mode) {
        if (!clear()) { return false; }
        _page = []; _pending = {}; _index = 0; _count = 0;
        _header = {"schema"=>1, "startTimestamp"=>timestamp, "mode"=>mode, "status"=>"in_progress", "attempts"=>0};
        return writeHeader();
    }
    function writeHeader() {
        try { Application.Storage.setValue("climb_session", _header); return true; }
        catch (ex) { System.println("History header: " + ex); return false; }
    }
    // Failed pages stay bounded and are retried before publishing the header.
    function writePage(index, page) { Application.Storage.setValue("climb_page_" + index, page); }
    function flushPages() {
        try {
            var keys = _pending.keys();
            for (var i = 0; i < keys.size(); i++) {
                writePage(keys[i], _pending[keys[i]]);
                _pending.remove(keys[i]);
            }
            return true;
        } catch (ex) { System.println("History write: " + ex); return false; }
    }
    function append(attempt) {
        if (_header == null || _count >= AppConstants.MAX_HISTORY) { return false; }
        _page.add(attempt.toDictionary()); _count++;
        _pending[_index] = _page;
        // Rotate even when storage fails; no page may exceed sixteen attempts.
        if (_page.size() >= 16) { _page = []; _index++; }
        _header["attempts"] = _count;
        return flushPages() && writeHeader();
    }
    function save(timestamp, stats) {
        if (_header == null || !flushPages()) { return false; }
        _header["status"] = "saved"; _header["endTimestamp"] = timestamp; _header["statistics"] = stats;
        return writeHeader();
    }
}
