import Toybox.Activity;
import Toybox.Test;

(:test)
function verifiedMixedClimbingSport(logger) {
    Test.assertEqual(Activity.SPORT_ROCK_CLIMBING, 31);
    Test.assertEqual(Activity.SUB_SPORT_GENERIC, 0);
    return true;
}

(:test)
function stringSelectorsUseValueEquality(logger) {
    var composed = ""; var parts = ["WATCH", "ING"];
    for (var i = 0; i < parts.size(); i++) { composed += parts[i]; }
    logger.debug("String operator value comparison: " + (composed == "WATCHING"));
    Test.assert(composed.equals("WATCHING"));
    return true;
}
