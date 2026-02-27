class_name JsonLoader
extends RefCounted

static func load_json(path: String, default_value: Variant) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("JsonLoader: Missing file '%s'." % path)
		return default_value

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("JsonLoader: Could not open file '%s'." % path)
		return default_value

	var raw_text := file.get_as_text()
	var parser := JSON.new()
	var parse_error := parser.parse(raw_text)
	if parse_error != OK:
		push_error(
			"JsonLoader: Parse error in '%s' at line %d: %s" % [
				path,
				parser.get_error_line(),
				parser.get_error_message()
			]
		)
		return default_value

	return parser.data
