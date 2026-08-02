class_name CharacterAdvancementCalculator
extends RefCounted

## Replays a character's ordered XP ledger and exposes the next legal purchases.

const KIND_TO_CATALOG := {
	"characteristic": "characteristics",
	"skill": "skills",
	"talent": "talents"
}
const CHARACTERISTIC_RANKS: Array[String] = [
	"Simple (+5)", "Intermediate (+10 total)", "Trained (+15 total)", "Expert (+20 total)"
]
const SKILL_RANKS: Array[String] = [
	"Known", "Trained (+10)", "Experienced (+20)", "Veteran (+30)"
]


func apply(state: CharacterState, result: Dictionary, repository: CharacterDataRepository) -> void:
	result["advancement_ready"] = _is_ready(result)
	result["advancement_options"] = []
	result["purchased_advances"] = []
	result["invalid_advances"] = []
	result["advancement_wounds_bonus"] = 0
	var purchase_counts: Dictionary = {}
	var remaining := int(result.get("xp_budget", 0))

	for index in state.purchased_advances.size():
		var advance_id := state.purchased_advances[index]
		var option := _build_option(advance_id, result, repository, purchase_counts, remaining)
		var record := option.duplicate(true)
		record["index"] = index
		if not bool(result["advancement_ready"]):
			record["valid"] = false
			record["reason"] = "Resolve the Speciality, Characteristics, and character choices first."
			(result["invalid_advances"] as Array).append(record)
			(result["purchased_advances"] as Array).append(record)
			continue
		if option.is_empty() or not bool(option.get("available", false)):
			record["valid"] = false
			var label := str(record.get("name", advance_id))
			var reason := str(record.get("reason", "Unknown advancement."))
			(result["errors"] as Array).append("XP purchase %d (%s) is invalid: %s" % [index + 1, label, reason])
			(result["invalid_advances"] as Array).append(record)
			(result["purchased_advances"] as Array).append(record)
			continue

		record["valid"] = true
		_apply_purchase(option, result)
		purchase_counts[advance_id] = int(purchase_counts.get(advance_id, 0)) + 1
		remaining -= int(option.get("cost", 0))
		result["xp_spent"] = int(result.get("xp_spent", 0)) + int(option.get("cost", 0))
		(result["purchased_advances"] as Array).append(record)

	result["xp_remaining"] = remaining
	_recalculate_characteristic_bonuses(result)
	result["advancement_options"] = _build_all_options(result, repository, purchase_counts, remaining)


func _is_ready(result: Dictionary) -> bool:
	return not str(result.get("speciality_name", "")).is_empty() \
		and (result.get("characteristics", {}) as Dictionary).size() == CharacterState.CHARACTERISTIC_ORDER.size() \
		and (result.get("unresolved_choices", []) as Array).is_empty()


func _build_all_options(result: Dictionary, repository: CharacterDataRepository, purchase_counts: Dictionary, remaining: int) -> Array[Dictionary]:
	var output: Array[Dictionary] = []
	for kind in ["characteristic", "skill", "talent"]:
		var catalog_name := str(KIND_TO_CATALOG[kind])
		for entry_id: Variant in repository.get_advancement_entries(catalog_name):
			var advance_id := "%s:%s" % [kind, entry_id]
			var option := _build_option(advance_id, result, repository, purchase_counts, remaining)
			if not bool(result.get("advancement_ready", false)):
				option["available"] = false
				option["reason"] = "Resolve the Speciality, Characteristics, and character choices first."
			output.append(option)
	output.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var type_compare := str(a.get("kind", "")) < str(b.get("kind", ""))
		if str(a.get("kind", "")) != str(b.get("kind", "")):
			return type_compare
		var a_recommended := bool(a.get("recommended", false))
		var b_recommended := bool(b.get("recommended", false))
		if a_recommended != b_recommended:
			return a_recommended
		return str(a.get("name", "")) < str(b.get("name", ""))
	)
	return output


func _build_option(advance_id: String, result: Dictionary, repository: CharacterDataRepository, purchase_counts: Dictionary, remaining: int) -> Dictionary:
	var parsed := _parse_advance_id(advance_id)
	if parsed.is_empty():
		return { "id": advance_id, "name": advance_id, "available": false, "reason": "Malformed advancement ID." }
	var kind := str(parsed["kind"])
	var entry_id := str(parsed["entry_id"])
	var catalog_name := str(KIND_TO_CATALOG[kind])
	var entry := repository.get_advancement_entry(catalog_name, entry_id)
	if entry.is_empty():
		return { "id": advance_id, "kind": kind, "entry_id": entry_id, "name": entry_id.capitalize(), "available": false, "reason": "Unknown advancement." }

	var matched := _matching_aptitudes(entry.get("aptitudes", []) as Array, result.get("aptitudes", {}) as Dictionary)
	var rank_index := 0
	var rank_label := ""
	var available := true
	var reason := ""
	match kind:
		"characteristic":
			rank_index = int(purchase_counts.get(advance_id, 0))
			if rank_index >= CHARACTERISTIC_RANKS.size():
				available = false
				reason = "Expert is the maximum Characteristic advance."
			else:
				rank_label = CHARACTERISTIC_RANKS[rank_index]
		"skill":
			rank_index = int((result.get("skills", {}) as Dictionary).get(entry_id, 0))
			if rank_index >= SKILL_RANKS.size():
				available = false
				reason = "Veteran (+30) is the maximum Skill rank."
			else:
				rank_label = SKILL_RANKS[rank_index]
		"talent":
			rank_index = int(entry.get("tier", 1)) - 1
			rank_label = "Tier %d" % int(entry.get("tier", 1))
			var known := int((result.get("talents", {}) as Dictionary).get(entry_id, 0))
			if known > 0 and not bool(entry.get("repeatable", false)):
				available = false
				reason = "Already known."
			var missing := _missing_prerequisites(entry, result)
			if available and not missing.is_empty():
				available = false
				reason = "Requires %s." % ", ".join(missing)

	var cost := _get_cost(kind, rank_index, matched.size(), repository)
	if available and cost > remaining:
		available = false
		reason = "Needs %d XP; %d XP remains." % [cost, remaining]
	var recommended_for := entry.get("recommended_for", []) as Array
	var source := repository.get_advancement_source(kind, entry)
	return {
		"id": advance_id,
		"kind": kind,
		"entry_id": entry_id,
		"name": str(entry.get("name", entry_id.capitalize())),
		"rank_label": rank_label,
		"cost": cost,
		"aptitudes": (entry.get("aptitudes", []) as Array).duplicate(),
		"matched_aptitudes": matched,
		"match_count": matched.size(),
		"available": available,
		"reason": reason,
		"recommended": str(result.get("speciality", {}).get("id", "")) in recommended_for,
		"prerequisite_label": _prerequisite_label(entry),
		"source": source,
		"source_label": repository.get_source_label(source)
	}


func _parse_advance_id(advance_id: String) -> Dictionary:
	var parts := advance_id.split(":", false, 1)
	if parts.size() != 2 or not KIND_TO_CATALOG.has(parts[0]) or parts[1].is_empty():
		return {}
	return { "kind": parts[0], "entry_id": parts[1] }


func _matching_aptitudes(required: Array, owned: Dictionary) -> Array[String]:
	var output: Array[String] = []
	for aptitude: Variant in required:
		var aptitude_name := str(aptitude)
		if int(owned.get(aptitude_name, 0)) > 0 and aptitude_name not in output:
			output.append(aptitude_name)
	return output


func _get_cost(kind: String, rank_index: int, match_count: int, repository: CharacterDataRepository) -> int:
	var match_key := "two" if match_count >= 2 else ("one" if match_count == 1 else "zero")
	var costs := repository.get_advancement_costs(kind).get(match_key, []) as Array
	return int(costs[clampi(rank_index, 0, costs.size() - 1)]) if not costs.is_empty() else 0


func _missing_prerequisites(entry: Dictionary, result: Dictionary) -> Array[String]:
	var missing: Array[String] = []
	var characteristics := result.get("characteristics", {}) as Dictionary
	var skills := result.get("skills", {}) as Dictionary
	var talents := result.get("talents", {}) as Dictionary
	for requirement_value: Variant in entry.get("prerequisites", []):
		if not requirement_value is Dictionary:
			continue
		var requirement := requirement_value as Dictionary
		var met := false
		match str(requirement.get("type", "")):
			"characteristic":
				met = int(characteristics.get(str(requirement.get("id", "")), 0)) >= int(requirement.get("minimum", 0))
			"skill":
				met = int(skills.get(str(requirement.get("id", "")), 0)) >= int(requirement.get("minimum_rank", 1))
			"talent":
				met = int(talents.get(str(requirement.get("id", "")), 0)) > 0
			"talent_any":
				for talent_id: Variant in requirement.get("ids", []):
					if int(talents.get(str(talent_id), 0)) > 0:
						met = true
						break
			"talent_prefix_count":
				var count := 0
				for talent_id: Variant in talents:
					if str(talent_id).begins_with(str(requirement.get("prefix", ""))) and int(talents[talent_id]) > 0:
						count += 1
				met = count >= int(requirement.get("minimum", 1))
			"skill_prefix":
				for skill_id: Variant in skills:
					if str(skill_id).begins_with(str(requirement.get("prefix", ""))) and int(skills[skill_id]) >= int(requirement.get("minimum_rank", 1)):
						met = true
						break
		if not met:
			missing.append(str(requirement.get("label", "prerequisite")))
	return missing


func _prerequisite_label(entry: Dictionary) -> String:
	var labels: Array[String] = []
	for requirement_value: Variant in entry.get("prerequisites", []):
		if requirement_value is Dictionary:
			labels.append(str((requirement_value as Dictionary).get("label", "Prerequisite")))
	return ", ".join(labels) if not labels.is_empty() else "None"


func _apply_purchase(option: Dictionary, result: Dictionary) -> void:
	var entry_id := str(option.get("entry_id", ""))
	match str(option.get("kind", "")):
		"characteristic":
			var characteristic := str(option.get("name", ""))
			(result["characteristics"] as Dictionary)[characteristic] = int((result["characteristics"] as Dictionary).get(characteristic, 0)) + 5
		"skill":
			(result["skills"] as Dictionary)[entry_id] = int((result["skills"] as Dictionary).get(entry_id, 0)) + 1
		"talent":
			(result["talents"] as Dictionary)[entry_id] = int((result["talents"] as Dictionary).get(entry_id, 0)) + 1
			if entry_id == "sound_constitution":
				result["advancement_wounds_bonus"] = int(result.get("advancement_wounds_bonus", 0)) + 1


func _recalculate_characteristic_bonuses(result: Dictionary) -> void:
	var bonuses := result["characteristic_bonuses"] as Dictionary
	for characteristic: Variant in (result["characteristics"] as Dictionary):
		bonuses[characteristic] = floori(float(result["characteristics"][characteristic]) / 10.0)
