class_name AtomicJsonStore
extends RefCounted

## Crash-conscious JSON storage used by every OWCA save format.
##
## A new document is written beside its destination as `.tmp`, flushed, opened
## again, parsed, and passed through the format validator. Only then is the
## previous valid destination rotated to `.bak` and the staged file renamed into
## place. A surviving valid `.tmp` is never overwritten silently: it becomes a
## recovery candidate the player can inspect or accept.

const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"
const FAILED_SUFFIX := ".failed"


static func save_dictionary(path: String, data: Dictionary, validator: Callable = Callable()) -> Dictionary:
	var destination := _absolute_path(path)
	if destination.is_empty():
		return { "error": ERR_INVALID_PARAMETER, "message": "Save path is empty." }
	var temporary := destination + TEMP_SUFFIX
	var discarded_invalid_temporary := false
	if FileAccess.file_exists(temporary):
		var existing_temporary := read_dictionary(temporary, validator)
		if int(existing_temporary.get("error", ERR_INVALID_DATA)) == OK:
			return {
				"error": ERR_ALREADY_EXISTS,
				"message": "A valid interrupted-save candidate already exists beside this file. Recover or discard it before saving again.",
				"recovery": inspect_recovery(destination, validator)
			}
		if DirAccess.remove_absolute(temporary) != OK:
			return { "error": ERR_CANT_CREATE, "message": "Could not remove an invalid temporary save file." }
		discarded_invalid_temporary = true

	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return { "error": FileAccess.get_open_error(), "message": "Could not create temporary save file beside %s." % path }
	file.store_string(JSON.stringify(data, "  "))
	file.flush()
	file = null

	var staged := read_dictionary(temporary, validator)
	if int(staged.get("error", ERR_INVALID_DATA)) != OK:
		DirAccess.remove_absolute(temporary)
		return {
			"error": ERR_INVALID_DATA,
			"message": "Temporary save failed post-write validation; the previous file was not changed.",
			"validation_message": str(staged.get("message", "Unknown validation error."))
		}

	var replacement := _replace_with_staged(destination, temporary, validator)
	replacement["discarded_invalid_temporary"] = discarded_invalid_temporary
	if int(replacement.get("error", ERR_INVALID_DATA)) == OK:
		replacement["message"] = "Saved atomically to %s%s" % [
			path,
			"; previous valid file backed up." if bool(replacement.get("backup_created", false)) else "."
		]
	return replacement


## Reads, parses, and optionally validates one complete JSON object.
static func read_dictionary(path: String, validator: Callable = Callable()) -> Dictionary:
	var source := _absolute_path(path)
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null:
		return { "error": FileAccess.get_open_error(), "message": "Could not open %s." % path }
	var parser := JSON.new()
	var parse_error := parser.parse(file.get_as_text())
	if parse_error != OK:
		return {
			"error": parse_error,
			"message": "Invalid JSON at line %d: %s" % [parser.get_error_line(), parser.get_error_message()]
		}
	if not parser.data is Dictionary:
		return { "error": ERR_INVALID_DATA, "message": "Save file must contain one JSON object." }
	var data := parser.data as Dictionary
	var validation := _run_validator(data, validator)
	if int(validation.get("error", ERR_INVALID_DATA)) != OK:
		return validation
	return { "error": OK, "message": "JSON object is valid.", "data": data }


## Reports recovery candidates without changing any file. A normal `.bak` is
## retained for safety but only demands attention when the destination is bad.
static func inspect_recovery(path: String, validator: Callable = Callable()) -> Dictionary:
	var destination := _absolute_path(path)
	var temporary := destination + TEMP_SUFFIX
	var backup := destination + BACKUP_SUFFIX
	var target_exists := FileAccess.file_exists(destination)
	var target_valid := target_exists and int(read_dictionary(destination, validator).get("error", ERR_INVALID_DATA)) == OK
	var temporary_exists := FileAccess.file_exists(temporary)
	var temporary_valid := temporary_exists and int(read_dictionary(temporary, validator).get("error", ERR_INVALID_DATA)) == OK
	var backup_exists := FileAccess.file_exists(backup)
	var backup_valid := backup_exists and int(read_dictionary(backup, validator).get("error", ERR_INVALID_DATA)) == OK
	return {
		"destination": destination,
		"target_exists": target_exists,
		"target_valid": target_valid,
		"temporary_path": temporary,
		"temporary_exists": temporary_exists,
		"temporary_valid": temporary_valid,
		"backup_path": backup,
		"backup_exists": backup_exists,
		"backup_valid": backup_valid,
		"recovery_available": temporary_valid or (not target_valid and backup_valid),
		"recommended": "temporary" if temporary_valid else ("backup" if not target_valid and backup_valid else "")
	}


static func recover_temporary(path: String, validator: Callable = Callable()) -> Dictionary:
	var destination := _absolute_path(path)
	var temporary := destination + TEMP_SUFFIX
	var staged := read_dictionary(temporary, validator)
	if int(staged.get("error", ERR_INVALID_DATA)) != OK:
		return { "error": ERR_INVALID_DATA, "message": "No valid interrupted-save candidate is available." }
	var result := _replace_with_staged(destination, temporary, validator, true)
	if int(result.get("error", ERR_INVALID_DATA)) == OK:
		result["message"] = "Recovered the validated interrupted save."
	return result


static func restore_backup(path: String, validator: Callable = Callable()) -> Dictionary:
	var destination := _absolute_path(path)
	var backup := destination + BACKUP_SUFFIX
	var backup_result := read_dictionary(backup, validator)
	if int(backup_result.get("error", ERR_INVALID_DATA)) != OK:
		return { "error": ERR_INVALID_DATA, "message": "No valid backup is available." }

	var temporary := destination + TEMP_SUFFIX
	if FileAccess.file_exists(temporary):
		var preserved_temporary := destination + FAILED_SUFFIX + TEMP_SUFFIX
		_remove_if_present(preserved_temporary)
		var preserve_error := DirAccess.rename_absolute(temporary, preserved_temporary)
		if preserve_error != OK:
			return { "error": preserve_error, "message": "Could not preserve the existing temporary candidate." }

	var failed_target := destination + FAILED_SUFFIX
	_remove_if_present(failed_target)
	if FileAccess.file_exists(destination):
		var move_error := DirAccess.rename_absolute(destination, failed_target)
		if move_error != OK:
			return { "error": move_error, "message": "Could not preserve the current destination before backup recovery." }

	var copy_error := DirAccess.copy_absolute(backup, destination)
	if copy_error != OK:
		if FileAccess.file_exists(failed_target):
			DirAccess.rename_absolute(failed_target, destination)
		return { "error": copy_error, "message": "Could not restore the backup." }
	var restored := read_dictionary(destination, validator)
	if int(restored.get("error", ERR_INVALID_DATA)) != OK:
		DirAccess.remove_absolute(destination)
		if FileAccess.file_exists(failed_target):
			DirAccess.rename_absolute(failed_target, destination)
		return { "error": ERR_INVALID_DATA, "message": "Restored backup failed validation; the previous destination was returned." }
	return { "error": OK, "message": "Restored the last validated backup.", "preserved_failed_path": failed_target }


static func discard_temporary(path: String) -> Dictionary:
	var temporary := _absolute_path(path) + TEMP_SUFFIX
	if not FileAccess.file_exists(temporary):
		return { "error": OK, "message": "No temporary save candidate exists." }
	var remove_error := DirAccess.remove_absolute(temporary)
	return {
		"error": remove_error,
		"message": "Discarded the temporary save candidate." if remove_error == OK else "Could not discard the temporary save candidate."
	}


static func _replace_with_staged(destination: String, temporary: String, validator: Callable, preserve_invalid_target: bool = false) -> Dictionary:
	var backup := destination + BACKUP_SUFFIX
	var backup_created := false
	var failed_target := destination + FAILED_SUFFIX
	if FileAccess.file_exists(destination):
		var current := read_dictionary(destination, validator)
		if int(current.get("error", ERR_INVALID_DATA)) != OK:
			if not preserve_invalid_target:
				return {
					"error": ERR_INVALID_DATA,
					"message": "Existing destination is invalid. Recover it or use Save As; the validated temporary file was preserved.",
					"recovery": inspect_recovery(destination, validator)
				}
			_remove_if_present(failed_target)
			var failed_move_error := DirAccess.rename_absolute(destination, failed_target)
			if failed_move_error != OK:
				return { "error": failed_move_error, "message": "Could not preserve the invalid destination before recovery." }
		else:
			_remove_if_present(backup)
			var backup_error := DirAccess.rename_absolute(destination, backup)
			if backup_error != OK:
				return { "error": backup_error, "message": "Could not create a backup of the previous valid file." }
			backup_created = true

	var replace_error := DirAccess.rename_absolute(temporary, destination)
	if replace_error != OK:
		if backup_created and FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, destination)
		elif FileAccess.file_exists(failed_target):
			DirAccess.rename_absolute(failed_target, destination)
		return { "error": replace_error, "message": "Could not replace the destination; the previous file was restored where possible." }
	return { "error": OK, "backup_created": backup_created, "backup_path": backup }


static func _run_validator(data: Dictionary, validator: Callable) -> Dictionary:
	if not validator.is_valid():
		return { "error": OK }
	var result: Variant = validator.call(data)
	if result is Dictionary:
		var dictionary := result as Dictionary
		if int(dictionary.get("error", ERR_INVALID_DATA)) == OK:
			return { "error": OK }
		return {
			"error": int(dictionary.get("error", ERR_INVALID_DATA)),
			"message": str(dictionary.get("message", "Save-file validation failed."))
		}
	if result is bool:
		return { "error": OK } if bool(result) else { "error": ERR_INVALID_DATA, "message": "Save-file validation failed." }
	return { "error": ERR_INVALID_DATA, "message": "Save-file validator returned an unsupported result." }


static func _absolute_path(path: String) -> String:
	var clean_path := path.strip_edges()
	return ProjectSettings.globalize_path(clean_path) if not clean_path.is_empty() else ""


static func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
