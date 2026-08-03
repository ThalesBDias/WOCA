extends SceneTree

## Run with: godot --headless --path . --script res://OWCA/tests/character_creation_roller_test.gd


func _init() -> void:
	var first_rng := RandomNumberGenerator.new()
	first_rng.seed = 40000
	var second_rng := RandomNumberGenerator.new()
	second_rng.seed = 40000
	var first := CharacterCreationRoller.new(first_rng)
	var second := CharacterCreationRoller.new(second_rng)

	# Matching injected seeds must produce matching audit records. This protects
	# deterministic tests without making normal application rolls predictable.
	for _sample in 250:
		var first_characteristic := first.roll_characteristic()
		var second_characteristic := second.roll_characteristic()
		_assert_equal(first_characteristic, second_characteristic, "seeded Characteristic roll is reproducible")
		_assert_roll(first_characteristic, 2, 1, 10, 20, 22, 40, "Characteristic")
		var first_wounds := first.roll_wounds()
		var second_wounds := second.roll_wounds()
		_assert_equal(first_wounds, second_wounds, "seeded Wounds roll is reproducible")
		_assert_roll(first_wounds, 1, 1, 5, 0, 1, 5, "Wounds")
		var first_fate := first.roll_fate()
		var second_fate := second.roll_fate()
		_assert_equal(first_fate, second_fate, "seeded Fate roll is reproducible")
		_assert_roll(first_fate, 1, 1, 10, 0, 1, 10, "Fate")

	var complete := first.roll_all_characteristics()
	_assert_equal(complete.size(), CharacterState.CHARACTERISTIC_ORDER.size(), "roll-all returns nine Characteristics")
	for characteristic in CharacterState.CHARACTERISTIC_ORDER:
		_assert_true(complete.has(characteristic), "roll-all contains %s" % characteristic)
		_assert_roll(complete[characteristic] as Dictionary, 2, 1, 10, 20, 22, 40, characteristic)

	var example := { "notation": "2d10 + 20", "dice": [7, 4], "base": 20, "total": 31 }
	_assert_equal(first.describe(example), "7 + 4 + 20 = 31", "roll description exposes individual dice")
	print("OWCA character creation roller tests passed.")
	quit(0)


func _assert_roll(result: Dictionary, dice_count: int, die_minimum: int, die_maximum: int, base: int, total_minimum: int, total_maximum: int, label: String) -> void:
	var dice := result.get("dice", []) as Array
	_assert_equal(dice.size(), dice_count, "%s die count" % label)
	for die: Variant in dice:
		_assert_true(int(die) in range(die_minimum, die_maximum + 1), "%s die is in range" % label)
	_assert_equal(int(result.get("base", -1)), base, "%s base modifier" % label)
	_assert_true(int(result.get("total", 0)) in range(total_minimum, total_maximum + 1), "%s total is in range" % label)


func _assert_true(condition: bool, label: String) -> void:
	if not condition:
		printerr("FAILED: %s" % label)
		quit(1)


func _assert_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual != expected:
		printerr("FAILED: %s (expected %s, got %s)" % [label, expected, actual])
		quit(1)
