#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", required=True)
    parser.add_argument("--project", default=".")
    parser.add_argument("--manifest", default="tests/runtime/stage_4_5g_runtime_suite.json")
    parser.add_argument("--report", default="STAGE_4_5G_RUNTIME_VALIDATION_RESULTS.txt")
    parser.add_argument("--stop-on-failure", action="store_true")
    args = parser.parse_args()

    root = Path(args.project).resolve()
    manifest = json.loads((root / args.manifest).read_text(encoding="utf-8"))
    godot = Path(args.godot).resolve()
    if not godot.exists():
        print(f"Godot executable not found: {godot}", file=sys.stderr)
        return 2

    rows = []
    failed = False
    version = subprocess.run([str(godot), "--version"], text=True, capture_output=True)
    for suite in manifest["suites"]:
        runner = suite["runner"].replace("res://", "")
        if not (root / runner).exists():
            rows.append((suite["id"], "MISSING", 0.0, "Runner file is missing"))
            failed = failed or suite.get("required", True)
            if failed and args.stop_on_failure:
                break
            continue
        cmd = [str(godot), "--headless", "--path", str(root), "--script", suite["runner"]]
        started = time.monotonic()
        try:
            proc = subprocess.run(cmd, text=True, capture_output=True, timeout=suite.get("timeout_seconds", 120))
            elapsed = time.monotonic() - started
            status = "PASS" if proc.returncode == 0 else "FAIL"
            output = (proc.stdout + "\n" + proc.stderr).strip()
        except subprocess.TimeoutExpired as exc:
            elapsed = time.monotonic() - started
            status = "TIMEOUT"
            output = ((exc.stdout or "") + "\n" + (exc.stderr or "")).strip()
        rows.append((suite["id"], status, elapsed, output))
        if status != "PASS" and suite.get("required", True):
            failed = True
            if args.stop_on_failure:
                break

    lines = [
        "SEETHE STAGE 4.5G RUNTIME VALIDATION",
        f"Godot: {(version.stdout or version.stderr).strip()}",
        f"Project: {root}",
        "",
    ]
    for suite_id, status, elapsed, output in rows:
        lines.append(f"{suite_id}: {status} ({elapsed:.3f}s)")
        if output:
            lines.extend(f"  {line}" for line in output.splitlines())
    lines.append("")
    lines.append("Overall: FAIL" if failed else "Overall: PASS")
    (root / args.report).write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
