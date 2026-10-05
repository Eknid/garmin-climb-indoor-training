import Toybox.Application;

class ClimbApp extends Application.AppBase {
    var controller;
    function initialize() { AppBase.initialize(); }
    function getInitialView() {
        controller = new AppController(); controller.startUpdates();
        return [new ClimbView(controller), new ClimbDelegate(controller)];
    }
    function onStop(state) { if (controller != null) { controller.shutdown(); } }
    function onActive(state) { if (controller != null) { controller.active(); } }
    function onInactive(state) { if (controller != null) { controller.inactive(); } }
    function onSettingsChanged() {
        if (controller != null) {
            controller.changeMode(controller.settings.get("lastMode")); controller.refresh();
        }
    }
}
