class_name GladiatorModel
extends RefCounted

var id: String = ""
var display_name: String = ""
var type: String = ""
var level: int = 1
var starting_health: int = 0
var starting_stamina: int = 0
var attack_damage: int = 0
var dodge_chance: float = 0.0

static func from_dict(data: Dictionary) -> GladiatorModel:
	var model := GladiatorModel.new()
	model.id = str(data.get("id", ""))
	model.display_name = str(data.get("display_name", ""))
	model.type = str(data.get("type", ""))
	model.level = int(data.get("level", 1))
	model.starting_health = int(data.get("starting_health", 0))
	model.starting_stamina = int(data.get("starting_stamina", 0))
	model.attack_damage = int(data.get("attack_damage", 0))
	model.dodge_chance = float(data.get("dodge_chance", 0.0))
	return model
