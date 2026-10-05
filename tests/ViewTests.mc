import Toybox.Test;
import Toybox.Graphics;
import Toybox.Lang;

(:test)
class ViewTestDc {
    var size; var background; var lines as Lang.Array; var circles as Lang.Array;
    function initialize(screenSize) { size = screenSize; lines = []; circles = []; }
    function getWidth() { return size; }
    function getHeight() { return size; }
    function setColor(foreground, fill) { background = fill; }
    function clear() { Test.assertEqual(background, Graphics.COLOR_BLACK); lines = []; circles = []; }
    function getTextWidthInPixels(value, font) { return value.length() * 10; }
    function drawText(x, y, font, value, justification) {
        // Opaque number-font padding must never erase a preceding heading.
        Test.assertEqual(background, Graphics.COLOR_TRANSPARENT);
        Test.assert(value.find("LAP:") == null); Test.assert(value.find("START:") == null);
        Test.assert(value.find("MENU:") == null); Test.assert(value.find("UP/DOWN") == null);
        lines.add(value);
    }
    function fillCircle(x, y, radius) { circles.add(true); }
    function drawCircle(x, y, radius) { circles.add(false); }
    function contains(value) {
        for (var i = 0; i < lines.size(); i++) { if (lines[i].equals(value)) { return true; } }
        return false;
    }
}

(:test)
function viewPagesPreserveHeadingsWithoutButtonInstructions(logger) {
    for (var i = 0; i < 4; i++) {
        var widths = [260, 280, 416, 454];
        var c = new ManualTestController(); var view = new ClimbView(c); var dc = new ViewTestDc(widths[i]);
        view.drawPage(dc); Test.assert(dc.contains("CLIMB"));
        c.select(); view.drawPage(dc); Test.assert(dc.contains("ROPE  REST"));
        c.page = 1; view.drawPage(dc); Test.assert(dc.contains("SESSION"));
        c.back(); c.resolveOutcome(1); view.drawPage(dc); Test.assert(dc.contains("ROPE  CLIMB #1"));
        c.page = 1; view.drawPage(dc); Test.assert(dc.contains("CLIMB #1"));
        c.clock.timestamp += 5000l; c.back(); c.resolveOutcome(1); view.drawPage(dc); Test.assert(dc.contains("CLIMB #1"));
        c.back(); c.resolveOutcome(1); c.select(); view.drawPage(dc); Test.assert(dc.contains("SESSION PAUSED"));
        Test.assert(c.save()); view.drawPage(dc); Test.assert(dc.contains("SAVED SUMMARY"));
        c.page = 1; view.drawPage(dc); Test.assert(dc.contains("SAVED SUMMARY"));
    }
    return true;
}
