extends SceneTree

## Ensures release labels use project.godot instead of stale hard-coded versions.
## Run with: godot --headless --path . --script res://OWCA/tests/app_version_ui_test.gd


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var version := str(ProjectSettings.get_setting("application/config/version", "development"))
	await _assert_scene_contains(
		"res://OWCA/ui/LandingPage.tscn",
		"OWCA v%s  |  Rules summaries with source and page references" % version,
		"landing page displays the configured application version"
	)
	await _assert_scene_contains(
		"res://OWCA/ui/RegimentCreator.tscn",
		"REGIMENT CREATION  |  v%s" % version,
		"Regiment Creator displays the configured application version"
	)
	print("OWCA app version UI tests passed.")
	quit(0)


func _assert_scene_contains(scene_path: String, expected_text: String, label: String) -> void:
	var packed_scene := load(scene_path) as PackedScene
	_assert_true(packed_scene != null, "%s scene loads" % label)
	var instance := packed_scene.instantiate()
	root.add_child(instance)
	await process_frame
	_assert_true(_contains_label_text(instance, expected_text), label)
	instance.queue_free()
	await process_frame


func _contains_label_text(node: Node, expected_text: String) -> bool:
	if node is Label and (node as Label).text == expected_text:
		return true
	for child in node.get_children():
		if _contains_label_text(child as Node, expected_text):
			return true
	return false


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		printerr("FAILED: %s" % label)
		quit(1)
