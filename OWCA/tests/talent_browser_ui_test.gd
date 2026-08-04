extends SceneTree

## Run with: godot --headless --path . --script res://OWCA/tests/talent_browser_ui_test.gd

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed_scene := load("res://OWCA/ui/CharacterCreator.tscn") as PackedScene
	_assert_true(packed_scene != null, "Character Creator scene loads")
	var creator := packed_scene.instantiate() as Control
	root.add_child(creator)
	await process_frame
	creator.set("advancement_filter", "talent")
	creator.set("advancement_search", "Never Die")
	creator.call("_select_stage", "xp")
	await process_frame

	var stage_content := creator.get("stage_content") as Node
	var search := _find_search(stage_content)
	_assert_true(search != null, "Talent browser exposes search")
	_assert_true(search.text == "Never Die", "search text survives browser rendering")
	_assert_equal(_collect_option_buttons(stage_content).size(), 3, "Tier, Aptitude, and status filters render")
	_assert_true(_contains_exact_label(stage_content, "Never Die"), "name search finds the expected Talent")
	_assert_equal(_filter_summary(creator), "SHOWING 1 OF 124 CORE TALENTS", "name search narrows the complete catalog")

	creator.set("advancement_search", "")
	creator.set("talent_status_filter", "unsupported")
	creator.call("_refresh_advancement_options")
	await process_frame
	_assert_equal(_filter_summary(creator), "SHOWING 10 OF 124 CORE TALENTS", "unsupported-choice filter exposes every blocked specialist or variable-cost Talent")

	creator.set("talent_status_filter", "all")
	creator.set("talent_tier_filter", 3)
	creator.set("talent_aptitude_filter", "Toughness")
	creator.call("_refresh_advancement_options")
	await process_frame
	var options_container := creator.get("advancement_options_container") as Node
	_assert_true(_contains_exact_label(options_container, "Never Die"), "Tier and Aptitude filters retain matching Talents")
	_assert_true(_contains_exact_label(options_container, "True Grit"), "Tier and Aptitude filters retain all matches")
	_assert_true(not _contains_exact_label(options_container, "Sound Constitution"), "Tier filter excludes nonmatching Talents")

	if _failures > 0:
		printerr("OWCA Talent browser UI tests failed: %d assertion(s)." % _failures)
		quit(1)
		return
	print("OWCA Talent browser UI tests passed.")
	quit(0)


func _find_search(node: Node) -> LineEdit:
	for child in node.get_children():
		if child is LineEdit and (child as LineEdit).placeholder_text.begins_with("Search by Talent"):
			return child as LineEdit
		var nested := _find_search(child)
		if nested != null:
			return nested
	return null


func _collect_option_buttons(node: Node) -> Array[OptionButton]:
	var output: Array[OptionButton] = []
	_collect_option_buttons_into(node, output)
	return output


func _collect_option_buttons_into(node: Node, output: Array[OptionButton]) -> void:
	for child in node.get_children():
		if child is OptionButton:
			output.append(child as OptionButton)
		_collect_option_buttons_into(child, output)


func _contains_exact_label(node: Node, expected_text: String) -> bool:
	for child in node.get_children():
		if child is Label and (child as Label).text == expected_text:
			return true
		if _contains_exact_label(child, expected_text):
			return true
	return false


func _filter_summary(creator: Control) -> String:
	var label := creator.get("talent_filter_summary") as Label
	return label.text if label != null else ""


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		printerr("FAILED: %s. Expected %s, got %s." % [label, expected, actual])
		_failures += 1


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		printerr("FAILED: %s" % label)
		_failures += 1
