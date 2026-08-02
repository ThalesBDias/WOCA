extends Control

## Functional testing UI for the five Core Guardsman Specialities.

const LANDING_SCENE := "res://OWCA/ui/LandingPage.tscn"
const STAGE_ORDER: Array[String] = ["regiment", "characteristics", "speciality", "choices", "derived", "review"]
const STAGE_LABELS := {
	"regiment": "Load Regiment",
	"characteristics": "Characteristics",
	"speciality": "Guardsman Speciality",
	"choices": "Character Choices",
	"derived": "Wounds, Fate & Movement",
	"review": "Review"
}
const ABBREVIATIONS := {
	"Weapon Skill": "WS", "Ballistic Skill": "BS", "Strength": "S",
	"Toughness": "T", "Agility": "Ag", "Intelligence": "Int",
	"Perception": "Per", "Willpower": "WP", "Fellowship": "Fel"
}

const COLOUR_BACKGROUND := Color("#101612")
const COLOUR_PANEL := Color("#19221c")
const COLOUR_PANEL_ALT := Color("#202b23")
const COLOUR_BORDER := Color("#52614d")
const COLOUR_GOLD := Color("#d5b35b")
const COLOUR_TEXT := Color("#e7eadf")
const COLOUR_MUTED := Color("#a5ad9d")
const COLOUR_GOOD := Color("#84c58a")
const COLOUR_BAD := Color("#ef7c70")

var regiment_repository := RegimentDataRepository.new()
var character_repository := CharacterDataRepository.new()
var regiment_persistence := RegimentPersistence.new()
var character_persistence := CharacterPersistence.new()
var calculator := CharacterCalculator.new()
var state := CharacterState.new()
var calculation: Dictionary = {}
var active_stage: String = "regiment"
var action_message: String = "Load a saved regiment to begin. Dice are entered from physical or Discord rolls."

var name_edit: LineEdit
var player_edit: LineEdit
var stage_buttons: Dictionary = {}
var stage_title: Label
var stage_content: VBoxContainer
var summary_text: RichTextLabel
var status_label: Label
var xp_label: Label
var notices_text: RichTextLabel
var characteristic_output_labels: Dictionary = {}
var derived_output: RichTextLabel
var regiment_load_dialog: FileDialog
var character_save_dialog: FileDialog
var character_load_dialog: FileDialog


func _ready() -> void:
	var regiment_error := regiment_repository.load_data()
	if regiment_error != OK:
		_show_fatal_error(regiment_repository.last_error)
		return
	var character_error := character_repository.load_data()
	if character_error != OK:
		_show_fatal_error(character_repository.last_error)
		return
	_build_interface()
	_refresh()


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = COLOUR_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	page.add_child(_build_header())
	page.add_child(_build_workspace())
	page.add_child(_build_status_panel())
	_build_dialogs()


func _build_header() -> Control:
	var panel := _make_panel(COLOUR_PANEL, COLOUR_BORDER, 8)
	panel.custom_minimum_size.y = 76
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)

	var title_column := VBoxContainer.new()
	title_column.custom_minimum_size.x = 270
	row.add_child(title_column)
	var title := Label.new()
	title.text = "ONLY WAR CHARACTER ASSISTANT"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", COLOUR_GOLD)
	title_column.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "GUARDSMAN CREATION TEST  |  v0.3"
	subtitle.add_theme_font_size_override("font_size", 11)
	subtitle.add_theme_color_override("font_color", COLOUR_MUTED)
	title_column.add_child(subtitle)

	var name_column := _field_column("CHARACTER NAME")
	name_column.custom_minimum_size.x = 195
	name_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_column)
	name_edit = LineEdit.new()
	name_edit.text_changed.connect(_on_name_changed)
	name_edit.focus_exited.connect(_on_name_committed)
	name_column.add_child(name_edit)

	var player_column := _field_column("PLAYER NAME")
	player_column.custom_minimum_size.x = 155
	player_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(player_column)
	player_edit = LineEdit.new()
	player_edit.text_changed.connect(_on_player_changed)
	player_edit.focus_exited.connect(_on_player_committed)
	player_column.add_child(player_edit)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 5)
	row.add_child(actions)
	actions.add_child(_make_action_button("HOME", _return_home))
	actions.add_child(_make_action_button("REGIMENT", _request_regiment_load))
	actions.add_child(_make_action_button("SAVE", _request_character_save))
	actions.add_child(_make_action_button("LOAD", _request_character_load))
	return panel


func _build_workspace() -> Control:
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)

	var navigation_panel := _make_panel(COLOUR_PANEL, COLOUR_BORDER, 8)
	navigation_panel.custom_minimum_size.x = 205
	row.add_child(navigation_panel)
	var navigation := VBoxContainer.new()
	navigation.add_theme_constant_override("separation", 7)
	navigation_panel.add_child(navigation)
	navigation.add_child(_section_label("CHARACTER STAGES"))
	var stage_group := ButtonGroup.new()
	for stage in STAGE_ORDER:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = stage_group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size.y = 48
		button.pressed.connect(_select_stage.bind(stage))
		navigation.add_child(button)
		stage_buttons[stage] = button
	(stage_buttons[active_stage] as Button).button_pressed = true
	var navigation_spacer := Control.new()
	navigation_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	navigation.add_child(navigation_spacer)
	var scope_note := Label.new()
	scope_note.text = "Testing scope:\n5 Core Guardsman Specialities\nNo in-app dice rolling\nNo XP purchases or PDF yet"
	scope_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scope_note.add_theme_font_size_override("font_size", 11)
	scope_note.add_theme_color_override("font_color", COLOUR_MUTED)
	navigation.add_child(scope_note)

	var content_panel := _make_panel(COLOUR_PANEL_ALT, COLOUR_BORDER, 8)
	content_panel.custom_minimum_size.x = 475
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_stretch_ratio = 1.05
	row.add_child(content_panel)
	var content_column := VBoxContainer.new()
	content_column.add_theme_constant_override("separation", 8)
	content_panel.add_child(content_column)
	stage_title = _section_label("")
	content_column.add_child(stage_title)
	var content_scroll := ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_column.add_child(content_scroll)
	stage_content = VBoxContainer.new()
	stage_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_content.add_theme_constant_override("separation", 9)
	content_scroll.add_child(stage_content)

	var summary_panel := _make_panel(COLOUR_PANEL, COLOUR_BORDER, 8)
	summary_panel.custom_minimum_size.x = 485
	summary_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_panel.size_flags_stretch_ratio = 1.2
	row.add_child(summary_panel)
	var summary_column := VBoxContainer.new()
	summary_column.add_theme_constant_override("separation", 6)
	summary_panel.add_child(summary_column)
	summary_column.add_child(_section_label("LIVE CHARACTER SUMMARY"))
	summary_text = RichTextLabel.new()
	summary_text.bbcode_enabled = true
	summary_text.scroll_active = true
	summary_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	summary_column.add_child(summary_text)
	return row


func _build_status_panel() -> Control:
	var panel := _make_panel(COLOUR_PANEL_ALT, COLOUR_BORDER, 8)
	panel.custom_minimum_size.y = 116
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var metrics := VBoxContainer.new()
	metrics.custom_minimum_size.x = 220
	row.add_child(metrics)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	metrics.add_child(status_label)
	xp_label = Label.new()
	xp_label.add_theme_font_size_override("font_size", 15)
	metrics.add_child(xp_label)
	var dice_note := Label.new()
	dice_note.text = "ROLLS ENTERED MANUALLY"
	dice_note.add_theme_font_size_override("font_size", 10)
	dice_note.add_theme_color_override("font_color", COLOUR_MUTED)
	metrics.add_child(dice_note)
	row.add_child(VSeparator.new())
	notices_text = RichTextLabel.new()
	notices_text.bbcode_enabled = true
	notices_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notices_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(notices_text)
	return panel


func _build_dialogs() -> void:
	regiment_load_dialog = FileDialog.new()
	regiment_load_dialog.title = "Load Regiment for Character"
	regiment_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	regiment_load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	regiment_load_dialog.filters = PackedStringArray(["*.owreg.json ; OWCA Regiment JSON", "*.json ; JSON files"])
	regiment_load_dialog.file_selected.connect(_load_regiment_from_path)
	add_child(regiment_load_dialog)

	character_save_dialog = FileDialog.new()
	character_save_dialog.title = "Save OWCA Character"
	character_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	character_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	character_save_dialog.filters = PackedStringArray(["*.owchar.json ; OWCA Character JSON"])
	character_save_dialog.file_selected.connect(_save_character_to_path)
	add_child(character_save_dialog)

	character_load_dialog = FileDialog.new()
	character_load_dialog.title = "Load OWCA Character"
	character_load_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	character_load_dialog.access = FileDialog.ACCESS_FILESYSTEM
	character_load_dialog.filters = PackedStringArray(["*.owchar.json ; OWCA Character JSON", "*.json ; JSON files"])
	character_load_dialog.file_selected.connect(_load_character_from_path)
	add_child(character_load_dialog)


func _refresh(rebuild_stage: bool = true) -> void:
	calculation = calculator.calculate(state, regiment_repository, character_repository)
	if name_edit != null and name_edit.text != state.character_name:
		name_edit.text = state.character_name
	if player_edit != null and player_edit.text != state.player_name:
		player_edit.text = state.player_name
	_render_stage_buttons()
	if rebuild_stage:
		_render_active_stage()
	else:
		_update_characteristic_outputs()
		_update_derived_output()
	_render_summary()
	_render_status()


func _render_stage_buttons() -> void:
	var entered := state.base_characteristics.size()
	var total_choices := (calculation.get("regiment_choices", []) as Array).size() + (calculation.get("speciality_choices", []) as Array).size()
	var resolved := (calculation.get("resolved_choices", []) as Array).size()
	var derived_count := (1 if state.wounds_roll in range(1, 6) else 0) + (1 if state.fate_roll in range(1, 11) else 0)
	(stage_buttons["regiment"] as Button).text = "Load Regiment\n%s" % ("1/1 loaded" if state.has_regiment() else "0/1 loaded")
	(stage_buttons["characteristics"] as Button).text = "Characteristics\n%d/9 entered" % entered
	(stage_buttons["speciality"] as Button).text = "Guardsman Speciality\n%s" % ("1/1 selected" if not state.speciality_id.is_empty() else "0/1 selected")
	(stage_buttons["choices"] as Button).text = "Character Choices\n%d/%d resolved" % [mini(resolved, total_choices), total_choices]
	(stage_buttons["derived"] as Button).text = "Wounds, Fate & Movement\n%d/2 rolls entered" % derived_count
	(stage_buttons["review"] as Button).text = "Review\n%s" % ("ready" if calculation.get("valid", false) else "incomplete")


func _render_active_stage() -> void:
	_clear_children(stage_content)
	characteristic_output_labels.clear()
	derived_output = null
	stage_title.text = str(STAGE_LABELS.get(active_stage, active_stage.capitalize())).to_upper()
	match active_stage:
		"regiment":
			_render_regiment_stage()
		"characteristics":
			_render_characteristics_stage()
		"speciality":
			_render_speciality_stage()
		"choices":
			_render_choices_stage()
		"derived":
			_render_derived_stage()
		"review":
			_render_review_stage()


func _render_regiment_stage() -> void:
	var intro := _wrapped_label("Characters inherit their shared benefits from a saved regiment. Individual choices from that regiment are answered later in this workflow.", COLOUR_MUTED)
	stage_content.add_child(intro)
	var load_button := _make_action_button("LOAD REGIMENT FILE", _request_regiment_load)
	load_button.custom_minimum_size.y = 46
	stage_content.add_child(load_button)
	if not state.has_regiment():
		stage_content.add_child(_notice_label("No regiment loaded.", COLOUR_BAD))
		return
	var card := _make_panel(COLOUR_PANEL, COLOUR_GOLD, 12)
	stage_content.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var regiment_name_label := Label.new()
	regiment_name_label.text = state.get_regiment_name()
	regiment_name_label.add_theme_font_size_override("font_size", 21)
	regiment_name_label.add_theme_color_override("font_color", COLOUR_GOLD)
	column.add_child(regiment_name_label)
	var selections := state.regiment.get("selections", {}) as Dictionary
	for category in regiment_repository.get_category_order():
		var option_names: Array[String] = []
		for option_id: Variant in selections.get(category, []):
			option_names.append(str(regiment_repository.get_option(str(option_id)).get("name", option_id)))
		if not option_names.is_empty():
			column.add_child(_wrapped_label("%s: %s" % [regiment_repository.get_selection_rule(category).get("label", category.capitalize()), ", ".join(option_names)], COLOUR_TEXT))
	column.add_child(_notice_label("Regiment rules snapshot: %s" % state.regiment_rules_content_version, COLOUR_MUTED))


func _render_characteristics_stage() -> void:
	stage_content.add_child(_wrapped_label("Enter results rolled with physical dice or Discord. Base 2d10+20 results are normally 22-40; OWCA applies all later modifiers.", COLOUR_MUTED))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 5)
	stage_content.add_child(grid)
	for heading_text in ["CHARACTERISTIC", "BASE", "REG.", "SPEC.", "MANUAL", "FINAL", "BONUS"]:
		var heading := Label.new()
		heading.text = heading_text
		heading.add_theme_font_size_override("font_size", 10)
		heading.add_theme_color_override("font_color", COLOUR_GOLD)
		grid.add_child(heading)
	for characteristic in CharacterState.CHARACTERISTIC_ORDER:
		var label := Label.new()
		label.text = "%s (%s)" % [characteristic, ABBREVIATIONS[characteristic]]
		label.custom_minimum_size.x = 135
		grid.add_child(label)
		var base_spin := SpinBox.new()
		base_spin.min_value = 0
		base_spin.max_value = 100
		base_spin.step = 1
		base_spin.custom_minimum_size.x = 58
		base_spin.value = int(state.base_characteristics.get(characteristic, 0))
		base_spin.value_changed.connect(_on_base_characteristic_changed.bind(characteristic))
		grid.add_child(base_spin)
		var regiment_value := Label.new()
		regiment_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(regiment_value)
		var speciality_value := Label.new()
		speciality_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(speciality_value)
		var manual_spin := SpinBox.new()
		manual_spin.min_value = -30
		manual_spin.max_value = 30
		manual_spin.step = 1
		manual_spin.custom_minimum_size.x = 62
		manual_spin.value = int(state.manual_adjustments.get(characteristic, 0))
		manual_spin.value_changed.connect(_on_manual_adjustment_changed.bind(characteristic))
		grid.add_child(manual_spin)
		var final_value := Label.new()
		final_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		final_value.add_theme_font_size_override("font_size", 16)
		grid.add_child(final_value)
		var bonus_value := Label.new()
		bonus_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(bonus_value)
		characteristic_output_labels[characteristic] = {
			"regiment": regiment_value,
			"speciality": speciality_value,
			"final": final_value,
			"bonus": bonus_value
		}
	_update_characteristic_outputs()


func _render_speciality_stage() -> void:
	stage_content.add_child(_wrapped_label("Choose exactly one Guardsman Speciality. Support Specialists are deliberately excluded from this testing slice.", COLOUR_MUTED))
	for speciality in character_repository.get_specialities():
		stage_content.add_child(_build_speciality_card(speciality))


func _build_speciality_card(speciality: Dictionary) -> Control:
	var selected := state.speciality_id == str(speciality.get("id", ""))
	var card := _make_panel(Color("#263128") if selected else Color("#1b241e"), COLOUR_GOLD if selected else COLOUR_BORDER, 9)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var top := HBoxContainer.new()
	column.add_child(top)
	var title := Label.new()
	title.text = str(speciality.get("name", "Speciality"))
	title.add_theme_font_size_override("font_size", 18)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var select := CheckButton.new()
	select.text = "SELECTED" if selected else "SELECT"
	select.button_pressed = selected
	select.toggled.connect(_on_speciality_toggled.bind(str(speciality.get("id", ""))))
	top.add_child(select)
	column.add_child(_wrapped_label(str(speciality.get("summary", "")), COLOUR_MUTED))
	var effects := speciality.get("effects", {}) as Dictionary
	var details: Array[String] = []
	for characteristic: Variant in (effects.get("characteristics", {}) as Dictionary):
		details.append("%s %s" % [characteristic, _signed(int(effects["characteristics"][characteristic]))])
	details.append("Wounds %d + entered 1d5" % int(speciality.get("wounds_base", 0)))
	details.append("%d required choice(s)" % (speciality.get("choices", []) as Array).size())
	column.add_child(_wrapped_label("  |  ".join(details), COLOUR_TEXT))
	column.add_child(_notice_label(character_repository.get_source_label(speciality.get("source", {}) as Dictionary), COLOUR_MUTED))
	return card


func _render_choices_stage() -> void:
	var choices: Array[Dictionary] = []
	for choice: Dictionary in calculation.get("regiment_choices", []):
		var regiment_choice := choice.duplicate(true)
		regiment_choice["ui_scope"] = "regiment"
		choices.append(regiment_choice)
	for choice: Dictionary in calculation.get("speciality_choices", []):
		var speciality_choice := choice.duplicate(true)
		speciality_choice["ui_scope"] = "speciality"
		choices.append(speciality_choice)
	if choices.is_empty():
		stage_content.add_child(_wrapped_label("Load a regiment and select a Speciality to reveal the choices for this character.", COLOUR_MUTED))
		return
	for choice in choices:
		stage_content.add_child(_build_choice_card(choice))


func _build_choice_card(choice: Dictionary) -> Control:
	var scope := str(choice.get("ui_scope", "speciality"))
	var choice_id := str(choice.get("id", ""))
	var selected_values := state.get_choice(scope, choice_id)
	var minimum := int(choice.get("minimum", 1))
	var maximum := int(choice.get("maximum", 1))
	var complete := selected_values.size() >= minimum and (maximum <= 0 or selected_values.size() <= maximum)
	var card := _make_panel(COLOUR_PANEL, COLOUR_GOLD if complete else COLOUR_BORDER, 9)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	card.add_child(column)
	var heading := Label.new()
	heading.text = str(choice.get("prompt", "Choice"))
	heading.add_theme_font_size_override("font_size", 15)
	column.add_child(heading)
	var scope_label := Label.new()
	scope_label.text = "%s  |  %d/%d selected" % ["REGIMENT BENEFIT" if scope == "regiment" else "SPECIALITY", selected_values.size(), maximum]
	scope_label.add_theme_font_size_override("font_size", 10)
	scope_label.add_theme_color_override("font_color", COLOUR_MUTED)
	column.add_child(scope_label)
	if maximum == 1:
		var selector := OptionButton.new()
		selector.add_item("Select...")
		selector.set_item_metadata(0, "")
		var selected_index := 0
		for answer_value: Variant in choice.get("options", []):
			if not answer_value is Dictionary:
				continue
			var answer := answer_value as Dictionary
			var index := selector.item_count
			selector.add_item(str(answer.get("label", answer.get("id", "Option"))))
			selector.set_item_metadata(index, str(answer.get("id", "")))
			if str(answer.get("id", "")) in selected_values:
				selected_index = index
		selector.select(selected_index)
		selector.item_selected.connect(_on_single_choice_selected.bind(scope, choice_id, selector))
		column.add_child(selector)
	else:
		var options_grid := GridContainer.new()
		options_grid.columns = 2
		options_grid.add_theme_constant_override("h_separation", 12)
		column.add_child(options_grid)
		for answer_value: Variant in choice.get("options", []):
			if not answer_value is Dictionary:
				continue
			var answer := answer_value as Dictionary
			var answer_id := str(answer.get("id", ""))
			var check := CheckBox.new()
			check.text = str(answer.get("label", answer_id))
			check.button_pressed = answer_id in selected_values
			check.disabled = not check.button_pressed and maximum > 0 and selected_values.size() >= maximum
			check.toggled.connect(_on_multiple_choice_toggled.bind(scope, choice_id, answer_id, maximum))
			options_grid.add_child(check)
	return card


func _render_derived_stage() -> void:
	stage_content.add_child(_wrapped_label("Roll these dice outside OWCA, then enter the results. OWCA performs only the lookup and arithmetic.", COLOUR_MUTED))
	var form := GridContainer.new()
	form.columns = 3
	form.add_theme_constant_override("h_separation", 12)
	form.add_theme_constant_override("v_separation", 8)
	stage_content.add_child(form)
	form.add_child(Label.new())
	var roll_heading := Label.new()
	roll_heading.text = "ENTERED ROLL"
	roll_heading.add_theme_font_size_override("font_size", 10)
	roll_heading.add_theme_color_override("font_color", COLOUR_GOLD)
	form.add_child(roll_heading)
	var range_heading := Label.new()
	range_heading.text = "VALID RANGE"
	range_heading.add_theme_font_size_override("font_size", 10)
	range_heading.add_theme_color_override("font_color", COLOUR_GOLD)
	form.add_child(range_heading)
	var wounds_label := Label.new()
	wounds_label.text = "Wounds die"
	form.add_child(wounds_label)
	var wounds_spin := SpinBox.new()
	wounds_spin.min_value = 0
	wounds_spin.max_value = 5
	wounds_spin.step = 1
	wounds_spin.value = state.wounds_roll
	wounds_spin.value_changed.connect(_on_wounds_roll_changed)
	form.add_child(wounds_spin)
	form.add_child(_notice_label("1d5: 1-5", COLOUR_MUTED))
	var fate_label := Label.new()
	fate_label.text = "Fate die"
	form.add_child(fate_label)
	var fate_spin := SpinBox.new()
	fate_spin.min_value = 0
	fate_spin.max_value = 10
	fate_spin.step = 1
	fate_spin.value = state.fate_roll
	fate_spin.value_changed.connect(_on_fate_roll_changed)
	form.add_child(fate_spin)
	form.add_child(_notice_label("1d10: 1-10", COLOUR_MUTED))
	derived_output = RichTextLabel.new()
	derived_output.bbcode_enabled = true
	derived_output.fit_content = true
	derived_output.custom_minimum_size.y = 170
	stage_content.add_child(derived_output)
	_update_derived_output()


func _render_review_stage() -> void:
	var heading := Label.new()
	heading.text = "CHARACTER BUILD %s" % ("READY" if calculation.get("valid", false) else "INCOMPLETE")
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", COLOUR_GOOD if calculation.get("valid", false) else COLOUR_BAD)
	stage_content.add_child(heading)
	stage_content.add_child(_wrapped_label("The live summary shows the current calculated character. Character JSON save/load is available now; starting XP purchases and printable PDF export are the next slices.", COLOUR_MUTED))
	var save_button := _make_action_button("SAVE CHARACTER JSON", _request_character_save)
	save_button.custom_minimum_size.y = 46
	stage_content.add_child(save_button)
	var details := RichTextLabel.new()
	details.bbcode_enabled = true
	details.fit_content = true
	details.custom_minimum_size.y = 220
	var lines: Array[String] = ["[color=#d5b35b][b]VALIDATION[/b][/color]"]
	if (calculation.get("errors", []) as Array).is_empty() and (calculation.get("unresolved_choices", []) as Array).is_empty():
		lines.append("No creation errors detected.")
	for error: Variant in calculation.get("errors", []):
		lines.append("[color=#ef7c70]- %s[/color]" % _escape_bbcode(str(error)))
	for choice: Dictionary in calculation.get("unresolved_choices", []):
		lines.append("[color=#d5b35b]- Unresolved: %s[/color]" % _escape_bbcode(str(choice.get("prompt", "Choice"))))
	for warning: Variant in calculation.get("warnings", []):
		lines.append("[color=#a5ad9d]- %s[/color]" % _escape_bbcode(str(warning)))
	details.text = "\n".join(lines)
	stage_content.add_child(details)


func _update_characteristic_outputs() -> void:
	for characteristic: Variant in characteristic_output_labels:
		var labels := characteristic_output_labels[characteristic] as Dictionary
		(labels["regiment"] as Label).text = _signed(int((calculation.get("regiment_characteristic_modifiers", {}) as Dictionary).get(characteristic, 0)))
		(labels["speciality"] as Label).text = _signed(int((calculation.get("speciality_characteristic_modifiers", {}) as Dictionary).get(characteristic, 0)))
		var has_final := (calculation.get("characteristics", {}) as Dictionary).has(characteristic)
		(labels["final"] as Label).text = str(calculation["characteristics"][characteristic]) if has_final else "-"
		(labels["bonus"] as Label).text = str(calculation["characteristic_bonuses"][characteristic]) if has_final else "-"


func _update_derived_output() -> void:
	if derived_output == null:
		return
	var movement := calculation.get("movement", {}) as Dictionary
	var lines: Array[String] = []
	lines.append("[color=#d5b35b][b]CALCULATED RESULTS[/b][/color]")
	lines.append("Maximum Wounds: [b]%s[/b]" % (str(calculation.get("wounds", 0)) if state.wounds_roll > 0 and not state.speciality_id.is_empty() else "-"))
	lines.append("Fate Points: [b]%s[/b]" % (str(calculation.get("fate_points", 0)) if state.fate_roll > 0 else "-"))
	if movement.is_empty():
		lines.append("Movement: - (enter Agility)")
	else:
		lines.append("Movement: Half %s | Full %s | Charge %s | Run %s" % [movement.get("half", "-"), movement.get("full", "-"), movement.get("charge", "-"), movement.get("run", "-")])
	lines.append("")
	lines.append("Wounds = Speciality base + entered 1d5 + regiment modifier (%s)." % _signed(int(calculation.get("wounds_modifier", 0))))
	derived_output.text = "\n".join(lines)


func _render_summary() -> void:
	var lines: Array[String] = []
	lines.append("[font_size=20][color=#d5b35b]%s[/color][/font_size]" % _escape_bbcode(state.character_name))
	lines.append("[color=#a5ad9d]Player:[/color] %s" % _escape_bbcode(state.player_name if not state.player_name.is_empty() else "-"))
	lines.append("[color=#a5ad9d]Regiment:[/color] %s" % _escape_bbcode(str(calculation.get("regiment_name", "No regiment loaded"))))
	lines.append("[color=#a5ad9d]Speciality:[/color] %s" % _escape_bbcode(str(calculation.get("speciality_name", "-"))))
	lines.append("")
	lines.append("[color=#d5b35b][b]CHARACTERISTICS[/b][/color]")
	var characteristic_parts: Array[String] = []
	for characteristic in CharacterState.CHARACTERISTIC_ORDER:
		if (calculation.get("characteristics", {}) as Dictionary).has(characteristic):
			characteristic_parts.append("%s %d (%d)" % [ABBREVIATIONS[characteristic], calculation["characteristics"][characteristic], calculation["characteristic_bonuses"][characteristic]])
		else:
			characteristic_parts.append("%s -" % ABBREVIATIONS[characteristic])
	lines.append("  ".join(characteristic_parts))
	lines.append("")
	var movement := calculation.get("movement", {}) as Dictionary
	lines.append("[color=#d5b35b][b]WOUNDS[/b][/color] %s    [color=#d5b35b][b]FATE[/b][/color] %s" % [str(calculation.get("wounds", 0)) if state.wounds_roll > 0 and not state.speciality_id.is_empty() else "-", str(calculation.get("fate_points", 0)) if state.fate_roll > 0 else "-"])
	if not movement.is_empty():
		lines.append("[color=#d5b35b][b]MOVE[/b][/color] %s / %s / %s / %s" % [movement.get("half"), movement.get("full"), movement.get("charge"), movement.get("run")])
	lines.append("[color=#d5b35b][b]XP[/b][/color] %d available" % int(calculation.get("xp_remaining", 0)))

	lines.append("\n[color=#d5b35b][b]SKILLS[/b][/color]")
	var skills: Array[String] = []
	for skill: Dictionary in calculation.get("skills", []):
		skills.append("%s [%s]" % [skill.get("name", "Skill"), skill.get("rank_label", "Known")])
	lines.append(", ".join(skills) if not skills.is_empty() else "-")

	lines.append("\n[color=#d5b35b][b]TALENTS[/b][/color]")
	var talents: Array[String] = []
	for talent: Dictionary in calculation.get("talents", []):
		talents.append(str(talent.get("name", "Talent")))
	lines.append(", ".join(talents) if not talents.is_empty() else "-")
	if int(calculation.get("bonus_xp", 0)) > 0:
		lines.append("Duplicate Talent compensation: +%d XP" % int(calculation.get("bonus_xp", 0)))

	lines.append("\n[color=#d5b35b][b]APTITUDES[/b][/color]")
	lines.append(", ".join(calculation.get("aptitudes", []) as Array) if not (calculation.get("aptitudes", []) as Array).is_empty() else "-")

	lines.append("\n[color=#d5b35b][b]SPECIAL RULES[/b][/color]")
	if (calculation.get("special_rules", []) as Array).is_empty():
		lines.append("-")
	for rule: Dictionary in calculation.get("special_rules", []):
		lines.append("[b]%s:[/b] %s" % [rule.get("name", "Rule"), rule.get("summary", "")])

	lines.append("\n[color=#d5b35b][b]EQUIPMENT[/b][/color]")
	var equipment: Array[String] = []
	for item: Dictionary in calculation.get("equipment", []):
		equipment.append("%dx %s" % [item.get("quantity", 1), item.get("name", "Item")])
	lines.append(", ".join(equipment) if not equipment.is_empty() else "-")

	lines.append("\n[color=#d5b35b][b]SOURCES[/b][/color]")
	var sources: Array[String] = []
	for source: Dictionary in calculation.get("sources", []):
		sources.append(str(source.get("label", "")))
	lines.append(", ".join(sources))
	summary_text.text = "\n".join(lines)


func _render_status() -> void:
	status_label.text = "VALID GUARDSMAN" if calculation.get("valid", false) else "INCOMPLETE / INVALID"
	status_label.add_theme_color_override("font_color", COLOUR_GOOD if calculation.get("valid", false) else COLOUR_BAD)
	xp_label.text = "STARTING XP  %d / %d" % [calculation.get("xp_remaining", 0), calculation.get("xp_budget", 600)]
	xp_label.add_theme_color_override("font_color", COLOUR_GOLD)
	var notices: Array[String] = []
	if not action_message.is_empty():
		notices.append("[color=#a5ad9d]%s[/color]" % _escape_bbcode(action_message))
	for error: Variant in calculation.get("errors", []):
		notices.append("[color=#ef7c70]ERROR - %s[/color]" % _escape_bbcode(str(error)))
	for choice: Dictionary in calculation.get("unresolved_choices", []):
		notices.append("[color=#d5b35b]CHOICE - %s[/color]" % _escape_bbcode(str(choice.get("prompt", "Choice"))))
	for warning: Variant in calculation.get("warnings", []):
		notices.append("[color=#a5ad9d]WARNING - %s[/color]" % _escape_bbcode(str(warning)))
	if calculation.get("valid", false):
		notices.append("[color=#84c58a]All inputs and starting choices are resolved.[/color]")
	notices_text.text = "\n".join(notices)


func _select_stage(stage: String) -> void:
	active_stage = stage
	_render_active_stage()


func _on_name_changed(value: String) -> void:
	state.character_name = value
	_render_summary()


func _on_name_committed() -> void:
	state.set_character_name(name_edit.text)
	_refresh(false)


func _on_player_changed(value: String) -> void:
	state.player_name = value
	_render_summary()


func _on_player_committed() -> void:
	state.set_player_name(player_edit.text)
	_refresh(false)


func _on_base_characteristic_changed(value: float, characteristic: String) -> void:
	if int(value) <= 0:
		state.base_characteristics.erase(characteristic)
	else:
		state.base_characteristics[characteristic] = int(value)
	_refresh(false)


func _on_manual_adjustment_changed(value: float, characteristic: String) -> void:
	if int(value) == 0:
		state.manual_adjustments.erase(characteristic)
	else:
		state.manual_adjustments[characteristic] = int(value)
	_refresh(false)


func _on_speciality_toggled(selected: bool, speciality_id: String) -> void:
	if not selected:
		return
	state.set_speciality(speciality_id)
	action_message = "Selected %s." % character_repository.get_speciality(speciality_id).get("name", speciality_id)
	_refresh()


func _on_single_choice_selected(index: int, scope: String, choice_id: String, selector: OptionButton) -> void:
	var answer_id := str(selector.get_item_metadata(index))
	if answer_id.is_empty():
		state.clear_choice(scope, choice_id)
	else:
		state.set_choice(scope, choice_id, answer_id)
	_refresh()


func _on_multiple_choice_toggled(selected: bool, scope: String, choice_id: String, answer_id: String, maximum: int) -> void:
	state.set_choice(scope, choice_id, answer_id, selected, maximum)
	_refresh()


func _on_wounds_roll_changed(value: float) -> void:
	state.wounds_roll = int(value)
	_refresh(false)


func _on_fate_roll_changed(value: float) -> void:
	state.fate_roll = int(value)
	_refresh(false)


func _request_regiment_load() -> void:
	regiment_load_dialog.popup_centered_ratio(0.72)


func _request_character_save() -> void:
	character_save_dialog.current_file = _safe_file_stem(state.character_name) + ".owchar.json"
	character_save_dialog.popup_centered_ratio(0.72)


func _request_character_load() -> void:
	character_load_dialog.popup_centered_ratio(0.72)


func _load_regiment_from_path(path: String) -> void:
	var loaded_regiment := RegimentState.new()
	var result := regiment_persistence.load_regiment(path, loaded_regiment, regiment_repository)
	action_message = str(result.get("message", ""))
	if int(result.get("error", ERR_INVALID_DATA)) == OK:
		state.set_regiment(loaded_regiment.to_dict(), str(regiment_repository.data.get("content_version", "")))
		active_stage = "characteristics"
		(stage_buttons[active_stage] as Button).button_pressed = true
	_refresh()


func _save_character_to_path(path: String) -> void:
	var save_path := path if path.to_lower().ends_with(".json") else path + ".owchar.json"
	var result := character_persistence.save_character(save_path, state, calculation, character_repository)
	action_message = str(result.get("message", ""))
	_render_status()


func _load_character_from_path(path: String) -> void:
	var result := character_persistence.load_character(path, state)
	action_message = str(result.get("message", ""))
	if int(result.get("error", ERR_INVALID_DATA)) == OK:
		active_stage = "review"
		(stage_buttons[active_stage] as Button).button_pressed = true
	_refresh()


func _return_home() -> void:
	get_tree().change_scene_to_file(LANDING_SCENE)


func _field_column(label_text: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", COLOUR_MUTED)
	column.add_child(label)
	return column


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


func _wrapped_label(value: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", colour)
	return label


func _notice_label(value: String, colour: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", colour)
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
	return output if not output.is_empty() else "character"


func _show_fatal_error(message: String) -> void:
	var label := Label.new()
	label.text = "OWCA Character Creator could not start.\n\n%s" % message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_color_override("font_color", COLOUR_BAD)
	add_child(label)
