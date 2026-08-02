# OWCA changelog

All notable player-facing and developer-facing changes to the Only War Character Assistant are recorded here. New work should be added under **Unreleased** and moved into a dated version section when a release is prepared.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and OWCA uses semantic version numbers where practical.

## [Unreleased]

No changes recorded yet.

## [0.3.0] - 2026-08-02

### Added

- Added a landing page separating regiment creation from character creation.
- Added all Core Rulebook Home Worlds, Commanding Officers, Regiment Types, Training Doctrines, and Equipment Doctrines used by the regiment creator.
- Added validation for the 12-point regiment budget, one required Regiment Type, and up to two optional doctrines.
- Added live aggregation of Characteristic modifiers, Skills, Talents, Aptitudes, special rules, Wounds modifiers, and equipment.
- Added support for single-answer and multiple-answer starting choices.
- Added correct duplicate Skill advancement and duplicate non-stackable Talent XP compensation.
- Added versioned regiment JSON save/load and readable text dossier export.
- Added the first Guardsman character-creation slice with Heavy Gunner, Medic, Operator, Sergeant, and Weapon Specialist.
- Added manual entry for the nine rolled Characteristics and manual Wounds and Fate rolls; OWCA performs the resulting arithmetic and lookups without rolling dice.
- Added character calculation for final Characteristics, Characteristic Bonuses, Wounds, Fate Points, Movement, Skills, Talents, Aptitudes, rules, and equipment.
- Added duplicate Aptitude replacement choices.
- Added versioned character JSON save/load.
- Added example 13th Varanox regiment and Weapon Specialist character files.
- Added source-book and printed-page references throughout the rules data.
- Added headless regiment and character calculator tests.
- Added an unofficial, non-commercial fan-project and third-party intellectual-property disclaimer.

### Changed

- Regiment Type is displayed as its own required creation stage instead of being counted in the optional doctrine counter.
- Choices that belong to individual soldiers are deferred from regiment creation and resolved in the Character Creator.
- The project was separated from the original beat-'em-up prototype and cleaned into a standalone OWCA Godot project.
- Repository documentation was promoted to the project root and expanded with fresh-clone test instructions.

### Fixed

- Fixed confusing doctrine-slot reporting by showing Regiment Type as `1/1` and optional doctrines as `0/2` through `2/2`.
- Fixed partial multiple-choice packages so selected benefits appear in the live summary while the package remains unresolved.
- Removed obsolete game input mappings, resources, plugins, caches, and broken legacy references.

### Known limitations

- Starting XP purchases and advancement costs are not implemented yet.
- Printable character-sheet PDF export is not implemented yet.
- Only the five Core Guardsman Specialities are available for character testing.
- OWCA intentionally does not roll dice.

