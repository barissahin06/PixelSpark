extends Node

# A - Core Management State
var current_day: int = 1
var gold: int = 100
var roster: Array[Gladiator] = []
var max_roster_size: int = 20

func _ready():
	reset_run()

func reset_run():
	current_day = 1
	gold = 100
	roster.clear()
	# Başlangıçtaki 3 rastgele gladyatörü oluştur (Örnek)
	add_gladiator("Spartacus", "Fighter")
	add_gladiator("Crixus", "Tank")
	add_gladiator("Gannicus", "Assassin")

func add_gladiator(g_name: String, type: String):
	if roster.size() >= max_roster_size:
		print("Roster dolu!")
		return
	var new_glad = Gladiator.new()
	new_glad.g_name = g_name
	new_glad.type = type
	roster.append(new_glad)