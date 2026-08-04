extends SceneTree

## Protects the player-facing v0.5.1 file-safety workflow from UI regressions.
## Run with: godot --headless --path . --script res://OWCA/tests/file_safety_ui_test.gd


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	await _test_regiment_controls()
	await _test_character_controls()
	await _test_recovery_prompt()
	print("OWCA file-safety UI tests passed.")
	quit(0)


func _test_regiment_controls() -> void:
	var packed_scene := load("res://OWCA/ui/RegimentCreator.tscn") as PackedScene
	_assert_true(packed_scene != null, "Regiment Creator scene loads")
	var creator := packed_scene.instantiate() as Control
	root.add_child(creator)
	await process_frame

	_assert_true(_find_button(creator, "SAVE AS") != null, "regiment header exposes Save As")
	_assert_true(_find_button(creator, "DUPLICATE") != null, "regiment status panel exposes Duplicate")
	var lifecycle_button := _find_button(creator, "MARK COMPLETE")
	_assert_true(lifecycle_button != null, "regiment status panel exposes lifecycle action")
	_assert_true(lifecycle_button.disabled, "incomplete regiment cannot be marked complete")

	var save_dialog := creator.get("save_dialog") as FileDialog
	var duplicate_dialog := creator.get("duplicate_dialog") as FileDialog
	_assert_true(save_dialog != null and save_dialog.title == "Save Regiment JSON As", "regiment Save As has an explicit destination dialog")
	_assert_true(duplicate_dialog != null and duplicate_dialog.title == "Duplicate Regiment as New Record", "regiment Duplicate explains that it creates a new record")
	_assert_true(creator.get("recovery_dialog") is SaveRecoveryDialog, "regiment controller owns the shared recovery prompt")

	creator.call("_load_example")
	await process_frame
	lifecycle_button = creator.get("lifecycle_button") as Button
	_assert_true(not lifecycle_button.disabled, "valid example regiment can be marked complete")
	creator.call("_toggle_completion")
	await process_frame
	_assert_true(lifecycle_button.text == "REOPEN DRAFT", "completed regiment can be explicitly reopened")

	creator.queue_free()
	await process_frame


func _test_character_controls() -> void:
	var packed_scene := load("res://OWCA/ui/CharacterCreator.tscn") as PackedScene
	_assert_true(packed_scene != null, "Character Creator scene loads")
	var creator := packed_scene.instantiate() as Control
	root.add_child(creator)
	await process_frame

	_assert_true(_find_button(creator, "SAVE AS") != null, "character header exposes Save As")
	_assert_true(creator.get("recovery_dialog") is SaveRecoveryDialog, "character controller owns the shared recovery prompt")
	var save_dialog := creator.get("character_save_dialog") as FileDialog
	var duplicate_dialog := creator.get("character_duplicate_dialog") as FileDialog
	_assert_true(save_dialog != null and save_dialog.title == "Save Character JSON As", "character Save As has an explicit destination dialog")
	_assert_true(duplicate_dialog != null and duplicate_dialog.title == "Duplicate Character as New Record", "character Duplicate explains that it creates a new record")

	creator.call("_select_stage", "review")
	await process_frame
	var stage_content := creator.get("stage_content") as Node
	_assert_true(_find_button(stage_content, "SAVE CHARACTER JSON AS") != null, "character review exposes Save As")
	_assert_true(_find_button(stage_content, "DUPLICATE AS NEW CHARACTER RECORD") != null, "character review exposes Duplicate")
	var lifecycle_button := _find_button(stage_content, "MARK CREATION COMPLETE")
	_assert_true(lifecycle_button != null and lifecycle_button.disabled, "incomplete character cannot be marked complete")

	var state := creator.get("state") as CharacterState
	state.mark_creation_complete()
	creator.call("_refresh")
	await process_frame
	stage_content = creator.get("stage_content") as Node
	_assert_true(_find_button(stage_content, "REOPEN AS DRAFT") != null, "completed character can be explicitly reopened")
	creator.call("_on_wounds_roll_changed", 1.0)
	_assert_true(state.workflow_state == CharacterState.WORKFLOW_DRAFT, "editing a creation input reopens a completed character")

	creator.queue_free()
	await process_frame


func _test_recovery_prompt() -> void:
	var dialog := SaveRecoveryDialog.new()
	root.add_child(dialog)
	await process_frame

	_assert_true(dialog.title == "OWCA Save Recovery", "recovery prompt has an explicit title")
	_assert_true(dialog.get_ok_button().text == "RECOVER", "recovery action is explicit")
	_assert_true(dialog.get_cancel_button().text == "KEEP CURRENT FILE", "cancel action preserves the current file")
	var discard_button := dialog.get("_discard_button") as Button
	_assert_true(discard_button != null and discard_button.text == "DISCARD TEMPORARY", "temporary discard action is explicit")
	# Do not call present() here. Opening a modal Window currently crashes the
	# Godot 4.7 Windows headless display path; recovery behavior is instead
	# exercised end-to-end by atomic_json_store_test.gd.

	dialog.queue_free()
	await process_frame


func _find_button(node: Node, exact_text: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == exact_text:
			return child as Button
		var nested := _find_button(child as Node, exact_text)
		if nested != null:
			return nested
	return null


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		printerr("FAILED: %s" % label)
		quit(1)
