class_name RegimentPersistence
extends RefCounted

## Versioned JSON persistence kept separate from the UI and rules engine.

const FILE_FORMAT := "owca_regiment"
const FILE_VERSION := 1


func save_regiment(path: String, state: RegimentState, repository: RegimentDataRepository) -> Dictionary:
	var regiment_data := state.to_dict()
	_filter_character_resolutions(regiment_data, repository)
	var envelope := {
		"format": FILE_FORMAT,
		"version": FILE_VERSION,
		"saved_at_utc": Time.get_datetime_string_from_system(true),
		"rules_content_version": str(repository.data.get("content_version", "unknown")),
		"character_creation_choices": _collect_character_choices(state, repository),
		"regiment": regiment_data
	}
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return { "error": FileAccess.get_open_error(), "message": "Could not write %s." % path }
	file.store_string(JSON.stringify(envelope, "  "))
	return { "error": OK, "message": "Saved regiment to %s." % path }


func load_regiment(path: String, state: RegimentState, repository: RegimentDataRepository) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return { "error": FileAccess.get_open_error(), "message": "Could not open %s." % path }
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		return { "error": parse_error, "message": "Invalid JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()] }
	if not parser.data is Dictionary:
		return { "error": ERR_INVALID_DATA, "message": "Regiment save must contain a JSON object." }
	var envelope := parser.data as Dictionary
	if str(envelope.get("format", "")) != FILE_FORMAT or int(envelope.get("version", 0)) != FILE_VERSION:
		return { "error": ERR_INVALID_DATA, "message": "Unsupported regiment save format or version." }
	if not envelope.get("regiment", {}) is Dictionary:
		return { "error": ERR_INVALID_DATA, "message": "Regiment save has no state object." }
	var regiment_data := (envelope["regiment"] as Dictionary).duplicate(true)
	_filter_character_resolutions(regiment_data, repository)
	var state_error := state.from_dict(regiment_data)
	if state_error != OK:
		return { "error": state_error, "message": "Regiment state is invalid or from an unsupported version." }
	return { "error": OK, "message": "Loaded regiment from %s." % path }


func _filter_character_resolutions(regiment_data: Dictionary, repository: RegimentDataRepository) -> void:
	var raw_resolutions: Variant = regiment_data.get("resolutions", {})
	if not raw_resolutions is Dictionary:
		return
	var resolutions := raw_resolutions as Dictionary
	for choice_id: Variant in resolutions.keys():
		var choice := repository.get_choice(str(choice_id))
		if str(choice.get("scope", "regiment")) == "per_character":
			resolutions.erase(choice_id)
	regiment_data["resolutions"] = resolutions


func _collect_character_choices(state: RegimentState, repository: RegimentDataRepository) -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for option_id in state.get_all_selected_ids():
		var option := repository.get_option(option_id)
		for choice_value: Variant in option.get("choices", []):
			if choice_value is Dictionary:
				var choice := choice_value as Dictionary
				if str(choice.get("scope", "regiment")) == "per_character":
					choices.append(choice.duplicate(true))
	return choices
