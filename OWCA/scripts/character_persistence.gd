class_name CharacterPersistence
extends RefCounted

## Versioned JSON persistence for individual OWCA characters.

const FILE_FORMAT := "owca_character"
const FILE_VERSION := 2


func save_character(path: String, state: CharacterState, calculation: Dictionary, character_repository: CharacterDataRepository) -> Dictionary:
	var envelope := {
		"format": FILE_FORMAT,
		"version": FILE_VERSION,
		"saved_at_utc": Time.get_datetime_string_from_system(true),
		"character_rules_content_version": str(character_repository.data.get("content_version", "unknown")),
		"advancement_rules_content_version": str(character_repository.advancement_data.get("content_version", "unknown")),
		"character": state.to_dict(),
		"calculated_preview": _build_preview(calculation)
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return { "error": FileAccess.get_open_error(), "message": "Could not write %s." % path }
	file.store_string(JSON.stringify(envelope, "  "))
	return { "error": OK, "message": "Saved character to %s." % path }


func load_character(path: String, state: CharacterState) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return { "error": FileAccess.get_open_error(), "message": "Could not open %s." % path }
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		return { "error": parse_error, "message": "Invalid JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()] }
	if not parser.data is Dictionary:
		return { "error": ERR_INVALID_DATA, "message": "Character save must contain a JSON object." }
	var envelope := parser.data as Dictionary
	if str(envelope.get("format", "")) != FILE_FORMAT or int(envelope.get("version", 0)) not in [1, FILE_VERSION]:
		return { "error": ERR_INVALID_DATA, "message": "Unsupported character save format or version." }
	if not envelope.get("character", {}) is Dictionary:
		return { "error": ERR_INVALID_DATA, "message": "Character save has no state object." }
	var state_error := state.from_dict(envelope["character"] as Dictionary)
	if state_error != OK:
		return { "error": state_error, "message": "Character state is invalid or from an unsupported version." }
	return { "error": OK, "message": "Loaded character from %s." % path }


func _build_preview(calculation: Dictionary) -> Dictionary:
	if calculation.is_empty():
		return {}
	return {
		"valid": bool(calculation.get("valid", false)),
		"speciality": str(calculation.get("speciality_name", "")),
		"characteristics": (calculation.get("characteristics", {}) as Dictionary).duplicate(true),
		"wounds": int(calculation.get("wounds", 0)),
		"fate_points": int(calculation.get("fate_points", 0)),
		"xp_spent": int(calculation.get("xp_spent", 0)),
		"xp_remaining": int(calculation.get("xp_remaining", 0))
	}
