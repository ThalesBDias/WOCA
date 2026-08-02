class_name CharacterState
extends RefCounted

## Serializable inputs for one character. Calculated values remain in CharacterCalculator.

signal changed

const SAVE_VERSION := 2
const CHARACTERISTIC_ORDER: Array[String] = [
	"Weapon Skill",
	"Ballistic Skill",
	"Strength",
	"Toughness",
	"Agility",
	"Intelligence",
	"Perception",
	"Willpower",
	"Fellowship"
]

var character_name: String = "New Character"
var player_name: String = ""
var regiment: Dictionary = {}
var regiment_rules_content_version: String = ""
var speciality_id: String = ""
var base_characteristics: Dictionary = {}
var manual_adjustments: Dictionary = {}
var regiment_resolutions: Dictionary = {}
var speciality_resolutions: Dictionary = {}
var wounds_roll: int = 0
var fate_roll: int = 0
var purchased_advances: Array[String] = []


func set_character_name(value: String) -> void:
	character_name = value.strip_edges()
	if character_name.is_empty():
		character_name = "Unnamed Character"
	changed.emit()


func set_player_name(value: String) -> void:
	player_name = value.strip_edges()
	changed.emit()


func set_regiment(regiment_data: Dictionary, content_version: String) -> void:
	regiment = regiment_data.duplicate(true)
	regiment_rules_content_version = content_version
	regiment_resolutions.clear()
	changed.emit()


func has_regiment() -> bool:
	return not regiment.is_empty()


func get_regiment_name() -> String:
	return str(regiment.get("name", "No regiment loaded"))


func set_speciality(value: String) -> void:
	if speciality_id == value:
		return
	speciality_id = value
	speciality_resolutions.clear()
	changed.emit()


func set_base_characteristic(characteristic: String, value: int) -> void:
	if value <= 0:
		base_characteristics.erase(characteristic)
	else:
		base_characteristics[characteristic] = value
	changed.emit()


func set_manual_adjustment(characteristic: String, value: int) -> void:
	if value == 0:
		manual_adjustments.erase(characteristic)
	else:
		manual_adjustments[characteristic] = value
	changed.emit()


func set_wounds_roll(value: int) -> void:
	wounds_roll = value
	changed.emit()


func set_fate_roll(value: int) -> void:
	fate_roll = value
	changed.emit()


func purchase_advance(advance_id: String) -> void:
	var clean_id := advance_id.strip_edges()
	if clean_id.is_empty():
		return
	purchased_advances.append(clean_id)
	changed.emit()


func remove_advance_at(index: int) -> void:
	if index < 0 or index >= purchased_advances.size():
		return
	purchased_advances.remove_at(index)
	changed.emit()


func clear_advances() -> void:
	if purchased_advances.is_empty():
		return
	purchased_advances.clear()
	changed.emit()


func set_choice(scope: String, choice_id: String, option_id: String, enabled: bool = true, maximum: int = 1) -> void:
	var collection := regiment_resolutions if scope == "regiment" else speciality_resolutions
	var current := get_choice(scope, choice_id)
	if enabled:
		if maximum == 1:
			current.assign([option_id])
		elif option_id not in current and (maximum <= 0 or current.size() < maximum):
			current.append(option_id)
	else:
		current.erase(option_id)
	if current.is_empty():
		collection.erase(choice_id)
	else:
		collection[choice_id] = current
	changed.emit()


func clear_choice(scope: String, choice_id: String) -> void:
	var collection := regiment_resolutions if scope == "regiment" else speciality_resolutions
	collection.erase(choice_id)
	changed.emit()


func get_choice(scope: String, choice_id: String) -> Array[String]:
	var collection := regiment_resolutions if scope == "regiment" else speciality_resolutions
	var output: Array[String] = []
	for value: Variant in collection.get(choice_id, []):
		output.append(str(value))
	return output


func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"name": character_name,
		"player_name": player_name,
		"regiment": regiment.duplicate(true),
		"regiment_rules_content_version": regiment_rules_content_version,
		"speciality_id": speciality_id,
		"base_characteristics": base_characteristics.duplicate(true),
		"manual_adjustments": manual_adjustments.duplicate(true),
		"regiment_resolutions": regiment_resolutions.duplicate(true),
		"speciality_resolutions": speciality_resolutions.duplicate(true),
		"wounds_roll": wounds_roll,
		"fate_roll": fate_roll,
		"purchased_advances": purchased_advances.duplicate()
	}


func from_dict(value: Dictionary) -> Error:
	var version := int(value.get("version", 0))
	if version not in [1, SAVE_VERSION]:
		return ERR_INVALID_DATA
	for field_name in ["regiment", "base_characteristics", "manual_adjustments", "regiment_resolutions", "speciality_resolutions"]:
		if not value.get(field_name, {}) is Dictionary:
			return ERR_INVALID_DATA

	character_name = str(value.get("name", "Unnamed Character")).strip_edges()
	if character_name.is_empty():
		character_name = "Unnamed Character"
	player_name = str(value.get("player_name", "")).strip_edges()
	regiment = (value.get("regiment", {}) as Dictionary).duplicate(true)
	regiment_rules_content_version = str(value.get("regiment_rules_content_version", ""))
	speciality_id = str(value.get("speciality_id", ""))
	base_characteristics = _clean_numeric_dictionary(value.get("base_characteristics", {}) as Dictionary, false)
	manual_adjustments = _clean_numeric_dictionary(value.get("manual_adjustments", {}) as Dictionary, true)
	regiment_resolutions = _clean_resolution_dictionary(value.get("regiment_resolutions", {}) as Dictionary)
	speciality_resolutions = _clean_resolution_dictionary(value.get("speciality_resolutions", {}) as Dictionary)
	wounds_roll = int(value.get("wounds_roll", 0))
	fate_roll = int(value.get("fate_roll", 0))
	purchased_advances.clear()
	if version >= 2:
		if not value.get("purchased_advances", []) is Array:
			return ERR_INVALID_DATA
		for advance_id: Variant in value.get("purchased_advances", []):
			var clean_id := str(advance_id).strip_edges()
			if not clean_id.is_empty():
				purchased_advances.append(clean_id)
	changed.emit()
	return OK


func _clean_numeric_dictionary(value: Dictionary, allow_zero: bool) -> Dictionary:
	var output: Dictionary = {}
	for key: Variant in value:
		var name := str(key)
		if name not in CHARACTERISTIC_ORDER:
			continue
		var number := int(value[key])
		if allow_zero or number > 0:
			output[name] = number
	return output


func _clean_resolution_dictionary(value: Dictionary) -> Dictionary:
	var output: Dictionary = {}
	for choice_id: Variant in value:
		if not value[choice_id] is Array:
			continue
		var entries: Array[String] = []
		for answer_id: Variant in value[choice_id]:
			var clean_id := str(answer_id)
			if not clean_id.is_empty() and clean_id not in entries:
				entries.append(clean_id)
		if not entries.is_empty():
			output[str(choice_id)] = entries
	return output
