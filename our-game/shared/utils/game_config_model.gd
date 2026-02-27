class_name GameConfigModel
extends RefCounted

var initial_route: String = "ludus"
var version: String = "0.0.0"

static func from_dict(data: Dictionary) -> GameConfigModel:
	var model := GameConfigModel.new()
	model.initial_route = str(data.get("initial_route", "ludus"))
	model.version = str(data.get("version", "0.0.0"))
	return model
