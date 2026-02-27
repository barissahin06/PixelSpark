class_name CardModel
extends RefCounted

var id: String = ""
var display_name: String = ""
var cost: int = 0
var tags: Array[String] = []

static func from_dict(data: Dictionary) -> CardModel:
	var model := CardModel.new()
	model.id = str(data.get("id", ""))
	model.display_name = str(data.get("display_name", ""))
	model.cost = int(data.get("cost", 0))

	var raw_tags := data.get("tags", [])
	if raw_tags is Array:
		for raw_tag in raw_tags:
			model.tags.append(str(raw_tag))

	return model
