extends SceneTree

## Run with: godot --headless --path . --script res://OWCA/tests/atomic_json_store_test.gd

const SAVE_PATH := "user://owca_atomic_store_test.json"
var _failures := 0


func _init() -> void:
	_cleanup()
	var validator := Callable(self, "_validate_test_document")

	var first := AtomicJsonStore.save_dictionary(SAVE_PATH, { "format": "atomic_test", "sequence": 1 }, validator)
	_assert_equal(first.get("error"), OK, "initial atomic save")
	_assert_true(not bool(first.get("backup_created", false)), "new file needs no backup")
	_assert_equal(_read_sequence(SAVE_PATH), 1, "initial destination content")

	var second := AtomicJsonStore.save_dictionary(SAVE_PATH, { "format": "atomic_test", "sequence": 2 }, validator)
	_assert_equal(second.get("error"), OK, "replacement atomic save")
	_assert_true(bool(second.get("backup_created", false)), "replacement creates backup")
	_assert_equal(_read_sequence(SAVE_PATH), 2, "replacement destination content")
	_assert_equal(_read_sequence(SAVE_PATH + AtomicJsonStore.BACKUP_SUFFIX), 1, "backup keeps previous valid content")

	_write_raw(SAVE_PATH + AtomicJsonStore.TEMP_SUFFIX, JSON.stringify({ "format": "atomic_test", "sequence": 3 }))
	var blocked := AtomicJsonStore.save_dictionary(SAVE_PATH, { "format": "atomic_test", "sequence": 4 }, validator)
	_assert_equal(blocked.get("error"), ERR_ALREADY_EXISTS, "valid interrupted save is never overwritten")
	var inspection := AtomicJsonStore.inspect_recovery(SAVE_PATH, validator)
	_assert_true(bool(inspection.get("temporary_valid", false)), "valid temporary candidate detected")
	_assert_equal(inspection.get("recommended"), "temporary", "temporary recovery is recommended")
	var recovered := AtomicJsonStore.recover_temporary(SAVE_PATH, validator)
	_assert_equal(recovered.get("error"), OK, "temporary candidate recovery")
	_assert_equal(_read_sequence(SAVE_PATH), 3, "temporary candidate becomes destination")
	_assert_equal(_read_sequence(SAVE_PATH + AtomicJsonStore.BACKUP_SUFFIX), 2, "recovery backs up previous destination")

	_write_raw(SAVE_PATH, "{ definitely not valid JSON")
	inspection = AtomicJsonStore.inspect_recovery(SAVE_PATH, validator)
	_assert_true(not bool(inspection.get("target_valid", true)), "corrupt destination detected")
	_assert_true(bool(inspection.get("backup_valid", false)), "valid backup detected")
	_assert_equal(inspection.get("recommended"), "backup", "backup recovery is recommended")
	var restored := AtomicJsonStore.restore_backup(SAVE_PATH, validator)
	_assert_equal(restored.get("error"), OK, "backup restoration")
	_assert_equal(_read_sequence(SAVE_PATH), 2, "backup becomes valid destination")

	_write_raw(SAVE_PATH + AtomicJsonStore.TEMP_SUFFIX, "invalid temporary data")
	var after_invalid_temp := AtomicJsonStore.save_dictionary(SAVE_PATH, { "format": "atomic_test", "sequence": 5 }, validator)
	_assert_equal(after_invalid_temp.get("error"), OK, "invalid temporary candidate does not block saving")
	_assert_true(bool(after_invalid_temp.get("discarded_invalid_temporary", false)), "invalid temporary candidate is reported as discarded")
	_assert_equal(_read_sequence(SAVE_PATH), 5, "save after invalid temporary succeeds")

	var rejected := AtomicJsonStore.save_dictionary(SAVE_PATH, { "format": "wrong", "sequence": 6 }, validator)
	_assert_equal(rejected.get("error"), ERR_INVALID_DATA, "post-write validator rejects bad format")
	_assert_equal(_read_sequence(SAVE_PATH), 5, "failed validation preserves previous destination")

	_cleanup()
	if _failures > 0:
		printerr("OWCA atomic JSON store tests failed: %d assertion(s)." % _failures)
		quit(1)
		return
	print("OWCA atomic JSON store tests passed.")
	quit(0)


func _validate_test_document(data: Dictionary) -> Dictionary:
	if str(data.get("format", "")) != "atomic_test" or not data.has("sequence"):
		return { "error": ERR_INVALID_DATA, "message": "Unexpected test document." }
	return { "error": OK }


func _read_sequence(path: String) -> int:
	var result := AtomicJsonStore.read_dictionary(path, Callable(self, "_validate_test_document"))
	if int(result.get("error", ERR_INVALID_DATA)) != OK:
		_assert_true(false, "read valid sequence from %s" % path)
		return -1
	return int((result.get("data", {}) as Dictionary).get("sequence", -1))


func _write_raw(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_assert_true(false, "write test fixture %s" % path)
		return
	file.store_string(value)


func _cleanup() -> void:
	for suffix in ["", AtomicJsonStore.TEMP_SUFFIX, AtomicJsonStore.BACKUP_SUFFIX, AtomicJsonStore.FAILED_SUFFIX, AtomicJsonStore.FAILED_SUFFIX + AtomicJsonStore.TEMP_SUFFIX]:
		var path := ProjectSettings.globalize_path(SAVE_PATH + suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


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
