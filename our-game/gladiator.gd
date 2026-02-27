class_name Gladiator extends Resource

@export var g_name: String
@export var type: String 

# Stats
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var max_stamina: int = 10
@export var current_stamina: int = 10
@export var morale: int = 100
@export var strength: int = 10

# Hooks / States
@export var traits: Array[String] = []
@export var is_active: bool = true

# Validation Rules & Hooks (E & F kısımları)
func train():
	if current_stamina >= 1 and is_active:
		strength += 1
		current_stamina -= 1
		return true # Başarılı
	return false # Stamina yetersiz veya ölü

func rest(stamina_gain: int, morale_gain: int):
	if is_active:
		current_stamina = clampi(current_stamina + stamina_gain, 0, max_stamina)
		morale = clampi(morale + morale_gain, 0, 100)

func take_damage(amount: int):
	current_hp -= amount
	if current_hp <= 0:
		current_hp = 0
		is_active = false # F - HP 0'a düşerse inaktif