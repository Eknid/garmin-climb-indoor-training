import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;
class ClimbView extends WatchUi.View {
    var c as AppController;
    var w;
    var h;
    function initialize(controller) { View.initialize(); c = controller; }
    function text(dc, y, value, font) {
        var maxWidth = w * ((y <= 0.20 || y >= 0.80) ? 0.66 : 0.80);
        if (font == Graphics.FONT_NUMBER_HOT && dc.getTextWidthInPixels(value, font) > maxWidth) { font = Graphics.FONT_NUMBER_MEDIUM; }
        if (font == Graphics.FONT_NUMBER_MEDIUM && dc.getTextWidthInPixels(value, font) > maxWidth) { font = Graphics.FONT_NUMBER_MILD; }
        if (dc.getTextWidthInPixels(value, font) > maxWidth) { font = Graphics.FONT_XTINY; }
        dc.drawText(w / 2, h * y, font, value, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    function row(dc, y, label, value) {
        dc.drawText(w * 0.19, h * y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(w * 0.81, h * y, Graphics.FONT_XTINY, value.toString(), Graphics.TEXT_JUSTIFY_RIGHT | Graphics.TEXT_JUSTIFY_VCENTER);
    }
    function onUpdate(dc) {
        drawPage(dc);
    }
    function drawPage(dc) {
        w = dc.getWidth(); h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK); dc.clear();
        // Number fonts have generous padding. An opaque text background would
        // erase nearby headings even where the number glyphs do not overlap.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var sm = c.sm; var state = sm.state; var s = c.statistics(); var a = sm.session.currentClimb;
        if (c.pendingOutcome != null) {
            text(dc, 0.18, "CLIMB #" + c.pendingOutcome.id, Graphics.FONT_SMALL);
            text(dc, 0.32, "Attempt result", Graphics.FONT_SMALL);
            text(dc, 0.51, (c.outcomeSelection == 1 ? "> " : "") + "Success", Graphics.FONT_MEDIUM);
            text(dc, 0.68, (c.outcomeSelection == 2 ? "> " : "") + "Failed", Graphics.FONT_MEDIUM);
            if (c.error != null) { drawError(dc, c.error); }
            return;
        }
        if (state == C.PRE_START) {
            text(dc, 0.20, "CLIMB", Graphics.FONT_LARGE);
            text(dc, 0.30, "INDOOR TRAINING", Graphics.FONT_SMALL);
            text(dc, 0.40, UiFormatter.mode(sm.currentMode), Graphics.FONT_MEDIUM);
            text(dc, 0.54, "0 climbs", Graphics.FONT_SMALL);
        } else if ((state == C.SESSION_SUMMARY || state == C.RESTING) && c.page == 2) {
            drawOutcomes(dc, s);
        } else if (state == C.SESSION_SUMMARY || (state == C.RESTING && c.page == 1)) {
            drawStatistics(dc, s, state == C.SESSION_SUMMARY);
        } else if (state == C.RESTING) {
            text(dc, 0.17, UiFormatter.mode(sm.currentMode) + "  REST", Graphics.FONT_SMALL);
            text(dc, 0.35, UiFormatter.timer(sm.session.restMs(c.now())), Graphics.FONT_NUMBER_HOT);
            row(dc, 0.53, "Climbs", s["totalClimbs"]);
            row(dc, 0.63, "Vertical", UiFormatter.height(s["totalVerticalGain"]));
            var last = sm.lastClimb;
            text(dc, 0.74, last == null ? "Last --" : "Last " + UiFormatter.height(last.heightGain) + "  " + UiFormatter.timer(last.durationMs), Graphics.FONT_XTINY);
        } else if (state == C.CLIMBING && a != null) {
            if (c.debugEnabled() && c.page % 3 == 2) { drawDebug(dc, a); }
            else if (c.page % (c.debugEnabled() ? 3 : 2) == 1) {
                text(dc, 0.17, "CLIMB #" + a.id, Graphics.FONT_SMALL);
                row(dc, 0.32, "Peak", UiFormatter.height(a.peakRelativeAltitude));
                row(dc, 0.43, "Current", UiFormatter.height(a.relativeAltitude));
                row(dc, 0.54, "HR", latestHr());
                row(dc, 0.65, "Max HR", UiFormatter.hr(a.maxHeartRate));
                row(dc, 0.76, "Rest before", UiFormatter.timer(a.restBeforeMs));
            } else {
                text(dc, 0.16, UiFormatter.mode(a.mode) + "  CLIMB #" + a.id, Graphics.FONT_SMALL);
                text(dc, 0.36, UiFormatter.timer(c.now() - a.startTimestamp), Graphics.FONT_NUMBER_HOT);
                text(dc, 0.56, UiFormatter.height(a.relativeAltitude), Graphics.FONT_LARGE);
                text(dc, 0.71, "HR " + latestHr(), Graphics.FONT_SMALL);
            }
        } else if (state == C.CLIMB_SUMMARY && sm.lastClimb != null) {
            a = sm.lastClimb;
            text(dc, 0.17, a.valid ? "CLIMB #" + a.id : "Climb cancelled", Graphics.FONT_SMALL);
            text(dc, 0.36, UiFormatter.timer(a.durationMs), Graphics.FONT_NUMBER_HOT);
            text(dc, 0.57, UiFormatter.height(a.heightGain), Graphics.FONT_LARGE);
            text(dc, 0.73, "Max HR " + UiFormatter.hr(a.maxHeartRate), Graphics.FONT_SMALL);
            text(dc, 0.84, UiFormatter.reason(a.endReason), Graphics.FONT_XTINY);
        } else {
            text(dc, 0.25, "SESSION PAUSED", Graphics.FONT_SMALL);
            text(dc, 0.48, UiFormatter.timer(s["elapsedMs"]), Graphics.FONT_NUMBER_HOT);
        }
        drawPageDots(dc);
        if (c.error != null) { drawError(dc, c.error); }
    }
    function drawPageDots(dc) {
        var count = c.pageCount();
        if (count < 2) { return; }
        var radius = w >= 400 ? 4 : 3;
        for (var i = 0; i < count; i++) {
            var y = h / 2 + (i - (count - 1) / 2.0) * h * 0.055;
            if (i == c.page) { dc.fillCircle(w * 0.07, y, radius); }
            else { dc.drawCircle(w * 0.07, y, radius); }
        }
    }
    function drawOutcomes(dc, s as Dictionary) {
        text(dc, 0.14, "RESULTS", Graphics.FONT_SMALL);
        text(dc, 0.30, s["successPercent"] == null ? "--" : s["successPercent"].format("%.0f") + "%", Graphics.FONT_LARGE);
        row(dc, 0.44, "Success", s["successes"]);
        row(dc, 0.54, "Failed", s["failures"]);
        row(dc, 0.64, "Rope S / F", s["ropeSuccesses"] + " / " + s["ropeFailures"]);
        row(dc, 0.74, "Boulder S / F", s["boulderSuccesses"] + " / " + s["boulderFailures"]);
        row(dc, 0.84, s["unrated"] > 0 ? "Unrated" : "Auto S / F", s["unrated"] > 0 ? s["unrated"].toString() : s["autoSuccesses"] + " / " + s["autoFailures"]);
    }
    function latestHr() { return c.lastSnapshot == null ? "--" : UiFormatter.hr(c.lastSnapshot["heartRate"]); }
    function drawStatistics(dc, s as Dictionary, saved) {
        text(dc, 0.14, saved ? "SAVED SUMMARY" : "SESSION", Graphics.FONT_SMALL);
        if (c.page == 0 && saved) {
            row(dc, 0.28, "Time", UiFormatter.timer(s["elapsedMs"]));
            row(dc, 0.38, "Climbs", s["totalClimbs"]);
            row(dc, 0.48, "Rope", s["ropeClimbs"]);
            row(dc, 0.58, "Boulder", s["boulderClimbs"]);
            row(dc, 0.68, "Auto", s["autoClimbs"]);
            row(dc, 0.78, "Success rate", s["successPercent"] == null ? "--" : s["successPercent"].format("%.0f") + "%");
        } else {
            row(dc, 0.28, "Climbing", UiFormatter.timer(s["totalClimbingTime"]));
            row(dc, 0.38, "Rest", UiFormatter.timer(s["totalRestTime"]));
            row(dc, 0.48, "Max climb", UiFormatter.height(s["maxClimbHeight"]));
            row(dc, 0.58, "Avg HR", UiFormatter.hr(s["averageHeartRate"]));
            row(dc, 0.68, "Max HR", UiFormatter.hr(s["maxHeartRate"]));
            row(dc, 0.78, "Time", UiFormatter.timer(s["elapsedMs"]));
        }
    }
    function drawError(dc, message) {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.fillRectangle(0, h * 0.70, w, h * 0.26);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var messageText = message.toString();
        var boundary = messageText.length(); var space = -1;
        for (var i = 0; i < messageText.length(); i += 1) {
            if (messageText.substring(i, i + 1).equals(" ")) { space = i; }
            if (dc.getTextWidthInPixels(messageText.substring(0, i + 1), Graphics.FONT_XTINY) > w * 0.76) { boundary = space > 0 ? space : i; break; }
        }
        var first = messageText.substring(0, boundary);
        var second = boundary < messageText.length() ? messageText.substring(boundary, messageText.length()) : "";
        while (dc.getTextWidthInPixels(second, Graphics.FONT_XTINY) > w * 0.66 && second.length() > 0) { second = second.substring(0, second.length() - 1); }
        text(dc, 0.76, first, Graphics.FONT_XTINY);
        text(dc, 0.85, second, Graphics.FONT_XTINY);
    }
    function drawDebug(dc, a) {
        text(dc, 0.16, "DIAGNOSTICS", Graphics.FONT_SMALL);
        row(dc, 0.28, "Raw", c.lastSnapshot == null ? "--" : UiFormatter.height(c.lastSnapshot["rawAltitude"]));
        row(dc, 0.38, "Filtered", c.lastSnapshot == null ? "--" : UiFormatter.height(c.lastSnapshot["altitude"]));
        row(dc, 0.48, "Relative", UiFormatter.height(a.relativeAltitude));
        row(dc, 0.58, "Peak", UiFormatter.height(a.peakRelativeAltitude));
        row(dc, 0.68, "Drop", UiFormatter.height(a.peakRelativeAltitude == null || a.relativeAltitude == null ? null : a.peakRelativeAltitude - a.relativeAltitude));
        var detector = a.mode == C.AUTO ? c.autoDetector.rope : c.ropeDetector;
        var detectorState = a.mode == C.BOULDER ? "MANUAL" :
            (a.relativeAltitude == null ? "NO ALTITUDE" :
                (detector.triggered ? "ENDED" :
                    (!detector.armed ? "UNARMED" :
                        (detector.descendingSamples > 0 ? "DESCENDING" : "ARMED"))));
        if (a.mode == C.AUTO && a.relativeAltitude != null && !detector.triggered) { detectorState = c.autoDetector.state; }
        row(dc, 0.78, "Detector", detectorState);
    }
}
