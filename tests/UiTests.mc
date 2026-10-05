import Toybox.Test;
import Toybox.Lang;
import Toybox.WatchUi;

// Force independently allocated text so identity comparisons cannot pass.
(:test)
module UiTestHelpers {
    function text(value) { return ("x" + value).substring(1, null) as Lang.String; }
    function item(id) { return new WatchUi.MenuItem("Test", null, id, null); }
}

(:test)
class UiActionController extends ManualTestController {
    function initialize() { ManualTestController.initialize(); }
    function select() {
        var action = ManualTestController.select();
        return action == null ? null : UiTestHelpers.text(action);
    }
}
(:test)
class UiTestDelegate extends ClimbDelegate {
    var opened = null;
    function initialize(controller) { ClimbDelegate.initialize(controller); }
    function openMenu(kind, depth) { opened = kind; }
}
(:test)
class UiTestMenuDelegate extends ClimbMenuDelegate {
    var opened = null; var closed = 0; var allClosed = 0;
    function initialize(controller, menuKind) { ClimbMenuDelegate.initialize(controller, menuKind, 1); }
    function openMenu(menuKind, menuDepth) { opened = menuKind; }
    function close() { closed++; }
    function closeAll() { allClosed++; }
}

(:test)
function uiAllocatedActionStringsRoutePauseAndConfirmation(logger) {
    var c = new UiActionController(); var delegate = new UiTestDelegate(c);
    delegate.onSelect(); Test.assertEqual(c.sm.state, C.RESTING); Test.assert(delegate.opened == null);
    delegate.onSelect(); Test.assertEqual(c.sm.state, C.PAUSED); Test.assert(delegate.opened.equals("pause"));
    delegate.onSelect(); Test.assertEqual(c.sm.state, C.RESTING); delegate.onBack();
    delegate.onSelect(); Test.assertEqual(c.sm.state, C.END_MENU); Test.assert(delegate.opened.equals("confirmPause"));
    delegate.opened = null; delegate.onMenu(); Test.assert(delegate.opened == null);
    c.cancelPause(); c.clock.timestamp += 5000l; c.select(); c.confirmPause(); c.select(); c.discard();
    Test.assert(!ClimbMenus.matches(null, "pause")); Test.assert(!ClimbMenus.matches(1, "pause"));
    return true;
}

(:test)
function uiAllocatedMenuSettingsSelectorsAndInvalidValues(logger) {
    var c = new ManualTestController();
    var main = new UiTestMenuDelegate(c, UiTestHelpers.text("main"));
    main.onSelect(UiTestHelpers.item(UiTestHelpers.text("settings"))); Test.assert(main.opened.equals("settings"));
    var settings = new UiTestMenuDelegate(c, UiTestHelpers.text("settings"));
    settings.onSelect(UiTestHelpers.item(UiTestHelpers.text("endSensitivity"))); Test.assert(settings.opened.equals("endSensitivity"));
    var preset = new UiTestMenuDelegate(c, UiTestHelpers.text("endSensitivity"));
    preset.onSelect(UiTestHelpers.item(2)); Test.assertEqual(c.settings.get("endSensitivity"), 2); Test.assertEqual(preset.closed, 1);
    preset.onSelect(UiTestHelpers.item(99)); Test.assertEqual(c.settings.get("endSensitivity"), 2); Test.assert(preset.opened.equals("error"));
    var seconds = new UiTestMenuDelegate(c, UiTestHelpers.text("summarySeconds"));
    seconds.onSelect(UiTestHelpers.item(6)); Test.assertEqual(c.settings.get("summarySeconds"), 6); Test.assertEqual(seconds.closed, 1);
    var mode = new UiTestMenuDelegate(c, UiTestHelpers.text("mode")); mode.onSelect(UiTestHelpers.item(C.BOULDER));
    Test.assertEqual(c.sm.currentMode, C.BOULDER); Test.assertEqual(mode.allClosed, 1);
    var built = ClimbMenus.build(c, UiTestHelpers.text("settings"));
    Test.assert(built.getItem(0).getId().equals("endSensitivity"));
    if (!AppConstants.DEBUG_BUILD) { Test.assert(built.getItem(3) == null); }
    return true;
}

(:test)
function uiConfirmationCancelAndDiscardRequireExplicitSelection(logger) {
    var c = new ManualTestController(); c.select(); c.back(); c.clock.timestamp += 5000l; c.select();
    var confirmation = new UiTestMenuDelegate(c, UiTestHelpers.text("confirmPause"));
    confirmation.onSelect(UiTestHelpers.item(UiTestHelpers.text("cancel"))); Test.assertEqual(c.sm.state, C.CLIMBING);
    Test.assertEqual(confirmation.closed, 1); Test.assertEqual(c.recorder.laps, 0);
    c.select(); confirmation.onSelect(UiTestHelpers.item(UiTestHelpers.text("confirm")));
    Test.assert(c.pendingOutcome != null); Test.assert(confirmation.opened == null);
    var actions = new UiTestDelegate(c); actions.onSelect();
    Test.assertEqual(c.sm.state, C.PAUSED); Test.assertEqual(c.recorder.laps, 1); Test.assert(actions.opened.equals("pause"));
    var paused = ClimbMenus.build(c, UiTestHelpers.text("pause")); Test.assert(paused.getItem(0).getId().equals("resume"));
    var pauseDelegate = new UiTestMenuDelegate(c, UiTestHelpers.text("pause"));
    pauseDelegate.onSelect(UiTestHelpers.item(UiTestHelpers.text("discard"))); Test.assert(pauseDelegate.opened.equals("discard")); Test.assert(!c.exited);
    var discard = ClimbMenus.build(c, UiTestHelpers.text("discard")); Test.assert(discard.getItem(0).getId().equals("cancel"));
    var discardDelegate = new UiTestMenuDelegate(c, UiTestHelpers.text("discard"));
    discardDelegate.onSelect(UiTestHelpers.item(UiTestHelpers.text("cancel"))); Test.assert(!c.exited);
    discardDelegate.onSelect(UiTestHelpers.item(UiTestHelpers.text("confirm"))); Test.assert(c.exited); Test.assertEqual(discardDelegate.allClosed, 1);
    return true;
}
