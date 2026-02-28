class_name CardModel
extends Resource

var id: String
var card_name: String
var cost: int
var attack_power: int
var health: int
var description: String
var tags: Array = []
var icon: Texture2D

func _init(p_id: String = "", p_name: String = "", p_cost: int = 0) -> void:
	id = p_id
	card_name = p_name
	cost = p_cost

func get_full_title() -> String:
	return id + ": " + card_name

# Stat-scaled attack: base card power + gladiator ATK contribution
func scaled_attack(gladiator) -> int:
	if attack_power <= 0:
		return 0
	var base = attack_power + int(gladiator.attack_damage * 0.3)
	return maxi(base, 1)

# Stat-scaled block: base card block + gladiator HP contribution
func scaled_block(gladiator) -> int:
	if health <= 0:
		return 0
	return health + int(gladiator.max_hp * 0.05)

# Check if this card has a specific tag
func has_tag(tag: String) -> bool:
	return tags.has(tag)

static func from_dict(data: Dictionary) -> CardModel:
	var p_id = data.get("id", "") as String
	var p_name = data.get("card_name", "Unknown Card") as String
	var p_cost = data.get("cost", 0) as int

	var card = CardModel.new(p_id, p_name, p_cost)
	
	if data.has("attack_power"): card.attack_power = data["attack_power"]
	if data.has("health"): card.health = data["health"]
	if data.has("description"): card.description = data["description"]
	if data.has("tags"): card.tags = data["tags"]
	
	return card
