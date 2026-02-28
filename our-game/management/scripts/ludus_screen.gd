extends Control

@onready var market_modal: ColorRect = $MarketModal
@onready var train_modal: ColorRect = $TrainModal
@onready var next_day_button: Button = $MarginContainer/VBoxContainer/BottomActions/NextDayButton
@onready var to_battle_button: Button = $MarginContainer/VBoxContainer/BottomActions/ToBattleButton

@onready var feed_modal: ColorRect = $ActionModals/FeedModal
@onready var feed_list: VBoxContainer = $ActionModals/FeedModal/Panel/MarginContainer/VBox/ScrollContainer/FeedList
@onready var train_list_modal: ColorRect = $ActionModals/TrainListModal
@onready var train_list: VBoxContainer = $ActionModals/TrainListModal/Panel/MarginContainer/VBox/ScrollContainer/TrainList

# Per-type character textures (south-facing static sprites)
var type_textures: Dictionary = {}

func _load_character_textures() -> void:
	var type_map := {
		"Murmillo": "res://assets/art/characters/Tank_Gladiator/rotations/south.png",
		"Thraex": "res://assets/art/characters/Fighter_Gladiator/rotations/south.png",
		"Retiarius": "res://assets/art/characters/Assassin_Gladiator/rotations/south.png",
		"Slave": "res://assets/art/characters/Slave/rotations/south.png",
	}
	for type_name in type_map:
		var path = type_map[type_name]
		if ResourceLoader.exists(path):
			type_textures[type_name] = load(path)
		else:
			push_warning("LudusScreen: Missing sprite for type '%s' at %s" % [type_name, path])

func _get_texture_for_type(type_name: String) -> Texture2D:
	if type_textures.has(type_name):
		return type_textures[type_name]
	# Fallback to first available or murmillo
	var fallback = load("res://assets/ui/murmillo_base.png")
	return fallback

var selected_gladiator: Gladiator = null
var selected_index: int = -1
var event_manager: EventManager = null

# Speech Bubble UI (built dynamically in code)
var bubble_overlay: ColorRect
var bubble_panel: PanelContainer
var bubble_pointer: ColorRect
var bubble_stats_label: Label
var bubble_actions_box: HBoxContainer
var bubble_upgrade_box: HBoxContainer
var _last_btn_node: TextureButton = null

# Event Modal UI (built in code)
var event_modal: ColorRect
var event_title_label: Label
var event_desc_label: Label
var event_choice1_btn: Button
var event_choice2_btn: Button
var event_result_label: Label
var event_close_btn: Button

@onready var gladiator_yard: Control = $GladiatorYard

# Dragging state
var _dragging_index: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _gladiator_positions: Array = []  # Stored yard positions per gladiator
var _gladiator_nodes: Array = []  # References to yard node containers

func _ready() -> void:
	_load_character_textures()
	market_modal.visible = false
	train_modal.visible = false
	feed_modal.visible = false
	train_list_modal.visible = false
	_update_top_bar()
	_populate_roster()
	_build_bubble()
	_build_event_modal()
	
	# Initialize EventManager
	event_manager = EventManager.new()
	event_manager.event_triggered.connect(_on_event_triggered)
	event_manager.event_resolved.connect(_on_event_resolved)

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
	# Clear yard
	for child in gladiator_yard.get_children():
		child.queue_free()
	_gladiator_nodes.clear()
	
	# Ensure we have enough stored positions
	while _gladiator_positions.size() < GameManager.roster.size():
		# Default positions: spread across the yard horizontally
		var idx = _gladiator_positions.size()
		var x = 200.0 + idx * 120.0
		var y = 400.0
		_gladiator_positions.append(Vector2(x, y))
	
	for i in range(GameManager.roster.size()):
		var gladiator = GameManager.roster[i]
		
		# Container for sprite + label (freely positioned)
		var container = Control.new()
		container.position = _gladiator_positions[i]
		container.size = Vector2(80, 100)
		
		# Character sprite button
		var btn = TextureButton.new()
		btn.texture_normal = _get_texture_for_type(gladiator.type)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(64, 64)
		btn.size = Vector2(64, 64)
		btn.position = Vector2(8, 0)
		
		# Connect button for selection (single click)
		var idx = i
		btn.pressed.connect(func(): _on_gladiator_selected(idx, btn))
		
		# Connect for dragging (gui_input)
		btn.gui_input.connect(func(event): _on_gladiator_gui_input(event, idx, container))
		
		# Name label
		var lbl = Label.new()
		lbl.text = "%s (Lv. %d)" % [gladiator.g_name, gladiator.level]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.position = Vector2(-20, 66)
		lbl.size = Vector2(120, 20)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		container.add_child(btn)
		container.add_child(lbl)
		gladiator_yard.add_child(container)
		_gladiator_nodes.append(container)

func _on_gladiator_gui_input(event: InputEvent, index: int, container: Control) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging_index = index
				_drag_offset = container.position - event.global_position
			else:
				if _dragging_index == index:
					# Save position when released
					if index < _gladiator_positions.size():
						_gladiator_positions[index] = container.position
					_dragging_index = -1
	
	if event is InputEventMouseMotion and _dragging_index == index:
		# Move the container with the mouse
		var new_pos = event.global_position + _drag_offset
		# Clamp to yard area (below doors, above bottom buttons)
		new_pos.x = clampf(new_pos.x, 60, 720)
		new_pos.y = clampf(new_pos.y, 300, 620)
		container.position = new_pos
		if index < _gladiator_positions.size():
			_gladiator_positions[index] = new_pos

func _on_gladiator_selected(index: int, btn_node: TextureButton = null) -> void:
	if selected_index == index and bubble_overlay.visible:
		# Toggle off if clicking same gladiator
		_close_bubble()
		return
	selected_index = index
	selected_gladiator = GameManager.roster[index]
	_last_btn_node = btn_node
	_update_bubble()
	_show_bubble(btn_node)

func _build_bubble() -> void:
	# Dark click-away overlay
	bubble_overlay = ColorRect.new()
	bubble_overlay.color = Color(0, 0, 0, 0.35)
	bubble_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble_overlay.visible = false
	bubble_overlay.gui_input.connect(_on_bubble_overlay_input)
	add_child(bubble_overlay)
	
	# Pointer triangle (small diamond below the bubble pointing at character)
	bubble_pointer = ColorRect.new()
	bubble_pointer.color = Color(0.12, 0.12, 0.15, 0.95)
	bubble_pointer.custom_minimum_size = Vector2(16, 16)
	bubble_pointer.size = Vector2(16, 16)
	bubble_pointer.rotation = deg_to_rad(45)
	bubble_pointer.pivot_offset = Vector2(8, 8)
	bubble_overlay.add_child(bubble_pointer)
	
	# Main bubble panel
	bubble_panel = PanelContainer.new()
	bubble_panel.custom_minimum_size = Vector2(240, 0)
	bubble_panel.size = Vector2(240, 0)
	
	# Apply a dark stylebox
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.border_color = Color(0.75, 0.6, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	bubble_panel.add_theme_stylebox_override("panel", style)
	bubble_overlay.add_child(bubble_panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	bubble_panel.add_child(vbox)
	
	# Stats label
	bubble_stats_label = Label.new()
	bubble_stats_label.add_theme_font_size_override("font_size", 13)
	bubble_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(bubble_stats_label)
	
	# Action buttons row (for non-slaves)
	bubble_actions_box = HBoxContainer.new()
	bubble_actions_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bubble_actions_box.add_theme_constant_override("separation", 8)
	vbox.add_child(bubble_actions_box)
	
	var heal_btn = Button.new()
	heal_btn.text = "Heal (-5G)"
	heal_btn.add_theme_font_size_override("font_size", 12)
	heal_btn.pressed.connect(_on_heal_button_pressed)
	bubble_actions_box.add_child(heal_btn)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	close_btn.pressed.connect(_close_bubble)
	bubble_actions_box.add_child(close_btn)
	
	# Upgrade buttons row (for slaves)
	bubble_upgrade_box = HBoxContainer.new()
	bubble_upgrade_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bubble_upgrade_box.add_theme_constant_override("separation", 6)
	vbox.add_child(bubble_upgrade_box)
	
	var up_tank = Button.new()
	up_tank.text = "→ Murmillo (-10G)"
	up_tank.add_theme_font_size_override("font_size", 11)
	up_tank.pressed.connect(_on_upgrade_tank_pressed)
	bubble_upgrade_box.add_child(up_tank)
	
	var up_fighter = Button.new()
	up_fighter.text = "→ Thraex (-10G)"
	up_fighter.add_theme_font_size_override("font_size", 11)
	up_fighter.pressed.connect(_on_upgrade_fighter_pressed)
	bubble_upgrade_box.add_child(up_fighter)
	
	var up_assassin = Button.new()
	up_assassin.text = "→ Retiarius (-10G)"
	up_assassin.add_theme_font_size_override("font_size", 11)
	up_assassin.pressed.connect(_on_upgrade_assassin_pressed)
	bubble_upgrade_box.add_child(up_assassin)

func _show_bubble(btn_node: TextureButton) -> void:
	bubble_overlay.visible = true
	
	if btn_node == null:
		# Fallback: center of screen
		bubble_panel.position = Vector2(270, 200)
		bubble_pointer.visible = false
		return
	
	# Position bubble above the character
	var char_center_x = btn_node.global_position.x + btn_node.size.x / 2.0
	var char_top_y = btn_node.global_position.y
	
	# Wait one frame for panel to size itself
	await get_tree().process_frame
	
	var panel_w = bubble_panel.size.x
	var panel_h = bubble_panel.size.y
	
	# Bubble positioned above character, centered horizontally
	var bx = char_center_x - panel_w / 2.0
	var by = char_top_y - panel_h - 24  # 24px gap for pointer
	
	# Clamp to viewport
	var viewport_size = get_viewport_rect().size
	bx = clampf(bx, 8, viewport_size.x - panel_w - 8)
	by = clampf(by, 8, viewport_size.y - panel_h - 8)
	
	bubble_panel.position = Vector2(bx, by)
	
	# Pointer triangle
	bubble_pointer.visible = true
	bubble_pointer.position = Vector2(char_center_x - 8, by + panel_h - 4)

func _update_bubble() -> void:
	if not selected_gladiator:
		return
	
	var g = selected_gladiator
	var text = "⚔ %s  [Lv.%d %s]\n" % [g.g_name, g.level, g.type]
	
	# HP bar as text
	var hp_pct = float(g.current_hp) / float(g.max_hp) if g.max_hp > 0 else 0.0
	var bar_len = 12
	var filled = int(hp_pct * bar_len)
	var hp_bar = "█".repeat(filled) + "░".repeat(bar_len - filled)
	text += "HP: [%s] %d/%d\n" % [hp_bar, g.current_hp, g.max_hp]
	
	if g.days_since_last_meal > 0:
		text += "⚠ STARVING!\n"
	
	text += "STA: %d/%d | ATK: %d | DOD: %.0f%%\n" % [g.current_stamina, g.max_stamina, g.attack_damage, g.dodge_chance]
	text += "Action: %s" % g.current_action.capitalize()
	if g.current_action != "idle":
		text += " (%dd)" % g.action_duration_left
	
	# Traits
	if g.traits.size() > 0:
		text += "\n"
		for trait_id in g.traits:
			text += "✦ %s\n" % TraitSystem.get_trait_name(trait_id)
	
	bubble_stats_label.text = text.strip_edges()
	
	# Show/hide correct button row
	if g.type == "Slave":
		bubble_actions_box.visible = false
		bubble_upgrade_box.visible = true
	else:
		bubble_actions_box.visible = true
		bubble_upgrade_box.visible = false

func _close_bubble() -> void:
	bubble_overlay.visible = false
	selected_index = -1
	selected_gladiator = null
	_last_btn_node = null

func _on_bubble_overlay_input(event: InputEvent) -> void:
	# Click outside bubble closes it
	if event is InputEventMouseButton and event.pressed:
		var local = bubble_panel.get_global_rect()
		if not local.has_point(event.global_position):
			_close_bubble()

func _update_stats_panel() -> void:
	if selected_gladiator and bubble_overlay.visible:
		_update_bubble()

func _on_close_details_pressed() -> void:
	_close_bubble()

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
		hbox.add_theme_constant_override("separation", 8)
		
		# Character icon
		var icon = TextureRect.new()
		icon.texture = _get_texture_for_type(glad.type)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(40, 40)
		hbox.add_child(icon)
		
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
		hbox.add_theme_constant_override("separation", 8)
		
		# Character icon
		var icon = TextureRect.new()
		icon.texture = _get_texture_for_type(glad.type)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(40, 40)
		hbox.add_child(icon)
		
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
	_close_bubble()
	
	_update_top_bar()
	_populate_roster()
	_update_stats_panel()
	
	# Try to trigger a random event
	if event_manager:
		event_manager.try_trigger_event()

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
			_close_bubble()

func _on_upgrade_fighter_pressed() -> void:
	if selected_index != -1:
		if GameManager.upgrade_slave(selected_index, "fighter_base"):
			_update_top_bar()
			_populate_roster()
			_close_bubble()

func _on_upgrade_assassin_pressed() -> void:
	if selected_index != -1:
		if GameManager.upgrade_slave(selected_index, "assassin_base"):
			_update_top_bar()
			_populate_roster()
			_close_bubble()

# ================= Event System =================

func _build_event_modal() -> void:
	event_modal = ColorRect.new()
	event_modal.color = Color(0, 0, 0, 0.7)
	event_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	event_modal.visible = false
	add_child(event_modal)
	
	# Use CenterContainer to properly center the panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	event_modal.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 300)
	
	# Dark styled panel with golden border
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.border_color = Color(0.75, 0.6, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)
	
	event_title_label = Label.new()
	event_title_label.add_theme_font_size_override("font_size", 24)
	event_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(event_title_label)
	
	event_desc_label = Label.new()
	event_desc_label.add_theme_font_size_override("font_size", 16)
	event_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(event_desc_label)
	
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 10
	vbox.add_child(spacer)
	
	event_choice1_btn = Button.new()
	event_choice1_btn.custom_minimum_size.y = 40
	event_choice1_btn.pressed.connect(func(): _on_event_choice_pressed("choice_1"))
	vbox.add_child(event_choice1_btn)
	
	event_choice2_btn = Button.new()
	event_choice2_btn.custom_minimum_size.y = 40
	event_choice2_btn.pressed.connect(func(): _on_event_choice_pressed("choice_2"))
	vbox.add_child(event_choice2_btn)
	
	event_result_label = Label.new()
	event_result_label.add_theme_font_size_override("font_size", 16)
	event_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_result_label.visible = false
	vbox.add_child(event_result_label)
	
	event_close_btn = Button.new()
	event_close_btn.text = "Close"
	event_close_btn.custom_minimum_size.y = 35
	event_close_btn.visible = false
	event_close_btn.pressed.connect(func(): event_modal.visible = false)
	vbox.add_child(event_close_btn)

func _on_event_triggered(event_data: Dictionary) -> void:
	event_title_label.text = "⚡ " + str(event_data.get("title", "Event"))
	event_desc_label.text = str(event_data.get("description", ""))
	
	var c1 = event_data.get("choice_1", {}) as Dictionary
	var c2 = event_data.get("choice_2", {}) as Dictionary
	event_choice1_btn.text = str(c1.get("text", "Choice 1"))
	event_choice2_btn.text = str(c2.get("text", "Choice 2"))
	
	event_choice1_btn.visible = true
	event_choice2_btn.visible = true
	event_result_label.visible = false
	event_close_btn.visible = false
	event_modal.visible = true

func _on_event_choice_pressed(choice_key: String) -> void:
	var result = event_manager.resolve_choice(choice_key)
	
	event_choice1_btn.visible = false
	event_choice2_btn.visible = false
	event_result_label.text = result
	event_result_label.visible = true
	event_close_btn.visible = true
	
	_update_top_bar()
	_populate_roster()
	_update_stats_panel()

func _on_event_resolved(result_text: String) -> void:
	print("Event resolved: ", result_text)
