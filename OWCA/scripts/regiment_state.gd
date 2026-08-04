class_name RegimentState
extends RefCounted

## Serializable mutable regiment state.
##
## It contains option and choice IDs only. Points, combined effects, validity,
## and deferred per-character benefits remain derived calculator output.

signal changed

const SAVE_VERSION := 2
const WORKFLOW_DRAFT := "draft"
const WORKFLOW_COMPLETE := "creation_complete"
const WORKFLOW_STATES: Array[String] = [WORKFLOW_DRAFT, WORKFLOW_COMPLETE]

var document_id: String = ""
var workflow_state: String = WORKFLOW_DRAFT
var regiment_name: String = "New Regiment"
var selections: Dictionary = {}
var resolutions: Dictionary = {}
## Opaque, namespaced data owned by external tools. OWCA never interprets these
## values, but persistence keeps them intact across load/save cycles.
var interoperability_extensions: Dictionary = {}


func _init() -> void:
	document_id = DocumentIdentity.generate()
	for category in ["home_world", "commander", "regiment_type", "training_doctrine", "equipment_doctrine"]:
		selections[category] = []


func set_regiment_name(value: String) -> void:
	regiment_name = value.strip_edges()
	if regiment_name.is_empty():
		regiment_name = "Unnamed Regiment"
	changed.emit()


## Selects or removes one stable option ID while enforcing the category's basic
## cardinality. Cross-option compatibility remains a calculator responsibility.
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
	_mark_creation_draft()
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
	_mark_creation_draft()
	changed.emit()


func clear_choice(choice_id: String) -> void:
	resolutions.erase(choice_id)
	_mark_creation_draft()
	changed.emit()


func get_choice(choice_id: String) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in resolutions.get(choice_id, []):
		result.append(str(value))
	return result


func clear_all() -> void:
	document_id = DocumentIdentity.generate()
	workflow_state = WORKFLOW_DRAFT
	regiment_name = "New Regiment"
	for category: Variant in selections:
		selections[category] = []
	resolutions.clear()
	interoperability_extensions.clear()
	changed.emit()


func load_example() -> void:
	document_id = DocumentIdentity.generate()
	workflow_state = WORKFLOW_DRAFT
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
		"document_id": document_id,
		"workflow_state": workflow_state,
		"name": regiment_name,
		"selections": selections.duplicate(true),
		"resolutions": resolutions.duplicate(true)
	}


func from_dict(value: Dictionary) -> Error:
	var version := int(value.get("version", 0))
	if version not in [1, SAVE_VERSION]:
		return ERR_INVALID_DATA
	if not value.get("selections", {}) is Dictionary or not value.get("resolutions", {}) is Dictionary:
		return ERR_INVALID_DATA

	if version >= 2:
		var loaded_document_id := str(value.get("document_id", ""))
		var loaded_workflow_state := str(value.get("workflow_state", ""))
		if not DocumentIdentity.is_valid(loaded_document_id) or loaded_workflow_state not in WORKFLOW_STATES:
			return ERR_INVALID_DATA
		document_id = loaded_document_id
		workflow_state = loaded_workflow_state
	else:
		document_id = DocumentIdentity.generate()
		workflow_state = WORKFLOW_DRAFT

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
	interoperability_extensions.clear()
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


## Marks a validated build complete. UI/services must verify calculator validity
## before calling this; state deliberately does not depend on the rules engine.
func mark_creation_complete() -> void:
	workflow_state = WORKFLOW_COMPLETE
	changed.emit()


func mark_draft() -> void:
	workflow_state = WORKFLOW_DRAFT
	changed.emit()


func duplicate_identity() -> void:
	document_id = DocumentIdentity.generate()
	workflow_state = WORKFLOW_DRAFT
	changed.emit()


func _mark_creation_draft() -> void:
	if workflow_state == WORKFLOW_COMPLETE:
		workflow_state = WORKFLOW_DRAFT
