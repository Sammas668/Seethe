from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]

session = (ROOT / "application/tactical/tactical_session.gd").read_text()
facade = (ROOT / "application/tactical/facades/tactical_screen_facade.gd").read_text()

errors = []

required_session = [
    'const TACTICAL_SCREEN_FACADE_SCRIPT: Script = preload(',
    '"res://application/tactical/facades/tactical_screen_facade.gd"',
    'screen_facade = TACTICAL_SCREEN_FACADE_SCRIPT.new(',
]
for token in required_session:
    if token not in session:
        errors.append(f"tactical_session.gd is missing: {token}")

if re.search(r'var\s+screen_facade\s*:\s*TacticalScreenFacade\b', session):
    errors.append("TacticalSession still depends on global TacticalScreenFacade type discovery.")
if 'screen_facade = TacticalScreenFacade.new(' in session:
    errors.append("TacticalSession still instantiates the global class directly.")

required_facade = [
    'const MOVEMENT_PREVIEW_QUERY_SCRIPT: Script = preload(',
    'const ACTION_AVAILABILITY_QUERY_SCRIPT: Script = preload(',
    '_movement_query = MOVEMENT_PREVIEW_QUERY_SCRIPT.new(',
    '_action_query = ACTION_AVAILABILITY_QUERY_SCRIPT.new(',
]
for token in required_facade:
    if token not in facade:
        errors.append(f"tactical_screen_facade.gd is missing: {token}")

presentation_files = [
    ROOT / "presentation/tactical/tactical_screen.gd",
    ROOT / "presentation/tactical/tactical_board_view.gd",
    ROOT / "presentation/tactical/unit_management_window.gd",
]
for path in presentation_files:
    text = path.read_text()
    if re.search(r':\s*TacticalScreenFacade(?:Type)?\b', text):
        errors.append(f"{path.relative_to(ROOT)} still requires global facade type resolution.")

for path in [
    ROOT / "application/tactical/tactical_session.gd",
    ROOT / "application/tactical/facades/tactical_screen_facade.gd",
    *presentation_files,
]:
    for line_number, line in enumerate(path.read_text().splitlines(), 1):
        if line.startswith(" "):
            errors.append(
                f"{path.relative_to(ROOT)}:{line_number} uses leading spaces instead of tabs."
            )

if errors:
    print("Stage 3.16.2 static validation FAILED.")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("Stage 3.16.2 static validation passed.")
print(" - TacticalScreenFacade and its new query dependencies load explicitly.")
print(" - Presentation no longer depends on global facade class discovery order.")
