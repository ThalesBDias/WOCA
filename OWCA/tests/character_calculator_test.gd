extends SceneTree

## Run with: godot --headless --path . --script res://OWCA/tests/character_calculator_test.gd


func _init() -> void:
	var regiment_repository := RegimentDataRepository.new()
	_assert_equal(regiment_repository.load_data(), OK, "regiment catalog loads")
	var character_repository := CharacterDataRepository.new()
	_assert_equal(character_repository.load_data(), OK, "Guardsman Speciality catalog loads")
	_assert_equal(character_repository.get_specialities().size(), 5, "five Core Guardsman Specialities")
	_assert_speciality(character_repository, "heavy_gunner", 10, 4)
	_assert_speciality(character_repository, "medic", 8, 3)
	_assert_speciality(character_repository, "operator", 6, 2)
	_assert_speciality(character_repository, "sergeant", 10, 3)
	_assert_speciality(character_repository, "weapon_specialist", 8, 6)

	var regiment_state := RegimentState.new()
	regiment_state.load_example()
	var state := CharacterState.new()
	state.character_name = "Varanox Operator"
	state.player_name = "Test Player"
	state.set_regiment(regiment_state.to_dict(), str(regiment_repository.data.get("content_version", "")))
	_fill_base_characteristics(state, 30)
	state.set_speciality("operator")
	state.set_wounds_roll(3)
	state.set_fate_roll(8)
	state.set_choice("regiment", "hive_characteristic_1", "agility")
	state.set_choice("regiment", "hive_characteristic_2", "fellowship")
	state.set_choice("regiment", "hive_urban_violence", "paranoia")
	state.set_choice("regiment", "close_order_talent", "combat_formation")
	state.set_choice("speciality", "operator_knowledge_skill", "common_lore_tech")
	state.set_choice("speciality", "operator_weapon_training", "las")

	var calculator := CharacterCalculator.new()
	var result := calculator.calculate(state, regiment_repository, character_repository)
	_assert_true(result["valid"], "complete Varanox Operator is valid")
	_assert_equal(result["speciality_name"], "Operator", "Operator selected")
	_assert_equal(result["characteristics"]["Agility"], 41, "base, regiment choice, regiment type, and Speciality combine")
	_assert_equal(result["characteristics"]["Fellowship"], 33, "second Hive choice combines")
	_assert_equal(result["characteristics"]["Toughness"], 27, "Light Infantry penalty combines")
	_assert_equal(result["characteristic_bonuses"]["Agility"], 4, "Characteristic Bonus")
	_assert_equal(result["wounds"], 8, "Operator Wounds with Hive modifier")
	_assert_equal(result["fate_points"], 2, "Fate lookup")
	_assert_equal(result["movement"], { "half": 4, "full": 8, "charge": 12, "run": 24 }, "Agility movement")
	_assert_equal(result["xp_budget"], 600, "Guardsman starting XP")
	_assert_true(_entry_exists(result["skills"], "common_lore_tech"), "Operator chosen Skill")
	_assert_true(_entry_exists(result["talents"], "technical_knock"), "Operator fixed Talent")
	_assert_true(_entry_exists(result["talents"], "weapon_training_las"), "Operator chosen Weapon Training")
	_assert_true(_entry_exists(result["equipment"], "auspex_scanner"), "Operator equipment")

	var incomplete := CharacterState.new()
	incomplete.set_regiment(regiment_state.to_dict(), str(regiment_repository.data.get("content_version", "")))
	var incomplete_result := calculator.calculate(incomplete, regiment_repository, character_repository)
	_assert_true(not incomplete_result["valid"], "incomplete character is invalid")
	_assert_true((incomplete_result["errors"] as Array).size() >= 3, "missing core stages are reported")

	var weapon_state := CharacterState.new()
	weapon_state.set_regiment(regiment_state.to_dict(), str(regiment_repository.data.get("content_version", "")))
	_fill_base_characteristics(weapon_state, 30)
	weapon_state.set_speciality("weapon_specialist")
	weapon_state.set_wounds_roll(5)
	weapon_state.set_fate_roll(10)
	_resolve_varanox_choices(weapon_state)
	weapon_state.set_choice("speciality", "weapon_specialist_characteristic", "ballistic_skill")
	weapon_state.set_choice("speciality", "weapon_specialist_field_skill", "athletics")
	weapon_state.set_choice("speciality", "weapon_specialist_talent", "rapid_reload")
	weapon_state.set_choice("speciality", "weapon_specialist_trainings", "las", true, 3)
	var partial_weapon_result := calculator.calculate(weapon_state, regiment_repository, character_repository)
	_assert_true(not partial_weapon_result["valid"], "partial choose-three package remains unresolved")
	_assert_true(_entry_exists(partial_weapon_result["talents"], "weapon_training_las"), "partial multi-choice grants appear in the live result")
	weapon_state.set_choice("speciality", "weapon_specialist_trainings", "launcher", true, 3)
	weapon_state.set_choice("speciality", "weapon_specialist_trainings", "low_tech", true, 3)
	weapon_state.set_choice("speciality", "weapon_specialist_grenades", "frag")
	weapon_state.set_choice("speciality", "weapon_specialist_weapon", "lasgun")
	var weapon_result := calculator.calculate(weapon_state, regiment_repository, character_repository)
	_assert_true(weapon_result["valid"], "Weapon Specialist three-selection choice resolves")
	_assert_equal(weapon_result["characteristics"]["Ballistic Skill"], 35, "Weapon Specialist characteristic choice")
	_assert_equal(_equipment_quantity(weapon_result["equipment"], "frag_grenade"), 6, "Speciality grenades merge with regiment kit")

	# A duplicate Aptitude generates a required replacement choice.
	var aptitude_regiment := RegimentState.new()
	aptitude_regiment.selections = {
		"home_world": ["imperial_world"],
		"commander": ["fixed"],
		"regiment_type": ["line_infantry"],
		"training_doctrine": ["sharpshooters"],
		"equipment_doctrine": []
	}
	var aptitude_state := CharacterState.new()
	aptitude_state.set_regiment(aptitude_regiment.to_dict(), str(regiment_repository.data.get("content_version", "")))
	_fill_base_characteristics(aptitude_state, 30)
	aptitude_state.set_speciality("operator")
	aptitude_state.set_wounds_roll(3)
	aptitude_state.set_fate_roll(7)
	aptitude_state.set_choice("regiment", "imperial_other_characteristic", "strength")
	aptitude_state.set_choice("speciality", "operator_knowledge_skill", "common_lore_tech")
	aptitude_state.set_choice("speciality", "operator_weapon_training", "las")
	var aptitude_result := calculator.calculate(aptitude_state, regiment_repository, character_repository)
	_assert_true(not aptitude_result["valid"], "duplicate Aptitude requires a replacement")
	_assert_true(_unresolved_prompt_contains(aptitude_result["unresolved_choices"], "Replacement for duplicate Ballistic Skill"), "duplicate Aptitude choice is exposed")
	aptitude_state.set_choice("speciality", "duplicate_aptitude_ballistic_skill_1", "strength")
	aptitude_result = calculator.calculate(aptitude_state, regiment_repository, character_repository)
	_assert_true(aptitude_result["valid"], "duplicate Aptitude replacement resolves")
	_assert_true("Strength" in aptitude_result["aptitudes"], "replacement Aptitude is applied")

	var persistence := CharacterPersistence.new()
	var save_result := persistence.save_character("user://owca_character_roundtrip.json", state, result, character_repository)
	_assert_equal(save_result["error"], OK, "save character JSON")
	var loaded := CharacterState.new()
	var load_result := persistence.load_character("user://owca_character_roundtrip.json", loaded)
	_assert_equal(load_result["error"], OK, "load character JSON")
	var loaded_result := calculator.calculate(loaded, regiment_repository, character_repository)
	_assert_true(loaded_result["valid"], "loaded character remains valid")
	_assert_equal(loaded_result["characteristics"], result["characteristics"], "character save/load calculation is stable")

	print("OWCA character calculator tests passed.")
	quit(0)


func _fill_base_characteristics(state: CharacterState, value: int) -> void:
	for characteristic in CharacterState.CHARACTERISTIC_ORDER:
		state.set_base_characteristic(characteristic, value)


func _resolve_varanox_choices(state: CharacterState) -> void:
	state.set_choice("regiment", "hive_characteristic_1", "agility")
	state.set_choice("regiment", "hive_characteristic_2", "fellowship")
	state.set_choice("regiment", "hive_urban_violence", "paranoia")
	state.set_choice("regiment", "close_order_talent", "combat_formation")


func _entry_exists(entries: Array, entry_id: String) -> bool:
	for entry: Dictionary in entries:
		if str(entry.get("id", "")) == entry_id:
			return true
	return false


func _equipment_quantity(entries: Array, entry_id: String) -> int:
	for entry: Dictionary in entries:
		if str(entry.get("id", "")) == entry_id:
			return int(entry.get("quantity", 0))
	return 0


func _unresolved_prompt_contains(entries: Array, text: String) -> bool:
	for entry: Dictionary in entries:
		if str(entry.get("prompt", "")).contains(text):
			return true
	return false


func _assert_speciality(repository: CharacterDataRepository, speciality_id: String, wounds_base: int, choice_count: int) -> void:
	var speciality := repository.get_speciality(speciality_id)
	_assert_true(not speciality.is_empty(), "Speciality exists: %s" % speciality_id)
	_assert_equal(int(speciality.get("wounds_base", 0)), wounds_base, "Speciality Wounds base: %s" % speciality_id)
	_assert_equal((speciality.get("choices", []) as Array).size(), choice_count, "Speciality choice count: %s" % speciality_id)


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		printerr("FAILED: %s" % label)
		quit(1)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		printerr("FAILED: %s (expected %s, got %s)" % [label, expected, actual])
		quit(1)
