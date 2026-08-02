class_name DossierExporter
extends RefCounted

## Produces a short, readable dossier without copying long rulebook passages.


func export_text(path: String, state: RegimentState, calculation: Dictionary, repository: RegimentDataRepository) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return { "error": FileAccess.get_open_error(), "message": "Could not write %s." % path }
	file.store_string(build_text(state, calculation, repository))
	return { "error": OK, "message": "Exported dossier to %s." % path }


func build_text(state: RegimentState, calculation: Dictionary, repository: RegimentDataRepository) -> String:
	var lines: Array[String] = []
	lines.append(state.regiment_name.to_upper())
	lines.append("ONLY WAR REGIMENT DOSSIER")
	lines.append("=".repeat(72))
	lines.append("Creation points: %d spent / %d remaining" % [calculation["points_spent"], calculation["points_remaining"]])
	lines.append("Regiment Type: %d / 1" % (int(calculation["doctrine_slots_used"]) - int(calculation["optional_doctrines_used"])))
	lines.append("Optional doctrines: %d / %d" % [calculation["optional_doctrines_used"], calculation["optional_doctrines_maximum"]])
	lines.append("Additional Standard Kit points: %d" % calculation["standard_kit_points"])
	lines.append("Status: %s" % ("VALID" if calculation["valid"] else "INCOMPLETE OR INVALID"))

	_append_heading(lines, "REGIMENT BUILD")
	for category in repository.get_category_order():
		var names: Array[String] = []
		for option_id in state.get_selected_for_category(category):
			names.append(str(repository.get_option(option_id).get("name", option_id)))
		var label := str(repository.get_selection_rule(category).get("label", category.capitalize()))
		lines.append("%-22s %s" % [label + ":", ", ".join(names) if not names.is_empty() else "-"])

	_append_heading(lines, "FIXED CHARACTERISTIC MODIFIERS")
	var characteristic_names: Array[String] = []
	for name: Variant in (calculation["characteristics"] as Dictionary).keys():
		characteristic_names.append(str(name))
	characteristic_names.sort()
	if characteristic_names.is_empty():
		lines.append("-")
	for name in characteristic_names:
		lines.append("%s %s" % [name, _signed(int(calculation["characteristics"][name]))])

	_append_heading(lines, "STARTING SKILLS")
	_append_named_entries(lines, calculation["skills"] as Array, "rank_label")
	_append_heading(lines, "STARTING TALENTS")
	_append_named_entries(lines, calculation["talents"] as Array, "")
	if int(calculation.get("bonus_xp", 0)) > 0:
		lines.append("Duplicate Talent compensation: +%d XP per character" % int(calculation["bonus_xp"]))

	_append_heading(lines, "STARTING APTITUDES")
	if (calculation["aptitudes"] as Array).is_empty():
		lines.append("-")
	for aptitude: Variant in calculation["aptitudes"]:
		lines.append(str(aptitude))

	_append_heading(lines, "SPECIAL RULES")
	if (calculation["special_rules"] as Array).is_empty():
		lines.append("-")
	for rule: Dictionary in calculation["special_rules"]:
		lines.append("%s - %s" % [rule.get("name", "Rule"), rule.get("summary", "")])

	_append_heading(lines, "WOUNDS")
	lines.append("Starting Wounds modifier: %s" % _signed(int(calculation["wounds"])))

	_append_heading(lines, "STANDARD EQUIPMENT")
	if (calculation["equipment"] as Array).is_empty():
		lines.append("-")
	for item: Dictionary in calculation["equipment"]:
		var scope := "per Squad" if str(item.get("scope", "per_character")) == "per_squad" else "per character"
		lines.append("%dx %s (%s)" % [item.get("quantity", 1), item.get("name", item.get("id", "Item")), scope])

	_append_heading(lines, "RESOLVED REGIMENT CHOICES")
	if (calculation["resolved_choices"] as Array).is_empty():
		lines.append("None")
	for choice: Dictionary in calculation["resolved_choices"]:
		lines.append("- %s: %s" % [choice.get("prompt", "Choice"), ", ".join(choice.get("answers", []))])

	_append_heading(lines, "UNRESOLVED REGIMENT CHOICES")
	if (calculation["unresolved_choices"] as Array).is_empty():
		lines.append("None")
	for choice: Dictionary in calculation["unresolved_choices"]:
		lines.append("- %s" % choice.get("prompt", choice.get("id", "Choice")))

	_append_heading(lines, "DEFERRED CHARACTER-CREATION CHOICES")
	if (calculation["character_creation_choices"] as Array).is_empty():
		lines.append("None")
	for choice: Dictionary in calculation["character_creation_choices"]:
		lines.append("- %s (choose separately for each character)" % choice.get("prompt", choice.get("id", "Choice")))

	_append_heading(lines, "VALIDATION")
	if (calculation["errors"] as Array).is_empty():
		lines.append("No rule errors detected.")
	for error: Variant in calculation["errors"]:
		lines.append("ERROR: %s" % error)
	for warning: Variant in calculation["warnings"]:
		lines.append("WARNING: %s" % warning)

	_append_heading(lines, "SOURCES")
	for source: Dictionary in calculation["sources"]:
		lines.append("- %s" % source.get("label", repository.get_source_label(source)))
	lines.append("")
	lines.append("Rules data contains brief summaries only. Consult the referenced books for complete wording.")
	return "\n".join(lines) + "\n"


func _append_heading(lines: Array[String], heading: String) -> void:
	lines.append("")
	lines.append(heading)
	lines.append("-".repeat(heading.length()))


func _append_named_entries(lines: Array[String], entries: Array, suffix_key: String) -> void:
	if entries.is_empty():
		lines.append("-")
	for entry: Dictionary in entries:
		var suffix := ""
		if not suffix_key.is_empty():
			suffix = " [%s]" % entry.get(suffix_key, "")
		elif bool(entry.get("stackable", false)) and int(entry.get("count", 1)) > 1:
			suffix = " x%d" % entry.get("count", 1)
		lines.append("%s%s" % [entry.get("name", entry.get("id", "Entry")), suffix])


func _signed(value: int) -> String:
	return "+%d" % value if value >= 0 else str(value)
