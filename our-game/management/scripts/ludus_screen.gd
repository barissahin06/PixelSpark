extends Control

@onready var market_modal: ColorRect = $MarketModal
@onready var train_modal: ColorRect = $TrainModal
@onready var next_day_button: Button = $MarginContainer/VBoxContainer/BottomActions/NextDayButton
@onready var to_battle_button: Button = $MarginContainer/VBoxContainer/BottomActions/ToBattleButton

@onready var feed_modal: ColorRect = $ActionModals/FeedModal
@onready var feed_list: VBoxContainer = $ActionModals/FeedModal/Panel/MarginContainer/VBox/ScrollContainer/FeedList
@onready var train_list_modal: ColorRect = $ActionModals/TrainListModal
@onready var train_list: VBoxContainer = $ActionModals/TrainListModal/Panel/MarginContainer/VBox/ScrollContainer/TrainList

# Per-type character textures (multi-directional for wandering)
var type_textures: Dictionary = {}  # type -> {"south": tex, "east": tex, ...}

const DIRECTIONS := ["south", "south-west", "west", "north-west", "north", "north-east", "east", "south-east"]
const TYPE_FOLDERS := {
	"Murmillo": "Tank_Gladiator",
	"Thraex": "Fighter_Gladiator",
	"Retiarius": "Assassin_Gladiator",
	"Slave": "Slave",
}

# Yard boundaries where gladiators can walk
const YARD_MIN := Vector2(80, 320)
const YARD_MAX := Vector2(720, 590)
const DOOR_POS := Vector2(380, 280)  # Center door for battle transition

# Wandering state per gladiator
var _wander_targets: Array = []   # target Vector2
var _wander_timers: Array = []    # pause timer
var _wander_speeds: Array = []    # walk speed
var _wander_active: bool = true   # false during battle transition
var _gladiator_btns: Array = []   # TextureButton refs for sprite swapping

# Battle transition
var _battle_transition_overlay: ColorRect
var _transitioning_to_battle: bool = false

# Ludus Management button
var ludus_mgmt_btn: Button

func _load_character_textures() -> void:
	for type_name in TYPE_FOLDERS:
		var folder = TYPE_FOLDERS[type_name]
		var base = "res://assets/art/characters/%s/rotations/" % folder
		var dir_textures := {}
		for dir_name in DIRECTIONS:
			var path = base + dir_name + ".png"
			if ResourceLoader.exists(path):
				dir_textures[dir_name] = load(path)
		if dir_textures.size() > 0:
			type_textures[type_name] = dir_textures
		else:
			push_warning("LudusScreen: No textures found for type '%s'" % type_name)

func _get_texture_for_type(type_name: String) -> Texture2D:
	if type_textures.has(type_name):
		var dirs = type_textures[type_name]
		if dirs.has("south"):
			return dirs["south"]
		return dirs.values()[0]
	var fallback_path = "res://assets/ui/murmillo_base.png"
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path)
	return null

func _get_directional_texture(type_name: String, direction: String) -> Texture2D:
	if type_textures.has(type_name):
		var dirs = type_textures[type_name]
		if dirs.has(direction):
			return dirs[direction]
		# Fallback to closest direction
		if dirs.has("south"):
			return dirs["south"]
		return dirs.values()[0]
	return _get_texture_for_type(type_name)

func _direction_from_velocity(vel: Vector2) -> String:
	if vel.length() < 0.5:
		return "south"
	var angle = vel.angle()
	# Convert angle to 8 directions
	if angle >= -PI/8 and angle < PI/8:
		return "east"
	elif angle >= PI/8 and angle < 3*PI/8:
		return "south-east"
	elif angle >= 3*PI/8 and angle < 5*PI/8:
		return "south"
	elif angle >= 5*PI/8 and angle < 7*PI/8:
		return "south-west"
	elif angle >= 7*PI/8 or angle < -7*PI/8:
		return "west"
	elif angle >= -7*PI/8 and angle < -5*PI/8:
		return "north-west"
	elif angle >= -5*PI/8 and angle < -3*PI/8:
		return "north"
	elif angle >= -3*PI/8 and angle < -PI/8:
		return "north-east"
	return "south"

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

# Slave Market Modal UI (built in code)
var slave_market_modal: ColorRect
var slave_market_list: VBoxContainer
var slave_market_refresh_label: Label

# Ludus Upgrades Modal UI (built in code)
var upgrades_modal: ColorRect
var upgrades_list: VBoxContainer
var upgrades_building_label: Label

# Pause Modal (ESC)
var pause_modal: ColorRect

# Game Over Modal
var game_over_modal: ColorRect

@onready var gladiator_yard: Control = $GladiatorYard

# Dragging state
var _dragging_index: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _gladiator_positions: Array = []
var _gladiator_nodes: Array = []

func _ready() -> void:
	_load_character_textures()
	market_modal.visible = false
	train_modal.visible = false
	feed_modal.visible = false
	train_list_modal.visible = false
	_style_door_buttons()
	_build_ludus_mgmt_button()
	_build_battle_transition_overlay()
	_update_top_bar()
	_populate_roster()
	_build_bubble()
	_build_event_modal()
	_build_slave_market_modal()
	_build_upgrades_modal()
	_build_pause_modal()
	_build_game_over_modal()
	_style_bottom_buttons()
	
	# Initialize EventManager
	event_manager = EventManager.new()
	event_manager.event_triggered.connect(_on_event_triggered)
	event_manager.event_resolved.connect(_on_event_resolved)
	
	# Check if game over on load
	_check_game_over()

func _process(delta: float) -> void:
	if not _wander_active or _transitioning_to_battle:
		return
	_tick_wandering(delta)

# ================= Door Button Styling =================

func _style_door_buttons() -> void:
	## Apply Roman theme to all door action buttons
	var door_actions = get_node_or_null("DoorActions")
	if not door_actions:
		return
	
	for child in door_actions.get_children():
		if child is Button:
			child.flat = false
			RomanTheme.style_button(child, Color(0.14, 0.11, 0.08, 0.85))
			child.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM)
			child.add_theme_color_override("font_hover_color", RomanTheme.ROMAN_GOLD_BRIGHT)
	
	# Hide the Upgrades button (replaced by Ludus Management)
	var upgrades_btn = door_actions.get_node_or_null("UpgradesMenuButton")
	if upgrades_btn:
		upgrades_btn.visible = false

func _build_ludus_mgmt_button() -> void:
	## Ludus Management button pinned to top-left corner
	ludus_mgmt_btn = RomanTheme.create_roman_button("🏛 Ludus", "", Vector2(110, 40))
	ludus_mgmt_btn.position = Vector2(0, 0)
	ludus_mgmt_btn.add_theme_font_size_override("font_size", 13)
	ludus_mgmt_btn.pressed.connect(_on_upgrades_menu_pressed)
	add_child(ludus_mgmt_btn)

func _style_bottom_buttons() -> void:
	## Style Next Day and Go To Battle buttons with Roman theme
	if next_day_button:
		RomanTheme.style_button(next_day_button, RomanTheme.ARENA_SAND_DARK)
		next_day_button.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM)
	if to_battle_button:
		RomanTheme.style_button(to_battle_button, RomanTheme.BLOOD_RED)
		to_battle_button.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM)

func _build_battle_transition_overlay() -> void:
	_battle_transition_overlay = ColorRect.new()
	_battle_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_battle_transition_overlay.color = Color(0, 0, 0, 0)
	_battle_transition_overlay.visible = false
	_battle_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_battle_transition_overlay)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if pause_modal and not pause_modal.visible:
			pause_modal.visible = true
		else:
			pause_modal.visible = false

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
	for child in gladiator_yard.get_children():
		child.queue_free()
	_gladiator_nodes.clear()
	_gladiator_btns.clear()
	_wander_targets.clear()
	_wander_timers.clear()
	_wander_speeds.clear()
	
	# Reset positions if roster changed
	while _gladiator_positions.size() < GameManager.roster.size():
		var idx = _gladiator_positions.size()
		var x = randf_range(YARD_MIN.x + 40, YARD_MAX.x - 40)
		var y = randf_range(YARD_MIN.y + 20, YARD_MAX.y - 20)
		_gladiator_positions.append(Vector2(x, y))
	
	for i in range(GameManager.roster.size()):
		var gladiator = GameManager.roster[i]
		
		var container = Control.new()
		container.position = _gladiator_positions[i]
		container.size = Vector2(80, 100)
		
		var btn = TextureButton.new()
		btn.texture_normal = _get_texture_for_type(gladiator.type)
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.custom_minimum_size = Vector2(64, 64)
		btn.size = Vector2(64, 64)
		btn.position = Vector2(8, 0)
		btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		
		var idx = i
		btn.pressed.connect(func(): _on_gladiator_selected(idx, btn))
		btn.gui_input.connect(func(event): _on_gladiator_gui_input(event, idx, container))
		
		var lbl = Label.new()
		lbl.text = "%s (Lv. %d)" % [gladiator.g_name, gladiator.level]
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM)
		lbl.position = Vector2(-20, 66)
		lbl.size = Vector2(120, 20)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		container.add_child(btn)
		container.add_child(lbl)
		gladiator_yard.add_child(container)
		_gladiator_nodes.append(container)
		_gladiator_btns.append(btn)
		
		# Initialize wandering state
		_wander_targets.append(_random_yard_pos())
		_wander_timers.append(randf_range(0.5, 3.0))  # Initial pause
		_wander_speeds.append(randf_range(25.0, 50.0))

func _random_yard_pos() -> Vector2:
	return Vector2(
		randf_range(YARD_MIN.x + 20, YARD_MAX.x - 20),
		randf_range(YARD_MIN.y + 10, YARD_MAX.y - 10)
	)

func _tick_wandering(delta: float) -> void:
	for i in range(_gladiator_nodes.size()):
		if i >= GameManager.roster.size():
			break
		if _dragging_index == i:
			continue  # Don't wander while being dragged
		
		var container = _gladiator_nodes[i]
		var target = _wander_targets[i]
		var timer = _wander_timers[i]
		
		if timer > 0:
			# Pausing — idle stance
			_wander_timers[i] -= delta
			continue
		
		# Walk toward target
		var current_pos = container.position
		var direction = (target - current_pos)
		var distance = direction.length()
		
		if distance < 5.0:
			# Reached target — pick new one and pause
			_wander_targets[i] = _random_yard_pos()
			_wander_timers[i] = randf_range(1.5, 5.0)
			# Face south when idle
			_update_gladiator_direction(i, "south")
			continue
		
		var velocity = direction.normalized() * _wander_speeds[i]
		var new_pos = current_pos + velocity * delta
		
		# Enforce strict boundaries
		new_pos.x = clampf(new_pos.x, YARD_MIN.x, YARD_MAX.x)
		new_pos.y = clampf(new_pos.y, YARD_MIN.y, YARD_MAX.y)
		container.position = new_pos
		_gladiator_positions[i] = new_pos
		
		# Update directional sprite
		var dir_name = _direction_from_velocity(velocity)
		_update_gladiator_direction(i, dir_name)

func _update_gladiator_direction(index: int, direction: String) -> void:
	if index >= _gladiator_btns.size() or index >= GameManager.roster.size():
		return
	var gladiator = GameManager.roster[index]
	var tex = _get_directional_texture(gladiator.type, direction)
	if tex and _gladiator_btns[index]:
		_gladiator_btns[index].texture_normal = tex

func _on_gladiator_gui_input(event: InputEvent, index: int, container: Control) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_dragging_index = index
				_drag_offset = container.position - event.global_position
			else:
				if _dragging_index == index:
					if index < _gladiator_positions.size():
						_gladiator_positions[index] = container.position
					_dragging_index = -1
	
	if event is InputEventMouseMotion and _dragging_index == index:
		var new_pos = event.global_position + _drag_offset
		new_pos.x = clampf(new_pos.x, 60, 720)
		new_pos.y = clampf(new_pos.y, 300, 620)
		container.position = new_pos
		if index < _gladiator_positions.size():
			_gladiator_positions[index] = new_pos

func _on_gladiator_selected(index: int, btn_node: TextureButton = null) -> void:
	if selected_index == index and bubble_overlay.visible:
		_close_bubble()
		return
	selected_index = index
	selected_gladiator = GameManager.roster[index]
	_last_btn_node = btn_node
	_update_bubble()
	_show_bubble(btn_node)

func _build_bubble() -> void:
	bubble_overlay = ColorRect.new()
	bubble_overlay.color = Color(0, 0, 0, 0.35)
	bubble_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	bubble_overlay.visible = false
	bubble_overlay.gui_input.connect(_on_bubble_overlay_input)
	add_child(bubble_overlay)
	
	bubble_pointer = ColorRect.new()
	bubble_pointer.color = Color(0.12, 0.12, 0.15, 0.95)
	bubble_pointer.custom_minimum_size = Vector2(16, 16)
	bubble_pointer.size = Vector2(16, 16)
	bubble_pointer.rotation = deg_to_rad(45)
	bubble_pointer.pivot_offset = Vector2(8, 8)
	bubble_overlay.add_child(bubble_pointer)
	
	bubble_panel = PanelContainer.new()
	bubble_panel.custom_minimum_size = Vector2(240, 0)
	bubble_panel.size = Vector2(240, 0)
	
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
	
	bubble_stats_label = Label.new()
	bubble_stats_label.add_theme_font_size_override("font_size", 13)
	bubble_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bubble_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(bubble_stats_label)
	
	bubble_actions_box = HBoxContainer.new()
	bubble_actions_box.alignment = BoxContainer.ALIGNMENT_CENTER
	bubble_actions_box.add_theme_constant_override("separation", 8)
	vbox.add_child(bubble_actions_box)
	
	var heal_btn = Button.new()
	heal_btn.text = "Heal (-%dG)" % GameManager.get_heal_cost()
	heal_btn.add_theme_font_size_override("font_size", 12)
	heal_btn.pressed.connect(_on_heal_button_pressed)
	bubble_actions_box.add_child(heal_btn)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.add_theme_font_size_override("font_size", 12)
	close_btn.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	close_btn.pressed.connect(_close_bubble)
	bubble_actions_box.add_child(close_btn)
	
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
		bubble_panel.position = Vector2(270, 200)
		bubble_pointer.visible = false
		return
	
	var char_center_x = btn_node.global_position.x + btn_node.size.x / 2.0
	var char_top_y = btn_node.global_position.y
	
	await get_tree().process_frame
	
	var panel_w = bubble_panel.size.x
	var panel_h = bubble_panel.size.y
	
	var bx = char_center_x - panel_w / 2.0
	var by = char_top_y - panel_h - 24
	
	var viewport_size = get_viewport_rect().size
	bx = clampf(bx, 8, viewport_size.x - panel_w - 8)
	by = clampf(by, 8, viewport_size.y - panel_h - 8)
	
	bubble_panel.position = Vector2(bx, by)
	
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
	
	# Hunger bar
	var hunger_pct = float(g.hunger) / 100.0
	var h_filled = int(hunger_pct * bar_len)
	var hunger_bar = "█".repeat(h_filled) + "░".repeat(bar_len - h_filled)
	text += "🍖 Hunger: [%s] %d/100\n" % [hunger_bar, g.hunger]
	if g.hunger == 0:
		text += "⚠ STARVING! (-30% HP/day)\n"
	
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
	
	# Update heal button cost
	var heal_btn = bubble_actions_box.get_child(0) as Button
	if heal_btn:
		heal_btn.text = "Heal (-%dG)" % GameManager.get_heal_cost()
	
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
	for child in feed_list.get_children():
		child.queue_free()
	
	for i in range(GameManager.roster.size()):
		var glad = GameManager.roster[i]
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		
		var icon = TextureRect.new()
		icon.texture = _get_texture_for_type(glad.type)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(40, 40)
		hbox.add_child(icon)
		
		var lbl = Label.new()
		lbl.text = "%s - HP: %d/%d | 🍖 %d/100" % [glad.g_name, glad.current_hp, glad.max_hp, glad.hunger]
		if glad.hunger == 0: lbl.text += " ⚠ STARVING!"
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		var btn = Button.new()
		btn.text = "Feed (-5 Food)"
		if glad.hunger >= 100:
			btn.disabled = true
			btn.text = "Full"
		btn.pressed.connect(func():
			if GameManager.feed_gladiator(i):
				_update_top_bar()
				_update_stats_panel()
				_on_feed_menu_pressed()
		)
		hbox.add_child(lbl)
		hbox.add_child(btn)
		feed_list.add_child(hbox)
		
	feed_modal.visible = true

func _on_close_feed_pressed():
	feed_modal.visible = false

func _on_train_menu_pressed() -> void:
	for child in train_list.get_children():
		child.queue_free()
	
	for i in range(GameManager.roster.size()):
		var glad = GameManager.roster[i]
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		
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
	_close_bubble()
	
	_update_top_bar()
	_populate_roster()
	_update_stats_panel()
	
	# Try to trigger a random event
	if event_manager:
		event_manager.try_trigger_event()
	
	# Check game over
	_check_game_over()

func _on_to_battle_button_pressed() -> void:
	if _transitioning_to_battle:
		return
	_transitioning_to_battle = true
	_wander_active = false
	_close_bubble()
	
	# Disable buttons during transition
	next_day_button.disabled = true
	to_battle_button.disabled = true
	
	# Walk all gladiators toward the center door
	var walk_tween = create_tween().set_parallel(true)
	for i in range(_gladiator_nodes.size()):
		var container = _gladiator_nodes[i]
		var target = DOOR_POS + Vector2(randf_range(-30, 30), randf_range(-10, 10))
		walk_tween.tween_property(container, "position", target, 1.8).set_ease(Tween.EASE_IN_OUT)
		# Face north (walking toward door)
		_update_gladiator_direction(i, "north")
		# Scale down slightly as they "walk away"
		walk_tween.tween_property(container, "scale", Vector2(0.7, 0.7), 1.8)
	
	walk_tween.finished.connect(func():
		# Fade to black
		_battle_transition_overlay.visible = true
		_battle_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
		var fade_tween = create_tween()
		fade_tween.tween_property(_battle_transition_overlay, "color:a", 1.0, 0.8)
		fade_tween.finished.connect(func():
			_transitioning_to_battle = false
			GameManager.reset_battle_timer()
			SceneRouter.go_to_battle()
		)
	)

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
	# Open slave market modal instead of direct buy
	market_modal.visible = false
	_open_slave_market()

# ================= Slave Market Modal =================

func _build_slave_market_modal() -> void:
	slave_market_modal = ColorRect.new()
	slave_market_modal.color = Color(0, 0, 0, 0.85)
	slave_market_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	slave_market_modal.visible = false
	add_child(slave_market_modal)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	slave_market_modal.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 400)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.border_color = Color(0.75, 0.6, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "🏛 Slave Market"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox.add_child(title)
	
	slave_market_refresh_label = Label.new()
	slave_market_refresh_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slave_market_refresh_label.add_theme_font_size_override("font_size", 13)
	slave_market_refresh_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(slave_market_refresh_label)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 250
	vbox.add_child(scroll)
	
	slave_market_list = VBoxContainer.new()
	slave_market_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slave_market_list.add_theme_constant_override("separation", 8)
	scroll.add_child(slave_market_list)
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size.y = 35
	close_btn.pressed.connect(func(): slave_market_modal.visible = false)
	vbox.add_child(close_btn)

func _open_slave_market() -> void:
	# Populate slave market list
	for child in slave_market_list.get_children():
		child.queue_free()
	
	var days_left = GameManager.get_days_until_market_refresh()
	slave_market_refresh_label.text = "New slaves in %d day(s)" % days_left
	
	if GameManager.slave_market.is_empty():
		var empty_lbl = Label.new()
		empty_lbl.text = "No slaves available. Check back later!"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 15)
		slave_market_list.add_child(empty_lbl)
	else:
		for i in range(GameManager.slave_market.size()):
			var data = GameManager.slave_market[i]
			var row = _create_slave_market_row(data, i)
			slave_market_list.add_child(row)
	
	slave_market_modal.visible = true

func _create_slave_market_row(data: Dictionary, index: int) -> PanelContainer:
	var row_panel = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	row_style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
	row_style.border_color = Color(0.4, 0.35, 0.15, 0.5)
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(6)
	row_style.set_content_margin_all(8)
	row_panel.add_theme_stylebox_override("panel", row_style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row_panel.add_child(hbox)
	
	# Slave icon
	var icon = TextureRect.new()
	icon.texture = _get_texture_for_type("Slave")
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(40, 40)
	hbox.add_child(icon)
	
	# Info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = "%s" % data["name"]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	info_vbox.add_child(name_lbl)
	
	var stats_lbl = Label.new()
	stats_lbl.text = "HP: %d | ATK: %d | DOD: %.1f%%" % [data["hp"], data["atk"], data["dodge"]]
	stats_lbl.add_theme_font_size_override("font_size", 12)
	info_vbox.add_child(stats_lbl)
	
	var trait_name = TraitSystem.get_trait_name(data["trait"])
	var trait_lbl = Label.new()
	trait_lbl.text = "✦ %s" % trait_name
	trait_lbl.add_theme_font_size_override("font_size", 11)
	trait_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	info_vbox.add_child(trait_lbl)
	
	# Price + Buy button
	var buy_vbox = VBoxContainer.new()
	buy_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(buy_vbox)
	
	var price_lbl = Label.new()
	price_lbl.text = "%d Gold" % data["price"]
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 14)
	price_lbl.add_theme_color_override("font_color", Color(1, 0.84, 0))
	buy_vbox.add_child(price_lbl)
	
	var buy_btn = Button.new()
	buy_btn.text = "Buy"
	buy_btn.custom_minimum_size = Vector2(70, 30)
	buy_btn.add_theme_font_size_override("font_size", 13)
	if GameManager.gold < data["price"] or GameManager.roster.size() >= GameManager.get_effective_roster_max():
		buy_btn.disabled = true
	buy_btn.pressed.connect(func():
		if GameManager.buy_market_slave(index):
			_update_top_bar()
			_populate_roster()
			_open_slave_market()  # Refresh the modal
	)
	buy_vbox.add_child(buy_btn)
	
	return row_panel

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

# ================= Ludus Upgrades Modal =================

func _build_upgrades_modal() -> void:
	upgrades_modal = ColorRect.new()
	upgrades_modal.color = Color(0, 0, 0, 0.85)
	upgrades_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrades_modal.visible = false
	add_child(upgrades_modal)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	upgrades_modal.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 450)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.95)
	style.border_color = Color(0.6, 0.45, 0.15, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "🏛 Ludus Upgrades"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox.add_child(title)
	
	upgrades_building_label = Label.new()
	upgrades_building_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrades_building_label.add_theme_font_size_override("font_size", 13)
	upgrades_building_label.add_theme_color_override("font_color", Color(0.6, 0.8, 0.6))
	vbox.add_child(upgrades_building_label)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 300
	vbox.add_child(scroll)
	
	upgrades_list = VBoxContainer.new()
	upgrades_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upgrades_list.add_theme_constant_override("separation", 8)
	scroll.add_child(upgrades_list)
	
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size.y = 35
	close_btn.pressed.connect(func(): upgrades_modal.visible = false)
	vbox.add_child(close_btn)

func _on_upgrades_menu_pressed() -> void:
	_open_upgrades_modal()

func _open_upgrades_modal() -> void:
	for child in upgrades_list.get_children():
		child.queue_free()
	
	var lu = GameManager.ludus_upgrades
	if lu.is_anything_building():
		upgrades_building_label.text = "🔨 Building: %s (%d days left)" % [
			LudusUpgrades.UPGRADE_DEFS[lu.building_upgrade]["name"],
			lu.build_days_left
		]
	else:
		upgrades_building_label.text = ""
	
	var all_upgrades = lu.get_all_upgrades()
	for data in all_upgrades:
		var row = _create_upgrade_row(data)
		upgrades_list.add_child(row)
	
	upgrades_modal.visible = true

func _create_upgrade_row(data: Dictionary) -> PanelContainer:
	var row_panel = PanelContainer.new()
	var row_style = StyleBoxFlat.new()
	
	if data["status"] == "built":
		row_style.bg_color = Color(0.1, 0.18, 0.1, 0.9)
		row_style.border_color = Color(0.3, 0.6, 0.3, 0.5)
	elif data["status"] == "building":
		row_style.bg_color = Color(0.18, 0.16, 0.1, 0.9)
		row_style.border_color = Color(0.6, 0.5, 0.2, 0.5)
	else:
		row_style.bg_color = Color(0.15, 0.15, 0.18, 0.9)
		row_style.border_color = Color(0.4, 0.35, 0.15, 0.5)
	
	row_style.set_border_width_all(1)
	row_style.set_corner_radius_all(6)
	row_style.set_content_margin_all(8)
	row_panel.add_theme_stylebox_override("panel", row_style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	row_panel.add_child(hbox)
	
	# Icon
	var icon_lbl = Label.new()
	icon_lbl.text = data["icon"]
	icon_lbl.add_theme_font_size_override("font_size", 24)
	icon_lbl.custom_minimum_size.x = 36
	hbox.add_child(icon_lbl)
	
	# Info
	var info_vbox = VBoxContainer.new()
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)
	
	var name_lbl = Label.new()
	name_lbl.text = data["name"]
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	info_vbox.add_child(name_lbl)
	
	var desc_lbl = Label.new()
	desc_lbl.text = data["description"]
	desc_lbl.add_theme_font_size_override("font_size", 11)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_vbox.add_child(desc_lbl)
	
	if data["requires"] != "":
		var req_name = LudusUpgrades.UPGRADE_DEFS.get(data["requires"], {}).get("name", data["requires"])
		var req_lbl = Label.new()
		req_lbl.text = "Requires: %s" % req_name
		req_lbl.add_theme_font_size_override("font_size", 10)
		req_lbl.add_theme_color_override("font_color", Color(0.8, 0.6, 0.4))
		info_vbox.add_child(req_lbl)
	
	# Status / Build button
	var action_vbox = VBoxContainer.new()
	action_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(action_vbox)
	
	if data["status"] == "built":
		var built_lbl = Label.new()
		built_lbl.text = "✓ Built"
		built_lbl.add_theme_font_size_override("font_size", 14)
		built_lbl.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
		built_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		action_vbox.add_child(built_lbl)
	elif data["status"] == "building":
		var bld_lbl = Label.new()
		bld_lbl.text = "🔨 %d days" % data["days_left"]
		bld_lbl.add_theme_font_size_override("font_size", 14)
		bld_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
		bld_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		action_vbox.add_child(bld_lbl)
	else:
		var cost_lbl = Label.new()
		cost_lbl.text = "%d Gold | %dd" % [data["cost"], data["build_days"]]
		cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_lbl.add_theme_font_size_override("font_size", 12)
		cost_lbl.add_theme_color_override("font_color", Color(1, 0.84, 0))
		action_vbox.add_child(cost_lbl)
		
		var lu = GameManager.ludus_upgrades
		var build_btn = Button.new()
		build_btn.text = "Build"
		build_btn.custom_minimum_size = Vector2(70, 28)
		build_btn.add_theme_font_size_override("font_size", 13)
		if not lu.can_build(data["id"], GameManager.gold):
			build_btn.disabled = true
		var upgrade_id = data["id"]
		build_btn.pressed.connect(func():
			_on_build_upgrade(upgrade_id)
		)
		action_vbox.add_child(build_btn)
	
	return row_panel

func _on_build_upgrade(upgrade_id: String) -> void:
	var lu = GameManager.ludus_upgrades
	if lu.can_build(upgrade_id, GameManager.gold):
		var cost = lu.start_build(upgrade_id)
		if cost > 0:
			GameManager.gold -= cost
			_update_top_bar()
			_open_upgrades_modal()  # Refresh

# ================= Event System =================

func _build_event_modal() -> void:
	event_modal = ColorRect.new()
	event_modal.color = Color(0, 0, 0, 0.7)
	event_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	event_modal.visible = false
	add_child(event_modal)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	event_modal.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 300)
	
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

# ================= Pause Modal (ESC) =================

func _build_pause_modal() -> void:
	pause_modal = ColorRect.new()
	pause_modal.color = RomanTheme.BG_MODAL
	pause_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_modal.visible = false
	add_child(pause_modal)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	pause_modal.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(350, 320)
	panel.add_theme_stylebox_override("panel", RomanTheme.create_panel_style())
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 14)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "⏸ Game Paused"
	RomanTheme.style_title(title, 24)
	vbox.add_child(title)
	
	var resume_btn = _create_pause_button("Resume", RomanTheme.VICTORY_GREEN)
	resume_btn.pressed.connect(func(): pause_modal.visible = false)
	vbox.add_child(resume_btn)
	
	var save_btn = _create_pause_button("Save Game", RomanTheme.WARM_BRONZE)
	save_btn.pressed.connect(func():
		if SaveManager.save_game():
			save_btn.text = "✓ Saved!"
			await get_tree().create_timer(1.0).timeout
			save_btn.text = "Save Game"
	)
	vbox.add_child(save_btn)
	
	var load_btn = _create_pause_button("Load Game", Color(0.35, 0.3, 0.45))
	if not SaveManager.has_save():
		load_btn.disabled = true
	load_btn.pressed.connect(func():
		if SaveManager.load_game():
			pause_modal.visible = false
			_update_top_bar()
			_populate_roster()
			_close_bubble()
	)
	vbox.add_child(load_btn)
	
	var quit_btn = _create_pause_button("Quit to Menu", RomanTheme.BLOOD_RED)
	quit_btn.pressed.connect(func():
		SceneRouter.go_to_main_menu()
	)
	vbox.add_child(quit_btn)

func _create_pause_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(220, 45)
	RomanTheme.style_button(btn, color)
	return btn

# ================= Game Over =================

func _build_game_over_modal() -> void:
	game_over_modal = ColorRect.new()
	game_over_modal.color = Color(0.05, 0.02, 0.02, 0.95)
	game_over_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_modal.visible = false
	add_child(game_over_modal)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_over_modal.add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	
	var title = Label.new()
	title.text = "☠ YOUR LUDUS HAS FALLEN ☠"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", RomanTheme.BLOOD_RED_BRIGHT)
	vbox.add_child(title)
	
	var flavor = Label.new()
	flavor.text = "The sands of the arena have claimed your legacy.\nYour gladiators have fallen, your coffers are empty.\nAs the crowds cheer for other masters,\nyour name fades from the annals of Rome.\n\n'Sic transit gloria mundi'\n— So passes the glory of the world."
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.add_theme_font_size_override("font_size", 15)
	flavor.add_theme_color_override("font_color", RomanTheme.TEXT_DIM)
	flavor.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	flavor.custom_minimum_size.x = 450
	vbox.add_child(flavor)
	
	var stats_label = Label.new()
	stats_label.name = "StatsLabel"
	stats_label.text = "You survived %d days." % GameManager.current_day
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_label.add_theme_font_size_override("font_size", 16)
	stats_label.add_theme_color_override("font_color", RomanTheme.ROMAN_GOLD_BRIGHT)
	vbox.add_child(stats_label)
	
	var menu_btn = _create_pause_button("Return to Main Menu", RomanTheme.BLOOD_RED)
	menu_btn.pressed.connect(func(): SceneRouter.go_to_main_menu())
	vbox.add_child(menu_btn)

func _check_game_over() -> void:
	## Check if the player has lost: no gladiators AND not enough gold to buy cheapest slave
	if GameManager.roster.is_empty():
		var cheapest = 999
		for slave in GameManager.slave_market:
			if slave is Dictionary and int(slave.get("price", 999)) < cheapest:
				cheapest = int(slave["price"])
		
		if GameManager.gold < cheapest:
			# Update stats label
			var stats_lbl = game_over_modal.find_child("StatsLabel", true, false)
			if stats_lbl:
				stats_lbl.text = "You survived %d days." % GameManager.current_day
			game_over_modal.visible = true
