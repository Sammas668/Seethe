# Stage 4.1.1 — Direct Weapon Targeting

The tactical HUD now treats held weapons as the attack selectors. The old visible Attack tab is removed.

## Player flow

1. Click the Primary or Secondary held weapon.
2. Configure Normal/Lethal/Nonlethal and Power Attack above the weapons.
3. Hover a hostile unit to see hit chance, damage, cost and mode at the cursor.
4. Left-click to execute the current attack.
5. Right-click a hostile to cycle lethal/nonlethal mode.

Empty terrain still previews and executes movement while a weapon is selected. Invalid targets use the forbidden cursor and explain why the attack cannot occur. Enemy AI continues to call the application attack resolver directly and has no dependency on these presentation controls.
