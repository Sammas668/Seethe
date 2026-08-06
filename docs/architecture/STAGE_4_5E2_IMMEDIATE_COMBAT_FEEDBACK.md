# Stage 4.5e2 — Immediate Combat Feedback and Post-Attack Refresh Consolidation

## Purpose

Improve the complete attack loop from click to impact to next action. Stage 4.5e1 made entry into targeting responsive; Stage 4.5e2 removes duplicated commit-time geometry and prevents broad presentation reconciliation from delaying the hit reaction.

## Commit-time preview contract

The exact preview already contains authoritative attack geometry, cover, automatic Lean origin, attack bonus, hit chance and damage data together with expected tactical and geometry revisions.

When those revisions still match, `AttackPreviewQuery.validate_committed_preview()` checks only current legality:

- attacker, target and attack still exist;
- the target remains hostile and available;
- the action is still granted by the equipped weapon;
- capacity or Reaction remains available;
- current controller and target visibility remain legal;
- range or melee reach remains legal;
- the accepted preview had line of sight, line of effect and less than Total Cover.

It does not call the complete `execute()` preview path and does not rebuild exposure samples, cover, automatic Lean, hit chance or display text.

If a provoking Reaction changes the state revision, the facade rebuilds the ordinary attack preview before entering this validator, preserving authoritative revalidation.

## Combat-impact ordering

`TacticalChangeSet.publish_post_commit()` runs after authoritative mutation and combat-journal publication but before `TacticalStateStore.state_changed`.

The attack handler uses that boundary to publish the committed damage event:

```text
commit mutation
→ publish combat log
→ publish immediate combat impact
→ state_changed
→ deferred broad reconciliation
```

The target badge reads the already committed life state and the red pulse/shake begins immediately. The artwork reaction remains non-blocking and does not control combat rules.

## Consolidated post-attack refresh

`attack_resolved` state changes are queued by the tactical screen and collapsed into one deferred reconciliation. This provides a rendered impact frame before the broad HUD, initiative, selection, board and perception work.

The successful direct-attack and explicit-confirm paths do not perform an additional `_refresh_all_presentation()` after the facade returns.

The consolidated reconciliation:

- updates attacker capacity and Reaction state;
- synchronises target life-state presentation;
- processes alert and initiative changes;
- requests the normal post-commit perception flush;
- refreshes the relevant HUD and board once.

## Contextual preview and target-list policy

After an attack, the old contextual target preview is cleared. The consolidated refresh passes `refresh_contextual_attack = false`, so the target under an unmoved cursor is not immediately previewed again.

A new contextual preview is requested by later mouse movement.

Legal target IDs are cleared and marked dirty. They are not rescanned synchronously after the attack. When explicit targeting remains active, one lazy scan occurs after a rendered frame.

## Performance reporting

F9 reports:

- commit-preview validations, reuse and failures;
- last commit-validation time;
- total attack commit time;
- combat-impact events emitted;
- immediate impact presentations;
- consolidated post-attack reconciliations;
- duplicate broad refreshes avoided;
- last post-attack reconciliation time.

## Locked exclusions

This patch does not alter:

- attack rolls, critical confirmation or damage;
- cover, line of sight, line of effect or automatic Lean;
- provoking Reactions or Reaction prompts;
- Stealth, alert or initiative rules;
- action costs or repeated attacks;
- movement interruption or hit-reaction duration.
