# FIT developer fields

Climb Indoor Training records one native rock-climbing/generic activity, with a lap for each completed attempt and developer-field totals in its session message. `source/FitSchema.mc` defines schema version 2; `resources/fitfields.xml` supplies Garmin Connect display metadata.

## Current recording evidence

[training-mixed-climbs.fit](../validation/training-mixed-climbs.fit) was decoded with Garmin FIT SDK 21.217.0 and checked against [fit-mixed-expected.json](../tests/fixtures/fit-mixed-expected.json). It has 29 developer fields, three climb laps, and exactly one cleared final/rest lap. Integrity and CRC pass with no decoder errors. Rope succeeded, Boulder failed, and Auto succeeded: 2 successful / 1 failed / 0 unrated, 66.7% success. Counts, per-type results, logical durations, altitude, and HR values all match the fixture.

The previous `mixed-climbs.fit/json` and `acceptance.fit/json` remain historical version-1 recordings; they predate outcome selection and must not be compared against the current version-2 expected file. The latest full regression report is [training-tests.log](../validation/training-tests.log).

Garmin Connect Mobile presentation has not been verified with a physical sync. The uploaded app’s FIT metadata is needed for Connect to display custom fields; [CONNECT_SETUP.md](CONNECT_SETUP.md) describes the prepared private beta package and account installation steps.

## Lap fields

All are registered with `displayInActivityLaps="true"`.

| ID | FIT name | Type | Meaning |
|---:|---|---|---|
| 0 | climb_number | uint16 | Completed-attempt number |
| 1 | climb_mode | uint8 | 1 Rope, 2 Boulder, 3 Auto (mapping included in display label) |
| 2 | climb_height | float | Height gain in m; -1 unavailable |
| 3 | climb_duration | float | Logical climbing duration in s |
| 4 | rest_before | float | Rest before attempt in s |
| 5 | end_reason | uint8 | 1 manual, 2 Rope descent, 3 Auto completion, 4 session stop |
| 6 | climb_avg_hr | float | Average bpm; -1 unavailable |
| 7 | climb_max_hr | uint16 | Maximum bpm; 65535 unavailable |
| 8 | attempt_id | uint16 | Attempt identifier |
| 9 | valid_values | uint8 | Height/average HR/maximum HR availability bits 0/1/2 |
| 10 | climb_success | uint8 | 1 successful; 0 otherwise |
| 11 | climb_failure | uint8 | 1 failed; 0 otherwise |
| 12 | climb_rated | uint8 | 1 result chosen; 0 unrated |

All outcome flags are cleared on the final/rest lap. Normal exits require a choice for a completed attempt; forced shutdown preserves it as explicitly unrated.

## Session fields

All are registered with `displayInActivitySummary="true"`.

| ID | FIT name | Type | Meaning |
|---:|---|---|---|
| 13 | rope_results | string[10] | Success / Failed counts for Rope |
| 14 | boulder_results | string[10] | Success / Failed counts for Boulder |
| 15 | auto_results | string[10] | Success / Failed counts for Auto |
| 16 | total_climbs | uint16 | Completed attempts |
| 17 | rope_climbs | uint16 | Rope attempts |
| 18 | boulder_climbs | uint16 | Boulder attempts |
| 19 | auto_climbs | uint16 | Auto attempts |
| 20 | total_vertical | float | Total available height gain in m |
| 21 | max_climb_height | float | Maximum gain in m; -1 unavailable |
| 22 | climbing_time | float | Active climbing time in s |
| 23 | rest_time | float | Rest time in s |
| 24 | elapsed_time | float | Active session elapsed time in s |
| 28 | successful_climbs | uint16 | Successful attempts |
| 29 | failed_climbs | uint16 | Failed attempts |
| 30 | success_percent | float | Successes / (successes + failures) × 100; -1 when unrated/empty |
| 31 | unrated_climbs | uint16 | Completed attempts without a chosen result |

IDs 25–27 (duplicate developer session HR fields and schema marker) are retired and never reused. Native activity HR remains available from Garmin’s recording; per-climb HR is retained. The native simulator rejects a seventeenth session developer field, so outcome pairs use three readable string fields and the redundant developer summary fields were removed. The final schema has 13 lap fields / 28 bytes and 16 session fields / 68 bytes; its three bounded strings use 30 bytes combined. Tests enforce these limits. At the 256-attempt history cap, a pair such as “256 / 0” fits comfortably.

## Reproduce FIT validation

Run `nativeFitMixedFixture` alone in a fresh simulator. Saved FIT files are under `$TMPDIR/com.garmin.connectiq/GARMIN/Activities`. Copy the newest saved file and decode it:

```sh
/private/tmp/climb-fit-tools/bin/python tools/validate_fit.py \
  validation/training-mixed-climbs.fit --expect-climbs 3 \
  --expected tests/fixtures/fit-mixed-expected.json \
  --output validation/training-mixed-climbs.json
```

The validator checks integrity, field identity, lap order, outcome flags, totals, percentages, per-type pairs, and cleared tail values, then compares the deterministic fixture values.
