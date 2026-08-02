# OWCA changelog

All notable player-facing and developer-facing changes to the Only War Character Assistant are recorded here. New work should be added under **Unreleased** and moved into a dated version section when a release is prepared.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and OWCA uses semantic version numbers where practical.

## [Unreleased]

### Added

- Added a **Spend Starting XP** character-creation stage with separate Characteristic, Skill, and Talent browsers.
- Added the Core Aptitude-matched cost tables for all four Characteristic ranks, all four Skill ranks, and all three Talent tiers.
- Added all nine Characteristic advancement tracks and the Core Skill categories/specialisations currently relevant to OWCA.
- Added a curated Core Talent advancement catalog covering the five Guardsman Specialities' recommended advances and Weapon Training prerequisite chains.
- Added specialty recommendation markers, source/page references, affordability feedback, and unmet-prerequisite explanations to advancement cards.
- Added an ordered purchase ledger with per-purchase XP costs and removal controls.
- Added headless tests for Aptitude pricing, sequential Skill and Characteristic costs, Talent prerequisites, affordability, invalidated dependencies, and XP save/load.
- Added a headless responsive-layout regression test at 960, 1090, and 1280 pixel window widths.
- Added an original two-page A4 Guardsman field-dossier design with riveted steel framing, parchment panels, oxblood section headers, and restrained hazard-strip accents.
- Added Review-stage export of one printable PDF plus two 2480x3508 PNG pages containing Characteristics, Skills, Talents, equipment, trackers, rules, choices, sources, advances, and campaign notes.
- Added a dependency-free Godot PDF writer and a normal-renderer visual export regression test.

### Changed

- Character calculations now apply purchased Characteristic, Skill, Talent, and Sound Constitution Wound advances to the live summary and derived values.
- Character JSON saves now use format/state version 2, record the advancement-data content version, and remain compatible with version 1 character files.
- Character summaries and status panels now show XP spent, remaining, and total.
- Advancement cards now use a vertically stacked action layout, and narrow windows automatically reclaim the live-summary column for the active creation stage.
- The character workflow scope text and Review guidance now advertise printable dossier export while retaining physical or Discord dice rolling.

### Fixed

- Fixed long advancement names pushing the Buy button outside the visible centre panel and requiring horizontal scrolling.

### Known limitations

- The v0.4 Talent browser is a focused Guardsman testing catalog, not every Talent in the Core Rulebook.
- Character-sheet PDFs are image-based; their text is not selectable.
- Only the five Core Guardsman Specialities are available for character testing.
- OWCA intentionally does not roll dice.

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
