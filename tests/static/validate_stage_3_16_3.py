from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRESENTATION_FILES = [
    ROOT / "presentation/tactical/tactical_screen.gd",
    ROOT / "presentation/tactical/tactical_board_view.gd",
    ROOT / "presentation/tactical/unit_management_window.gd",
]

errors: list[str] = []


def variable_statements(text: str):
    lines = text.splitlines()
    index = 0
    while index < len(lines):
        line = lines[index]
        if line.lstrip().startswith("var ") and ":=" in line:
            statement = line
            balance = sum(statement.count(char) for char in "([{")
            balance -= sum(statement.count(char) for char in ")]}")
            end_index = index
            while balance > 0 and end_index + 1 < len(lines):
                end_index += 1
                statement += "\n" + lines[end_index]
                balance = sum(statement.count(char) for char in "([{")
                balance -= sum(statement.count(char) for char in ")]}")
            yield index + 1, statement
            index = end_index
        index += 1


for path in PRESENTATION_FILES:
    text = path.read_text(encoding="utf-8")
    for line_number, statement in variable_statements(text):
        if "_facade" in statement or "screen_facade" in statement:
            errors.append(
                f"{path.relative_to(ROOT)}:{line_number} infers a variable from "
                "the dynamically loaded facade. Use an explicit type."
            )

window = PRESENTATION_FILES[2].read_text(encoding="utf-8")
required_tokens = [
    "var unit: TacticalUnitState = _facade.state().get_unit(_current_unit_id)",
    "var state: TacticalState = _facade.state()",
    "var preview: TacticalInventoryTransferPreview = _facade.preview_inventory_transfer(command)",
    "var result: OperationResult = _facade.execute_inventory_transfer_plan(preview.plan, preview)",
]
for token in required_tokens:
    if token not in window:
        errors.append(f"unit_management_window.gd is missing explicit typing: {token}")

for path in PRESENTATION_FILES:
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if line.startswith(" "):
            errors.append(
                f"{path.relative_to(ROOT)}:{line_number} uses leading spaces instead of tabs."
            )

if errors:
    print("Stage 3.16.3 static validation FAILED.")
    for error in errors:
        print(" -", error)
    raise SystemExit(1)

print("Stage 3.16.3 static validation passed.")
print(" - Presentation variables returned through the dynamically loaded facade use explicit types.")
print(" - Unit-management, board and tactical-screen facade calls cannot trigger Variant inference warnings.")
