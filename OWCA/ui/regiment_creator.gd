extends Control

## Thin UI/controller for OWCA. Rules and persistence live in dedicated services.

const LANDING_SCENE := "res://OWCA/ui/LandingPage.tscn"

const CATEGORY_ORDER: Array[String] = [
	"home_world",
	"commander",
	"regiment_type",
	"training_doctrine",
	"equipment_doctrine"
]

const COLOUR_BACKGROUND := Color("#101612")
const COLOUR_PANEL := Color("#19221c")
const COLOUR_PANEL_ALT := Color("#202b23")
const COLOUR_BORDER := Color("#52614d")
const COLOUR_GOLD := Color("#d5b35b")
const COLOUR_TEXT := Color("#e7eadf")
const COLOUR_MUTED := Color("#a5ad9d")
const COLOUR_GOOD := Color("#84c58a")
const COLOUR_BAD := Color("#ef7c70")

var repository := RegimentDataRepository.new()
var state := RegimentState.new()
var calculator := RegimentCalculator.new()
var persistence := RegimentPersistence.new()
var exporter := DossierExporter.new()
var calculation: Dictionary = {}
var active_category: String = "home_world"
var action_message: String = "Ready. Select a stage to begin, or load the Varanox example."

var name_edit: LineEdit
var stage_buttons: Dictionary = {}
var category_title: Label
var option_list: VBoxContainer
var summary_text: RichTextLabel
var choices_list: VBoxContainer
var points_label: Label
var doctrine_label: Label
var validity_label: Label
var notices_text: RichTextLabel
var save_dialog: FileDialog
var load_dialog: FileDialog
var export_dialog: FileDialog


func _ready() -> void:
	var load_error := repository.load_data()
	if load_error != OK:
		_show_fatal_error(repository.last_error)
		return
	_build_interface()
	state.changed.connect(_refresh)
	_refresh()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = COLOUR_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	page.add_child(_build_header())
	page.add_child(_build_workspace())
	page.add_child(_build_status_panel())
	_build_dialogs()


func _build_header() -> Control:
	var panel := _make_panel(COLOUR_PANEL, COLOUR_BORDER, 8)
	panel.custom_minimum_size.y = 76
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	var title_column := VBoxContainer.new()
	title_column.custom_minimum_size.x = 315
	row.add_child(title_column)
	var title := Label.new()
	title.text = "ONLY WAR CHARACTER ASSISTANT"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", COLOUR_GOLD)
	title_column.add_child(title)
	var subtitle := Label.new()
	# project.godot is the single source of truth for the displayed app version.
	var app_version := str(ProjectSettings.get_setting("application/config/version", "development"))
	subtitle.text = "REGIMENT CREATION  |  v%s" % app_version
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", COLOUR_MUTED)
	title_column.add_child(subtitle)

	var name_column := VBoxContainer.new()
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_column)
	var name_label := Label.new()
	name_label.text = "REGIMENT DESIGNATION"
	name_label.add_theme_font_size_override("font_size", 11)
	name_label.add_theme_color_override("font_color", COLOUR_MUTED)
	name_column.add_child(name_label)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Enter regiment name"
	name_edit.text_changed.connect(_on_name_changed)
	name_edit.focus_exited.connect(_on_name_committed)
	name_column.add_child(name_edit)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	row.add_child(actions)
	actions.add_child(_make_action_button("HOME", _return_home))
	actions.add_child(_make_action_button("13TH VARANOX", _load_example))
	actions.add_child(_make_action_button("SAVE", _request_save))
	actions.add_child(_make_action_button("LOAD", _request_load))
	actions.add_child(_make_action_button("EXPORT", _request_export))
	return panel


func _build_workspace() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 12)

	var stage_panel := _make_panel(COLOUR_PANEL, COLOUR_BORDER, 8)
	stage_panel.custom_minimum_size.x = 220
	row.add_child(stage_panel)
	var stage_column := VBoxContainer.new()
	stage_column.add_theme_constant_override("separation", 8)
	stage_panel.add_child(stage_column)
	stage_column.add_child(_section_label("CREATION STAGES"))
	var stage_group := ButtonGroup.new()
	for category in CATEGORY_ORDER:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = stage_group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 48
		button.pressed.connect(_select_category.bind(category))
		stage_column.add_child(button)
		stage_buttons[category] = button
	(stage_buttons[active_category] as Button).button_pressed = true
	var stage_spacer := Control.new()
	stage_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage_column.add_child(stage_spacer)
	var note := Label.new()
	note.text = "Choose exactly 1 Regiment Type.\nThen choose up to 2 optional\ndoctrines total from Training\nand Equipment."
	note.add_theme_font_size_override("font_size", 11)
	note.add_theme_color_override("font_color", COLOUR_MUTED)
	stage_column.add_child(note)

	var option_panel := _make_panel(COLOUR_PANEL_ALT, COLOUR_BORDER, 8)
	option_panel.custom_minimum_size.x = 410
	option_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_panel.size_flags_stretch_ratio = 1.05
	row.add_child(option_panel)
	var option_column := VBoxContainer.new()
	option_column.add_theme_constant_override("separation", 10)
	option_panel.add_child(option_column)
	category_title = _section_label("")
	option_column.add_child(category_title)
	var option_scroll := ScrollContainer.new()
	option_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	option_column.add_child(option_scroll)
	option_list = VBoxContainer.new()
	option_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option_list.add_theme_constant_override("separation", 10)
	option_scroll.add_child(option_list)

	var summary_panel := _make_panel(COLOUR_PANEL, COLOUR_BORDER, 8)
	summary_panel.custom_minimum_size.x = 390
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_panel.size_flags_stretch_ratio = 1.25
	row.add_child(summary_panel)
	var summary_column := VBoxContainer.new()
	summary_column.add_theme_constant_override("separation", 8)
	summary_panel.add_child(summary_column)
	summary_column.add_child(_section_label("LIVE REGIMENT SUMMARY"))
	summary_text = RichTextLabel.new()
	summary_text.bbcode_enabled = true
	summary_text.scroll_active = true
	summary_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_text.custom_minimum_size.y = 245
	summary_column.add_child(summary_text)
	var choice_heading := _section_label("REGIMENT CHOICES")
	choice_heading.add_theme_font_size_override("font_size", 12)
	summary_column.add_child(choice_heading)
	var choices_scroll := ScrollContainer.new()
	choices_scroll.custom_minimum_size.y = 165
	choices_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_column.add_child(choices_scroll)
	choices_list = VBoxContainer.new()
	choices_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices_list.add_theme_constant_override("separation", 5)
	choices_scroll.add_child(choices_list)
	return row


func _build_status_panel() -> Control:
	var panel := _make_panel(COLOUR_PANEL_ALT, COLOUR_BORDER, 8)
	panel.custom_minimum_size.y = 122
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)

	var metrics := VBoxContainer.new()
	metrics.custom_minimum_size.x = 205
	row.add_child(metrics)
	points_label = Label.new()
	points_label.add_theme_font_size_override("font_size", 17)
	metrics.add_child(points_label)
	doctrine_label = Label.new()
	doctrine_label.add_theme_font_size_override("font_size", 17)
	metrics.add_child(doctrine_label)
	validity_label = Label.new()
	validity_label.add_theme_font_size_override("font_size", 13)
	metrics.add_child(validity_label)

	var divider := VSeparator.new()
	row.add_child(divider)
	notices_text = RichTextLabel.new()
	notices_text.bbcode_enabled = true
	notices_text.fit_content = false
	notices_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notices_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(notices_text)
	return panel


func _build_dialogs() -> void:
	save_dialog = FileDialog.new()
	save_dialog.title = "Save Regiment JSON"
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.filters = PackedStringArray(["*.owreg.json ; OWCA Regiment JSON"])
	save_dialog.file_selected.connect(_save_to_path)
	add_child(save_dialog)

	load_dialog = FileDialog.new()
	load_dialog.title = "Load Regiment JSON"
	load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	load_dialog.filters = PackedStringArray(["*.json ; JSON files"])
	load_dialog.file_selected.connect(_load_from_path)
	add_child(load_dialog)

	export_dialog = FileDialog.new()
	export_dialog.title = "Export Regiment Dossier"
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	export_dialog.filters = PackedStringArray(["*.txt ; Text dossier"])
	export_dialog.file_selected.connect(_export_to_path)
	add_child(export_dialog)


func _refresh() -> void:
	calculation = calculator.calculate(state, repository)
	if name_edit != null and name_edit.text != state.regiment_name:
		name_edit.text = state.regiment_name
	_render_stage_buttons()
	_render_options()
	_render_summary()
	_render_choices()
	_render_status()


func _render_stage_buttons() -> void:
	for category in CATEGORY_ORDER:
		var rule := repository.get_selection_rule(category)
		var count := state.get_selected_for_category(category).size()
		var maximum := int(rule.get("maximum", 0))
		var counter := str(count)
		if category in ["home_world", "commander", "regiment_type"] and maximum > 0:
			counter = "%d/%d" % [count, maximum]
		(stage_buttons[category] as Button).text = "%s\n%s selected" % [rule.get("label", category.capitalize()), counter]


func _render_options() -> void:
	_clear_children(option_list)
	var rule := repository.get_selection_rule(active_category)
	category_title.text = str(rule.get("label", active_category.capitalize())).to_upper()
	var options := repository.get_options_for_category(active_category)
	if options.is_empty():
		var empty := Label.new()
		empty.text = "No options are installed for this stage yet."
		empty.add_theme_color_override("font_color", COLOUR_MUTED)
		option_list.add_child(empty)
		return
	for option in options:
		option_list.add_child(_build_option_card(option, rule))


func _build_option_card(option: Dictionary, rule: Dictionary) -> Control:
	var selected := state.is_selected(str(option["id"]))
	var card := _make_panel(Color("#263128") if selected else Color("#1b241e"), COLOUR_GOLD if selected else COLOUR_BORDER, 7)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	card.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var option_name := Label.new()
	option_name.text = str(option.get("name", option.get("id", "Option")))
	option_name.add_theme_font_size_override("font_size", 18)
	option_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(option_name)
	var cost := Label.new()
	cost.text = "%d PTS" % int(option.get("cost", 0))
	cost.add_theme_font_size_override("font_size", 15)
	cost.add_theme_color_override("font_color", COLOUR_GOLD)
	top.add_child(cost)
	var summary := Label.new()
	summary.text = str(option.get("summary", ""))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_color_override("font_color", COLOUR_MUTED)
	column.add_child(summary)
	var bottom := HBoxContainer.new()
	column.add_child(bottom)
	var source := Label.new()
	source.text = repository.get_source_label(option.get("source", {}) as Dictionary)
	source.add_theme_font_size_override("font_size", 11)
	source.add_theme_color_override("font_color", COLOUR_MUTED)
	source.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(source)
	var toggle := CheckButton.new()
	toggle.text = "SELECTED" if selected else "SELECT"
	toggle.button_pressed = selected
	toggle.toggled.connect(_on_option_toggled.bind(str(option["category"]), str(option["id"]), int(rule.get("maximum", 0))))
	bottom.add_child(toggle)
	return card


func _render_summary() -> void:
	var lines: Array[String] = []
	lines.append("[font_size=20][color=#d5b35b]%s[/color][/font_size]" % _escape_bbcode(state.regiment_name))
	lines.append("")
	for category in CATEGORY_ORDER:
		var names: Array[String] = []
		for option_id in state.get_selected_for_category(category):
			names.append(str(repository.get_option(option_id).get("name", option_id)))
		if not names.is_empty():
			lines.append("[color=#a5ad9d]%s:[/color] %s" % [repository.get_selection_rule(category).get("label", category.capitalize()), ", ".join(names)])

	lines.append("\n[color=#d5b35b][b]FIXED CHARACTERISTIC MODIFIERS[/b][/color]")
	var characteristic_parts: Array[String] = []
	for characteristic_name: Variant in (calculation["characteristics"] as Dictionary):
		characteristic_parts.append("%s %s" % [characteristic_name, _signed(int(calculation["characteristics"][characteristic_name]))])
	characteristic_parts.sort()
	lines.append(", ".join(characteristic_parts) if not characteristic_parts.is_empty() else "-")

	lines.append("\n[color=#d5b35b][b]SKILLS[/b][/color]")
	var skills: Array[String] = []
	for skill: Dictionary in calculation["skills"]:
		skills.append("%s [%s]" % [skill["name"], skill["rank_label"]])
	lines.append(", ".join(skills) if not skills.is_empty() else "-")

	lines.append("\n[color=#d5b35b][b]TALENTS[/b][/color]")
	var talents: Array[String] = []
	for talent: Dictionary in calculation["talents"]:
		talents.append(str(talent["name"]))
	lines.append(", ".join(talents) if not talents.is_empty() else "-")
	if int(calculation.get("bonus_xp", 0)) > 0:
		lines.append("Duplicate Talent compensation: +%d XP per character" % int(calculation["bonus_xp"]))

	lines.append("\n[color=#d5b35b][b]APTITUDES[/b][/color]")
	lines.append(", ".join(calculation["aptitudes"] as Array) if not (calculation["aptitudes"] as Array).is_empty() else "-")

	lines.append("\n[color=#d5b35b][b]SPECIAL RULES[/b][/color]")
	if (calculation["special_rules"] as Array).is_empty():
		lines.append("-")
	for rule: Dictionary in calculation["special_rules"]:
		lines.append("[b]%s:[/b] %s" % [rule.get("name", "Rule"), rule.get("summary", "")])

	lines.append("\n[color=#d5b35b][b]WOUNDS[/b][/color] Starting modifier %s" % _signed(int(calculation["wounds"])))
	lines.append("[color=#d5b35b][b]ADDITIONAL KIT POOL[/b][/color] %d points" % int(calculation["standard_kit_points"]))
	lines.append("\n[color=#d5b35b][b]STANDARD EQUIPMENT[/b][/color]")
	var equipment: Array[String] = []
	for item: Dictionary in calculation["equipment"]:
		equipment.append("%dx %s" % [item.get("quantity", 1), item.get("name", item.get("id", "Item"))])
	lines.append(", ".join(equipment) if not equipment.is_empty() else "-")

	lines.append("\n[color=#d5b35b][b]SOURCES[/b][/color]")
	var sources: Array[String] = []
	for source: Dictionary in calculation["sources"]:
		sources.append(str(source.get("label", "")))
	lines.append(", ".join(sources))
	summary_text.text = "\n".join(lines)


func _render_choices() -> void:
	_clear_children(choices_list)
	var regiment_choice_count := 0
	for option: Dictionary in calculation["selected_options"]:
		for value: Variant in option.get("choices", []):
			if not value is Dictionary:
				continue
			var choice := value as Dictionary
			if str(choice.get("scope", "regiment")) == "per_character":
				continue
			regiment_choice_count += 1
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			choices_list.add_child(row)
			var label := Label.new()
			label.text = str(choice.get("prompt", "Choice"))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.custom_minimum_size.x = 160
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(label)
			var selector := OptionButton.new()
			selector.custom_minimum_size.x = 170
			selector.add_item("Select...")
			selector.set_item_metadata(0, "")
			var selected_values := state.get_choice(str(choice.get("id", "")))
			var selected_index := 0
			for choice_option: Variant in choice.get("options", []):
				if not choice_option is Dictionary:
					continue
				var index := selector.item_count
				selector.add_item(str(choice_option.get("label", choice_option.get("id", "Option"))))
				selector.set_item_metadata(index, str(choice_option.get("id", "")))
				if str(choice_option.get("id", "")) in selected_values:
					selected_index = index
			selector.select(selected_index)
			selector.item_selected.connect(_on_choice_selected.bind(str(choice.get("id", "")), selector))
			row.add_child(selector)
	if regiment_choice_count == 0:
		var none := Label.new()
		none.text = "No regiment-wide choices for the selected options."
		none.add_theme_color_override("font_color", COLOUR_MUTED)
		choices_list.add_child(none)

	var character_choices := calculation.get("character_creation_choices", []) as Array
	if not character_choices.is_empty():
		choices_list.add_child(HSeparator.new())
		var deferred_heading := Label.new()
		deferred_heading.text = "DEFERRED TO CHARACTER CREATION"
		deferred_heading.add_theme_font_size_override("font_size", 11)
		deferred_heading.add_theme_color_override("font_color", COLOUR_GOLD)
		choices_list.add_child(deferred_heading)
		for choice: Dictionary in character_choices:
			var deferred := Label.new()
			deferred.text = "- %s" % str(choice.get("prompt", "Character choice"))
			deferred.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			deferred.add_theme_color_override("font_color", COLOUR_MUTED)
			choices_list.add_child(deferred)


func _render_status() -> void:
	points_label.text = "POINTS  %d / %d" % [calculation["points_spent"], repository.data.get("budget", 12)]
	points_label.add_theme_color_override("font_color", COLOUR_BAD if int(calculation["points_remaining"]) < 0 else COLOUR_GOLD)
	doctrine_label.text = "OPTIONAL DOCTRINES  %d / %d" % [calculation["optional_doctrines_used"], calculation["optional_doctrines_maximum"]]
	doctrine_label.add_theme_color_override("font_color", COLOUR_BAD if int(calculation["optional_doctrines_used"]) > int(calculation["optional_doctrines_maximum"]) else COLOUR_TEXT)
	validity_label.text = "VALID REGIMENT" if calculation["valid"] else "INCOMPLETE / INVALID"
	validity_label.add_theme_color_override("font_color", COLOUR_GOOD if calculation["valid"] else COLOUR_BAD)

	var notices: Array[String] = []
	if not action_message.is_empty():
		notices.append("[color=#a5ad9d]%s[/color]" % _escape_bbcode(action_message))
	for error: Variant in calculation["errors"]:
		notices.append("[color=#ef7c70]ERROR - %s[/color]" % _escape_bbcode(str(error)))
	for choice: Dictionary in calculation["unresolved_choices"]:
		notices.append("[color=#d5b35b]REGIMENT CHOICE - %s[/color]" % _escape_bbcode(str(choice.get("prompt", choice.get("id", "Choice")))))
	if calculation["valid"]:
		notices.append("[color=#84c58a]All regiment selections and regiment-wide choices are resolved.[/color]")
	var deferred_count := (calculation.get("character_creation_choices", []) as Array).size()
	if deferred_count > 0:
		notices.append("[color=#a5ad9d]%d choice(s) will be resolved separately for each character.[/color]" % deferred_count)
	notices_text.text = "\n".join(notices)


func _on_option_toggled(selected: bool, category: String, option_id: String, maximum: int) -> void:
	state.set_option(category, option_id, selected, maximum)


func _on_choice_selected(index: int, choice_id: String, selector: OptionButton) -> void:
	var selected_id := str(selector.get_item_metadata(index))
	if selected_id.is_empty():
		state.clear_choice(choice_id)
	else:
		state.set_choice(choice_id, selected_id)


func _select_category(category: String) -> void:
	active_category = category
	_render_options()


func _on_name_changed(value: String) -> void:
	state.regiment_name = value
	if not calculation.is_empty():
		_render_summary()


func _on_name_committed() -> void:
	state.set_regiment_name(name_edit.text)


func _load_example() -> void:
	action_message = "Loaded the 13th Varanox example. Its four individual choices are deferred to character creation."
	state.load_example()


func _return_home() -> void:
	get_tree().change_scene_to_file(LANDING_SCENE)


func _request_save() -> void:
	save_dialog.current_file = _safe_file_stem(state.regiment_name) + ".owreg.json"
	save_dialog.popup_centered_ratio(0.72)


func _request_load() -> void:
	load_dialog.popup_centered_ratio(0.72)


func _request_export() -> void:
	export_dialog.current_file = _safe_file_stem(state.regiment_name) + "_dossier.txt"
	export_dialog.popup_centered_ratio(0.72)


func _save_to_path(path: String) -> void:
	var save_path := path if path.to_lower().ends_with(".json") else path + ".owreg.json"
	var result := persistence.save_regiment(save_path, state, repository)
	action_message = str(result["message"])
	_render_status()


func _load_from_path(path: String) -> void:
	var result := persistence.load_regiment(path, state, repository)
	action_message = str(result["message"])
	_render_status()


func _export_to_path(path: String) -> void:
	var export_path := path if path.to_lower().ends_with(".txt") else path + ".txt"
	var result := exporter.export_text(export_path, state, calculation, repository)
	action_message = str(result["message"])
	_render_status()


func _make_action_button(label_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size.y = 38
	button.pressed.connect(callback)
	return button


func _section_label(value: String) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", COLOUR_GOLD)
	return label


func _make_panel(fill: Color, border: Color, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = padding
	style.content_margin_top = padding
	style.content_margin_right = padding
	style.content_margin_bottom = padding
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


func _escape_bbcode(value: String) -> String:
	return value.replace("[", "[lb]")


func _signed(value: int) -> String:
	return "+%d" % value if value >= 0 else str(value)


func _safe_file_stem(value: String) -> String:
	var output := value.strip_edges().to_lower().replace(" ", "_")
	for character in ["/", "\\", ":", "*", "?", "\"", "<", ">", "|"]:
		output = output.replace(character, "")
	return output if not output.is_empty() else "regiment"


func _show_fatal_error(message: String) -> void:
	var label := Label.new()
	label.text = "OWCA could not start.\n\n%s" % message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", COLOUR_BAD)
	add_child(label)
