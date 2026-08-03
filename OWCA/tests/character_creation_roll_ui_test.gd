extends SceneTree

## Run with: godot --headless --path . --script res://OWCA/tests/character_creation_roll_ui_test.gd


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://OWCA/ui/CharacterCreator.tscn") as PackedScene
	var creator := packed_scene.instantiate() as Control
	root.add_child(creator)
	await process_frame

	creator.call("_select_stage", "characteristics")
	await process_frame
	var stage_content := creator.get("stage_content") as Node
	_assert_true(_find_button(stage_content, "ROLL ALL CHARACTERISTICS") != null, "roll-all Characteristic action is visible")
	_assert_equal(_count_buttons(stage_content, "ROLL"), 9, "each Characteristic has an individual roll action")

	creator.call("_roll_all_characteristics")
	await process_frame
	var state := creator.get("state") as CharacterState
	var details := creator.get("creation_roll_details") as Dictionary
	_assert_equal(state.base_characteristics.size(), 9, "roll-all fills all base Characteristics")
	_assert_equal(details.size(), 9, "roll-all displays nine audit records")
	for characteristic in CharacterState.CHARACTERISTIC_ORDER:
		_assert_true(int(state.base_characteristics[characteristic]) in range(22, 41), "%s roll is valid" % characteristic)
		_assert_true("=" in str(details[characteristic]), "%s audit shows arithmetic" % characteristic)

	var previous_weapon_skill := int(state.base_characteristics["Weapon Skill"])
	creator.call("_request_characteristic_roll", "Weapon Skill")
	await process_frame
	var overwrite_dialog := creator.get("roll_overwrite_dialog") as ConfirmationDialog
	_assert_true(overwrite_dialog.visible, "rerolling an entered value requires confirmation")
	_assert_equal(int(state.base_characteristics["Weapon Skill"]), previous_weapon_skill, "value is unchanged before confirmation")
	overwrite_dialog.hide()
	creator.call("_clear_pending_roll_action")

	creator.call("_on_base_characteristic_changed", 31.0, "Weapon Skill")
	details = creator.get("creation_roll_details") as Dictionary
	_assert_true(not details.has("Weapon Skill"), "manual edit clears stale roll evidence")

	creator.call("_select_stage", "derived")
	await process_frame
	stage_content = creator.get("stage_content") as Node
	_assert_true(_find_button(stage_content, "ROLL WOUNDS + FATE") != null, "combined derived roll action is visible")
	_assert_true(_find_button(stage_content, "ROLL 1D5") != null, "Wounds roll action is visible")
	_assert_true(_find_button(stage_content, "ROLL 1D10") != null, "Fate roll action is visible")
	creator.call("_roll_wounds_and_fate")
	await process_frame
	_assert_true(state.wounds_roll in range(1, 6), "OWCA Wounds roll is valid")
	_assert_true(state.fate_roll in range(1, 11), "OWCA Fate roll is valid")

	print("OWCA character creation roll UI tests passed.")
	quit(0)


func _find_button(node: Node, exact_text: String) -> Button:
	for child in node.get_children():
		if child is Button and (child as Button).text == exact_text:
			return child as Button
		var nested := _find_button(child, exact_text)
		if nested != null:
			return nested
	return null


func _count_buttons(node: Node, exact_text: String) -> int:
	var count := 0
	for child in node.get_children():
		if child is Button and (child as Button).text == exact_text:
			count += 1
		count += _count_buttons(child, exact_text)
	return count


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		printerr("FAILED: %s" % label)
		quit(1)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		printerr("FAILED: %s (expected %s, got %s)" % [label, expected, actual])
		quit(1)
