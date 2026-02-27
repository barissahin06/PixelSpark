class_name GladiatorModel
extends RefCounted

var id: String = ""
var display_name: String = ""
var starting_health: int = 0
var starting_stamina: int = 0

static func from_dict(data: Dictionary) -> GladiatorModel:
	var model := GladiatorModel.new()
	model.id = str(data.get("id", ""))
	model.display_name = str(data.get("display_name", ""))
	model.starting_health = int(data.get("starting_health", 0))
	model.starting_stamina = int(data.get("starting_stamina", 0))
	return model
