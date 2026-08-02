# Regiment data schema (v1)

The root object provides `schema_version`, `content_version`, `budget`, `maximum_doctrines`, catalog dictionaries, `base_effects`, and `options`.

Each option has:

```json
{
  "id": "stable_snake_case_id",
  "category": "home_world | commander | regiment_type | training_doctrine | equipment_doctrine",
  "name": "Display name",
  "cost": 0,
  "summary": "Short original summary",
  "effects": {},
  "choices": [],
  "requirements": { "all": [], "any": [] },
  "excludes": [],
  "source": { "book": "source_catalog_id", "page": 0 }
}
```

Supported effect keys are:

- `characteristics`: map of characteristic name to signed integer.
- `skills`: array of skill catalog IDs. Grants advance through Known, Trained (+10), Experienced (+20), and Veteran (+30), capped by the catalog's `maximum_rank`.
- `talents`: array of talent catalog IDs. Stackable talents keep a count. Each extra grant of a non-stackable starting Talent is converted to 100 bonus XP per character.
- `aptitudes`: array of Starting Aptitude names. Repeated names are de-duplicated in the regiment result.
- `special_rules`: array of `{ "name", "summary" }` objects.
- `wounds`: signed integer.
- `equipment`: array of catalog references. Entries support `quantity`, `scope`, `slot`, `replace_slot`, and `merge` (`add`, `replace`, or `unique`).
- `equipment_adjustments`: adjusts only matching existing kit. It can target a catalog `tag` or the current main weapon's `ammunition_id`; Well-Provisioned uses both forms.
- `standard_kit_points_base`: overrides the normal 30-point additional kit pool before adding 2 points per unused Regiment Creation point.

A choice belongs to its parent option and contains `id`, `prompt`, `minimum`, `maximum`, optional `scope`, optional `unique_group`, and an `options` array. Every choice option has its own `id`, `label`, and `effects`. Choice IDs must be globally stable. `unique_group` prevents two choice fields from resolving to the same option, as used by Hive World's two distinct characteristic bonuses. Core options marked with an "or" use `scope: "per_character"`. The Regiment Creator lists those choices without resolving them; their definitions are copied into the regiment save so the Character Creator can answer them independently for every character.

`requirements.all` means every listed option ID must be selected. `requirements.any` means at least one listed option ID must be selected. `excludes` lists incompatible option IDs. These checks are symmetrical at calculation time even if only one side declares the exclusion.

The UI reads `selection_rules`; category limits and doctrine-slot participation are therefore data rather than widget logic.
