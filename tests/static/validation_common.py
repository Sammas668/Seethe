from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def require_file(path: str, failures: list[str]) -> str:
    target = ROOT / path
    if not target.is_file():
        failures.append(f"missing required file: {path}")
        return ""
    return target.read_text(encoding="utf-8")


def require_tokens(path: str, tokens: list[str], failures: list[str]) -> None:
    text = require_file(path, failures)
    if not text:
        return
    for token in tokens:
        if token not in text:
            failures.append(f"{path} missing required token: {token}")


def forbid_tokens(path: str, tokens: list[str], failures: list[str]) -> None:
    text = require_file(path, failures)
    if not text:
        return
    for token in tokens:
        if token in text:
            failures.append(f"{path} contains forbidden token: {token}")


def require_absent(path: str, failures: list[str]) -> None:
    if (ROOT / path).exists():
        failures.append(f"obsolete file remains: {path}")


def validate_resource_references(failures: list[str]) -> None:
    pattern = re.compile(r'res://([^"\'\s)\],]+)')
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix not in {".gd", ".tscn", ".tres", ".godot"}:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for match in pattern.finditer(text):
            reference = match.group(1).rstrip(".,;:")
            if not (ROOT / reference).exists():
                failures.append(
                    f"broken res:// reference in {path.relative_to(ROOT)}: res://{reference}"
                )


def validate_unique_class_names(failures: list[str]) -> None:
    seen: dict[str, Path] = {}
    pattern = re.compile(r"(?m)^class_name\s+([A-Za-z_][A-Za-z0-9_]*)\s*$")
    for path in ROOT.rglob("*.gd"):
        match = pattern.search(path.read_text(encoding="utf-8", errors="ignore"))
        if not match:
            continue
        name = match.group(1)
        if name in seen:
            failures.append(
                f"duplicate class_name {name}: {seen[name].relative_to(ROOT)} and {path.relative_to(ROOT)}"
            )
        else:
            seen[name] = path


def validate_tab_indentation(failures: list[str]) -> None:
    for path in ROOT.rglob("*.gd"):
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if line.startswith(" "):
                failures.append(
                    f"{path.relative_to(ROOT)}:{number} begins with spaces instead of tabs"
                )


def validate_balanced_delimiters(failures: list[str]) -> None:
    pairs = {")": "(", "]": "[", "}": "{"}
    for path in list(ROOT.rglob("*.gd")) + list(ROOT.rglob("*.tres")) + list(ROOT.rglob("*.tscn")):
        text = path.read_text(encoding="utf-8", errors="ignore")
        stack: list[str] = []
        in_string = False
        escaped = False
        in_comment = False
        for char in text:
            if in_comment:
                if char == "\n":
                    in_comment = False
                continue
            if in_string:
                if escaped:
                    escaped = False
                elif char == "\\":
                    escaped = True
                elif char == '"':
                    in_string = False
                continue
            if char == "#":
                in_comment = True
            elif char == '"':
                in_string = True
            elif char in "([{":
                stack.append(char)
            elif char in ")]}":
                if not stack or stack[-1] != pairs[char]:
                    failures.append(f"unbalanced delimiter in {path.relative_to(ROOT)}")
                    break
                stack.pop()
        else:
            if stack:
                failures.append(f"unclosed delimiter in {path.relative_to(ROOT)}")
            if in_string:
                failures.append(f"unclosed string in {path.relative_to(ROOT)}")


def finish(stage: str, failures: list[str], messages: list[str] | None = None) -> int:
    if failures:
        print(f"{stage} static validation FAILED:")
        for failure in failures:
            print(" -", failure)
        return 1
    print(f"{stage} static validation passed.")
    for message in messages or []:
        print(" -", message)
    return 0
