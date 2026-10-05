import Toybox.FitContributor;
import Toybox.Lang;

// IDs are stable across versions and unique across lap and session messages.
module FitSchema {
    const VERSION = 2;
    const CLIMB_NUMBER = 0; const CLIMB_MODE = 1; const CLIMB_HEIGHT = 2;
    const CLIMB_DURATION = 3; const REST_BEFORE = 4; const END_REASON = 5;
    const CLIMB_AVG_HR = 6; const CLIMB_MAX_HR = 7; const ATTEMPT_ID = 8; const VALID_VALUES = 9;
    const CLIMB_SUCCESS = 10; const CLIMB_FAILURE = 11; const CLIMB_RATED = 12;
    const TOTAL_CLIMBS = 16; const ROPE_CLIMBS = 17; const BOULDER_CLIMBS = 18; const AUTO_CLIMBS = 19;
    const TOTAL_VERTICAL = 20; const MAX_HEIGHT = 21; const CLIMBING_TIME = 22; const REST_TIME = 23;
    const ELAPSED_TIME = 24; // 25-27 retired: duplicate native HR and schema marker. Never reuse.
    const SUCCESSES = 28; const FAILURES = 29; const SUCCESS_PERCENT = 30; const UNRATED = 31;
    const ROPE_RESULTS = 13; const BOULDER_RESULTS = 14; const AUTO_RESULTS = 15;
    const UNKNOWN_FLOAT = -1.0; const UNKNOWN_HR = 65535;
    const LAP_BYTES = 28; const SESSION_BYTES = 68;
    function definition(id, name, type, message, units) {
        return {"id"=>id, "name"=>name, "type"=>type, "message"=>message, "units"=>units};
    }
    function resultDefinition(id, name, message) {
        var result = definition(id, name, FitContributor.DATA_TYPE_STRING, message, "") as Lang.Dictionary;
        result["count"] = 10; return result;
    }
    function definitions() as Lang.Array {
        var lap = FitContributor.MESG_TYPE_LAP; var summary = FitContributor.MESG_TYPE_SESSION;
        var u8 = FitContributor.DATA_TYPE_UINT8; var u16 = FitContributor.DATA_TYPE_UINT16; var f = FitContributor.DATA_TYPE_FLOAT;
        return [
            definition(CLIMB_NUMBER, "climb_number", u16, lap, ""),
            definition(CLIMB_MODE, "climb_mode", u8, lap, ""),
            definition(CLIMB_HEIGHT, "climb_height", f, lap, "m"),
            definition(CLIMB_DURATION, "climb_duration", f, lap, "s"),
            definition(REST_BEFORE, "rest_before", f, lap, "s"),
            definition(END_REASON, "end_reason", u8, lap, ""),
            definition(CLIMB_AVG_HR, "climb_avg_hr", f, lap, "bpm"),
            definition(CLIMB_MAX_HR, "climb_max_hr", u16, lap, "bpm"),
            definition(ATTEMPT_ID, "attempt_id", u16, lap, ""),
            definition(VALID_VALUES, "valid_values", u8, lap, ""),
            definition(CLIMB_SUCCESS, "climb_success", u8, lap, ""),
            definition(CLIMB_FAILURE, "climb_failure", u8, lap, ""),
            definition(CLIMB_RATED, "climb_rated", u8, lap, ""),
            definition(TOTAL_CLIMBS, "total_climbs", u16, summary, ""),
            definition(ROPE_CLIMBS, "rope_climbs", u16, summary, ""),
            definition(BOULDER_CLIMBS, "boulder_climbs", u16, summary, ""),
            definition(AUTO_CLIMBS, "auto_climbs", u16, summary, ""),
            definition(TOTAL_VERTICAL, "total_vertical", f, summary, "m"),
            definition(MAX_HEIGHT, "max_climb_height", f, summary, "m"),
            definition(CLIMBING_TIME, "climbing_time", f, summary, "s"),
            definition(REST_TIME, "rest_time", f, summary, "s"),
            definition(ELAPSED_TIME, "elapsed_time", f, summary, "s"),
            definition(SUCCESSES, "successful_climbs", u16, summary, ""),
            definition(FAILURES, "failed_climbs", u16, summary, ""),
            definition(SUCCESS_PERCENT, "success_percent", f, summary, "%"),
            definition(UNRATED, "unrated_climbs", u16, summary, ""),
            resultDefinition(ROPE_RESULTS, "rope_results", summary),
            resultDefinition(BOULDER_RESULTS, "boulder_results", summary),
            resultDefinition(AUTO_RESULTS, "auto_results", summary)
        ];
    }
    function seconds(milliseconds) { return milliseconds.toFloat() / 1000.0; }
    function numberOrUnknown(value) { return value == null ? UNKNOWN_FLOAT : value.toFloat(); }
}
