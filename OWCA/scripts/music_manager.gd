extends Node

## Persistent OWCA soundtrack controller. Autoloaded so music survives scene changes.

signal music_enabled_changed(enabled: bool)

const MUSIC_STREAM := preload("res://OWCA/audio/war_grinder.mp3")
const DEFAULT_VOLUME_DB := -14.0

var _music_enabled := true
var _player: AudioStreamPlayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.name = "WarGrinderPlayer"
	_player.volume_db = DEFAULT_VOLUME_DB
	var looping_stream := MUSIC_STREAM.duplicate() as AudioStreamMP3
	looping_stream.loop = true
	_player.stream = looping_stream
	add_child(_player)
	_player.play()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_music()
		get_viewport().set_input_as_handled()


func is_music_enabled() -> bool:
	return _music_enabled


func set_music_enabled(value: bool) -> void:
	if _music_enabled == value:
		return
	_music_enabled = value
	if _music_enabled:
		if not _player.playing:
			_player.play()
		_player.stream_paused = false
	else:
		_player.stream_paused = true
	music_enabled_changed.emit(_music_enabled)


func toggle_music() -> void:
	set_music_enabled(not _music_enabled)
