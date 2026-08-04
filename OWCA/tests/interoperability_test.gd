extends SceneTree

## Run with: godot --headless --path . --script res://OWCA/tests/interoperability_test.gd
##
## These tests protect OWCA's JSON boundary as a public API. They deliberately
## inspect the written envelopes as an external consumer would, then verify that
## previews cannot override authoritative state when a file is loaded again.

const REGIMENT_PATH := "user://owca_interop_regiment.owreg.json"
const REGIMENT_ROUNDTRIP_PATH := "user://owca_interop_regiment_roundtrip.owreg.json"
const CHARACTER_PATH := "user://owca_interop_character.owchar.json"
const CHARACTER_ROUNDTRIP_PATH := "user://owca_interop_character_roundtrip.owchar.json"
const MUTATED_PATH := "user://owca_interop_mutated.json"

var _failures := 0


func _init() -> void:
	_cleanup_test_files()
	var regiment_repository := RegimentDataRepository.new()
	_assert_equal(regiment_repository.load_data(), OK, "regiment rules load")
	var character_repository := CharacterDataRepository.new()
	_assert_equal(character_repository.load_data(), OK, "character rules load")

	_test_regiment_contract(regiment_repository)
	_test_character_contract(regiment_repository, character_repository)
	_test_published_examples(regiment_repository)
	_test_schema_documents()
	_cleanup_test_files()

	if _failures > 0:
		printerr("OWCA interoperability tests failed: %d assertion(s)." % _failures)
		quit(1)
		return
	print("OWCA interoperability tests passed.")
	quit(0)


func _test_regiment_contract(repository: RegimentDataRepository) -> void:
	var state := RegimentState.new()
	state.load_example()
	state.mark_creation_complete()
	state.interoperability_extensions = {
		"com.example.combat/regiment": {
			"external_id": "regiment-13",
			"initiative_note": "consumer-owned example"
		}
	}
	var persistence := RegimentPersistence.new()
	var save_result := persistence.save_regiment(REGIMENT_PATH, state, repository)
	_assert_equal(save_result.get("error"), OK, "regiment save succeeds")

	var envelope := _read_json(REGIMENT_PATH)
	_assert_equal(envelope.get("format"), RegimentPersistence.FILE_FORMAT, "regiment format discriminator")
	_assert_equal(envelope.get("schema_version"), RegimentPersistence.SCHEMA_VERSION, "regiment public schema version")
	_assert_equal(envelope.get("equipment_rules_content_version"), "0.6.0-core-equipment", "regiment records equipment rules version")
	_assert_equal(envelope.get("version"), RegimentPersistence.FILE_VERSION, "current regiment envelope version")
	_assert_true(DocumentIdentity.is_valid(str(_nested(envelope, ["regiment", "document_id"]))), "regiment has a durable document ID")
	_assert_equal(_nested(envelope, ["regiment", "workflow_state"]), RegimentState.WORKFLOW_COMPLETE, "regiment completion state is explicit")
	_assert_equal((envelope.get("producer", {}) as Dictionary).get("version"), str(ProjectSettings.get_setting("application/config/version", "unknown")), "producer version is recorded")
	_assert_equal(_nested(envelope, ["regiment", "selections", "home_world", 0]), "hive_world", "regiment selection uses a stable ID")
	_assert_equal(_nested(envelope, ["calculated_preview", "points_spent"]), 12, "regiment preview includes point totals")
	_assert_equal(_nested(envelope, ["calculated_preview", "optional_doctrines_used"]), 2, "regiment preview separates optional doctrines")
	_assert_true((envelope.get("calculated_preview", {}) as Dictionary).has("equipment"), "regiment preview includes calculated equipment")

	var loaded := RegimentState.new()
	var load_result := persistence.load_regiment(REGIMENT_PATH, loaded, repository)
	_assert_equal(load_result.get("error"), OK, "regiment contract loads")
	_assert_equal(loaded.interoperability_extensions, state.interoperability_extensions, "regiment extensions load intact")
	_assert_equal(loaded.document_id, state.document_id, "regiment document identity loads intact")
	_assert_equal(persistence.save_regiment(REGIMENT_ROUNDTRIP_PATH, loaded, repository).get("error"), OK, "loaded regiment saves again")
	var roundtrip := _read_json(REGIMENT_ROUNDTRIP_PATH)
	_assert_equal(roundtrip.get("extensions"), state.interoperability_extensions, "regiment extensions round-trip intact")
	_assert_equal(_nested(roundtrip, ["regiment", "document_id"]), state.document_id, "Save As preserves regiment identity")

	var duplicate_state := RegimentState.new()
	_assert_equal(duplicate_state.from_dict(state.to_dict()), OK, "clone regiment for Duplicate")
	duplicate_state.duplicate_identity()
	_assert_true(duplicate_state.document_id != state.document_id, "Duplicate creates a new regiment identity")
	_assert_equal(duplicate_state.workflow_state, RegimentState.WORKFLOW_DRAFT, "Duplicate resets regiment lifecycle to draft")
	var edited_state := RegimentState.new()
	_assert_equal(edited_state.from_dict(state.to_dict()), OK, "clone completed regiment for edit")
	edited_state.set_option("training_doctrine", "close_order_drill", false, 2)
	_assert_equal(edited_state.workflow_state, RegimentState.WORKFLOW_DRAFT, "editing a completed regiment reopens draft")

	# Pre-v0.5.1 envelopes had no public schema field. They remain supported.
	var legacy := envelope.duplicate(true)
	legacy["version"] = 1
	legacy.erase("schema_version")
	legacy.erase("producer")
	legacy.erase("extensions")
	legacy.erase("calculated_preview")
	(legacy["regiment"] as Dictionary)["version"] = 1
	(legacy["regiment"] as Dictionary).erase("document_id")
	(legacy["regiment"] as Dictionary).erase("workflow_state")
	_write_json(MUTATED_PATH, legacy)
	var legacy_state := RegimentState.new()
	var legacy_result := persistence.load_regiment(MUTATED_PATH, legacy_state, repository)
	_assert_equal(legacy_result.get("error"), OK, "legacy regiment envelope loads")
	_assert_true(DocumentIdentity.is_valid(legacy_state.document_id), "legacy regiment receives a document ID")
	_assert_equal(legacy_state.workflow_state, RegimentState.WORKFLOW_DRAFT, "legacy regiment safely defaults to draft")
	_assert_true(_array_contains_fragment(legacy_result.get("migration_report", []) as Array, "document ID"), "regiment migration report explains generated identity")

	var invalid_identity := envelope.duplicate(true)
	(invalid_identity["regiment"] as Dictionary)["document_id"] = "not-a-document-id"
	_write_json(MUTATED_PATH, invalid_identity)
	_assert_equal(persistence.load_regiment(MUTATED_PATH, RegimentState.new(), repository).get("error"), ERR_INVALID_DATA, "invalid current regiment document ID is rejected")

	var future := envelope.duplicate(true)
	future["schema_version"] = "2.0.0"
	_write_json(MUTATED_PATH, future)
	_assert_equal(persistence.load_regiment(MUTATED_PATH, RegimentState.new(), repository).get("error"), ERR_INVALID_DATA, "future regiment schema major is rejected")
	var malformed_version := envelope.duplicate(true)
	malformed_version["schema_version"] = "1.x"
	_write_json(MUTATED_PATH, malformed_version)
	_assert_equal(persistence.load_regiment(MUTATED_PATH, RegimentState.new(), repository).get("error"), ERR_INVALID_DATA, "malformed regiment schema version is rejected")
	malformed_version["schema_version"] = "1.-1.0"
	_write_json(MUTATED_PATH, malformed_version)
	_assert_equal(persistence.load_regiment(MUTATED_PATH, RegimentState.new(), repository).get("error"), ERR_INVALID_DATA, "negative schema version component is rejected")

	var invalid_extensions := envelope.duplicate(true)
	invalid_extensions["extensions"] = []
	_write_json(MUTATED_PATH, invalid_extensions)
	_assert_equal(persistence.load_regiment(MUTATED_PATH, RegimentState.new(), repository).get("error"), ERR_INVALID_DATA, "invalid regiment extensions container is rejected")
	invalid_extensions["extensions"] = { "unowned_key": {} }
	_write_json(MUTATED_PATH, invalid_extensions)
	_assert_equal(persistence.load_regiment(MUTATED_PATH, RegimentState.new(), repository).get("error"), ERR_INVALID_DATA, "non-namespaced regiment extension is rejected")
	var invalid_state := RegimentState.new()
	invalid_state.interoperability_extensions = { "unowned_key": {} }
	_assert_equal(persistence.save_regiment(REGIMENT_ROUNDTRIP_PATH, invalid_state, repository).get("error"), ERR_INVALID_DATA, "OWCA refuses to write invalid extension keys")


func _test_character_contract(regiment_repository: RegimentDataRepository, character_repository: CharacterDataRepository) -> void:
	var regiment := RegimentState.new()
	regiment.load_example()
	var state := CharacterState.new()
	state.set_character_name("Varanox Operator")
	state.set_player_name("Interoperability Test")
	state.set_regiment(regiment.to_dict(), str(regiment_repository.data.get("content_version", "")))
	for characteristic in CharacterState.CHARACTERISTIC_ORDER:
		state.set_base_characteristic(characteristic, 30)
	state.set_speciality("operator")
	state.set_wounds_roll(3)
	state.set_fate_roll(8)
	state.set_choice("regiment", "hive_characteristic_1", "agility")
	state.set_choice("regiment", "hive_characteristic_2", "fellowship")
	state.set_choice("regiment", "hive_urban_violence", "paranoia")
	state.set_choice("regiment", "close_order_talent", "combat_formation")
	state.set_choice("speciality", "operator_knowledge_skill", "common_lore_tech")
	state.set_choice("speciality", "operator_weapon_training", "las")
	state.purchase_advance("skill:tech_use")
	state.mark_creation_complete()
	state.interoperability_extensions = {
		"com.example.combat/character": {
			"external_id": "character-operator-1"
		}
	}

	var calculation := CharacterCalculator.new().calculate(state, regiment_repository, character_repository)
	_assert_true(bool(calculation.get("valid", false)), "test character is valid")
	var persistence := CharacterPersistence.new()
	_assert_equal(persistence.save_character(CHARACTER_PATH, state, calculation, character_repository).get("error"), OK, "character save succeeds")

	var envelope := _read_json(CHARACTER_PATH)
	_assert_equal(envelope.get("format"), CharacterPersistence.FILE_FORMAT, "character format discriminator")
	_assert_equal(envelope.get("schema_version"), CharacterPersistence.SCHEMA_VERSION, "character public schema version")
	_assert_equal(envelope.get("equipment_rules_content_version"), "0.6.0-core-equipment", "character records equipment rules version")
	_assert_equal(envelope.get("version"), CharacterPersistence.FILE_VERSION, "current character envelope version")
	_assert_true(DocumentIdentity.is_valid(str(_nested(envelope, ["character", "document_id"]))), "character has a durable document ID")
	_assert_equal(_nested(envelope, ["character", "workflow_state"]), CharacterState.WORKFLOW_COMPLETE, "character completion state is explicit")
	_assert_equal(_nested(envelope, ["character", "speciality_id"]), "operator", "Speciality uses a stable ID")
	_assert_equal(_nested(envelope, ["character", "purchased_advances", 0]), "skill:tech_use", "advancement ledger uses a stable ID")
	_assert_true((_nested(envelope, ["calculated_preview", "skills"]) as Array).size() > 0, "character preview includes calculated Skills")
	_assert_true((_nested(envelope, ["calculated_preview", "talents"]) as Array).size() > 0, "character preview includes calculated Talents")
	_assert_true((_nested(envelope, ["calculated_preview", "equipment"]) as Array).size() > 0, "character preview includes calculated equipment")

	# Calculated previews are caches, not an alternate way to modify a character.
	var mutated := envelope.duplicate(true)
	(mutated["calculated_preview"] as Dictionary)["characteristics"] = { "Agility": 999 }
	_write_json(MUTATED_PATH, mutated)
	var loaded := CharacterState.new()
	_assert_equal(persistence.load_character(MUTATED_PATH, loaded).get("error"), OK, "character with modified preview loads")
	var recalculated := CharacterCalculator.new().calculate(loaded, regiment_repository, character_repository)
	_assert_equal(recalculated["characteristics"]["Agility"], calculation["characteristics"]["Agility"], "load ignores calculated preview")
	_assert_equal(loaded.interoperability_extensions, state.interoperability_extensions, "character extensions load intact")
	_assert_equal(loaded.document_id, state.document_id, "character document identity loads intact")
	_assert_equal(persistence.save_character(CHARACTER_ROUNDTRIP_PATH, loaded, recalculated, character_repository).get("error"), OK, "loaded character saves again")
	_assert_equal(_read_json(CHARACTER_ROUNDTRIP_PATH).get("extensions"), state.interoperability_extensions, "character extensions round-trip intact")
	_assert_equal(_nested(_read_json(CHARACTER_ROUNDTRIP_PATH), ["character", "document_id"]), state.document_id, "Save As preserves character identity")
	var duplicate_state := CharacterState.new()
	_assert_equal(duplicate_state.from_dict(state.to_dict()), OK, "clone character for Duplicate")
	duplicate_state.duplicate_identity()
	_assert_true(duplicate_state.document_id != state.document_id, "Duplicate creates a new character identity")
	_assert_equal(duplicate_state.workflow_state, CharacterState.WORKFLOW_DRAFT, "Duplicate resets character lifecycle to draft")
	var edited_state := CharacterState.new()
	_assert_equal(edited_state.from_dict(state.to_dict()), OK, "clone completed character for edit")
	edited_state.set_base_characteristic("Agility", 31)
	_assert_equal(edited_state.workflow_state, CharacterState.WORKFLOW_DRAFT, "editing a completed character reopens draft")

	var legacy := envelope.duplicate(true)
	legacy["version"] = 2
	legacy.erase("schema_version")
	legacy.erase("producer")
	legacy.erase("extensions")
	legacy.erase("calculated_preview")
	(legacy["character"] as Dictionary)["version"] = 2
	(legacy["character"] as Dictionary).erase("document_id")
	(legacy["character"] as Dictionary).erase("workflow_state")
	var legacy_regiment := (legacy["character"] as Dictionary)["regiment"] as Dictionary
	legacy_regiment["version"] = 1
	legacy_regiment.erase("document_id")
	legacy_regiment.erase("workflow_state")
	_write_json(MUTATED_PATH, legacy)
	var version_two_state := CharacterState.new()
	var version_two_result := persistence.load_character(MUTATED_PATH, version_two_state)
	_assert_equal(version_two_result.get("error"), OK, "version 2 character envelope loads")
	_assert_true(DocumentIdentity.is_valid(version_two_state.document_id), "version 2 character receives a document ID")
	_assert_equal(version_two_state.workflow_state, CharacterState.WORKFLOW_DRAFT, "version 2 character safely defaults to draft")
	_assert_true(_array_contains_fragment(version_two_result.get("migration_report", []) as Array, "document ID"), "character migration report explains generated identity")
	_assert_equal(version_two_state.regiment.get("version"), RegimentState.SAVE_VERSION, "legacy embedded regiment migrates to the current state version")
	_assert_true(DocumentIdentity.is_valid(str(version_two_state.regiment.get("document_id", ""))), "legacy embedded regiment receives a document ID")
	_assert_equal(version_two_state.regiment.get("workflow_state"), RegimentState.WORKFLOW_DRAFT, "legacy embedded regiment safely defaults to draft")
	_assert_true(_array_contains_fragment(version_two_result.get("migration_report", []) as Array, "embedded regiment"), "character migration report explains embedded regiment migration")
	var migrated_calculation := CharacterCalculator.new().calculate(version_two_state, regiment_repository, character_repository)
	_assert_equal(persistence.save_character(CHARACTER_ROUNDTRIP_PATH, version_two_state, migrated_calculation, character_repository).get("error"), OK, "migrated legacy character writes a current envelope")
	var migrated_envelope := _read_json(CHARACTER_ROUNDTRIP_PATH)
	_assert_equal(_nested(migrated_envelope, ["character", "regiment", "version"]), RegimentState.SAVE_VERSION, "migrated character writes a current embedded regiment")
	_assert_true(DocumentIdentity.is_valid(str(_nested(migrated_envelope, ["character", "regiment", "document_id"]))), "migrated character writes the embedded regiment identity")

	var version_one := legacy.duplicate(true)
	version_one["version"] = 1
	(version_one["character"] as Dictionary)["version"] = 1
	(version_one["character"] as Dictionary).erase("purchased_advances")
	_write_json(MUTATED_PATH, version_one)
	var version_one_state := CharacterState.new()
	_assert_equal(persistence.load_character(MUTATED_PATH, version_one_state).get("error"), OK, "character envelope/state version 1 loads")
	_assert_true(version_one_state.purchased_advances.is_empty(), "version 1 character defaults to no purchases")

	var invalid_identity := envelope.duplicate(true)
	(invalid_identity["character"] as Dictionary)["document_id"] = "not-a-document-id"
	_write_json(MUTATED_PATH, invalid_identity)
	_assert_equal(persistence.load_character(MUTATED_PATH, CharacterState.new()).get("error"), ERR_INVALID_DATA, "invalid current character document ID is rejected")

	var future := envelope.duplicate(true)
	future["schema_version"] = "2.0.0"
	_write_json(MUTATED_PATH, future)
	_assert_equal(persistence.load_character(MUTATED_PATH, CharacterState.new()).get("error"), ERR_INVALID_DATA, "future character schema major is rejected")


func _test_schema_documents() -> void:
	for path in [
		"res://OWCA/data/owca_regiment_save.schema.json",
		"res://OWCA/data/owca_character_save.schema.json"
	]:
		var schema := _read_json(path)
		_assert_equal(schema.get("$schema"), "https://json-schema.org/draft/2020-12/schema", "%s uses JSON Schema 2020-12" % path)
		_assert_true("schema_version" in (schema.get("required", []) as Array), "%s requires the public schema version" % path)
	var regiment_schema := _read_json("res://OWCA/data/owca_regiment_save.schema.json")
	var regiment_required := (((regiment_schema.get("$defs", {}) as Dictionary).get("regiment_state", {}) as Dictionary).get("required", []) as Array)
	_assert_true("document_id" in regiment_required and "workflow_state" in regiment_required, "regiment schema requires identity and lifecycle")
	var character_schema := _read_json("res://OWCA/data/owca_character_save.schema.json")
	var character_required := (((character_schema.get("$defs", {}) as Dictionary).get("character_state", {}) as Dictionary).get("required", []) as Array)
	_assert_true("document_id" in character_required and "workflow_state" in character_required, "character schema requires identity and lifecycle")


func _test_published_examples(regiment_repository: RegimentDataRepository) -> void:
	var regiment_state := RegimentState.new()
	var regiment_result := RegimentPersistence.new().load_regiment(
		"res://OWCA/examples/13th_varanox_light_infantry.owreg.json",
		regiment_state,
		regiment_repository
	)
	_assert_equal(regiment_result.get("error"), OK, "published regiment example loads")
	_assert_equal(regiment_result.get("schema_version"), InteroperabilityContract.SCHEMA_VERSION, "published regiment example declares current schema")
	_assert_equal(regiment_state.workflow_state, RegimentState.WORKFLOW_COMPLETE, "published regiment example is complete")
	var character_state := CharacterState.new()
	var character_result := CharacterPersistence.new().load_character(
		"res://OWCA/examples/varanox_weapon_specialist.owchar.json",
		character_state
	)
	_assert_equal(character_result.get("error"), OK, "published character example loads")
	_assert_equal(character_result.get("schema_version"), InteroperabilityContract.SCHEMA_VERSION, "published character example declares current schema")
	_assert_equal(character_state.workflow_state, CharacterState.WORKFLOW_COMPLETE, "published character example is complete")


func _array_contains_fragment(values: Array, fragment: String) -> bool:
	for value: Variant in values:
		if fragment in str(value):
			return true
	return false


func _cleanup_test_files() -> void:
	for base_path in [REGIMENT_PATH, REGIMENT_ROUNDTRIP_PATH, CHARACTER_PATH, CHARACTER_ROUNDTRIP_PATH, MUTATED_PATH]:
		for suffix in ["", AtomicJsonStore.TEMP_SUFFIX, AtomicJsonStore.BACKUP_SUFFIX, AtomicJsonStore.FAILED_SUFFIX, AtomicJsonStore.FAILED_SUFFIX + AtomicJsonStore.TEMP_SUFFIX]:
			var path := ProjectSettings.globalize_path(base_path + suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_assert_true(false, "open JSON for reading: %s" % path)
		return {}
	var value: Variant = JSON.parse_string(file.get_as_text())
	if not value is Dictionary:
		_assert_true(false, "parse JSON object: %s" % path)
		return {}
	return value as Dictionary


func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_assert_true(false, "open JSON for writing: %s" % path)
		return
	file.store_string(JSON.stringify(value, "  "))


func _nested(root: Variant, path: Array) -> Variant:
	var current: Variant = root
	for key: Variant in path:
		if key is int:
			if not current is Array or int(key) < 0 or int(key) >= (current as Array).size():
				return null
			current = (current as Array)[int(key)]
		else:
			if not current is Dictionary or not (current as Dictionary).has(key):
				return null
			current = (current as Dictionary)[key]
	return current


func _assert_true(condition: bool, label: String) -> void:
	if condition:
		return
	_failures += 1
	printerr("FAIL: %s" % label)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	_failures += 1
	printerr("FAIL: %s (expected %s, got %s)" % [label, expected, actual])
