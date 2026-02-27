extends Node

const GLADIATORS_PATH := "res://data/gladiators.json"
const CARDS_PATH := "res://data/cards.json"
const CONFIG_PATH := "res://data/config.json"

var gladiators: Array[GladiatorModel] = []
var cards: Array[CardModel] = []
var config: GameConfigModel = GameConfigModel.new()

func _ready() -> void:
	reload()

func reload() -> void:
	gladiators.clear()
	cards.clear()
	config = GameConfigModel.new()

	_load_gladiators()
	_load_cards()
	_load_config()

func _load_gladiators() -> void:
	var raw_gladiators = JsonLoader.load_json(GLADIATORS_PATH, [])
	if raw_gladiators is not Array:
		push_error("GameData: '%s' should contain an array." % GLADIATORS_PATH)
		return

	for raw_gladiator in raw_gladiators:
		if raw_gladiator is Dictionary:
			gladiators.append(GladiatorModel.from_dict(raw_gladiator))

func _load_cards() -> void:
	var raw_cards = JsonLoader.load_json(CARDS_PATH, [])
	if raw_cards is not Array:
		push_error("GameData: '%s' should contain an array." % CARDS_PATH)
		return

	for raw_card in raw_cards:
		if raw_card is Dictionary:
			cards.append(CardModel.from_dict(raw_card))

func _load_config() -> void:
	var raw_config = JsonLoader.load_json(CONFIG_PATH, {})
	if raw_config is Dictionary:
		config = GameConfigModel.from_dict(raw_config)
	else:
		push_error("GameData: '%s' should contain an object." % CONFIG_PATH)
