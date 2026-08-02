extends Control

## Entry point for the two independent OWCA creation workflows.

const REGIMENT_SCENE := "res://OWCA/ui/RegimentCreator.tscn"
const CHARACTER_SCENE := "res://OWCA/ui/CharacterCreator.tscn"

const COLOUR_BACKGROUND := Color("#101612")
const COLOUR_PANEL_ALT := Color("#202b23")
const COLOUR_BORDER := Color("#52614d")
const COLOUR_GOLD := Color("#d5b35b")
const COLOUR_TEXT := Color("#e7eadf")
const COLOUR_MUTED := Color("#a5ad9d")

var music_button: Button


func _ready() -> void:
	_build_interface()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = COLOUR_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 72)
	margin.add_theme_constant_override("margin_top", 54)
	margin.add_theme_constant_override("margin_right", 72)
	margin.add_theme_constant_override("margin_bottom", 42)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 28)
	margin.add_child(page)

	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", 6)
	page.add_child(header)
	var title := Label.new()
	title.text = "ONLY WAR CHARACTER ASSISTANT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", COLOUR_GOLD)
	header.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Prepare the regiment. Then prepare the soldiers who serve in it."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", COLOUR_MUTED)
	header.add_child(subtitle)

	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spacer_top)

	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 24)
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	page.add_child(cards)
	cards.add_child(_build_workflow_card(
		"CREATE REGIMENT",
		"AVAILABLE",
		"Choose a Home World, Commanding Officer, Regiment Type, and optional doctrines. Validate the 12-point build and save a regiment file.",
		"OPEN REGIMENT CREATOR",
		_open_regiment_creator
	))
	cards.add_child(_build_workflow_card(
		"CREATE CHARACTER",
		"GUARDSMAN TEST",
		"Load a saved regiment, enter the nine rolled Characteristics, choose one of five Core Guardsman Specialities, and resolve every individual starting choice.",
		"OPEN CHARACTER CREATOR",
		_open_character_creator
	))

	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(spacer_bottom)

	var music_row := HBoxContainer.new()
	music_row.alignment = BoxContainer.ALIGNMENT_CENTER
	music_row.add_theme_constant_override("separation", 12)
	page.add_child(music_row)
	var track_label := Label.new()
	track_label.text = "NOW PLAYING: WAR GRINDER"
	track_label.add_theme_font_size_override("font_size", 11)
	track_label.add_theme_color_override("font_color", COLOUR_MUTED)
	music_row.add_child(track_label)
	music_button = Button.new()
	music_button.custom_minimum_size = Vector2(130, 34)
	music_button.pressed.connect(MusicManager.toggle_music)
	music_row.add_child(music_button)
	MusicManager.music_enabled_changed.connect(_on_music_enabled_changed)
	_on_music_enabled_changed(MusicManager.is_music_enabled())

	var footer := Label.new()
	footer.text = "OWCA v0.3  |  Rules summaries with source and page references"
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.add_theme_font_size_override("font_size", 12)
	footer.add_theme_color_override("font_color", COLOUR_MUTED)
	page.add_child(footer)


func _on_music_enabled_changed(enabled: bool) -> void:
	if music_button != null:
		music_button.text = "MUSIC: %s  [M]" % ("ON" if enabled else "OFF")


func _build_workflow_card(title_text: String, status_text: String, description: String, button_text: String, callback: Callable) -> PanelContainer:
	var panel := _make_panel(COLOUR_PANEL_ALT, COLOUR_BORDER, 22)
	panel.custom_minimum_size = Vector2(455, 310)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)

	var status := Label.new()
	status.text = status_text
	status.add_theme_font_size_override("font_size", 11)
	status.add_theme_color_override("font_color", COLOUR_GOLD)
	column.add_child(status)

	var heading := Label.new()
	heading.text = title_text
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", COLOUR_TEXT)
	column.add_child(heading)

	column.add_child(HSeparator.new())

	var body := Label.new()
	body.text = description
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", COLOUR_MUTED)
	column.add_child(body)

	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size.y = 48
	button.pressed.connect(callback)
	column.add_child(button)
	return panel


func _make_panel(fill: Color, border: Color, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = padding
	style.content_margin_top = padding
	style.content_margin_right = padding
	style.content_margin_bottom = padding
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _open_regiment_creator() -> void:
	get_tree().change_scene_to_file(REGIMENT_SCENE)


func _open_character_creator() -> void:
	get_tree().change_scene_to_file(CHARACTER_SCENE)
