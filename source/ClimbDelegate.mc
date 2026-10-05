import Toybox.WatchUi;
import Toybox.Lang;
class ClimbDelegate extends WatchUi.BehaviorDelegate {
    var c as AppController;
    function initialize(controller) { BehaviorDelegate.initialize(); c = controller; }
    function openMenu(kind, depth) { ClimbMenus.open(c, kind, depth); }
    function onSelect() {
        var action = c.select();
        if (ClimbMenus.matches(action, "pauseMenu")) { openMenu("pause", 1); }
        else if (ClimbMenus.matches(action, "confirmPause")) { openMenu("confirmPause", 1); }
        WatchUi.requestUpdate(); return true;
    }
    function onBack() { c.back(); WatchUi.requestUpdate(); return true; }
    function onNextPage() { c.nextPage(); WatchUi.requestUpdate(); return true; }
    function onPreviousPage() { c.previousPage(); WatchUi.requestUpdate(); return true; }
    function onMenu() {
        if (c.sm.state == C.PAUSED) { openMenu("pause", 1); }
        else if (c.menuAllowed()) { openMenu("main", 1); }
        return true;
    }
}
module ClimbMenus {
    function matches(value, expected) { return value instanceof Lang.String && value.equals(expected); }
    function item(menu, title, subtitle, id) { menu.addItem(new WatchUi.MenuItem(title, subtitle, id, null)); }
    function build(c as AppController, kind) {
        var title = "CLIMB INDOOR TRAINING";
        if (ClimbMenus.matches(kind, "pause")) { title = "SESSION PAUSED"; }
        else if (ClimbMenus.matches(kind, "mode")) { title = "NEXT CLIMB"; }
        else if (ClimbMenus.matches(kind, "settings")) { title = "SETTINGS"; }
        else if (ClimbMenus.matches(kind, "confirmPause")) { title = "Pause session?"; }
        else if (ClimbMenus.matches(kind, "discard")) { title = "Discard session?"; }
        else if (ClimbMenus.matches(kind, "summarySeconds")) { title = "SUMMARY DURATION"; }
        else if (ClimbMenus.matches(kind, "endSensitivity")) { title = "AUTO END"; }
        else if (ClimbMenus.matches(kind, "startSensitivity")) { title = "AUTO START"; }
        else if (ClimbMenus.matches(kind, "error")) { title = "Action failed"; }
        else if (ClimbMenus.matches(kind, "about")) { title = "CLIMB INDOOR TRAINING"; }
        var menu = new WatchUi.Menu2({:title=>title, :focus=>0});
        if (ClimbMenus.matches(kind, "main")) {
            item(menu, "Mode", UiFormatter.mode(c.sm.currentMode), "mode");
            item(menu, "Settings", null, "settings");
            if (AppConstants.DEBUG_BUILD) { item(menu, "About / Debug", null, "about"); }
        } else if (ClimbMenus.matches(kind, "mode")) {
            item(menu, "ROPE", "Manual start / Auto end", 1);
            item(menu, "BOULDER", "Manual start / finish", 2);
            item(menu, "AUTO", "Experimental", 3);
            menu.setFocus(c.sm.currentMode - 1);
        } else if (ClimbMenus.matches(kind, "pause")) {
            item(menu, "Resume", null, "resume");
            item(menu, "Save", null, "save");
            item(menu, "Discard", null, "discard");
        } else if (ClimbMenus.matches(kind, "confirmPause")) {
            item(menu, "Cancel", "Continue current climb", "cancel");
            item(menu, "Confirm", "Current climb will be ended", "confirm");
        } else if (ClimbMenus.matches(kind, "discard")) {
            item(menu, "Cancel", "Keep session", "cancel");
            item(menu, "Discard", "Delete unsaved activity", "confirm");
        } else if (ClimbMenus.matches(kind, "settings")) {
            item(menu, "Auto End Sensitivity", UiFormatter.preset(c.settings.get("endSensitivity")), "endSensitivity");
            item(menu, "Auto Start Sensitivity", UiFormatter.preset(c.settings.get("startSensitivity")), "startSensitivity");
            item(menu, "Summary Duration", c.settings.get("summarySeconds").toString() + " seconds", "summarySeconds");
            if (AppConstants.DEBUG_BUILD) { item(menu, "Debug", c.settings.get("debug") ? "On" : "Off", "debug"); }
        } else if (ClimbMenus.matches(kind, "summarySeconds")) {
            item(menu, "2 seconds", null, 2); item(menu, "4 seconds", null, 4); item(menu, "6 seconds", null, 6);
        } else if (ClimbMenus.matches(kind, "endSensitivity") || ClimbMenus.matches(kind, "startSensitivity")) {
            item(menu, "Conservative", null, 0); item(menu, "Normal", null, 1); item(menu, "Sensitive", null, 2);
            menu.setFocus(c.settings.get(kind));
        } else if (ClimbMenus.matches(kind, "error")) {
            item(menu, "Back", c.error == null ? "Please try again" : c.error, "cancel");
        } else {
            item(menu, "Climb", "Rope / Boulder / Auto", "cancel");
            item(menu, "Auto: Experimental", "Calibrate on real climbs", "cancel");
            item(menu, "Buttons", "BACK: Climb  START: Session", "cancel");
        }
        return menu;
    }
    function open(c as AppController, kind, depth) {
        var menu = build(c, kind);
        c.setMenuOpen(true);
        WatchUi.pushView(menu, new ClimbMenuDelegate(c, kind, depth), WatchUi.SLIDE_UP);
    }
}
class ClimbMenuDelegate extends WatchUi.Menu2InputDelegate {
    var c as AppController; var kind; var depth;
    function initialize(controller, menuKind, menuDepth) { Menu2InputDelegate.initialize(); c = controller; kind = menuKind; depth = menuDepth; }
    function close() { WatchUi.popView(WatchUi.SLIDE_DOWN); if (depth == 1) { c.setMenuOpen(false); } WatchUi.requestUpdate(); }
    function closeAll() { for (var i = 0; i < depth; i += 1) { WatchUi.popView(WatchUi.SLIDE_IMMEDIATE); } c.setMenuOpen(false); WatchUi.requestUpdate(); }
    function openMenu(menuKind, menuDepth) { ClimbMenus.open(c, menuKind, menuDepth); }
    function failed() { openMenu("error", depth + 1); }
    function onBack() { if (ClimbMenus.matches(kind, "confirmPause")) { c.cancelPause(); } close(); }
    function onSelect(item) {
        var id = item.getId();
        if (ClimbMenus.matches(kind, "main")) { openMenu(id, depth + 1); }
        else if (ClimbMenus.matches(kind, "mode")) { if (c.changeMode(id)) { closeAll(); } else { failed(); } }
        else if (ClimbMenus.matches(kind, "settings")) {
            if (ClimbMenus.matches(id, "debug") && AppConstants.DEBUG_BUILD) { if (c.changeSetting("debug", !c.settings.get("debug"))) { close(); } else { failed(); } }
            else { openMenu(id, depth + 1); }
        } else if (ClimbMenus.matches(kind, "startSensitivity") || ClimbMenus.matches(kind, "endSensitivity") || ClimbMenus.matches(kind, "summarySeconds")) { if (c.changeSetting(kind, id)) { close(); } else { failed(); } }
        else if (ClimbMenus.matches(kind, "pause")) {
            if (ClimbMenus.matches(id, "resume")) { if (c.resume()) { closeAll(); } else { failed(); } }
            else if (ClimbMenus.matches(id, "save")) { if (c.save()) { closeAll(); } else { failed(); } }
            else if (ClimbMenus.matches(id, "discard")) { openMenu("discard", depth + 1); }
        } else if (ClimbMenus.matches(kind, "confirmPause")) {
            if (ClimbMenus.matches(id, "confirm")) {
                if (c.confirmPause()) { closeAll(); if (c.pendingOutcome == null) { openMenu("pause", 1); } }
                else { failed(); }
            } else { c.cancelPause(); close(); }
        } else if (ClimbMenus.matches(kind, "discard")) {
            if (ClimbMenus.matches(id, "confirm")) { if (c.discard()) { closeAll(); } else { failed(); } }
            else { close(); }
        } else { close(); }
    }
}
