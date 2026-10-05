import Toybox.Test;
import Toybox.Lang;
import Toybox.Application;
import Toybox.System;

(:test)
class FailingPageStore extends SessionStore {
    var pages as Lang.Dictionary<Lang.Number, Lang.Array<Lang.Dictionary>>; var failBoundary = true; var headerWrites = 0;
    function initialize() { SessionStore.initialize(); pages = {}; }
    function clear() { return true; }
    function writeHeader() { headerWrites++; return true; }
    function writePage(index, page) {
        Test.assert(page.size() <= 16);
        if (failBoundary && page.size() == 16) {
            failBoundary = false;
            throw new Lang.InvalidValueException("Injected storage failure");
        }
        pages[index] = page;
    }
}

(:test)
function storagePageBoundaryFailureRecovers(logger) {
    var store = new FailingPageStore(); Test.assert(store.start(0l, C.BOULDER));
    for (var i = 0; i < 256; i++) {
        var attempt = new ClimbAttempt(i + 1, C.BOULDER, i * 10000l, null, 0l, false, i * 10000l);
        attempt.finish(i * 10000l + 5000l, i * 10000l + 5000l, null, C.MANUAL);
        var result = store.append(attempt);
        if (i == 15) { Test.assert(!result); Test.assertEqual(store._index, 1); }
        else { Test.assert(result); }
    }
    Test.assert(store.save(2560000l, {})); Test.assertEqual(store.pages.size(), 16);
    Test.assertEqual(store._pending.size(), 0); Test.assertEqual(store._count, 256);
    for (var p = 0; p < 16; p++) {
        Test.assertEqual(store.pages[p].size(), 16);
        Test.assertEqual(store.pages[p][0]["id"], p * 16 + 1);
    }
    return true;
}

(:test)
function storageHundredClimbsPersistAndReadBack(logger) {
    var store = new SessionStore(); Test.assert(store.start(0l, C.BOULDER));
    for (var i = 0; i < 100; i++) {
        var attempt = new ClimbAttempt(i + 1, C.BOULDER, i * 10000l, 100.0, 0l, false, i * 10000l);
        attempt.sample(i * 10000l + 4000l, 102.0, 140);
        attempt.finish(i * 10000l + 5000l, i * 10000l + 5000l, 102.0, C.MANUAL);
        Test.assert(store.append(attempt));
    }
    Test.assert(store.save(1000000l, {"totalClimbs"=>100}));
    var header = Application.Storage.getValue("climb_session") as Lang.Dictionary;
    Test.assertEqual(header["attempts"], 100); Test.assert(header["status"].equals("saved"));
    var count = 0;
    for (var p = 0; p < 7; p++) {
        var page = Application.Storage.getValue("climb_page_" + p) as Lang.Array<Lang.Dictionary>;
        Test.assertEqual(page[0]["id"], p * 16 + 1); count += page.size();
    }
    Test.assertEqual(count, 100);
    logger.debug("100 climbs persisted/read back; memory=" + System.getSystemStats().usedMemory);
    Test.assert(store.clear()); return true;
}
