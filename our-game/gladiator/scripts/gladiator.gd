class_name Gladiator extends Resource

@export var g_name: String
@export var type: String
@export var level: int = 1

# Stats
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var max_stamina: int = 10
@export var current_stamina: int = 10
@export var attack_damage: int = 10
@export var dodge_chance: float = 20.0

# Base stats at level 1 (for level-up threshold calculations)
@export var base_hp: int = 100
@export var base_attack: int = 10
@export var base_dodge: float = 20.0

# Hooks / States
@export var traits: Array[String] = []
@export var is_active: bool = true

# Hunger System (0-100, starts full)
@export var hunger: int = 100

# Time Logic & Actions
@export var current_action: String = "idle" # "idle", "training"
@export var action_duration_left: int = 0
@export var training_target: String = ""

# ================= Historical Titles & Colors =================

## Title tiers change every 3 levels, with historically themed Roman titles.
const TITLE_TIERS := [
	{"title": "Tiro", "color": Color(0.9, 0.9, 0.9)}, # 1-3: White
	{"title": "Novicius", "color": Color(0.3, 0.8, 0.3)}, # 4-6: Green
	{"title": "Veteranus", "color": Color(0.3, 0.5, 1.0)}, # 7-9: Blue
	{"title": "Primus Palus", "color": Color(0.7, 0.3, 0.9)}, # 10-12: Purple
	{"title": "Champion", "color": Color(1.0, 0.85, 0.3)}, # 13-15: Gold
	{"title": "Gloria Romae", "color": Color(1.0, 0.55, 0.1)}, # 16-18: Orange
	{"title": "Invictus", "color": Color(0.95, 0.15, 0.1)}, # 19+: Red
]

func get_title() -> String:
	var tier_index = clampi(int((level - 1) / 3), 0, TITLE_TIERS.size() - 1)
	return TITLE_TIERS[tier_index]["title"]

func get_title_color() -> Color:
	var tier_index = clampi(int((level - 1) / 3), 0, TITLE_TIERS.size() - 1)
	return TITLE_TIERS[tier_index]["color"]

# ================= Level-Up System =================

func check_level_up() -> bool:
	## Check if gladiator meets class-specific level-up thresholds.
	## Returns true if a level-up occurred.
	var leveled_up := false
	
	match type:
		"Murmillo":
			# Tank: needs +10% base HP and +2% base ATK per level
			var hp_threshold = base_hp * (1.0 + 0.10 * level)
			var atk_threshold = base_attack * (1.0 + 0.02 * level)
			if max_hp >= int(hp_threshold) and attack_damage >= int(atk_threshold):
				leveled_up = true
				# Reward: +10% of initial HP
				var hp_bonus = int(base_hp * 0.10)
				max_hp += hp_bonus
				current_hp += hp_bonus
				
		"Thraex":
			# Fighter: needs +5% HP, +10% ATK, +2.5 dodge per level
			var hp_threshold = base_hp * (1.0 + 0.05 * level)
			var atk_threshold = base_attack * (1.0 + 0.10 * level)
			var dodge_threshold = base_dodge + 2.5 * level
			if max_hp >= int(hp_threshold) and attack_damage >= int(atk_threshold) and dodge_chance >= dodge_threshold:
				leveled_up = true
				# Reward: +5% HP, +5% ATK, +0.5 dodge
				var hp_bonus = int(base_hp * 0.05)
				max_hp += hp_bonus
				current_hp += hp_bonus
				attack_damage += int(base_attack * 0.05)
				dodge_chance += 0.5
				
		"Retiarius":
			# Assassin: needs +15% ATK and +5 dodge per level
			var atk_threshold = base_attack * (1.0 + 0.15 * level)
			var dodge_threshold = base_dodge + 5.0 * level
			if attack_damage >= int(atk_threshold) and dodge_chance >= dodge_threshold:
				leveled_up = true
				# Reward: +10% ATK, +1 dodge
				attack_damage += int(base_attack * 0.10)
				dodge_chance += 1.0
	
	if leveled_up:
		level += 1
		print("%s leveled up to %d! Title: %s" % [g_name, level, get_title()])
	
	return leveled_up

# ================= Core Actions =================

func train():
	if current_stamina >= 1 and is_active:
		attack_damage += 1
		current_stamina -= 1
		return true
	return false

func rest(stamina_gain: int):
	if is_active:
		current_stamina = clampi(current_stamina + stamina_gain, 0, max_stamina)

func feed():
	hunger = 100

func start_training(duration: int, target: String):
	current_action = "training"
	training_target = target
	action_duration_left = duration

func pass_day():
	if not is_active: return
	
	# Hunger decreases by 25 each day
	hunger = maxi(hunger - 25, 0)
	
	# At hunger 0: apply 30% max HP reduction
	if hunger == 0:
		var starvation_dmg = int(max_hp * 0.3)
		current_hp -= starvation_dmg
		print(g_name + " is starving! Lost %d HP" % starvation_dmg)
		
		if current_hp <= 0:
			current_hp = 0
			is_active = false
			print(g_name + " died of starvation!")
			return
	
	# Passive Health Regen (5 HP) only when not starving
	if hunger > 0:
		if current_hp < max_hp:
			current_hp = mini(current_hp + 5, max_hp)
	
	if current_action != "idle":
		action_duration_left -= 1
		if action_duration_left <= 0:
			_complete_current_action()

func _complete_current_action():
	if current_action == "training":
		if training_target == "health":
			max_hp += 15
			current_hp += 15
			print(g_name + " completed training! +15 Health")
		elif training_target == "attack":
			attack_damage += 5
			print(g_name + " completed training! +5 Attack Damage")
		elif training_target == "dodge":
			dodge_chance += 0.5
			print(g_name + " completed training! +0.5% Dodge Chance")
		elif training_target == "all":
			max_hp += 15
			current_hp += 15
			attack_damage += 5
			dodge_chance += 0.5
			print(g_name + " completed training! (All Stats)")
		
		# Check for level-up after training completes
		check_level_up()
		
	current_action = "idle"
	training_target = ""
	action_duration_left = 0

func take_damage(amount: int):
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		is_active = false