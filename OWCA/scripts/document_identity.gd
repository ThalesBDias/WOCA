class_name DocumentIdentity
extends RefCounted

## Generates and validates durable UUIDv4-style identifiers for saved records.
##
## File paths and display names are user-controlled and can change. A document
## ID lets Save As preserve identity while Duplicate deliberately creates a new
## regiment or character record for interoperability consumers.

const UUID_PATTERN := "^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$"


static func generate() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		# Crypto is available on supported Godot platforms. This fallback keeps
		# record creation functional on an unusual platform while preserving the
		# same UUID shape expected by schemas and external consumers.
		var generator := RandomNumberGenerator.new()
		generator.randomize()
		bytes.resize(16)
		for index in range(16):
			bytes[index] = generator.randi_range(0, 255)
	bytes[6] = (int(bytes[6]) & 0x0f) | 0x40
	bytes[8] = (int(bytes[8]) & 0x3f) | 0x80
	var encoded := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		encoded.substr(0, 8),
		encoded.substr(8, 4),
		encoded.substr(12, 4),
		encoded.substr(16, 4),
		encoded.substr(20, 12)
	]


static func is_valid(value: String) -> bool:
	var pattern := RegEx.new()
	return pattern.compile(UUID_PATTERN) == OK and pattern.search(value) != null
