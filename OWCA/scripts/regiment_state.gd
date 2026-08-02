class_name RegimentState
extends RefCounted

## Serializable mutable state. It contains choices only; derived rules stay in the calculator.

signal changed

const SAVE_VERSION := 1

var regiment_name: String = "New Regiment"
var selections: Dictionary = {}
var resolutions: Dictionary = {}


func _init() -> void:
	for category in ["home_world", "commander", "regiment_type", "training_doctrine", "equipment_doctrine"]:
		selections[category] = []


func set_regiment_name(value: String) -> void:
	regiment_name = value.strip_edges()
	if regiment_name.is_empty():
		regiment_name = "Unnamed Regiment"
	changed.emit()


func set_option(category: String, option_id: String, selected: bool, maximum: int) -> void:
	var current := get_selected_for_category(category)
	if selected:
		if option_id in current:
			return
		if maximum == 1:
			current.clear()
		elif maximum > 0 and current.size() >= maximum:
			return
		current.append(option_id)
	else:
		current.erase(option_id)
	selections[category] = current
	changed.emit()


func is_selected(option_id: String) -> bool:
	for category: Variant in selections:
		if option_id in get_selected_for_category(str(category)):
			return true
	return false


func get_selected_for_category(category: String) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in selections.get(category, []):
		result.append(str(value))
	return result


func get_all_selected_ids() -> Array[String]:
	var result: Array[String] = []
	for category: Variant in selections:
		result.append_array(get_selected_for_category(str(category)))
	return result


func set_choice(choice_id: String, option_id: String, enabled: bool = true, maximum: int = 1) -> void:
	var current := get_choice(choice_id)
	if enabled:
		if maximum == 1:
			current.assign([option_id])
		elif option_id not in current and (maximum <= 0 or current.size() < maximum):
			current.append(option_id)
	else:
		current.erase(option_id)
	resolutions[choice_id] = current
	changed.emit()


func clear_choice(choice_id: String) -> void:
	resolutions.erase(choice_id)
	changed.emit()


func get_choice(choice_id: String) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in resolutions.get(choice_id, []):
		result.append(str(value))
	return result


func clear_all() -> void:
	regiment_name = "New Regiment"
	for category: Variant in selections:
		selections[category] = []
	resolutions.clear()
	changed.emit()


func load_example() -> void:
	regiment_name = "13th Varanox Light Infantry"
	selections = {
		"home_world": ["hive_world"],
		"commander": ["choleric"],
		"regiment_type": ["light_infantry"],
		"training_doctrine": ["close_order_drill"],
		"equipment_doctrine": ["scavengers"]
	}
	resolutions.clear()
	changed.emit()


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"name": regiment_name,
		"selections": selections.duplicate(true),
		"resolutions": resolutions.duplicate(true)
	}


func from_dict(value: Dictionary) -> Error:
	if int(value.get("version", 0)) != SAVE_VERSION:
		return ERR_INVALID_DATA
	if not value.get("selections", {}) is Dictionary or not value.get("resolutions", {}) is Dictionary:
		return ERR_INVALID_DATA

	regiment_name = str(value.get("name", "Unnamed Regiment")).strip_edges()
	if regiment_name.is_empty():
		regiment_name = "Unnamed Regiment"

	var loaded_selections := value.get("selections", {}) as Dictionary
	for category: Variant in selections:
		var clean_values: Array[String] = []
		var raw_values: Variant = loaded_selections.get(category, [])
		if not raw_values is Array:
			return ERR_INVALID_DATA
		for entry: Variant in raw_values:
			clean_values.append(str(entry))
		selections[category] = clean_values

	resolutions.clear()
	var loaded_resolutions := value.get("resolutions", {}) as Dictionary
	for choice_id: Variant in loaded_resolutions:
		var clean_values: Array[String] = []
		var raw_values: Variant = loaded_resolutions[choice_id]
		if not raw_values is Array:
			return ERR_INVALID_DATA
		for entry: Variant in raw_values:
			clean_values.append(str(entry))
		resolutions[str(choice_id)] = clean_values

	changed.emit()
	return OK
