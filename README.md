# Only War Character Assistant v0.3

This module is a data-driven Godot 4 regiment and Guardsman creation assistant. Regiment creation includes every Core Rulebook option in the five supported categories: 8 Home Worlds, 9 Commanding Officers, 8 Regiment Types, 7 Training Doctrines, and 7 Equipment Doctrines. The current character-creation testing slice implements the five Core Guardsman Specialities: Heavy Gunner, Medic, Operator, Sergeant, and Weapon Specialist. Entries were checked against the supplied Only War Core Rulebook PDF; content files record printed book pages rather than PDF viewer indices.

## Unofficial fan-project disclaimer

OWCA is an unofficial, non-commercial fan-made tool. It is not affiliated with, sponsored by, or endorsed by Games Workshop, Fantasy Flight Games, or any other rights holder. *Warhammer 40,000*, *Only War*, and all related names, settings, characters, and game material remain the property of their respective owners.

This repository does not include rulebook PDFs or reproduce long-form rules text. Users are expected to own the relevant source books. Its rules data is limited to numerical effects, concise summaries, and source/page references for personal tabletop use. The GNU GPL in this repository applies only to original OWCA code and other material the project authors have the right to license; it does not grant rights to third-party intellectual property.

## Project layout

```text
OWCA/
  data/
    regiment_options.json       Regiment rules and catalog data
    guardsman_specialities.json Five Core Guardsman starting packages
    regiment_options.schema.json Formal JSON Schema (Draft 2020-12)
    schema.md                    Data contract and extension guide
  examples/
    13th_varanox_light_infantry.owreg.json Example saved regiment
    varanox_weapon_specialist.owchar.json  Example saved Guardsman
  scripts/
    regiment_data_repository.gd Rules loading and lookup
    regiment_state.gd           Serializable user selections
    regiment_calculator.gd      Pure aggregation and validation
    regiment_persistence.gd     JSON save/load
    dossier_exporter.gd         Readable text export
    character_data_repository.gd Character rules loading and lookup
    character_state.gd          Serializable individual inputs
    character_calculator.gd     Character aggregation and validation
    character_persistence.gd    Character JSON save/load
  ui/
    landing_page.gd             Landing-page controller
    LandingPage.tscn            Main scene and workflow selection
    regiment_creator.gd         UI/controller
    RegimentCreator.tscn        Regiment workflow
    character_creator.gd        Guardsman workflow UI/controller
    CharacterCreator.tscn       Guardsman workflow scene
  tests/
    regiment_calculator_test.gd Headless smoke tests
    character_calculator_test.gd Guardsman package and persistence tests
```

## Run

Open the repository's `project.godot` in Godot 4 and run the project. The landing page separates regiment and character creation. The **13th Varanox** button fills the regiment acceptance example.

## Headless tests

On a fresh clone, let Godot build its generated global-class cache before running the script-based tests:

```text
godot --headless --editor --path . --quit
godot --headless --path . --script res://OWCA/tests/regiment_calculator_test.gd
godot --headless --path . --script res://OWCA/tests/character_calculator_test.gd
```

The Regiment Creator resolves only regiment-wide decisions. Choices marked `per_character` are listed as deferred benefits, do not prevent a regiment from being valid, and are not answered or stored as resolutions in the regiment file. The file carries a snapshot of those choice definitions for the future Character Creator.

Save files use a small versioned JSON envelope. Dossier export writes a readable plain-text summary that is suitable for printing from any editor. Rules are stored as short summaries with source/page pointers; consult the owned rulebook for complete wording.

Duplicate starting Skills advance from Known through Trained (+10), Experienced (+20), and Veteran (+30). Extra copies of a non-stackable starting Talent are reported as +100 XP per duplicate, following the Core Rulebook's regiment/character creation guidance.

The Guardsman Character Creator loads an `.owreg.json` regiment, accepts manually rolled base Characteristics, applies shared and individual modifiers, resolves regiment and Speciality choices, and calculates Wounds, Fate Points, Characteristic Bonuses, and Movement. It combines Skills, Talents, Aptitudes, rules, and equipment into one live summary and saves versioned `.owchar.json` character files. Dice remain physical or Discord rolls. Starting XP purchases and printable character-sheet PDF export are deliberately deferred.

## Acceptance example

- Hive World (3)
- Choleric commander (2)
- Light Infantry (2)
- Close Order Drill (2)
- Scavengers (3)
- Total: 12/12 points, Regiment Type 1/1, and Optional Doctrines 2/2
