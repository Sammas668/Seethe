#!/usr/bin/env python3
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRODUCTION_ROOTS = [ROOT / "application", ROOT / "bootstrap", ROOT / "infrastructure"]


def iter_gdscript():
    for base in PRODUCTION_ROOTS:
        if base.exists():
            yield from base.rglob("*.gd")


def find_calls(text: str, token: str):
    start = 0
    while True:
        idx = text.find(token, start)
        if idx < 0:
            return
        open_idx = text.find("(", idx + len(token))
        depth = 0
        in_string = False
        escape = False
        for pos in range(open_idx, len(text)):
            ch = text[pos]
            if in_string:
                if escape:
                    escape = False
                elif ch == "\\":
                    escape = True
                elif ch == '"':
                    in_string = False
                continue
            if ch == '"':
                in_string = True
            elif ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth == 0:
                    yield idx, text[open_idx + 1 : pos]
                    start = pos + 1
                    break
        else:
            return


def count_top_level_args(body: str) -> int:
    if not body.strip():
        return 0
    depths = {"(": 0, "[": 0, "{": 0}
    pairs = {")": "(", "]": "[", "}": "{"}
    commas = 0
    in_string = False
    escape = False
    for ch in body:
        if in_string:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == '"':
                in_string = False
            continue
        if ch == '"':
            in_string = True
        elif ch in depths:
            depths[ch] += 1
        elif ch in pairs:
            depths[pairs[ch]] -= 1
        elif ch == "," and all(v == 0 for v in depths.values()):
            commas += 1
    return commas + 1


def main() -> int:
    failures: list[str] = []
    transaction_count = 0
    for path in iter_gdscript():
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT)
        for _, body in find_calls(text, "TacticalChangeSet.new"):
            transaction_count += 1
            if count_top_level_args(body) < 3:
                failures.append(f"{rel}: production TacticalChangeSet lacks explicit invalidation contract")
        if "TacticalInvalidationFlags.for_reason(" in text:
            failures.append(f"{rel}: production reason-derived invalidation remains")
        if ".set_invalidation_flags(" in text and rel.as_posix() != "application/tactical/transactions/tactical_change_set.gd":
            failures.append(f"{rel}: production compatibility invalidation setter remains")

    change_set = (ROOT / "application/tactical/transactions/tactical_change_set.gd").read_text(encoding="utf-8")
    if "tactical_invalidation_contract_missing" not in change_set:
        failures.append("TacticalChangeSet does not fail a missing invalidation contract")
    if "TacticalTransactionSnapshot.capture" not in change_set:
        failures.append("TacticalChangeSet does not use the typed transaction snapshot")

    setup = (ROOT / "domain/missions/mission_setup_snapshot.gd").read_text(encoding="utf-8")
    for required in ["verify_integrity", "CanonicalDataHasher.sha256_hex", "var _mission_id", "var _finalized_setup_hash"]:
        if required not in setup:
            failures.append(f"MissionSetupSnapshot missing {required}")
    if re.search(r"^var mission_id:\s*StringName\s*=", setup, re.M):
        failures.append("MissionSetupSnapshot still exposes writable mission identity")

    result = (ROOT / "domain/missions/mission_result.gd").read_text(encoding="utf-8")
    if "source_setup_hash" not in result or "generated_item_provenance_ids" not in result:
        failures.append("MissionResult is not bound to setup hash and trusted provenance IDs")
    if "authorize_generated_item" in result:
        failures.append("MissionResult can still authorise its own generated item")

    provenance = ROOT / "domain/tactical/items/tactical_generated_item_provenance.gd"
    authority = ROOT / "domain/missions/mission_authority_snapshot.gd"
    envelope = ROOT / "domain/missions/mission_commit_envelope.gd"
    for required_path in [provenance, authority, envelope]:
        if not required_path.exists():
            failures.append(f"Missing authority file {required_path.relative_to(ROOT)}")

    store = (ROOT / "application/tactical/tactical_state_store.gd").read_text(encoding="utf-8")
    if "nested_tactical_commit_forbidden" not in store:
        failures.append("TacticalStateStore does not reject direct nested commits")
    if "commit_after_notifications" not in store:
        failures.append("TacticalStateStore has no post-notification commit queue")

    attack = (ROOT / "application/tactical/combat/attack_handler.gd").read_text(encoding="utf-8")
    if "TacticalInvalidationContract.attack" not in attack:
        failures.append("AttackHandler does not own an explicit attack contract")

    if failures:
        print("Stage 4.5g architecture validation FAILED")
        for failure in failures:
            print(f" - {failure}")
        return 1
    print(f"Stage 4.5g architecture validation PASSED ({transaction_count} production transactions checked)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
