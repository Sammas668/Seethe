# Stage 5.3c — Persistent Health, Nonlethal Recovery and Injured Deployment

## Authority

Permanent campaign characters now own persistent health state:

- current lethal HP;
- nonlethal damage;
- recovery progress for each pool;
- strategic health condition;
- permanent death.

A legacy or newly created character without an initialised health record resolves at full maximum HP with zero nonlethal damage. The first committed mission result initialises the persistent record.

## Mission transfer

At deployment:

- the resolved maximum HP comes from the normal character-resolution pipeline;
- persistent current HP becomes tactical current HP;
- persistent nonlethal damage becomes tactical nonlethal damage.

At mission resolution:

- final tactical current HP is committed back to the permanent character;
- final tactical nonlethal damage is committed separately;
- neither pool is automatically restored;
- permanent death remains authoritative.

The generic Wounded and Gravely Wounded labels are no longer stored as injury strings. They are derived from persistent health. Authored lasting injuries remain separate entries.

## Strategic conditions

- **Ready** — full HP, zero nonlethal damage and no lasting injury.
- **Wounded** — below full HP, carrying nonlethal damage or carrying a lasting injury.
- **Gravely Wounded** — at or below half HP, at zero/negative HP, or unconscious from nonlethal damage.
- **Dead** — permanently lost.

## Deployment rule

Conscious injured characters remain deployable and enter the mission with their exact persistent health values.

A character is health-blocked only while unconscious:

- current HP is zero or below; or
- nonlethal damage is at least current HP.

The briefing displays current HP and nonlethal damage and warns when injured characters are selected. Recovery pauses when a deployment reservation takes the character away from the stronghold.

## Recovery

Recovery advances only through strategic time while the character is physically at the stronghold and not reserved for deployment.

Base natural recovery:

- lethal HP: 4 points per day;
- nonlethal damage: 8 points per day.

Therefore equivalent nonlethal damage takes half as long to remove.

An operational Recovery Chamber increases lethal recovery by 2 points per day per facility level. Nonlethal recovery remains exactly twice the resulting lethal rate. A chamber under construction, damaged or disabled provides no bonus. A chamber being upgraded retains its current-level benefit.

Recovery uses integer healing units so partial-day progress survives save/load without floating-point drift.

## UI

The roster and character dossier now show:

- persistent current/max HP;
- nonlethal damage;
- Wounded or Gravely Wounded state;
- lethal and nonlethal recovery estimates;
- treatment source;
- whether recovery is active or paused;
- whether the character is unconscious or may deploy injured.
