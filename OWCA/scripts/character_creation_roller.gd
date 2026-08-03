class_name CharacterCreationRoller
extends RefCounted

## Generates dice used only during character creation.
##
## This service deliberately knows nothing about regiments, Specialities, final
## Characteristics, or the UI. It returns transparent roll records so callers
## can display the individual dice before storing only the selected input value
## in CharacterState. Gameplay tests, attacks, and damage rolls do not belong
## here and remain outside OWCA's scope.

const CHARACTERISTIC_DICE := 2
const CHARACTERISTIC_DIE_SIDES := 10
const CHARACTERISTIC_BASE := 20
const WOUNDS_DIE_SIDES := 5
const FATE_DIE_SIDES := 10

var _rng: RandomNumberGenerator


## Uses a time-randomized generator in the app. Tests may inject a seeded
## RandomNumberGenerator to make every expected result reproducible.
func _init(random_number_generator: RandomNumberGenerator = null) -> void:
	if random_number_generator == null:
		_rng = RandomNumberGenerator.new()
		_rng.randomize()
	else:
		_rng = random_number_generator


## Rolls the Core characteristic-generation expression, 2d10 + 20.
func roll_characteristic() -> Dictionary:
	var dice: Array[int] = []
	for _die_index in CHARACTERISTIC_DICE:
		dice.append(_roll_die(CHARACTERISTIC_DIE_SIDES))
	return _build_result("2d10 + 20", dice, CHARACTERISTIC_BASE)


## Rolls all nine Characteristics in the stable order used by CharacterState.
func roll_all_characteristics() -> Dictionary:
	var output: Dictionary = {}
	for characteristic in CharacterState.CHARACTERISTIC_ORDER:
		output[characteristic] = roll_characteristic()
	return output


## Rolls the 1d5 value later combined with the selected Speciality's Wounds.
func roll_wounds() -> Dictionary:
	return _build_result("1d5", [_roll_die(WOUNDS_DIE_SIDES)], 0)


## Rolls the 1d10 value used by the character-creation Fate lookup.
func roll_fate() -> Dictionary:
	return _build_result("1d10", [_roll_die(FATE_DIE_SIDES)], 0)


## Converts a roll record into a human-readable audit string such as
## "7 + 4 + 20 = 31". This is presentation only and is not saved.
func describe(result: Dictionary) -> String:
	var parts: Array[String] = []
	for die: Variant in result.get("dice", []):
		parts.append(str(int(die)))
	var base := int(result.get("base", 0))
	if base != 0:
		parts.append(str(base))
	return "%s = %d" % [" + ".join(parts), int(result.get("total", 0))]


func _roll_die(sides: int) -> int:
	return _rng.randi_range(1, sides)


func _build_result(notation: String, dice: Array[int], base: int) -> Dictionary:
	var total := base
	for die in dice:
		total += die
	return {
		"notation": notation,
		"dice": dice.duplicate(),
		"base": base,
		"total": total
	}
