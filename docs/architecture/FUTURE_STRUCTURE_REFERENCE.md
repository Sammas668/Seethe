# Future Structure Reference

This file records the intended expansion direction without physically creating every folder.

Add these only when required.

```text
domain/<feature>/
├── definitions/
├── state/
├── rules/
└── enums/

application/<feature>/
├── commands/
├── handlers/
├── queries/
└── coordinators/      # only when cross-feature workflow exists

presentation/screens/<screen>/
├── <screen>.tscn
├── <screen>.gd
├── <screen>_view_model.gd
├── <screen>_controller.gd   # optional
└── <screen>_presenter.gd    # optional

content/archetypes/<archetype_id>/
├── <archetype_id>_definition.tres
├── abilities/
├── troops/
├── facilities/
├── research/
└── strategic_actions/

content/regions/<region_id>/
├── region_definition.tres
├── hexes/
├── sites/
├── routes/
├── factions/
├── opportunities/
├── story_events/
└── raids/

content/missions/<mission_or_map_id>/
├── mission_definition.tres
├── tactical_map.tscn
├── objectives/
├── variants/
└── validation/
```

## Future feature homes

- Research permanent knowledge: `domain/research/`
- Active Research timing: `domain/projects/`
- Production recipes/rules: `domain/production/`
- Active production timing: `domain/projects/`
- Captive processing state: `domain/captives/`
- Captive identity and injuries: `domain/characters/`
- Base-defence assembly: `application/stronghold/assembly/`
- Editor tools: `addons/seethe_tools/`
- Save inspection/debug launchers: `tools/`
- Additional classes: `content/classes/<class_id>/`
- Additional archetypes: `content/archetypes/<archetype_id>/`
- Shared Research only: `content/research/universal/`, `class/`, `hybrid/`
- Generic facilities only: `content/facilities/generic/`

Do not add global `content/facilities/archetype/` or `content/research/archetype/` trees. Archetype-specific content belongs with the archetype.
