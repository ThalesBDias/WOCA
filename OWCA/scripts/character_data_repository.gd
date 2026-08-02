class_name CharacterDataRepository
extends RefCounted

## Loads the first character-creation slice: the five Core Guardsman Specialities.

const DEFAULT_DATA_PATH := "res://OWCA/data/guardsman_specialities.json"

var data: Dictionary = {}
var last_error: String = ""
var _specialities_by_id: Dictionary = {}
var _choices_by_id: Dictionary = {}


func load_data(path: String = DEFAULT_DATA_PATH) -> Error:
	last_error = ""
	_specialities_by_id.clear()
	_choices_by_id.clear()

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		last_error = "Could not open character rules data: %s" % path
		return FileAccess.get_open_error()
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		last_error = "Character rules JSON line %d: %s" % [parser.get_error_line(), parser.get_error_message()]
		return parse_error
	if not parser.data is Dictionary:
		last_error = "Character rules JSON root must be an object."
		return ERR_PARSE_ERROR

	data = parser.data as Dictionary
	if int(data.get("schema_version", 0)) != 1:
		last_error = "Unsupported character rules schema version."
		return ERR_INVALID_DATA

	var validation_error := _validate_loaded_data()
	if not validation_error.is_empty():
		last_error = validation_error
		_specialities_by_id.clear()
		_choices_by_id.clear()
		return ERR_INVALID_DATA
	return OK


func get_specialities() -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for value: Variant in data.get("specialities", []):
		if value is Dictionary:
			output.append(value as Dictionary)
	return output


func get_speciality(speciality_id: String) -> Dictionary:
	return _specialities_by_id.get(speciality_id, {}) as Dictionary


func get_choice(choice_id: String) -> Dictionary:
	return _choices_by_id.get(choice_id, {}) as Dictionary


func get_catalog_entry(catalog: String, entry_id: String) -> Dictionary:
	return (data.get(catalog, {}) as Dictionary).get(entry_id, {}) as Dictionary


func get_catalog_name(catalog: String, entry_id: String) -> String:
	var entry := get_catalog_entry(catalog, entry_id)
	return str(entry.get("name", entry_id.replace("_", " ").capitalize()))


func get_source_label(source_reference: Dictionary) -> String:
	var source_id := str(source_reference.get("book", ""))
	var source := (data.get("sources", {}) as Dictionary).get(source_id, {}) as Dictionary
	var title := str(source.get("short", source.get("title", source_id)))
	var page := int(source_reference.get("page", 0))
	var page_end := int(source_reference.get("page_end", 0))
	if page > 0 and page_end > page:
		return "%s pp. %d-%d" % [title, page, page_end]
	return "%s p. %d" % [title, page] if page > 0 else title


func get_speciality_choice_ids(speciality_id: String) -> Array[String]:
	var output: Array[String] = []
	for value: Variant in get_speciality(speciality_id).get("choices", []):
		if value is Dictionary:
			output.append(str((value as Dictionary).get("id", "")))
	return output


func _validate_loaded_data() -> String:
	if not data.get("specialities", []) is Array:
		return "Character rules must contain a specialities array."
	for value: Variant in data.get("specialities", []):
		if not value is Dictionary:
			return "Every Speciality must be an object."
		var speciality := value as Dictionary
		var speciality_id := str(speciality.get("id", ""))
		if speciality_id.is_empty() or _specialities_by_id.has(speciality_id):
			return "Every Speciality needs a unique, non-empty id."
		_specialities_by_id[speciality_id] = speciality
		if str(speciality.get("group", "")) != "guardsman":
			return "This character-data slice only accepts Guardsman Specialities."
		var effect_error := _validate_effects(speciality.get("effects", {}) as Dictionary, "Speciality '%s'" % speciality_id)
		if not effect_error.is_empty():
			return effect_error
		for choice_value: Variant in speciality.get("choices", []):
			if not choice_value is Dictionary:
				return "Speciality '%s' contains a choice that is not an object." % speciality_id
			var choice := choice_value as Dictionary
			var choice_id := str(choice.get("id", ""))
			if choice_id.is_empty() or _choices_by_id.has(choice_id):
				return "Character choice IDs must be globally unique; invalid id '%s'." % choice_id
			_choices_by_id[choice_id] = choice
			var minimum := int(choice.get("minimum", 1))
			var maximum := int(choice.get("maximum", 1))
			if minimum < 0 or maximum < minimum:
				return "Choice '%s' has invalid selection limits." % choice_id
			var option_ids: Dictionary = {}
			for answer_value: Variant in choice.get("options", []):
				if not answer_value is Dictionary:
					return "Choice '%s' contains an answer that is not an object." % choice_id
				var answer := answer_value as Dictionary
				var answer_id := str(answer.get("id", ""))
				if answer_id.is_empty() or option_ids.has(answer_id):
					return "Choice '%s' has a missing or duplicate answer id '%s'." % [choice_id, answer_id]
				option_ids[answer_id] = true
				var answer_error := _validate_effects(answer.get("effects", {}) as Dictionary, "Choice '%s' answer '%s'" % [choice_id, answer_id])
				if not answer_error.is_empty():
					return answer_error
			if option_ids.size() < maximum:
				return "Choice '%s' does not contain enough answers for its maximum." % choice_id
	return ""


func _validate_effects(effects: Dictionary, context: String) -> String:
	for catalog_name in ["skills", "talents"]:
		var catalog := data.get(catalog_name, {}) as Dictionary
		for entry_id: Variant in effects.get(catalog_name, []):
			if not catalog.has(str(entry_id)):
				return "%s references unknown %s id '%s'." % [context, catalog_name, entry_id]
	var equipment_catalog := data.get("equipment", {}) as Dictionary
	for equipment_value: Variant in effects.get("equipment", []):
		if not equipment_value is Dictionary:
			return "%s contains a non-object equipment grant." % context
		var equipment_id := str((equipment_value as Dictionary).get("id", ""))
		if not equipment_catalog.has(equipment_id):
			return "%s references unknown equipment id '%s'." % [context, equipment_id]
	return ""
