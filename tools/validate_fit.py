#!/usr/bin/env python3
"""Validate an exported Climb activity with Garmin's official FIT Python SDK."""
import argparse
import json
import math
from pathlib import Path


def named_fields(message, descriptions):
    return {descriptions[key]: value for key, value in message.get("developer_fields", {}).items()
            if key in descriptions}


def validate(path, expected_count=None, expected=None):
    from garmin_fit_sdk import Decoder, Stream
    if not Decoder(Stream.from_file(str(path))).check_integrity():
        raise ValueError("FIT header, size, or CRC validation failed")
    # Integrity checking consumes the stream; decode a fresh stream.
    messages, errors = Decoder(Stream.from_file(str(path))).read()
    if errors:
        raise ValueError(f"Garmin decoder errors: {errors}")
    files = messages.get("file_id_mesgs", [])
    if not files or files[0].get("type") != "activity":
        raise ValueError("Not a FIT activity file")
    sessions = messages.get("session_mesgs", [])
    if len(sessions) != 1 or sessions[0].get("sport") != "rock_climbing" or sessions[0].get("sub_sport") != "generic":
        raise ValueError("Expected one rock-climbing / generic session")
    definitions = messages.get("field_description_mesgs", [])
    descriptions = {d["key"]: d.get("field_name", d.get("name")) for d in definitions}
    if not descriptions:
        raise ValueError("No FIT developer field descriptions")
    identities = {}
    for d in definitions:
        identity = (d.get("developer_data_index"), d.get("field_definition_number"))
        name = descriptions[d["key"]]
        if identity in identities and identities[identity] != name:
            raise ValueError(f"Field ID reused for different names: {identity}")
        identities[identity] = name
    laps = [named_fields(lap, descriptions) for lap in messages.get("lap_mesgs", [])]
    climbs = [lap for lap in laps if lap.get("climb_number", 0) > 0]
    if expected_count is not None and len(climbs) != expected_count:
        raise ValueError(f"Expected {expected_count} climb laps, found {len(climbs)}")
    numbers = [lap["climb_number"] for lap in climbs]
    if numbers != list(range(1, len(climbs) + 1)):
        raise ValueError(f"Climb lap attribution duplicated or out of order: {numbers}")
    required = {"climb_number", "climb_mode", "climb_height", "climb_duration", "rest_before", "end_reason"}
    for lap in climbs:
        if not required.issubset(lap):
            raise ValueError(f"Missing climb fields: {required - lap.keys()}")
        if lap["climb_mode"] not in (1, 2, 3) or lap["end_reason"] not in (1, 2, 3, 4):
            raise ValueError(f"Invalid mode or end reason: {lap}")
        if lap["climb_duration"] < 0 or lap["rest_before"] < 0 or (lap["climb_height"] < 0 and lap["climb_height"] != -1):
            raise ValueError(f"Invalid climb metrics: {lap}")
    tails = [lap for lap in laps if lap.get("climb_number", 0) == 0]
    for tail in tails:
        if tail.get("climb_number") != 0 or tail.get("climb_mode") != 0 or tail.get("valid_values") != 0 or tail.get("attempt_id") != 0:
            raise ValueError("Unattributed or uncleared final/rest lap")
    summary = named_fields(sessions[0], descriptions)
    required_summary = {"total_climbs", "rope_climbs", "boulder_climbs", "auto_climbs", "total_vertical"}
    if not required_summary.issubset(summary):
        raise ValueError(f"Missing session fields: {required_summary - summary.keys()}")
    if summary["total_climbs"] != len(climbs):
        raise ValueError("Session count disagrees with attributed climb laps")
    for mode, field in [(1, "rope_climbs"), (2, "boulder_climbs"), (3, "auto_climbs")]:
        if summary[field] != sum(lap["climb_mode"] == mode for lap in climbs):
            raise ValueError(f"Session {field} disagrees with climb laps")
    vertical = sum(max(0, lap["climb_height"]) for lap in climbs)
    if not math.isclose(summary["total_vertical"], vertical, abs_tol=0.01):
        raise ValueError("Session vertical gain disagrees with climb heights")
    if "successful_climbs" in summary:
        for lap in climbs:
            if any(lap.get(key) not in (0, 1) for key in ("climb_success", "climb_failure", "climb_rated")):
                raise ValueError("Missing or invalid attempt outcome")
            if lap["climb_success"] + lap["climb_failure"] != lap["climb_rated"]:
                raise ValueError("Attempt outcome flags disagree")
        successes = sum(lap["climb_success"] for lap in climbs)
        failures = sum(lap["climb_failure"] for lap in climbs)
        rated = successes + failures
        if summary.get("successful_climbs") != successes or summary.get("failed_climbs") != failures:
            raise ValueError("Session results disagree with climb laps")
        if summary.get("unrated_climbs") != len(climbs) - rated:
            raise ValueError("Unrated count disagrees with climb laps")
        percent = successes * 100 / rated if rated else -1
        if not math.isclose(summary.get("success_percent", -2), percent, abs_tol=0.01):
            raise ValueError("Success percentage disagrees with rated attempts")
        for mode, prefix in [(1, "rope"), (2, "boulder"), (3, "auto")]:
            mode_laps = [lap for lap in climbs if lap["climb_mode"] == mode]
            expected_results = f'{sum(lap["climb_success"] for lap in mode_laps)} / {sum(lap["climb_failure"] for lap in mode_laps)}'
            if summary.get(prefix + "_results") != expected_results:
                raise ValueError(f"{prefix} outcome breakdown disagrees with climb laps")
        for tail in tails:
            if any(tail.get(key) != 0 for key in ("climb_success", "climb_failure", "climb_rated")):
                raise ValueError("Final/rest lap retained an attempt outcome")
    result = {"integrity": True, "decoder_errors": [], "sport": "rock_climbing", "sub_sport": "generic",
              "native_laps": len(laps), "climbs": climbs, "summary": summary,
              "developer_fields": list(descriptions.values())}
    if expected:
        if len(laps) != len(expected["climbs"]) + 1:
            raise ValueError("Fixture must contain exactly the climb laps and one cleared tail")
        comparisons = list(zip(climbs, expected["climbs"]))
        if "summary" in expected:
            comparisons.append((summary, expected["summary"]))
        for actual, wanted in comparisons:
            for key, value in wanted.items():
                found = actual.get(key)
                if isinstance(value, (int, float)):
                    if found is None or not math.isclose(found, value, abs_tol=0.01):
                        raise ValueError(f"Fixture {key}: expected {value}, got {found}")
                elif found != value:
                    raise ValueError(f"Fixture {key}: expected {value}, got {found}")
        if len(climbs) != len(expected["climbs"]):
            raise ValueError("Fixture climb count mismatch")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fit", type=Path)
    parser.add_argument("--expect-climbs", type=int)
    parser.add_argument("--expected", type=Path, help="JSON fixture containing expected climb field dictionaries")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        result = validate(args.fit, args.expect_climbs, json.loads(args.expected.read_text()) if args.expected else None)
    except (ValueError, ImportError, OSError) as error:
        parser.exit(1, f"FIT validation failed: {error}\n")
    data = json.dumps(result, indent=2) + "\n"
    if args.output:
        args.output.write_text(data)
    print(data, end="")


if __name__ == "__main__":
    main()
