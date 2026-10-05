import Toybox.Lang;
module SessionStats {
    function calculate(session as SessionController, now) as Lang.Dictionary {
        var result = {"totalClimbs"=>0, "ropeClimbs"=>0, "boulderClimbs"=>0, "autoClimbs"=>0,
            "successes"=>0, "failures"=>0, "unrated"=>0, "successPercent"=>null,
            "ropeSuccesses"=>0, "ropeFailures"=>0, "boulderSuccesses"=>0, "boulderFailures"=>0, "autoSuccesses"=>0, "autoFailures"=>0,
            "totalClimbingTime"=>0l, "totalRestTime"=>0l, "totalVerticalGain"=>0.0,
            "maxClimbHeight"=>null, "averageHeartRate"=>null, "maxHeartRate"=>null, "elapsedMs"=>session.elapsedMs(now)};
        for (var i = 0; i < session.climbs.size(); i++) {
            var climb = session.climbs[i];
            if (!climb.valid) { continue; }
            result["totalClimbs"]++;
            var key = climb.mode == C.ROPE ? "ropeClimbs" : (climb.mode == C.BOULDER ? "boulderClimbs" : "autoClimbs");
            result[key]++;
            var prefix = climb.mode == C.ROPE ? "rope" : (climb.mode == C.BOULDER ? "boulder" : "auto");
            if (climb.outcome == 1) { result["successes"]++; result[prefix + "Successes"]++; }
            else if (climb.outcome == 2) { result["failures"]++; result[prefix + "Failures"]++; }
            else { result["unrated"]++; }
            result["totalClimbingTime"] += climb.durationMs;
            if (climb.heightGain != null) {
                result["totalVerticalGain"] += climb.heightGain;
                if (result["maxClimbHeight"] == null || climb.heightGain > result["maxClimbHeight"]) { result["maxClimbHeight"] = climb.heightGain; }
            }
        }
        if (session.currentClimb != null) {
            var current = session.currentClimb;
            var duration = now - current.startTimestamp;
            if (duration > 0) { result["totalClimbingTime"] += duration; }
        }
        var rated = result["successes"] + result["failures"];
        result["successPercent"] = rated > 0 ? result["successes"].toFloat() * 100.0 / rated : null;
        result["averageHeartRate"] = session.heartRateSamples > 0 ? session.heartRateSum.toFloat() / session.heartRateSamples : null;
        result["maxHeartRate"] = session.maxHeartRate;
        result["totalRestTime"] = result["elapsedMs"] - result["totalClimbingTime"];
        if (result["totalRestTime"] < 0) { result["totalRestTime"] = 0l; }
        return result;
    }
}
