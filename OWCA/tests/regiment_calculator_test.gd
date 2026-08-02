extends SceneTree

## Run with: godot --headless --path . --script res://OWCA/tests/regiment_calculator_test.gd


func _init() -> void:
	var repository := RegimentDataRepository.new()
	_assert_equal(repository.load_data(), OK, "Core rules catalog loads")
	_assert_equal(repository.get_options_for_category("home_world").size(), 8, "all Core home worlds")
	_assert_equal(repository.get_options_for_category("commander").size(), 9, "all Core commanding officers")
	_assert_equal(repository.get_options_for_category("regiment_type").size(), 8, "all Core regiment types")
	_assert_equal(repository.get_options_for_category("training_doctrine").size(), 7, "all Core training doctrines")
	_assert_equal(repository.get_options_for_category("equipment_doctrine").size(), 7, "all Core equipment doctrines")
	_assert_option_costs(repository, {
		"death_world": 3, "fortress_world": 3, "highborn": 3, "hive_world": 3,
		"imperial_world": 1, "penal_colony": 2, "penitent": 3, "schola_progenium": 3,
		"bilious": 2, "circumspect": 2, "choleric": 2, "fixed": 1, "maverick": 2,
		"melancholic": 2, "phlegmatic": 1, "sanguine": 2, "supine": 1,
		"armoured_regiment": 4, "reconnaissance_regiment": 3, "drop_troops": 3,
		"hunter_killer": 3, "light_infantry": 2, "line_infantry": 2,
		"mechanised_infantry": 3, "siege_infantry": 2,
		"close_order_drill": 2, "die_hards": 3, "favoured_foe": 3,
		"hardened_fighters": 2, "iron_discipline": 3, "sharpshooters": 4, "survivalists": 4,
		"augmetics": 2, "chameleoline": 3, "combat_drugs": 2, "demolitions": 3,
		"scavengers": 3, "warrior_weapons": 3, "well_provisioned": 3
	})
	var state := RegimentState.new()
	state.load_example()
	var calculator := RegimentCalculator.new()
	var result := calculator.calculate(state, repository)

	_assert_equal(result["points_spent"], 12, "Varanox points")
	_assert_equal(result["points_remaining"], 0, "Varanox remaining points")
	_assert_equal(result["doctrine_slots_used"], 3, "Varanox doctrine slots")
	_assert_equal(result["optional_doctrines_used"], 2, "Varanox optional doctrines")
	_assert_equal(result["optional_doctrines_maximum"], 2, "optional doctrine limit")
	_assert_equal((result["unresolved_choices"] as Array).size(), 0, "Varanox regiment-wide choices")
	_assert_equal((result["character_creation_choices"] as Array).size(), 4, "Varanox deferred character choices")
	_assert_true(result["valid"], "character choices do not invalidate a regiment")

	var unresolved_regiment_choice := RegimentState.new()
	unresolved_regiment_choice.selections = {
		"home_world": ["fortress_world"],
		"commander": ["fixed"],
		"regiment_type": ["light_infantry"],
		"training_doctrine": ["survivalists"],
		"equipment_doctrine": []
	}
	var unresolved_result := calculator.calculate(unresolved_regiment_choice, repository)
	_assert_equal((unresolved_result["unresolved_choices"] as Array).size(), 2, "regiment-wide choices remain required")
	_assert_true(not unresolved_result["valid"], "unresolved regiment-wide choices invalidate the regiment")

	var too_many_doctrines := RegimentState.new()
	too_many_doctrines.selections = {
		"home_world": ["imperial_world"],
		"commander": ["fixed"],
		"regiment_type": ["line_infantry"],
		"training_doctrine": ["close_order_drill", "die_hards"],
		"equipment_doctrine": ["augmetics"]
	}
	var doctrine_result := calculator.calculate(too_many_doctrines, repository)
	_assert_equal(doctrine_result["optional_doctrines_used"], 3, "combined optional doctrine count")
	_assert_true(not doctrine_result["valid"], "more than two optional doctrines is invalid")

	state.set_choice("hive_characteristic_1", "agility")
	state.set_choice("hive_characteristic_2", "fellowship")
	state.set_choice("hive_urban_violence", "paranoia")
	state.set_choice("close_order_talent", "combat_formation")
	result = calculator.calculate(state, repository)
	_assert_true(result["valid"], "saved character answers are ignored by regiment calculation")
	_assert_equal(result["characteristics"]["Agility"], 3, "only fixed Agility modifier is applied")
	_assert_true(not (result["characteristics"] as Dictionary).has("Fellowship"), "deferred Fellowship choice is not applied")
	_assert_equal(result["characteristics"]["Toughness"], -3, "Light Infantry Toughness modifier")
	_assert_equal(result["wounds"], -1, "Hive World Wounds modifier")
	_assert_equal(result["standard_kit_points"], 30, "Varanox additional kit pool")
	_assert_true(_equipment_contains(result["equipment"], "lascarbine"), "Light Infantry lascarbine")
	_assert_true(not _equipment_contains(result["equipment"], "laspistol"), "main weapon replacement")

	# JSON persistence round-trip and readable dossier export.
	var persistence := RegimentPersistence.new()
	var save_result := persistence.save_regiment("user://owca_roundtrip.json", state, repository)
	_assert_equal(save_result["error"], OK, "save regiment JSON")
	var loaded_state := RegimentState.new()
	var load_result := persistence.load_regiment("user://owca_roundtrip.json", loaded_state, repository)
	_assert_equal(load_result["error"], OK, "load regiment JSON")
	_assert_equal(loaded_state.selections, state.selections, "save/load regiment selections")
	_assert_true(loaded_state.resolutions.is_empty(), "per-character answers are not stored in regiment state")
	var saved_envelope := JSON.parse_string(FileAccess.get_file_as_string("user://owca_roundtrip.json")) as Dictionary
	_assert_equal((saved_envelope["character_creation_choices"] as Array).size(), 4, "regiment file carries deferred choice definitions")
	var exporter := DossierExporter.new()
	var export_result := exporter.export_text("user://owca_dossier.txt", state, result, repository)
	_assert_equal(export_result["error"], OK, "export text dossier")
	var dossier := FileAccess.get_file_as_string("user://owca_dossier.txt")
	_assert_true(dossier.contains("13TH VARANOX LIGHT INFANTRY"), "dossier designation")
	_assert_true(dossier.contains("Creation points: 12 spent / 0 remaining"), "dossier points")
	_assert_true(dossier.contains("DEFERRED CHARACTER-CREATION CHOICES"), "dossier deferred character choices")

	# Well-Provisioned adjusts only equipment already supplied by the regiment.
	var supplied_state := RegimentState.new()
	supplied_state.regiment_name = "Provisioned Line Test"
	supplied_state.selections = {
		"home_world": ["imperial_world"],
		"commander": ["fixed"],
		"regiment_type": ["line_infantry"],
		"training_doctrine": ["sharpshooters"],
		"equipment_doctrine": ["well_provisioned"]
	}
	supplied_state.set_choice("imperial_other_characteristic", "agility")
	var supplied_result := calculator.calculate(supplied_state, repository)
	_assert_true(supplied_result["valid"], "representative full-catalog regiment is valid")
	_assert_equal(supplied_result["points_spent"], 11, "representative regiment points")
	_assert_equal(supplied_result["standard_kit_points"], 32, "unused point increases kit pool")
	_assert_true("Ballistic Skill" in supplied_result["aptitudes"], "Sharpshooters aptitude")
	_assert_equal(_equipment_quantity(supplied_result["equipment"], "charge_pack"), 6, "Well-Provisioned ammunition")
	_assert_equal(_equipment_quantity(supplied_result["equipment"], "rations"), 4, "Well-Provisioned rations")
	_assert_equal(_equipment_quantity(supplied_result["equipment"], "frag_grenade"), 3, "Well-Provisioned frag grenades")
	_assert_equal(_equipment_quantity(supplied_result["equipment"], "krak_grenade"), 3, "Well-Provisioned krak grenades")
	_assert_equal(_equipment_quantity(supplied_result["equipment"], "smoke_grenade"), 0, "Well-Provisioned does not add absent grenade types")

	var reordered_state := RegimentState.new()
	reordered_state.selections = {
		"home_world": ["imperial_world"],
		"commander": ["fixed"],
		"regiment_type": ["line_infantry"],
		"training_doctrine": [],
		"equipment_doctrine": ["well_provisioned", "warrior_weapons"]
	}
	reordered_state.set_choice("imperial_other_characteristic", "agility")
	var reordered_result := calculator.calculate(reordered_state, repository)
	_assert_true(reordered_result["valid"], "equipment doctrines remain valid in selection order")
	_assert_equal(_equipment_quantity(reordered_result["equipment"], "charge_pack"), 2, "Well-Provisioned does not increase secondary-weapon ammunition")
	_assert_true(_equipment_contains(reordered_result["equipment"], "common_low_tech_weapon"), "Warrior Weapons main weapon replacement")

	# Penal Colony replaces the base additional-kit pool before unused-point bonuses.
	var penal_state := RegimentState.new()
	penal_state.selections = {
		"home_world": ["penal_colony"],
		"commander": ["fixed"],
		"regiment_type": ["light_infantry"],
		"training_doctrine": [],
		"equipment_doctrine": []
	}
	penal_state.set_choice("penal_characteristic_1", "strength")
	penal_state.set_choice("penal_characteristic_2", "toughness")
	penal_state.set_choice("penal_honour_talent", "street_fighting")
	var penal_result := calculator.calculate(penal_state, repository)
	_assert_true(penal_result["valid"], "Penal Colony test regiment is valid")
	_assert_equal(penal_result["standard_kit_points"], 29, "Penal Colony kit pool")

	# Synthetic duplicate grants verify the generic stacking policy without altering starter rules.
	var duplicate_option := {
		"id": "test_duplicate_grants",
		"category": "training_doctrine",
		"name": "Test Duplicate Grants",
		"cost": 0,
		"effects": {
			"skills": ["navigate_surface"],
			"talents": ["sprint", "sprint"]
		}
	}
	(repository.data["options"] as Array).append(duplicate_option)
	repository._options_by_id["test_duplicate_grants"] = duplicate_option
	state.selections["training_doctrine"] = ["test_duplicate_grants"]
	result = calculator.calculate(state, repository)
	var navigate := _find_entry(result["skills"], "navigate_surface")
	var sprint := _find_entry(result["talents"], "sprint")
	_assert_equal(navigate["rank_label"], "Trained (+10)", "duplicate skill raises its rank")
	_assert_equal(sprint["count"], 1, "non-stackable talent is de-duplicated")
	_assert_equal(result["bonus_xp"], 200, "duplicate talents become 100 XP each")

	# Per-character choice validation belongs to the future Character Calculator.
	state.set_choice("hive_characteristic_2", "agility")
	result = calculator.calculate(state, repository)
	_assert_true(result["valid"], "per-character duplicate answers do not invalidate regiment creation")

	print("OWCA regiment calculator tests passed.")
	quit(0)


func _equipment_contains(entries: Array, item_id: String) -> bool:
	for entry: Dictionary in entries:
		if str(entry.get("id", "")) == item_id:
			return true
	return false


func _find_entry(entries: Array, entry_id: String) -> Dictionary:
	for entry: Dictionary in entries:
		if str(entry.get("id", "")) == entry_id:
			return entry
	return {}


func _equipment_quantity(entries: Array, item_id: String) -> int:
	var entry := _find_entry(entries, item_id)
	return int(entry.get("quantity", 0))


func _assert_option_costs(repository: RegimentDataRepository, expected: Dictionary) -> void:
	for option_id: Variant in expected:
		var option := repository.get_option(str(option_id))
		_assert_true(not option.is_empty(), "Core option exists: %s" % option_id)
		_assert_equal(int(option.get("cost", -1)), int(expected[option_id]), "Core cost: %s" % option_id)


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		printerr("FAILED: %s" % label)
		quit(1)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		printerr("FAILED: %s (expected %s, got %s)" % [label, expected, actual])
		quit(1)
