class_name TraitSystem
extends RefCounted

## Defines all available gladiator traits and their effects.
## Traits are assigned when a gladiator is created or upgraded.

# Trait definitions: id -> {name, description, effects}
const TRAIT_DEFS := {
	"iron_skin": {
		"name": "Iron Skin",
		"description": "Takes 20% less damage from all sources.",
		"damage_reduction": 0.2,
	},
	"shield_master": {
		"name": "Shield Master",
		"description": "Block cards are 50% more effective.",
		"block_bonus": 0.5,
	},
	"glutton": {
		"name": "Glutton",
		"description": "Requires double food to feed (12 instead of 6).",
		"food_cost_multiplier": 2.0,
	},
	"berserker": {
		"name": "Berserker",
		"description": "Deals 30% more damage when below 50% HP.",
		"low_hp_damage_bonus": 0.3,
	},
	"fast_learner": {
		"name": "Fast Learner",
		"description": "Training completes 1 day faster.",
		"training_speed_bonus": 1,
	},
	"battle_hardened": {
		"name": "Battle Hardened",
		"description": "+10 Max HP after each battle survived.",
		"post_battle_hp_bonus": 10,
	},
	"shadow_step": {
		"name": "Shadow Step",
		"description": "+5% Dodge Chance.",
		"dodge_bonus": 5.0,
	},
	"poisoner": {
		"name": "Poisoner",
		"description": "Attacks deal 3 extra damage over time.",
		"poison_damage": 3,
	},
	"resilient": {
		"name": "Resilient",
		"description": "Survives 1 extra day without food before taking damage.",
		"starvation_delay": 1,
	},
	"frail": {
		"name": "Frail",
		"description": "Takes 25% more damage from all sources.",
		"damage_increase": 0.25,
	},
}

static func get_trait_info(trait_id: String) -> Dictionary:
	return TRAIT_DEFS.get(trait_id, {})

static func get_trait_name(trait_id: String) -> String:
	var info = get_trait_info(trait_id)
	return str(info.get("name", trait_id))

static func get_trait_description(trait_id: String) -> String:
	var info = get_trait_info(trait_id)
	return str(info.get("description", "Unknown trait."))

static func assign_random_trait(gladiator: Gladiator, possible_traits: Array) -> void:
	## Assigns a random trait from the possible list if the gladiator doesn't have one yet.
	if gladiator.traits.size() > 0:
		return  # Already has traits
	
	if possible_traits.is_empty():
		return
	
	var trait_id = str(possible_traits[randi() % possible_traits.size()])
	gladiator.traits.append(trait_id)
	
	# Apply immediate stat effects
	var info = get_trait_info(trait_id)
	if info.has("dodge_bonus"):
		gladiator.dodge_chance += float(info["dodge_bonus"])

static func get_damage_modifier(gladiator: Gladiator) -> float:
	## Returns the total damage multiplier from traits (applied to outgoing damage).
	var modifier := 1.0
	for trait_id in gladiator.traits:
		var info = get_trait_info(trait_id)
		if info.has("low_hp_damage_bonus"):
			if gladiator.current_hp < gladiator.max_hp * 0.5:
				modifier += float(info["low_hp_damage_bonus"])
	return modifier

static func get_damage_reduction(gladiator: Gladiator) -> float:
	## Returns total damage reduction factor (applied to incoming damage).
	var reduction := 0.0
	for trait_id in gladiator.traits:
		var info = get_trait_info(trait_id)
		if info.has("damage_reduction"):
			reduction += float(info["damage_reduction"])
		if info.has("damage_increase"):
			reduction -= float(info["damage_increase"])
	return clampf(reduction, -0.5, 0.8)

static func get_block_bonus(gladiator: Gladiator) -> float:
	## Returns block effectiveness multiplier.
	var bonus := 1.0
	for trait_id in gladiator.traits:
		var info = get_trait_info(trait_id)
		if info.has("block_bonus"):
			bonus += float(info["block_bonus"])
	return bonus

static func get_training_speed_bonus(gladiator: Gladiator) -> int:
	## Returns days to subtract from training duration.
	var bonus := 0
	for trait_id in gladiator.traits:
		var info = get_trait_info(trait_id)
		if info.has("training_speed_bonus"):
			bonus += int(info["training_speed_bonus"])
	return bonus

static func get_starvation_delay(gladiator: Gladiator) -> int:
	## Returns extra days before starvation damage begins.
	var delay := 0
	for trait_id in gladiator.traits:
		var info = get_trait_info(trait_id)
		if info.has("starvation_delay"):
			delay += int(info["starvation_delay"])
	return delay
