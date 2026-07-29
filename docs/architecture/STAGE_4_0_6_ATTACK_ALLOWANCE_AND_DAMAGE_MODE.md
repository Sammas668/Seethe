# Stage 4.0.6 — Attack allowance and damage mode

## Normal attack allowance

A normal attack remains a Half Action, but a unit can make only one normal
attack during an activation. Remaining normal movement capacity may still be
spent after that attack.

Multiple attacks require an authored Full Attack sequence. Stage 4.0.6 does
not implement Full Attack; it establishes the allowance that future Full
Attack actions bypass through their own sequence type.

## Lethal and nonlethal choice

Every supported weapon attack can be switched between lethal and nonlethal
damage in the attack-confirmation tray.

- Lethal damage reduces HP.
- Nonlethal damage increases the separate nonlethal total.
- Choosing nonlethal normally applies -4 to the attack roll and critical
  confirmation roll.
- `trait.take_them_alive` ignores this penalty when the weapon's damage type is
  blunt or bludgeoning.

The selected damage channel, penalty and any exemption are stored in the
preview and structured combat event.

## Authoritative rule correction

This milestone deliberately supersedes the earlier prototype text that allowed
additional ordinary attacks at cumulative -5. In the implemented Seethe action
economy, a normal attack is limited to once per activation. Cumulative and
iterative penalties belong inside an authored Full Attack sequence rather than
being purchased with leftover movement capacity.
