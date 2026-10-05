# Decisions

## 2026-10-04 — Tooling and implementation gates

Decision: use Garmin's official Connect IQ SDK 9.2.0, downloaded directly into `/private/tmp/garmin-sdk`. Finish environment inspection and obtain official compiler/simulator device definitions before feature implementation.

Alternatives: guess product identifiers, generate substitute compiler definitions, or write uncompiled code against web documentation.

Reason: the specification requires installed SDK verification and successful compilation at integration milestones. The SDK does not bundle device packages; first-time SDK Manager setup was pending at inventory and was completed during M0.

Impact: implementation is awaiting official fēnix 8 device downloads. No build/test pass or sideload artifact is claimed.

## 2026-10-04 — Agent model availability

Decision: use Sol for architecture, review, and the implementation roles assigned to Terra; use Luna for inventory, resources, and documentation.

Alternatives: leave implementation roles unassigned.

Reason: Terra is not an available model in this session.

Impact: logical roles and strict file ownership remain, with Sol covering implementation.

## 2026-10-04 — Planned API floor and permissions

Decision: minimum API 4.2.3, `Fit` and `Sensor` permissions, rock climbing sport with generic sub-sport for the entire session.

Alternatives: API 3.2.0 without multitasking callbacks; fixed indoor/bouldering sub-sport; GPS sampling.

Reason: SDK confirms fēnix 8 multitasking lifecycle callbacks at 4.2.3 and barometer-first altitude through Sensor.getInfo. Mixed climbs require stable session classification.

Impact: no Positioning or Background permission is planned. Recheck against downloaded compiler definitions and compilation before adoption in a manifest.

## 2026-10-04 — Local signing key

Decision: generate an RSA-4096 PKCS#8 DER key at `/private/tmp/climb-signing/developer_key.der`, with private directory/file permissions, outside the repository.

Alternatives: require an existing user key or store a new key in the project.

Reason: the compiler requires a key; no existing key was discovered. Local generation does not require Garmin Store registration.

Impact: ready for local sideload builds once device definitions arrive. This temporary key must be preserved securely for continuity if used for ongoing builds; it is never committed or printed.

## 2026-10-04 — Foundation review recovery

Decision: clear cached altitude and heart rate on pause/resume; establish the next baseline from a fresh sample. Preserve failed history pages in a bounded retry map and rotate at sixteen entries even if the storage write fails. Publish the header only after pending pages are written. Skip native sensor cleanup after inactivity because Garmin disables sensors for the inactive app.

Alternatives: retain pre-pause values; discard failed pages; invoke sensor APIs and catch inactive exceptions.

Reason: stale barometer baselines produce false height, failed boundary writes must not grow storage values indefinitely, and inactive sensor changes are prohibited by the SDK.

Impact: storage retries use memory only for failed pages, capped by the 256-attempt session limit. Users see a history error while pending writes remain. The regression suite verifies recovery from a failed sixteenth-entry write through a full 256-attempt workout. Production diagnostics require `AppConstants.DEBUG_BUILD`; persistent debug preferences cannot enable the production debug page.

## 2026-10-04 — Conservative altitude recovery

Decision: wait for a full five-sample median window before emitting filtered altitude after initialization, missing altitude, or a sample gap over 2500 ms. Clear current relative height while altitude is unavailable; preserve established baseline and peak metrics. Require at least five seconds between logical climb start and the strict altitude peak for Rope auto-ending. Expire a descent trend if no qualifying negative step arrives within 1500 ms.

Alternatives: emit a partial-window median immediately; hold the first recovery reading; measure minimum duration at delayed detection time; keep stalled descent history indefinitely.

Reason: review reproduced an automatic false ending when a single high spike entered a two-sample recovery median. Holding the first reading also fails when that first reading is the spike. Full-window median initialization rejects isolated spikes in every warmup position.

Impact: approximately four seconds of unavailable altitude during sensor warmup at a one-second tick. Manual start/finish remains available throughout. All 26 M3 tests passed, including integrated recovery and pause-confirmation peak alignment. Independent Sol review approved these changes; hardware calibration remains separate.

## 2026-10-04 — Statistics outside drawing

Decision: calculate session statistics in controller refresh/lifecycle operations and expose a cached dictionary to the view.

Alternatives: walk the bounded climb history each time the view draws.

Reason: drawing may happen more often than sensor ticks. The view should render prepared values rather than aggregate workout history.

Impact: statistics refresh with the application tick and input changes. Save and shutdown refresh the cache before writing persisted summary data.

## 2026-10-04 — Auto logical start is the candidate threshold point

Decision: capture Auto's logical climb start timestamp and altitude on the sample that enters `POSSIBLE_START`, after the selected candidate-gain and upward-sample requirements are reached. Keep confirmation gain measured from the original resting-ascent onset. Replay heart-rate samples into the climb only from the logical candidate timestamp onward.

Alternatives: backdate the climb to the first upward sample, or use the candidate altitude as the origin for the confirmation-gain test.

Reason: early upward movement can be incidental; recording begins when the candidate threshold identifies sustained movement, while confirmation still requires a larger total rise from its resting origin. This keeps the candidate-entry point as the stable baseline and start of recorded duration.

Impact: climb-relative height excludes the gain before candidate entry. The session HR accumulator already includes those earlier samples; replay starts at candidate entry and does not double count session HR. Equality qualifies for candidate/confirmation thresholds because comparisons use `>=`. Auto has passed its software integration gate but remains experimental pending physical threshold calibration.

## 2026-10-04 — Compare Monkey C strings by value

Decision: use `String.equals()` for semantic comparisons of Monkey C string values, including detector event kinds and test result names.

Alternatives: use `==` as if string objects were guaranteed to be identical references.

Reason: event routing and tests should compare string contents, not object identity; separately allocated equal strings must follow the same code path.

Impact: tests and controller routing assert the actual string value. Type-sensitive numeric and dictionary comparisons continue to use the appropriate `Test.assertEqual` checks.

## 2026-10-04 — Clear sensor/filter warmup after context changes

Decision: clear the altitude filter window, filtered snapshot, and Auto history at rest-menu entry, completed attempts, mode changes, and sensitivity changes. Require a fresh five-sample median window before automatic detection resumes. Preserve the active climb's established domain baseline and peak through pause/inactivity while breaking detector trend continuity.

Alternatives: carry EMA and candidate history through menu/settings transitions, or discard the active climb's peak along with volatile sensor values.

Reason: stale barometric slope after menu movement or mode/preset changes can look like a delayed Auto start. Retaining an active climb's established peak avoids losing meaningful progress, while a fresh filter window prevents old raw values from joining post-transition readings.

Impact: automatic altitude decisions wait for five new valid samples after these rest-state transitions. Manual start/finish remains available; resumed active climbs preserve their recorded start/peak and rebuild only detector continuity.

## 2026-10-04 — Isolate and pace native simulator FIT fixtures

Decision: close any stranded native recording before the FIT fixture, pace native lap events more than two seconds apart in simulator-only tests, and fully quit/relaunch Connect IQ Simulator before a fresh full suite or final FIT fixture capture.

Alternatives: issue native lap events in the same second and reuse an already-running simulator process for repeated captures.

Reason: simulator `ActivityRecording` rejects repeated same-second lap events and can retain a native session across test/app runs. The test helper waits 2,100 ms between fixture lap events; a clean simulator process avoids contamination by a prior native recording.

Impact: the FIT golden and controller-acceptance files are reproducible with four native lap messages (three climb laps and the cleared tail lap). The normal in-memory unit tests remain fast and do not use this native pacing helper.

## 2026-10-04 — Persist signing key outside the project

Decision: keep the developer signing key at `$HOME/.garmin-climb/developer_key.der`, with a mode `0700` parent directory and mode `0600` key file; builds reference it through `CIQ_KEY` or `--key`.

Alternatives: keep a transient key under `/private/tmp`, store it in the repository, or embed the machine-specific path in committed editor settings.

Reason: release builds need a stable local key, while the private key must remain secret and project documentation should remain portable.

Impact: the key is retained outside the repository and its contents are never printed or documented. Users provide their own key path in another environment.


## 2026-10-04 — Preserve headings and remove page instructions

Decision: clear the display with black, then render all page text with a transparent background. Remove button instructions from every metric and summary page; controls remain documented in the README.

Alternatives: move headings farther from the timer or reduce the timer font.

Reason: number-font bounding boxes include blank padding. Drawing those boxes with an opaque background erased the lower portions of previously drawn headings, as shown in the supplied simulator screenshots. Transparent text preserves existing pixels without shrinking the main metrics. The user explicitly requested pages without button hints.

Impact: headings remain intact, and pages show workout information. A rendering-contract regression exercises all normal states/pages at 260, 280, 416, and 454 pixels, checks transparent text drawing, and rejects button instructions. No input behavior changes.


## 2026-10-05 — Use the supplied climbing illustration as the launcher icon

Decision: retain the exact supplied PNG at `resources/drawables/launcher_icon.png` and let Garmin's resource compiler scale it to 65 pixels for the default AMOLED profiles, 60 pixels for the 43mm profile, and 40 pixels for the Solar profiles. All variants reference the same source artwork; obsolete mountain SVG icons are removed.

Reason: the user requested this image as the app icon. Native bitmap scaling keeps the original artwork intact and produces resources suitable for each supported watch.

Validation: all five signed release builds passed without compiler warnings; the manifest continues to use `@Drawables.LauncherIcon`.

## 2026-10-05 — Indoor training outcomes and navigation

Renamed the displayed app and native recording to Climb Indoor Training. BACK exits pre-start without a recording. The view renders left-side page indicators only when multiple data pages exist. A completed valid attempt requires Success/Failed selection with UP/DOWN and START before continuation; classification precedes FIT lap closure and native pause. Short nonzero-duration failures count; a zero-time accidental lap remains cancelled. Forced shutdown preserves an unrated outcome, excluded from the success-rate denominator. Summary pages and FIT expose overall and per-mode outcomes.

Native testing demonstrated a 16-field session-message limit: creating the seventeenth session developer field raises a System Error. Use bounded readable “Success / Failed” pairs for each type and retire redundant developer session HR/schema fields (IDs 25–27, never reused); native recording HR and per-climb HR remain. Schema v2 has 13 lap fields / 28 bytes and 16 session fields / 68 bytes, with 30 combined string bytes. The golden native FIT shows successful Rope, failed Boulder, successful Auto and 66.7% success.

Create local signed production and separate-ID private beta IQ packages to make the Connect integration reviewable. No Garmin account upload or public release is performed; official SDK Beta Apps documentation explains the remaining upload/install/sync step.
