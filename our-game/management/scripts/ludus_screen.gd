extends Control

@onready var gold_label: Label = $MarginContainer/VBoxContainer/TopBar/GoldLabel
@onready var food_label: Label = $MarginContainer/VBoxContainer/TopBar/FoodLabel
@onready var day_label: Label = $MarginContainer/VBoxContainer/TopBar/DayLabel
@onready var roster_list: VBoxContainer = $MarginContainer/VBoxContainer/MainContent/RosterPanel/VBoxContainer/RosterList
@onready var stats_label: Label = $MarginContainer/VBoxContainer/MainContent/DetailsPanel/VBoxContainer/StatsLabel
@onready var actions_container: HBoxContainer = $MarginContainer/VBoxContainer/MainContent/DetailsPanel/VBoxContainer/ActionsContainer
@onready var heal_button: Button = $MarginContainer/VBoxContainer/MainContent/DetailsPanel/VBoxContainer/ActionsContainer/HealButton
@onready var market_modal: ColorRect = $MarketModal
@onready var train_modal: ColorRect = $TrainModal

var selected_gladiator: Gladiator = null
var selected_index: int = -1

func _ready() -> void:
	actions_container.hide()
	market_modal.visible = false
	train_modal.visible = false
	_update_top_bar()
	_populate_roster()

func _update_top_bar() -> void:
	gold_label.text = "Gold: %d" % GameManager.gold
	food_label.text = "Food: %d" % GameManager.food
	day_label.text = "Day: %d" % GameManager.current_day

func _populate_roster() -> void:
	# Listeyi temizle
	for child in roster_list.get_children():
		child.queue_free()
		
	# GameManager içerisindeki karakterleri listele
	for i in range(GameManager.roster.size()):
		var gladiator = GameManager.roster[i]
		var btn = Button.new()
		btn.text = "%s (Lv. %d)" % [gladiator.g_name, gladiator.level]
		btn.custom_minimum_size = Vector2(0, 40)
		
		# Butona tıklandığında hangi karakterin seçildiğini anlamak için array index'ini gönderiyoruz
		btn.pressed.connect(self._on_gladiator_selected.bind(i))
		roster_list.add_child(btn)

func _on_gladiator_selected(index: int) -> void:
	selected_index = index
	selected_gladiator = GameManager.roster[index]
	_update_stats_panel()

func _update_stats_panel() -> void:
	if not selected_gladiator:
		stats_label.text = "Select a gladiator to view stats."
		actions_container.hide()
		return
		
	actions_container.show()
	var stats_text = "[ %s ]\nType: %s | Level: %d\n\n" % [selected_gladiator.g_name, selected_gladiator.type, selected_gladiator.level]
	if selected_gladiator.days_since_last_meal > 0:
		stats_text += "Health: %d / %d (STARVING)\n" % [selected_gladiator.max_hp, selected_gladiator.current_hp]
	else:
		stats_text += "Health: %d / %d\n" % [selected_gladiator.max_hp, selected_gladiator.current_hp]
		
	stats_text += "Stamina: %d / %d\n" % [selected_gladiator.max_stamina, selected_gladiator.current_stamina]
	stats_text += "Attack Damage: %d\n" % selected_gladiator.attack_damage
	stats_text += "Dodge Chance: %.1f%%\n\n" % selected_gladiator.dodge_chance
	
	stats_text += "Current Action: %s" % selected_gladiator.current_action.capitalize()
	if selected_gladiator.current_action != "idle":
		stats_text += " (%d days left)" % selected_gladiator.action_duration_left
	
	stats_label.text = stats_text

# ================= Actions =================

func _on_feed_button_pressed() -> void:
	if selected_index != -1:
		if GameManager.feed_gladiator(selected_index):
			_update_top_bar()
			_update_stats_panel()

func _on_heal_button_pressed() -> void:
	if selected_index != -1:
		if GameManager.heal_gladiator(selected_index):
			_update_top_bar()
			_update_stats_panel()

func _on_train_button_pressed() -> void:
	if selected_index != -1:
		var glad = GameManager.roster[selected_index]
		if glad.current_action == "idle":
			train_modal.visible = true

func _on_close_train_button_pressed() -> void:
	train_modal.visible = false

func _on_train_health_pressed() -> void:
	if GameManager.train_gladiator(selected_index, "health"):
		_update_top_bar()
		_update_stats_panel()
		train_modal.visible = false

func _on_train_attack_pressed() -> void:
	if GameManager.train_gladiator(selected_index, "attack"):
		_update_top_bar()
		_update_stats_panel()
		train_modal.visible = false

func _on_train_dodge_pressed() -> void:
	if GameManager.train_gladiator(selected_index, "dodge"):
		_update_top_bar()
		_update_stats_panel()
		train_modal.visible = false

func _on_train_all_pressed() -> void:
	if GameManager.train_gladiator(selected_index, "all"):
		_update_top_bar()
		_update_stats_panel()
		train_modal.visible = false

func _on_next_day_button_pressed() -> void:
	GameManager.pass_day()
	# Günü geçtikten sonra gladyatörler ölmüş/silinmiş olabileceğinden seçimi sıfırla
	selected_index = -1
	selected_gladiator = null
	
	_update_top_bar()
	_populate_roster() # Listeyi baştan çiz (biri öldüyse arayüzden de kalkar)
	_update_stats_panel()

func _on_to_battle_button_pressed() -> void:
	SceneRouter.go_to_battle()

# ================= Marketplace =================

func _on_marketplace_button_pressed() -> void:
	market_modal.visible = true

func _on_close_market_button_pressed() -> void:
	market_modal.visible = false

func _on_buy_food_button_pressed() -> void:
	if GameManager.buy_food():
		_update_top_bar()

func _on_sell_food_button_pressed() -> void:
	if GameManager.sell_food():
		_update_top_bar()
