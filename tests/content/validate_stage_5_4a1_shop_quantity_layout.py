from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
shell = (ROOT / "presentation/campaign/campaign_shell.gd").read_text(encoding="utf-8")

required = (
    'quantity_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL',
    'quantity_label.autowrap_mode = TextServer.AUTOWRAP_OFF',
    'quantity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL',
    'quantity_edit.custom_minimum_size = Vector2(54, 36)',
    'quantity_controls.size_flags_horizontal = Control.SIZE_SHRINK_END',
)
for token in required:
    assert token in shell, f"Missing Stage 5.4A1 quantity-layout token: {token}"

assert 'quantity.custom_minimum_size.x = 120' not in shell, (
    "The oversized legacy Shop quantity field is still present."
)
assert 'var quantity := SpinBox.new()' not in shell, (
    "The legacy SpinBox quantity control was restored."
)

print("Stage 5.4A1 Shop quantity layout validation passed.")
