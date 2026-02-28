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

# Hooks / States
@export var traits: Array[String] = []
@export var is_active: bool = true

# Hunger System (0-100, starts full)
@export var hunger: int = 100

# Time Logic & Actions
@export var current_action: String = "idle" # "idle", "training"
@export var action_duration_left: int = 0
@export var training_target: String = ""

# Validation Rules & Hooks
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
			
	current_action = "idle"
	training_target = ""
	action_duration_left = 0

func take_damage(amount: int):
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		is_active = false