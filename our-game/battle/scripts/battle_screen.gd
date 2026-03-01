extends Control

## BattleScreen - Multi-gladiator arena combat with targeting, sprite display,
## card-based turns, attack animations, and progressive difficulty.

var battle: BattleManager = null
var card_buttons: Array[Button] = []

# Arena UI
var arena_bg: TextureRect
var main_vbox: VBoxContainer
var turn_label: Label
var info_label: Label
var energy_label: Label
var hand_container: HBoxContainer
var end_turn_button: Button
var retreat_button: Button

# Result overlay
var result_overlay: ColorRect
var result_panel: PanelContainer
var result_label: Label
var return_button: Button

# Multi-gladiator sprites and panels
var player_sprites: Array[TextureRect] = []
var enemy_sprites: Array[TextureRect] = []
var player_panels: Array[Control] = []
var enemy_panels: Array[Control] = []
var player_name_labels: Array[Label] = []
var player_hp_bars: Array[ProgressBar] = []
var player_hp_labels: Array[Label] = []
var enemy_name_labels: Array[Label] = []
var enemy_hp_bars: Array[ProgressBar] = []
var enemy_hp_labels: Array[Label] = []

# Animation tracking for gladiator idle/walking
var player_anim_frames: Array[Array] = []
var enemy_anim_frames: Array[Array] = []
var player_anim_index: Array[int] = []
var enemy_anim_index: Array[int] = []
var anim_timer: float = 0.0
var anim_frame_duration: float = 0.15

# Selection highlight
var player_highlight_panels: Array[Panel] = []
var enemy_highlight_panels: Array[Panel] = []

# Picker
var picker_overlay: ColorRect
var picker_list: VBoxContainer
var picker_selected: Array[int] = [] # Indices of selected gladiators
var max_player_count: int = 1

# Textures
var type_textures_east: Dictionary = {}
var type_textures_west: Dictionary = {}
var type_textures_south: Dictionary = {}

# Base positions for sprites (will scale for multi)
var arena_center_node: Control = null
var player_base_positions: Array[Vector2] = []
var enemy_base_positions: Array[Vector2] = []

func _ready() -> void:
	_load_character_textures()
	_build_ui()
	_show_gladiator_picker()
	set_process(true)

# ======================== TEXTURE LOADING ========================

func _load_character_textures() -> void:
	var base_path := "res://assets/art/characters/"
	var type_map := {
		"Murmillo": "Tank_Gladiator",
		"Thraex": "Fighter_Gladiator",
		"Retiarius": "Assassin_Gladiator",
		"Slave": "Slave",
	}
	for type_name in type_map:
		var folder_name = type_map[type_name]
		for dir_suffix in ["east", "west", "south"]:
			var tex_path = base_path + folder_name + "/rotations/" + dir_suffix + ".png"
			if ResourceLoader.exists(tex_path):
				var tex = load(tex_path)
				match dir_suffix:
					"east": type_textures_east[type_name] = tex
					"west": type_textures_west[type_name] = tex
					"south": type_textures_south[type_name] = tex

func _get_player_texture(type_name: String) -> Texture2D:
	if type_textures_east.has(type_name):
		return type_textures_east[type_name]
	if type_textures_south.has(type_name):
		return type_textures_south[type_name]
	return null

func _get_enemy_texture(type_name: String) -> Texture2D:
	if type_textures_west.has(type_name):
		return type_textures_west[type_name]
	if type_textures_south.has(type_name):
		return type_textures_south[type_name]
	return null

func _get_picker_texture(type_name: String) -> Texture2D:
	if type_textures_south.has(type_name):
		return type_textures_south[type_name]
	return null

func _load_animation_frames(type_name: String, direction: String) -> Array:
	"""Load animation frames for breathing-idle (for Tank) or walking"""
	var frames: Array = []
	var base_path := "res://assets/art/characters/"
	var type_map := {
		"Murmillo": "Tank_Gladiator",
		"Thraex": "Fighter_Gladiator",
		"Retiarius": "Assassin_Gladiator",
	}
	var folder_name = type_map.get(type_name, "")
	if folder_name.is_empty():
		return frames
	
	# Try breathing-idle first (Tank gladiators)
	for i in range(10):
		var frame_path = base_path + folder_name + "/animations/breathing-idle/" + direction + "/frame_%03d.png" % i
		if ResourceLoader.exists(frame_path):
			frames.append(load(frame_path))
		else:
			break
	
	# If no breathing-idle, try walking
	if frames.is_empty():
		for i in range(10):
			var frame_path = base_path + folder_name + "/animations/walking/" + direction + "/frame_%03d.png" % i
			if ResourceLoader.exists(frame_path):
				frames.append(load(frame_path))
			else:
				break
	
	return frames

# ======================== ANIMATION UPDATE ========================

func _process(delta: float) -> void:
	"""Update gladiator idle animations"""
	if not battle or not battle.battle_active or player_anim_frames.is_empty():
		return
	
	anim_timer += delta
	if anim_timer >= anim_frame_duration:
		anim_timer -= anim_frame_duration
		
		# Update player animations
		for i in range(player_anim_frames.size()):
			if player_anim_frames[i].size() > 0:
				player_anim_index[i] = (player_anim_index[i] + 1) % player_anim_frames[i].size()
				player_sprites[i].texture = player_anim_frames[i][player_anim_index[i]]
		
		# Update enemy animations
		for i in range(enemy_anim_frames.size()):
			if enemy_anim_frames[i].size() > 0:
				enemy_anim_index[i] = (enemy_anim_index[i] + 1) % enemy_anim_frames[i].size()
				enemy_sprites[i].texture = enemy_anim_frames[i][enemy_anim_index[i]]

# ======================== UI BUILDING ========================

func _build_ui() -> void:
	# --- Arena Background (Battle Arena Image) ---
	arena_bg = TextureRect.new()
	arena_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arena_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	arena_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Load texture safely
	var bg_tex = load("res://assets/ui/battle_arena.png")
	if bg_tex:
		arena_bg.texture = bg_tex
	else:
		# Fallback: use dark color if texture fails to load
		var fallback = ColorRect.new()
		fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
		fallback.color = RomanTheme.DARK_STONE
		fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(fallback)
		arena_bg = TextureRect.new()  # Keep it as TextureRect for type consistency
		arena_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		arena_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	add_child(arena_bg)
	
	# --- Main VBox ---
	main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 4)
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	add_child(margin)
	margin.add_child(main_vbox)
	
	# --- Turn Label ---
	turn_label = Label.new()
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 18)
	turn_label.add_theme_color_override("font_color", RomanTheme.ROMAN_GOLD_BRIGHT)
	turn_label.text = "⚔ ARENA COMBAT ⚔"
	main_vbox.add_child(turn_label)
	
	# --- Arena Center (sprites) - Positioned on background ---
	arena_center_node = Control.new()
	arena_center_node.custom_minimum_size = Vector2(800, 300)
	arena_center_node.size_flags_vertical = Control.SIZE_EXPAND_FILL
	arena_center_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(arena_center_node)
	
	# Create player gladiators with panels above them
	for i in range(3):
		# Panel above
		var panel = _create_inline_fighter_panel("player", i)
		panel.visible = false
		arena_center_node.add_child(panel)
		player_panels.append(panel)
		
		# Sprite below
		var ps = TextureRect.new()
		ps.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ps.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ps.custom_minimum_size = Vector2(160, 192)
		ps.size = Vector2(160, 192)
		ps.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ps.visible = false
		arena_center_node.add_child(ps)
		player_sprites.append(ps)
	
	# Create enemy gladiators with panels above them
	for i in range(3):
		# Panel above
		var panel = _create_inline_fighter_panel("enemy", i)
		panel.visible = false
		arena_center_node.add_child(panel)
		enemy_panels.append(panel)
		
		# Sprite below
		var es = TextureRect.new()
		es.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		es.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		es.custom_minimum_size = Vector2(160, 192)
		es.size = Vector2(160, 192)
		es.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		es.modulate = Color(1, 0.75, 0.75)
		es.visible = false
		arena_center_node.add_child(es)
		enemy_sprites.append(es)
	
	# --- Info Label ---
	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 12)
	info_label.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM)
	info_label.text = "Click a gladiator to select, then an enemy to target."
	main_vbox.add_child(info_label)
	
	# --- Energy Label ---
	energy_label = Label.new()
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.add_theme_font_size_override("font_size", 14)
	energy_label.add_theme_color_override("font_color", Color(0.3, 0.85, 1.0))
	main_vbox.add_child(energy_label)
	
	# --- Card Hand ---
	var hand_scroll = ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = 90
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(hand_scroll)
	
	hand_container = HBoxContainer.new()
	hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_container.add_theme_constant_override("separation", 6)
	hand_scroll.add_child(hand_container)
	
	# --- Bottom Buttons ---
	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 10)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_child(btn_hbox)
	
	end_turn_button = _create_themed_button("End Turn", RomanTheme.ARENA_SAND_DARK)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	btn_hbox.add_child(end_turn_button)
	
	retreat_button = _create_themed_button("Retreat", RomanTheme.BLOOD_RED)
	retreat_button.pressed.connect(_on_retreat_pressed)
	btn_hbox.add_child(retreat_button)
	
	# --- Result Overlay ---
	result_overlay = ColorRect.new()
	result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.color = Color(0, 0, 0, 0.7)
	result_overlay.visible = false
	add_child(result_overlay)
	
	var result_center = CenterContainer.new()
	result_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(result_center)
	
	result_panel = PanelContainer.new()
	result_panel.custom_minimum_size = Vector2(380, 200)
	result_panel.add_theme_stylebox_override("panel", RomanTheme.create_panel_style())
	result_center.add_child(result_panel)
	
	var result_vbox = VBoxContainer.new()
	result_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	result_panel.add_child(result_vbox)
	
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 26)
	result_label.add_theme_color_override("font_color", RomanTheme.ROMAN_GOLD_BRIGHT)
	result_vbox.add_child(result_label)
	
	return_button = _create_themed_button("Return to Ludus", RomanTheme.VICTORY_GREEN)
	return_button.pressed.connect(_on_return_pressed)
	result_vbox.add_child(return_button)

func _create_mini_fighter_panel(side: String, index: int) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(125, 45)
	panel.add_theme_stylebox_override("panel", RomanTheme.create_panel_style(RomanTheme.BG_PANEL))
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)
	
	var name_lbl = Label.new()
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM if side == "player" else Color(1.0, 0.6, 0.6))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(name_lbl)
	
	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(120, 10)
	hp_bar.show_percentage = false
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.15, 0.15)
	bar_bg.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = RomanTheme.VICTORY_GREEN if side == "player" else RomanTheme.BLOOD_RED
	bar_fill.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(hp_bar)
	
	var hp_lbl = Label.new()
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 10)
	hp_lbl.add_theme_color_override("font_color", RomanTheme.MARBLE_LIGHT)
	vbox.add_child(hp_lbl)
	
	# Make panel clickable for targeting
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if battle and battle.battle_active and battle.is_player_turn:
				if side == "player":
					battle.select_player(index)
					_update_selection_highlights()
					info_label.text = "Selected: %s" % battle.get_selected_player().g_name if battle.get_selected_player() else ""
				elif side == "enemy":
					battle.select_enemy(index)
					_update_selection_highlights()
					var enemy = battle.get_selected_enemy()
					info_label.text = "Target: %s" % enemy.get("name", "") if enemy else ""
	)
	
	if side == "player":
		player_name_labels.append(name_lbl)
		player_hp_bars.append(hp_bar)
		player_hp_labels.append(hp_lbl)
	else:
		enemy_name_labels.append(name_lbl)
		enemy_hp_bars.append(hp_bar)
		enemy_hp_labels.append(hp_lbl)
	
	return panel

func _create_inline_fighter_panel(side: String, index: int) -> Control:
	"""Create a compact panel for displaying above arena sprites"""
	var container = Control.new()
	container.custom_minimum_size = Vector2(140, 50)
	container.size = Vector2(140, 50)
	container.visible = false
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.add_child(vbox)
	
	var name_lbl = Label.new()
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM if side == "player" else Color(1.0, 0.6, 0.6))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.clip_text = true
	vbox.add_child(name_lbl)
	
	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(130, 10)
	hp_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	hp_bar.show_percentage = false
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.2, 0.15, 0.15)
	bar_bg.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("background", bar_bg)
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = RomanTheme.VICTORY_GREEN if side == "player" else RomanTheme.BLOOD_RED
	bar_fill.set_corner_radius_all(2)
	hp_bar.add_theme_stylebox_override("fill", bar_fill)
	vbox.add_child(hp_bar)
	
	var hp_lbl = Label.new()
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 12)
	hp_lbl.add_theme_color_override("font_color", RomanTheme.MARBLE_LIGHT)
	vbox.add_child(hp_lbl)
	
	if side == "player":
		player_name_labels.append(name_lbl)
		player_hp_bars.append(hp_bar)
		player_hp_labels.append(hp_lbl)
	else:
		enemy_name_labels.append(name_lbl)
		enemy_hp_bars.append(hp_bar)
		enemy_hp_labels.append(hp_lbl)
	
	# Make panel clickable for targeting
	container.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if battle and battle.battle_active and battle.is_player_turn:
				if side == "player":
					battle.select_player(index)
					_update_selection_highlights()
					info_label.text = "Selected: %s" % battle.get_selected_player().g_name if battle.get_selected_player() else ""
				elif side == "enemy":
					battle.select_enemy(index)
					_update_selection_highlights()
					var enemy = battle.get_selected_enemy()
					info_label.text = "Target: %s" % enemy.get("name", "") if enemy else ""
	)
	
	return container

func _create_themed_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(130, 38)
	RomanTheme.style_button(btn, color)
	return btn

# ======================== GLADIATOR PICKER ========================

func _show_gladiator_picker() -> void:
	# Determine max player count based on difficulty
	var bw = GameManager.battles_won
	if bw <= 1:
		max_player_count = 1
	elif bw <= 3:
		max_player_count = 2
	else:
		max_player_count = 3
	
	picker_selected.clear()
	
	picker_overlay = ColorRect.new()
	picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	picker_overlay.color = RomanTheme.BG_MODAL
	add_child(picker_overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	picker_overlay.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(500, 450)
	panel.add_theme_stylebox_override("panel", RomanTheme.create_panel_style())
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "⚔ SELECT GLADIATORS ⚔"
	if max_player_count > 1:
		title.text = "⚔ SELECT UP TO %d GLADIATORS ⚔" % max_player_count
	RomanTheme.style_subtitle(title, 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var difficulty_label = Label.new()
	var bw_text = "Battle %d" % (GameManager.battles_won + 1)
	if bw <= 1:
		difficulty_label.text = "%s — Easy (1v1)" % bw_text
	elif bw <= 3:
		difficulty_label.text = "%s — Normal (up to 2v2)" % bw_text
	elif bw <= 6:
		difficulty_label.text = "%s — Hard (up to 3v3)" % bw_text
	else:
		difficulty_label.text = "%s — Brutal (3v3)" % bw_text
	difficulty_label.add_theme_font_size_override("font_size", 13)
	difficulty_label.add_theme_color_override("font_color", RomanTheme.BLOOD_RED_BRIGHT if bw > 6 else RomanTheme.MARBLE_CREAM)
	difficulty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(difficulty_label)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 250
	vbox.add_child(scroll)
	
	picker_list = VBoxContainer.new()
	picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_list.add_theme_constant_override("separation", 6)
	scroll.add_child(picker_list)
	
	var available_count = 0
	for i in range(GameManager.roster.size()):
		var g = GameManager.roster[i]
		if g.is_active and g.current_action == "idle" and g.current_hp > 0:
			available_count += 1
			
			var btn = Button.new()
			btn.custom_minimum_size.y = 70
			
			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 12)
			hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
			
			# Add margin so content isn't hugging the edge of the button
			var margin = MarginContainer.new()
			margin.add_theme_constant_override("margin_left", 12)
			margin.add_theme_constant_override("margin_right", 12)
			margin.add_theme_constant_override("margin_top", 6)
			margin.add_theme_constant_override("margin_bottom", 6)
			margin.set_anchors_preset(Control.PRESET_FULL_RECT)
			margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
			btn.add_child(margin)
			margin.add_child(hbox)
			
			var icon = TextureRect.new()
			icon.custom_minimum_size = Vector2(48, 48)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var tex = _get_picker_texture(g.type)
			if tex:
				icon.texture = tex
			hbox.add_child(icon)
			
			var info = Label.new()
			info.text = "%s [Lv.%d %s]\nHP: %d/%d | ATK: %d | DOD: %.0f%%" % [g.g_name, g.level, g.type, g.current_hp, g.max_hp, g.attack_damage, g.dodge_chance]
			info.add_theme_font_size_override("font_size", 14)
			info.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			hbox.add_child(info)
			
			var glad_idx = i
			
			# Stylish toggled appearance using StyleBoxes
			var style_selected = StyleBoxFlat.new()
			style_selected.bg_color = Color(0.3, 0.4, 0.2, 0.8) # Greenish tint for selected
			style_selected.border_color = RomanTheme.VICTORY_GREEN
			style_selected.set_border_width_all(2)
			style_selected.set_corner_radius_all(6)
			
			var style_normal = StyleBoxFlat.new()
			style_normal.bg_color = Color(0.15, 0.12, 0.10, 0.8)
			style_normal.border_color = Color(0.3, 0.25, 0.2)
			style_normal.set_border_width_all(1)
			style_normal.set_corner_radius_all(6)
			
			# Update visually when state changes
			var update_visuals = func():
				if picker_selected.has(glad_idx):
					btn.add_theme_stylebox_override("normal", style_selected)
					btn.add_theme_stylebox_override("hover", style_selected)
					btn.add_theme_stylebox_override("pressed", style_selected)
				else:
					btn.add_theme_stylebox_override("normal", style_normal)
					btn.add_theme_stylebox_override("hover", style_normal)
					btn.add_theme_stylebox_override("pressed", style_normal)
			
			btn.pressed.connect(func():
				if picker_selected.has(glad_idx):
					picker_selected.erase(glad_idx)
				else:
					if picker_selected.size() < max_player_count:
						picker_selected.append(glad_idx)
				update_visuals.call()
			)
			
			# Auto-select gladiators up to max capacity
			if picker_selected.size() < max_player_count:
				picker_selected.append(glad_idx)
			
			update_visuals.call()
			picker_list.add_child(btn)
	
	if available_count == 0:
		var no_glad = Label.new()
		no_glad.text = "No gladiators available for battle!"
		RomanTheme.style_subtitle(no_glad, 16)
		picker_list.add_child(no_glad)
	
	# Buttons row
	var btn_row = HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_row)
	
	var fight_btn = _create_themed_button("Fight!", RomanTheme.VICTORY_GREEN)
	fight_btn.pressed.connect(func():
		if picker_selected.size() > 0:
			_on_gladiators_picked()
	)
	btn_row.add_child(fight_btn)
	
	var retreat_btn = _create_themed_button("Retreat to Ludus", RomanTheme.BLOOD_RED)
	retreat_btn.pressed.connect(func(): SceneRouter.go_to_ludus())
	btn_row.add_child(retreat_btn)

func _on_gladiators_picked() -> void:
	var selected_glads: Array[Gladiator] = []
	for idx in picker_selected:
		selected_glads.append(GameManager.roster[idx])
	
	picker_overlay.queue_free()
	_start_combat_with(selected_glads)

# ======================== COMBAT LOGIC ========================

func _start_combat_with(fighters: Array[Gladiator]) -> void:
	# Position player sprites on LEFT side of arena
	var player_count = fighters.size()
	player_base_positions.clear()
	player_anim_frames.clear()
	player_anim_index.clear()
	
	for i in range(player_count):
		var g = fighters[i]
		# Spread players horizontally on left side (x: 80-200)
		var x_pos = 120 + i * 110
		var y_pos = 400  # Positioned in sand area
		player_base_positions.append(Vector2(x_pos, y_pos))
		
		# Position panel above sprite
		player_panels[i].visible = true
		player_panels[i].position = Vector2(x_pos + 10, y_pos - 65)
		
		# Position sprite
		player_sprites[i].visible = true
		player_sprites[i].position = player_base_positions[i]
		var tex = _get_player_texture(g.type)
		if tex:
			player_sprites[i].texture = tex
		player_sprites[i].modulate = Color.WHITE
		
		# Load animation frames for sprite
		var frames = _load_animation_frames(g.type, "south")
		player_anim_frames.append(frames)
		player_anim_index.append(0)
	
	# Generate enemies and position on RIGHT side of arena
	var enemy_data_list = _generate_enemies()
	var enemy_count = enemy_data_list.size()
	
	enemy_base_positions.clear()
	enemy_anim_frames.clear()
	enemy_anim_index.clear()
	
	for i in range(enemy_count):
		# Spread enemies horizontally on right side, pulling them inwards (x: 430-550)
		var x_pos = 550 - i * 110
		var y_pos = 400  # Positioned in sand area
		enemy_base_positions.append(Vector2(x_pos, y_pos))
		
		# Position panel above sprite
		enemy_panels[i].visible = true
		enemy_panels[i].position = Vector2(x_pos + 10, y_pos - 65)
		
		# Position sprite
		enemy_sprites[i].visible = true
		enemy_sprites[i].position = enemy_base_positions[i]
		var tex = _get_enemy_texture(enemy_data_list[i]["type"])
		if tex:
			enemy_sprites[i].texture = tex
		enemy_sprites[i].modulate = Color(1.0, 0.7, 0.7)
		
		# Load animation frames for sprite
		var frames = _load_animation_frames(enemy_data_list[i]["type"], "south")
		enemy_anim_frames.append(frames)
		enemy_anim_index.append(0)
	
	# Create battle
	battle = BattleManager.new()
	battle.battle_started.connect(_on_battle_started)
	battle.turn_started.connect(_on_turn_started)
	battle.card_played.connect(_on_card_played)
	battle.damage_dealt.connect(_on_damage_dealt)
	battle.battle_ended.connect(_on_battle_ended)
	battle.animation_requested.connect(_on_animation_requested)
	battle.gladiator_defeated.connect(_on_gladiator_defeated)
	
	battle.start_battle(fighters, enemy_data_list)

func _generate_enemies() -> Array[Dictionary]:
	var bw = GameManager.battles_won
	var difficulty_scale: float
	var enemy_count: int
	
	# Progressive difficulty
	if bw <= 1:
		enemy_count = 1
		difficulty_scale = 0.7
	elif bw <= 3:
		enemy_count = mini(picker_selected.size(), 2)
		difficulty_scale = 1.0
	elif bw <= 6:
		enemy_count = mini(picker_selected.size(), 3)
		enemy_count = maxi(enemy_count, 2)
		difficulty_scale = 1.3
	else:
		enemy_count = 3
		difficulty_scale = 1.3 + (bw - 6) * 0.1 # Keeps scaling

	var base_day = clampi(GameManager.current_day, 1, 30)
	var enemy_types = [
		{"name": "Wild Beast", "base_hp": 40 + base_day * 5, "base_atk": 6 + base_day, "dodge": 3.0, "type": "Murmillo"},
		{"name": "Rival Gladiator", "base_hp": 50 + base_day * 4, "base_atk": 8 + base_day, "dodge": 5.0, "type": "Thraex"},
		{"name": "Arena Champion", "base_hp": 70 + base_day * 6, "base_atk": 10 + base_day * 2, "dodge": 8.0, "type": "Retiarius"},
	]
	
	var result: Array[Dictionary] = []
	for i in range(enemy_count):
		var template: Dictionary
		if bw < 2:
			template = enemy_types[0].duplicate()
		elif bw < 5:
			template = enemy_types[randi() % 2].duplicate()
		else:
			template = enemy_types[randi() % enemy_types.size()].duplicate()
		
		var enemy: Dictionary = {
			"name": template["name"] + (" " + str(i + 1) if enemy_count > 1 else ""),
			"hp": int(template["base_hp"] * difficulty_scale),
			"max_hp": int(template["base_hp"] * difficulty_scale),
			"attack": int(template["base_atk"] * difficulty_scale),
			"dodge": template["dodge"],
			"type": template["type"],
			"block": 0,
		}
		result.append(enemy)
	
	return result

# ======================== UI UPDATES ========================

func _update_all_ui() -> void:
	if not battle:
		return
	
	# Update player panels
	for i in range(battle.player_gladiators.size()):
		var g = battle.player_gladiators[i]
		player_name_labels[i].text = "⚔ %s" % g.g_name
		player_hp_bars[i].max_value = g.max_hp
		player_hp_bars[i].value = g.current_hp
		player_hp_labels[i].text = "%d/%d" % [g.current_hp, g.max_hp]
		if g.current_hp <= 0:
			player_sprites[i].modulate = Color(0.3, 0.3, 0.3, 0.5)
	
	# Update enemy panels
	for i in range(battle.enemies.size()):
		var e = battle.enemies[i]
		enemy_name_labels[i].text = "💀 %s" % e["name"]
		enemy_hp_bars[i].max_value = e["max_hp"]
		enemy_hp_bars[i].value = e["hp"]
		enemy_hp_labels[i].text = "%d/%d" % [e["hp"], e["max_hp"]]
		if e["hp"] <= 0:
			enemy_sprites[i].modulate = Color(0.3, 0.3, 0.3, 0.5)
	
	energy_label.text = "⚡ Energy: %d / %d" % [battle.energy, battle.max_energy]
	_rebuild_hand()
	_update_selection_highlights()

func _update_selection_highlights() -> void:
	if not battle:
		return
	
	# Highlight selected player (gold border)
	for i in range(battle.player_gladiators.size()):
		var g = battle.player_gladiators[i]
		if g.current_hp <= 0:
			player_panels[i].modulate = Color(0.5, 0.5, 0.5, 0.7)
		elif i == battle.selected_player_index:
			player_panels[i].modulate = Color(1.2, 1.1, 0.8) # Gold tint
		else:
			player_panels[i].modulate = Color.WHITE
	
	# Highlight selected enemy (red border)
	for i in range(battle.enemies.size()):
		var e = battle.enemies[i]
		if e["hp"] <= 0:
			enemy_panels[i].modulate = Color(0.5, 0.5, 0.5, 0.7)
		elif i == battle.selected_enemy_index:
			enemy_panels[i].modulate = Color(1.3, 0.8, 0.8) # Red tint
		else:
			enemy_panels[i].modulate = Color.WHITE

func _rebuild_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	card_buttons.clear()
	
	if not battle:
		return
	
	for i in range(battle.hand.size()):
		var card = battle.hand[i]
		var card_btn = _build_card_button(card, i)
		hand_container.add_child(card_btn)
		card_buttons.append(card_btn)

func _build_card_button(card: CardModel, index: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(110, 80)
	
	var desc_parts = []
	if card.attack_power > 0:
		desc_parts.append("⚔ %d" % card.attack_power)
	if card.health > 0:
		desc_parts.append("🛡 %d" % card.health)
	
	btn.text = "%s\n%s\n⚡%d" % [card.card_name, " ".join(desc_parts), card.cost]
	
	var can_play = battle.can_play_card(index) if battle else false
	
	var style = StyleBoxFlat.new()
	if can_play:
		style.bg_color = Color(0.18, 0.16, 0.12, 0.95)
		style.border_color = RomanTheme.ROMAN_GOLD_BRIGHT
	else:
		style.bg_color = Color(0.12, 0.1, 0.08, 0.7)
		style.border_color = Color(0.3, 0.3, 0.3)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	if can_play:
		hover_style.bg_color = Color(0.25, 0.22, 0.15, 0.95)
		hover_style.border_color = RomanTheme.MARBLE_CREAM
	btn.add_theme_stylebox_override("hover", hover_style)
	
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM if can_play else Color(0.5, 0.5, 0.5))
	
	btn.disabled = not can_play
	btn.pressed.connect(func(): _on_card_button_pressed(index))
	
	return btn

# ======================== ANIMATIONS ========================

func _play_attack_lunge(sprite: TextureRect, target_pos: Vector2) -> void:
	var original_pos = sprite.position
	var lunge_target = original_pos + (target_pos - original_pos).normalized() * 40
	
	var tween = create_tween()
	tween.tween_property(sprite, "position", lunge_target, 0.1).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "position", original_pos, 0.15).set_ease(Tween.EASE_IN)

func _play_hit_shake(sprite: TextureRect) -> void:
	var original_pos = sprite.position
	var shake_tween = create_tween()
	shake_tween.tween_property(sprite, "position", original_pos + Vector2(8, -4), 0.03)
	shake_tween.tween_property(sprite, "position", original_pos - Vector2(10, -3), 0.03)
	shake_tween.tween_property(sprite, "position", original_pos + Vector2(6, 2), 0.03)
	shake_tween.tween_property(sprite, "position", original_pos - Vector2(4, 0), 0.03)
	shake_tween.tween_property(sprite, "position", original_pos, 0.04)

func _play_dodge_anim(sprite: TextureRect) -> void:
	var original_pos = sprite.position
	var dodge_dir = Vector2(35, -12) if player_sprites.has(sprite) else Vector2(-35, -12)
	
	var tween = create_tween()
	tween.tween_property(sprite, "position", original_pos + dodge_dir, 0.1)
	tween.tween_property(sprite, "position", original_pos, 0.18)
	
	var mod_tween = create_tween()
	mod_tween.tween_property(sprite, "modulate:a", 0.25, 0.08)
	mod_tween.tween_property(sprite, "modulate:a", 1.0, 0.14)

# ======================== SIGNAL HANDLERS ========================

func _on_battle_started() -> void:
	AudioManager.pause_bgm()
	_update_all_ui()

func _on_turn_started(is_player: bool) -> void:
	if is_player:
		turn_label.text = "⚔ YOUR TURN (Round %d) ⚔" % battle.turn_count
		end_turn_button.disabled = false
	else:
		turn_label.text = "💀 ENEMY TURN 💀"
		end_turn_button.disabled = true
	_update_all_ui()

func _on_card_played(card: CardModel, is_player: bool) -> void:
	if is_player:
		info_label.text = "You played %s!" % card.card_name
		if card.attack_power > 0:
			var pi = battle.selected_player_index
			var ei = battle.selected_enemy_index
			if pi < player_sprites.size() and ei < enemy_sprites.size():
				_play_attack_lunge(player_sprites[pi], enemy_sprites[ei].position)
			AudioManager.play_sfx("sword_hit")
	_update_all_ui()

func _on_damage_dealt(target: String, amount: int, blocked: int) -> void:
	if target == "enemy":
		if amount == 0:
			var enemy = battle.get_selected_enemy()
			info_label.text = "%s dodged!" % enemy.get("name", "Enemy")
		else:
			var enemy = battle.get_selected_enemy()
			info_label.text = "Dealt %d damage to %s!" % [amount, enemy.get("name", "Enemy")]
	elif target == "player":
		var g = battle.get_selected_player()
		
		# Figure out which enemy just attacked (defaults to 0, or selected)
		var attacking_enemy_idx = battle.selected_enemy_index
		if attacking_enemy_idx >= enemy_sprites.size():
			attacking_enemy_idx = 0
			
		var target_player_idx = battle.selected_player_index
		if target_player_idx >= player_sprites.size():
			target_player_idx = 0
			
		# Play enemy lunge animation towards player!
		if not enemy_sprites.is_empty() and attacking_enemy_idx < enemy_sprites.size() and target_player_idx < player_sprites.size():
			_play_attack_lunge(enemy_sprites[attacking_enemy_idx], player_sprites[target_player_idx].position)
			AudioManager.play_sfx("sword_hit")
		
		if g:
			if amount == 0:
				info_label.text = "%s dodged the attack!" % g.g_name
			elif blocked > 0:
				info_label.text = "Enemy attacks! %d dmg (%d blocked)" % [amount, blocked]
			else:
				info_label.text = "Enemy attacks for %d damage!" % amount
	_update_all_ui()

func _on_animation_requested(anim_type: String, target: String) -> void:
	# Parse target like "player_0", "enemy_1"
	var parts = target.split("_")
	if parts.size() < 2:
		return
	var side = parts[0]
	var idx = int(parts[1])
	
	var sprite: TextureRect = null
	if side == "player" and idx < player_sprites.size():
		sprite = player_sprites[idx]
	elif side == "enemy" and idx < enemy_sprites.size():
		sprite = enemy_sprites[idx]
	
	if sprite == null:
		return
	
	match anim_type:
		"hit":
			_play_hit_shake(sprite)
		"dodge":
			_play_dodge_anim(sprite)

func _on_gladiator_defeated(side: String, index: int) -> void:
	if side == "enemy" and index < enemy_sprites.size():
		var tween = create_tween()
		tween.tween_property(enemy_sprites[index], "modulate:a", 0.3, 0.5)
	elif side == "player" and index < player_sprites.size():
		var tween = create_tween()
		tween.tween_property(player_sprites[index], "modulate:a", 0.3, 0.5)

func _on_battle_ended(player_won: bool, reward_gold: int) -> void:
	end_turn_button.disabled = true
	
	if player_won:
		result_label.text = "🏆 VICTORIA! 🏆\n+%d Gold" % reward_gold
		result_label.add_theme_color_override("font_color", RomanTheme.ROMAN_GOLD_BRIGHT)
		turn_label.text = "⚔ BATTLE WON ⚔"
		AudioManager.play_sfx("win")
	else:
		result_label.text = "💀 DEFEAT 💀\nYour gladiators have fallen..."
		result_label.add_theme_color_override("font_color", RomanTheme.BLOOD_RED_BRIGHT)
		turn_label.text = "💀 BATTLE LOST 💀"
		AudioManager.play_sfx("lose")
	
	_animate_result_overlay()
	_update_all_ui()

func _animate_result_overlay() -> void:
	return_button.disabled = true
	
	result_overlay.visible = true
	result_overlay.modulate.a = 0.0
	
	result_panel.pivot_offset = result_panel.size / 2.0
	result_panel.scale = Vector2(0.8, 0.8)
	
	var fade_tween = create_tween()
	fade_tween.tween_property(result_overlay, "modulate:a", 1.0, 1.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	var scale_tween = create_tween()
	scale_tween.tween_property(result_panel, "scale", Vector2(1.1, 1.1), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	scale_tween.tween_property(result_panel, "scale", Vector2(1.0, 1.0), 0.4).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	
	fade_tween.finished.connect(func(): return_button.disabled = false)

# ======================== BUTTON HANDLERS ========================

func _on_card_button_pressed(index: int) -> void:
	if battle and battle.is_player_turn:
		battle.play_card(index)

func _on_end_turn_pressed() -> void:
	if battle:
		battle.end_player_turn()

func _on_retreat_pressed() -> void:
	SceneRouter.go_to_ludus()

func _on_return_pressed() -> void:
	GameManager.reset_battle_timer()
	AudioManager.resume_bgm()
	SceneRouter.go_to_ludus()
