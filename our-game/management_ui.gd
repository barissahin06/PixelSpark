extends Control

# UI Element Referansları (Sahnende bu isimlerde nodlar olmalı)
@onready var day_label = $VBoxContainer/TopBar/DayLabel
@onready var gold_label = $VBoxContainer/TopBar/GoldLabel
@onready var gladiator_list = $VBoxContainer/MainPanel/GladiatorList
@onready var stats_label = $VBoxContainer/MainPanel/StatsLabel

var selected_gladiator: Gladiator = null

func _ready():
	# Rastgele sayı üretecini başlatır (Event'ler için önemli)
	randomize() 
	update_ui()
	populate_gladiator_list()

# B - Gladiator Overview Panel
func update_ui():
	# GameManager henüz yüklenmediyse hata vermemesi için güvenlik kalkanı
	if not GameManager: return 
	
	day_label.text = "Day: " + str(GameManager.current_day)
	gold_label.text = "Gold: " + str(GameManager.gold)
	
	if selected_gladiator:
		stats_label.text = "Name: %s\nType: %s\nHP: %d/%d\nStamina: %d/%d\nMorale: %d\nStrength: %d" % [
			selected_gladiator.g_name, selected_gladiator.type,
			selected_gladiator.current_hp, selected_gladiator.max_hp,
			selected_gladiator.current_stamina, selected_gladiator.max_stamina,
			selected_gladiator.morale, selected_gladiator.strength
		]
	else:
		stats_label.text = "No Gladiator Selected"

func populate_gladiator_list():
	gladiator_list.clear()
	for g in GameManager.roster:
		var status = "" if g.is_active else " (DEAD)"
		gladiator_list.add_item(g.g_name + " - " + g.type + status)

func _on_gladiator_list_item_selected(index):
	selected_gladiator = GameManager.roster[index]
	update_ui()

# C - Action Buttons
func _on_train_button_pressed():
	if selected_gladiator and selected_gladiator.train():
		print(selected_gladiator.g_name + " antrenman yaptı!")
		update_ui()
	else:
		print("Antrenman başarısız! Stamina yok veya ölü.")

func _on_rest_button_pressed():
	if selected_gladiator:
		selected_gladiator.rest(3, 10) # Stamina +3, Morale +10
		update_ui()

func _on_advance_day_button_pressed():
	GameManager.current_day += 1
	trigger_random_event()
	update_ui()

func _on_fight_button_pressed():
	var active_count = 0
	for g in GameManager.roster:
		if g.is_active: active_count += 1
		
	if active_count > 0:
		print("Dövüş ekranına geçiliyor...")
	else:
		print("Savaşacak gladyatör yok!")

# D - Event System (Eksik olan fonksiyon buradaydı)
func trigger_random_event():
	# Dosya yoksa çökmesin diye güvenlik kontrolü ekledim
	if not FileAccess.file_exists("res://events.json"):
		print("UYARI: events.json dosyası bulunamadı, event tetiklenmedi.")
		return
		
	var file = FileAccess.open("res://events.json", FileAccess.READ)
	if file:
		var events = JSON.parse_string(file.get_as_text())
		if events and events.size() > 0:
			var random_event = events[randi() % events.size()]
			print("EVENT TETİKLENDİ: ", random_event["title"])

# G - Debug Tools
func _on_debug_add_gold_pressed():
	GameManager.gold += 100
	update_ui()

func _on_debug_print_state_pressed():
	print("--- CURRENT STATE ---")
	print("Day: ", GameManager.current_day, " Gold: ", GameManager.gold)
	for g in GameManager.roster:
		print(g.g_name, " | HP: ", g.current_hp, " | Stamina: ", g.current_stamina)
