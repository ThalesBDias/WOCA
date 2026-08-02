extends SceneTree

## Run with: godot --headless --path . --script res://OWCA/tests/music_manager_test.gd


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var manager := root.get_node_or_null("MusicManager")
	_assert_true(manager != null, "MusicManager autoload exists")
	var player := manager.get_node_or_null("WarGrinderPlayer") as AudioStreamPlayer
	_assert_true(player != null, "persistent music player exists")
	_assert_true(player.stream is AudioStreamMP3, "War Grinder imports as MP3")
	_assert_true(player.stream.get_length() > 0.0, "soundtrack contains playable audio")
	_assert_true((player.stream as AudioStreamMP3).loop, "soundtrack loops")
	_assert_true(is_equal_approx(player.volume_db, -14.0), "soundtrack uses restrained default volume")
	var landing_scene := load("res://OWCA/ui/LandingPage.tscn") as PackedScene
	var landing := landing_scene.instantiate() as Control
	root.add_child(landing)
	await process_frame
	var music_button := landing.get("music_button") as Button
	_assert_true(music_button != null and "ON" in music_button.text, "landing page shows enabled music control")
	manager.call("set_music_enabled", false)
	_assert_true(player.stream_paused, "music can be paused")
	_assert_true("OFF" in music_button.text, "landing control follows paused state")
	manager.call("set_music_enabled", true)
	_assert_true(not player.stream_paused, "music can resume")
	_assert_true("ON" in music_button.text, "landing control follows resumed state")
	landing.queue_free()
	manager.queue_free()
	await process_frame
	print("OWCA music manager tests passed.")
	quit(0)


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		printerr("FAILED: %s" % label)
		quit(1)
