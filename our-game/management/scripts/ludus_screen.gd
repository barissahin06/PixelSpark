extends Control

@onready var gladiators_container: Control = get_node_or_null("MarginContainer/VBoxContainer/MainContent/RosterList")
@onready var details_panel: VBoxContainer = $DetailsPanel
@onready var stats_label: Label = $DetailsPanel/StatsLabel
@onready var actions_container: HBoxContainer = $DetailsPanel/ActionsContainer
@onready var upgrade_container: HBoxContainer = $DetailsPanel/UpgradeContainer
@onready var heal_button: Button = $DetailsPanel/ActionsContainer/HealButton
@onready var market_modal: ColorRect = $MarketModal
@onready var train_modal: ColorRect = $TrainModal
@onready var next_day_button: Button = $MarginContainer/VBoxContainer/BottomActions/NextDayButton
@onready var to_battle_button: Button = $MarginContainer/VBoxContainer/BottomActions/ToBattleButton

@onready var feed_modal: ColorRect = $ActionModals/FeedModal
@onready var feed_list: VBoxContainer = $ActionModals/FeedModal/Panel/MarginContainer/VBox/ScrollContainer/FeedList
@onready var train_list_modal: ColorRect = $ActionModals/TrainListModal
@onready var train_list: VBoxContainer = $ActionModals/TrainListModal/Panel/MarginContainer/VBox/ScrollContainer/TrainList

# Load Image
@onready var murmillo_tex = load("res://assets/ui/murmillo_base.png")

var selected_gladiator: Gladiator = null
var selected_index: int = -1

func _ready() -> void:
	details_panel.visible = false
	actions_container.hide()
	upgrade_container.hide()
	market_modal.visible = false
	train_modal.visible = false
	feed_modal.visible = false
	train_list_modal.visible = false
	_update_top_bar()
	_populate_roster()

# Helper for resolving missing nodes smoothly during transitions
@onready var gold_label: Label = $MarginContainer/VBoxContainer/TopBar/GoldLabel
@onready var food_label: Label = $MarginContainer/VBoxContainer/TopBar/FoodLabel
@onready var day_label: Label = $MarginContainer/VBoxContainer/TopBar/DayLabel

func _update_top_bar() -> void:
	gold_label.text = "Gold: %d" % GameManager.gold
	food_label.text = "Food: %d" % GameManager.food
	day_label.text = "Day: %d" % GameManager.current_day
	_update_battle_button()

func _update_battle_button() -> void:
	if GameManager.days_to_next_battle > 0:
		to_battle_button.disabled = true
		to_battle_button.text = "Battle in %d Days" % GameManager.days_to_next_battle
		next_day_button.disabled = false
	else:
		to_battle_button.disabled = false
		to_battle_button.text = "Go To Battle"
		next_day_button.disabled = true

func _populate_roster() -> void:
	# Listeyi temizle
	if gladiators_container:
		for child in gladiators_container.get_children():
			child.queue_free()
		
		# GameManager içerisindeki karakterleri sahneye ekle
		for i in range(GameManager.roster.size()):
			var gladiator = GameManager.roster[i]
			var vbox = VBoxContainer.new()
			vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			
			var btn = TextureButton.new()
			btn.texture_normal = murmillo_tex
			btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
			btn.custom_minimum_size = Vector2(80, 80)
			btn.pressed.connect(self._on_gladiator_selected.bind(i, btn))
			
			var lbl = Label.new()
			lbl.text = "%s (Lv. %d)" % [gladiator.g_name, gladiator.level]
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 14)
			
			vbox.add_child(btn)
			vbox.add_child(lbl)
			gladiators_container.add_child(vbox)

func _on_gladiator_selected(index: int, btn_node: TextureButton = null) -> void:
	selected_index = index
	selected_gladiator = GameManager.roster[index]
	_update_stats_panel()
	details_panel.visible = true
	if btn_node:
		# Position panel centered above the character
		details_panel.global_position = btn_node.global_position + Vector2(btn_node.size.x / 2.0 - details_panel.size.x / 2.0, -220)

func _update_stats_panel() -> void:
	if not selected_gladiator:
		stats_label.text = "Select a gladiator to view stats."
		actions_container.hide()
		upgrade_container.hide()
		details_panel.visible = false
		return
		
	if selected_gladiator.type == "Slave":
		actions_container.hide()
		upgrade_container.show()
	else:
		actions_container.show()
		upgrade_container.hide()
		
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

func _on_close_details_pressed() -> void:
	details_panel.visible = false
	selected_index = -1
	selected_gladiator = null

# ================= Actions =================

func _on_marketplace_menu_pressed() -> void:
	market_modal.visible = true

func _on_feed_menu_pressed() -> void:
	# Populate Feed List
	for child in feed_list.get_children():
		child.queue_free()
	
	for i in range(GameManager.roster.size()):
		var glad = GameManager.roster[i]
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "%s - HP: %d/%d" % [glad.g_name, glad.current_hp, glad.max_hp]
		if glad.days_since_last_meal > 0: lbl.text += " (STARVING!)"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var btn = Button.new()
		btn.text = "Feed (-6 Food)"
		btn.pressed.connect(func():
			if GameManager.feed_gladiator(i):
				_update_top_bar()
				_update_stats_panel()
				_on_feed_menu_pressed() # Refresh list
		)
		hbox.add_child(lbl)
		hbox.add_child(btn)
		feed_list.add_child(hbox)
		
	feed_modal.visible = true

func _on_close_feed_pressed():
	feed_modal.visible = false

func _on_train_menu_pressed() -> void:
	# Populate Train Selection List
	for child in train_list.get_children():
		child.queue_free()
	
	for i in range(GameManager.roster.size()):
		var glad = GameManager.roster[i]
		var hbox = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = "%s - Action: %s" % [glad.g_name, glad.current_action]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var btn = Button.new()
		btn.text = "Select for Training"
		if glad.current_action != "idle":
			btn.disabled = true
			
		btn.pressed.connect(func():
			selected_index = i
			train_list_modal.visible = false
			train_modal.visible = true
		)
		hbox.add_child(lbl)
		hbox.add_child(btn)
		train_list.add_child(hbox)
		
	train_list_modal.visible = true

func _on_close_train_list_pressed():
	train_list_modal.visible = false

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
	details_panel.visible = false
	
	_update_top_bar()
	_populate_roster() # Listeyi baştan çiz (biri öldüyse arayüzden de kalkar)
	_update_stats_panel()

func _on_to_battle_button_pressed() -> void:
	GameManager.reset_battle_timer()
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

func _on_buy_slave_button_pressed() -> void:
	if GameManager.buy_slave():
		_update_top_bar()
		_populate_roster()

# ================= Upgrades =================

func _on_upgrade_tank_pressed() -> void:
	if selected_index != -1:
		if GameManager.upgrade_slave(selected_index, "tank_base"):
			_update_top_bar()
			_populate_roster()
			# Re-select the gladiator so the UI refreshes properly
			_on_gladiator_selected(selected_index)

func _on_upgrade_fighter_pressed() -> void:
	if selected_index != -1:
		if GameManager.upgrade_slave(selected_index, "fighter_base"):
			_update_top_bar()
			_populate_roster()
			_on_gladiator_selected(selected_index)

func _on_upgrade_assassin_pressed() -> void:
	if selected_index != -1:
		if GameManager.upgrade_slave(selected_index, "assassin_base"):
			_update_top_bar()
			_populate_roster()
			_on_gladiator_selected(selected_index)
