extends Node

# A - Core Management State
var current_day: int = 1
var gold: int = 100
var food: int = 50
var roster: Array[Gladiator] = []
var max_roster_size: int = 20

# Battle System
var days_to_next_battle: int = 0

func _ready():
	randomize()
	reset_run()

func reset_run():
	current_day = 1
	days_to_next_battle = randi_range(3, 7)
	gold = 100
	food = 50
	roster.clear()
	# Başlangıçtaki gladyatörleri JSON verisinden (GameData) ekle
	add_gladiator("tank_base")
	add_gladiator("fighter_base")
	add_gladiator("assassin_base")

func add_gladiator(gladiator_id: String):
	if roster.size() >= max_roster_size:
		print("Roster dolu!")
		return
		
	# JSON'dan yüklenmiş olan veriyi bul
	var model: GladiatorModel = null
	for g in GameData.gladiators:
		if g.id == gladiator_id:
			model = g
			break
			
	if model == null:
		push_error("GameManager: Gladiator ID '%s' bulunamadı!" % gladiator_id)
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
	
	roster.append(new_glad)

func pass_day():
	current_day += 1
	
	if days_to_next_battle > 0:
		days_to_next_battle -= 1
	
	# Ölümleri kontrol etmek ve listeyi temizlemek için roster'ı güncelleriz
	var dead_gladiators = []
	
	for gladiator in roster:
		# Gladyatör kendi gün işlemlerini yapsın (eylem süresi düşer, açlık uygulanır)
		gladiator.pass_day()
		
		if not gladiator.is_active:
			dead_gladiators.append(gladiator)
	
	# Ölen gladyatörleri listeden çıkar
	for dead in dead_gladiators:
		roster.erase(dead)
				
	print("Day %d başlıyor! Kalan yemek: %d" % [current_day, food])

func reset_battle_timer():
	days_to_next_battle = randi_range(3, 7)

func feed_gladiator(index: int) -> bool:
	if food >= 6 and index >= 0 and index < roster.size():
		food -= 6
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

func buy_slave() -> bool:
	if gold >= 25 and roster.size() < max_roster_size:
		gold -= 25
		add_gladiator("slave_base")
		return true
	return false

func upgrade_slave(index: int, target_class: String) -> bool:
	if gold >= 10 and index >= 0 and index < roster.size():
		var glad = roster[index]
		if glad.type == "Slave":
			# Hedef sınıfın statlarını GameData'dan alalım
			var model: GladiatorModel = null
			for g in GameData.gladiators:
				if g.id == target_class:
					model = g
					break
			
			if model != null:
				gold -= 10
				glad.g_name = model.display_name
				glad.type = model.type
				# HP ve Stamina'yı orantılı artırmak/güncellemek için
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
				glad.start_training(3, target) # 3 gün sürer
				return true
	return false

func heal_gladiator(index: int) -> bool:
	if gold >= 5 and index >= 0 and index < roster.size():
		var glad = roster[index]
		if glad.current_hp < glad.max_hp:
			gold -= 5
			glad.current_hp = mini(glad.current_hp + 50, glad.max_hp)
			return true
	return false