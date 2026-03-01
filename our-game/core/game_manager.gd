extends Node

# A - Core Management State
var current_day: int = 1
var gold: int = 100
var food: int = 50
var roster: Array[Gladiator] = []
var max_roster_size: int = 20

# Battle System
var days_to_next_battle: int = 0
var battles_won: int = 0 # Track wins for progressive difficulty

# Slave Market
var slave_market: Array = [] # Array of Dictionaries with slave data
var last_market_refresh_day: int = 0

# Slave name pools
const SLAVE_NAMES := [
	"Marcus", "Lucius", "Gaius", "Titus", "Quintus", "Decimus", "Cassius",
	"Brutus", "Severus", "Felix", "Maximus", "Corvus", "Nero", "Drusus",
	"Varro", "Cato", "Otho", "Rufus", "Spurius", "Tiberius", "Ajax",
	"Theron", "Darius", "Kael", "Bran", "Rook", "Ash", "Flint"
]

# Ludus Upgrades
var ludus_upgrades: LudusUpgrades = null

func _ready():
	randomize()
	ludus_upgrades = LudusUpgrades.new()
	reset_run()

func reset_run():
	current_day = 1
	days_to_next_battle = randi_range(3, 7)
	battles_won = 0
	gold = 100
	food = 50
	roster.clear()
	if ludus_upgrades:
		ludus_upgrades = LudusUpgrades.new()
	last_market_refresh_day = 0
	# Starting gladiators from JSON data (GameData)
	add_gladiator("tank_base")
	add_gladiator("fighter_base")
	add_gladiator("assassin_base")
	# Generate initial slave market
	refresh_slave_market()

func get_effective_roster_max() -> int:
	var bonus = ludus_upgrades.get_roster_capacity_bonus() if ludus_upgrades else 0
	return max_roster_size + bonus

func add_gladiator(gladiator_id: String):
	if roster.size() >= get_effective_roster_max():
		print("Roster full!")
		return
		
	var model: GladiatorModel = null
	for g in GameData.gladiators:
		if g.id == gladiator_id:
			model = g
			break
			
	if model == null:
		push_error("GameManager: Gladiator ID '%s' not found!" % gladiator_id)
		return
		
	var new_glad = Gladiator.new()
	new_glad.g_name = model.display_name
	new_glad.type = model.type
	new_glad.level = model.level
	new_glad.max_hp = model.starting_health
	new_glad.current_hp = model.starting_health
	new_glad.max_stamina = model.starting_stamina
	new_glad.current_stamina = model.starting_stamina
	new_glad.attack_damage = model.attack_damage
	new_glad.dodge_chance = model.dodge_chance
	# Store base stats for level-up threshold calculations
	new_glad.base_hp = model.starting_health
	new_glad.base_attack = model.attack_damage
	new_glad.base_dodge = model.dodge_chance
	
	roster.append(new_glad)
	
	# Assign a random trait from the gladiator's possible traits
	TraitSystem.assign_random_trait(new_glad, model.possible_traits)

func purge_dead():
	## Remove dead gladiators from roster immediately (called after battle)
	var dead = []
	for g in roster:
		if not g.is_active:
			dead.append(g)
	for d in dead:
		roster.erase(d)

func pass_day():
	current_day += 1
	
	if days_to_next_battle > 0:
		days_to_next_battle -= 1
	
	# Ludus upgrades tick (build progress)
	if ludus_upgrades:
		ludus_upgrades.pass_day()
		# Passive gold income from farm yard
		gold += ludus_upgrades.get_daily_gold_income()
	
	# Process each gladiator's day
	var dead_gladiators = []
	var hp_regen_bonus = ludus_upgrades.get_daily_hp_regen_bonus() if ludus_upgrades else 0
	
	for gladiator in roster:
		gladiator.pass_day()
		# Apply ludus HP regen bonus (showers)
		if gladiator.is_active and gladiator.hunger > 0 and hp_regen_bonus > 0:
			gladiator.current_hp = mini(gladiator.current_hp + hp_regen_bonus, gladiator.max_hp)
		if not gladiator.is_active:
			dead_gladiators.append(gladiator)
	
	# Remove dead gladiators
	for dead in dead_gladiators:
		roster.erase(dead)
	
	# Refresh slave market every 7 days
	if current_day - last_market_refresh_day >= 7:
		refresh_slave_market()
	
	# Ensure gold never goes below 0
	gold = maxi(gold, 0)
				
	print("Day %d started! Food: %d | Gold: %d" % [current_day, food, gold])

func reset_battle_timer():
	purge_dead() # Clean up dead gladiators right after battle
	days_to_next_battle = randi_range(3, 7)

func feed_gladiator(index: int) -> bool:
	if food >= 5 and index >= 0 and index < roster.size():
		food -= 5
		roster[index].feed()
		return true
	return false

func buy_food() -> bool:
	if gold >= 3:
		gold -= 3
		food += 20
		return true
	return false

func sell_food() -> bool:
	if food >= 20:
		food -= 20
		gold += 1
		return true
	return false

# ================= Slave Market =================

func refresh_slave_market():
	slave_market.clear()
	last_market_refresh_day = current_day
	var count = randi_range(3, 5)
	
	for i in range(count):
		var slave_data = _generate_random_slave()
		slave_market.append(slave_data)

func _generate_random_slave() -> Dictionary:
	var hp = randi_range(30, 80)
	var atk = randi_range(3, 20)
	var dodge = snapped(randf_range(1.0, 8.0), 0.1)
	var stamina = randi_range(4, 10)
	var slave_name = SLAVE_NAMES[randi() % SLAVE_NAMES.size()]
	
	# Random trait from slave trait pool
	var trait_pool = ["resilient", "glutton", "frail", "iron_skin", "fast_learner", "berserker"]
	var trait_id = trait_pool[randi() % trait_pool.size()]
	
	# Price based on stats
	var price = 15 + int(hp * 0.2) + int(atk * 1.5) + int(dodge * 2.0)
	
	return {
		"name": slave_name,
		"hp": hp,
		"atk": atk,
		"dodge": dodge,
		"stamina": stamina,
		"trait": trait_id,
		"price": price,
	}

func buy_market_slave(index: int) -> bool:
	if index < 0 or index >= slave_market.size():
		return false
	
	var data = slave_market[index]
	if gold < data["price"] or roster.size() >= get_effective_roster_max():
		return false
	
	gold -= data["price"]
	
	var new_glad = Gladiator.new()
	new_glad.g_name = data["name"]
	new_glad.type = "Slave"
	new_glad.level = 1
	new_glad.max_hp = data["hp"]
	new_glad.current_hp = data["hp"]
	new_glad.max_stamina = data["stamina"]
	new_glad.current_stamina = data["stamina"]
	new_glad.attack_damage = data["atk"]
	new_glad.dodge_chance = data["dodge"]
	new_glad.hunger = 100
	new_glad.traits.append(data["trait"])
	# Store base stats for level-up threshold calculations
	new_glad.base_hp = data["hp"]
	new_glad.base_attack = data["atk"]
	new_glad.base_dodge = data["dodge"]
	
	roster.append(new_glad)
	slave_market.remove_at(index)
	return true

func get_days_until_market_refresh() -> int:
	return maxi(7 - (current_day - last_market_refresh_day), 0)

# ================= Upgrades =================

func upgrade_slave(index: int, target_class: String) -> bool:
	if gold >= 10 and index >= 0 and index < roster.size():
		var glad = roster[index]
		if glad.type == "Slave":
			var model: GladiatorModel = null
			for g in GameData.gladiators:
				if g.id == target_class:
					model = g
					break
			
			if model != null:
				gold -= 10
				glad.g_name = model.display_name
				glad.type = model.type
				glad.max_hp = model.starting_health
				glad.current_hp = model.starting_health
				glad.max_stamina = model.starting_stamina
				glad.current_stamina = model.starting_stamina
				glad.attack_damage = model.attack_damage
				glad.dodge_chance = model.dodge_chance
				return true
	return false

func train_gladiator(index: int, target: String) -> bool:
	if index >= 0 and index < roster.size():
		var glad = roster[index]
		if glad.current_action == "idle":
			var cost = 10
			if target == "all":
				cost = 35
				
			if gold >= cost:
				gold -= cost
				var duration = 3 - TraitSystem.get_training_speed_bonus(glad)
				duration = maxi(duration, 1) # Minimum 1 day
				glad.start_training(duration, target)
				return true
	return false

func heal_gladiator(index: int) -> bool:
	var base_cost = 5
	var reduction = ludus_upgrades.get_heal_cost_reduction() if ludus_upgrades else 0
	var cost = maxi(base_cost - reduction, 1)
	
	if gold >= cost and index >= 0 and index < roster.size():
		var glad = roster[index]
		if glad.current_hp < glad.max_hp:
			gold -= cost
			# Doctor level 2: full heal
			if ludus_upgrades and ludus_upgrades.is_built("ludus_doctor_2"):
				glad.current_hp = glad.max_hp
			else:
				glad.current_hp = mini(glad.current_hp + 50, glad.max_hp)
			return true
	return false

func get_heal_cost() -> int:
	var base_cost = 5
	var reduction = ludus_upgrades.get_heal_cost_reduction() if ludus_upgrades else 0
	return maxi(base_cost - reduction, 1)