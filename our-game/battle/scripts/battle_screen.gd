extends Control

## BattleScreen - Visual arena combat with gladiator sprites, pre-battle picker,
## stat-scaled cards, attack lunge animations, and Roman-themed UI.

var battle: BattleManager = null
var card_buttons: Array[Button] = []

# Character texture maps
var type_textures_east: Dictionary = {}
var type_textures_west: Dictionary = {}
var type_textures_south: Dictionary = {}

# UI References
var picker_overlay: ColorRect
var picker_list: VBoxContainer

var arena_bg: ColorRect
var player_sprite: TextureRect
var enemy_sprite: TextureRect
var player_name_label: Label
var player_hp_bar: ProgressBar
var player_hp_label: Label
var player_block_label: Label

var enemy_name_label: Label
var enemy_hp_bar: ProgressBar
var enemy_hp_label: Label
var enemy_block_label: Label

var energy_label: Label
var turn_label: Label
var info_label: Label

var hand_container: HBoxContainer
var end_turn_button: Button
var retreat_button: Button

var result_overlay: ColorRect
var result_label: Label
var return_button: Button

# Sprite positions (closer together for combat feel)
var player_base_pos := Vector2(180, 110)
var enemy_base_pos := Vector2(440, 70)

func _ready() -> void:
	_load_character_textures()
	_build_ui()
	_show_gladiator_picker()

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
		var folder = type_map[type_name]
		# East-facing (player)
		var east_path = base_path + folder + "/rotations/east.png"
		if ResourceLoader.exists(east_path):
			type_textures_east[type_name] = load(east_path)
		# West-facing (enemy)
		var west_path = base_path + folder + "/rotations/west.png"
		if ResourceLoader.exists(west_path):
			type_textures_west[type_name] = load(west_path)
		# South-facing (fallback/picker)
		var south_path = base_path + folder + "/rotations/south.png"
		if ResourceLoader.exists(south_path):
			type_textures_south[type_name] = load(south_path)

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

# ======================== UI BUILDING ========================

func _build_ui() -> void:
	# --- Arena Background (warm Roman sand) ---
	arena_bg = ColorRect.new()
	arena_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena_bg.color = RomanTheme.DARK_STONE
	add_child(arena_bg)
	
	# Sand floor gradient at bottom
	var sand_floor = ColorRect.new()
	sand_floor.color = Color(0.35, 0.28, 0.18, 0.25)
	sand_floor.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena_bg.add_child(sand_floor)
	
	# Root layout
	var root_margin = MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 16)
	root_margin.add_theme_constant_override("margin_right", 16)
	root_margin.add_theme_constant_override("margin_top", 10)
	root_margin.add_theme_constant_override("margin_bottom", 10)
	add_child(root_margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 4)
	root_margin.add_child(main_vbox)
	
	# --- Title ---
	turn_label = Label.new()
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 20)
	turn_label.add_theme_color_override("font_color", RomanTheme.ROMAN_GOLD_BRIGHT)
	turn_label.text = "⚔ ARENA COMBAT ⚔"
	main_vbox.add_child(turn_label)
	
	# --- Enemy Panel ---
	var enemy_panel = _create_styled_fighter_panel("enemy")
	main_vbox.add_child(enemy_panel)
	
	# --- Arena Center (sprites - closer together!) ---
	var arena_center = Control.new()
	arena_center.custom_minimum_size.y = 260
	arena_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(arena_center)
	
	# Arena sand floor line
	var arena_floor = ColorRect.new()
	arena_floor.color = RomanTheme.ARENA_SAND_DARK
	arena_floor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	arena_floor.offset_top = -35
	arena_center.add_child(arena_floor)
	
	# Player sprite (LEFT side, facing EAST → toward enemy)
	player_sprite = TextureRect.new()
	player_sprite.custom_minimum_size = Vector2(128, 128)
	player_sprite.size = Vector2(128, 128)
	player_sprite.position = player_base_pos
	player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	arena_center.add_child(player_sprite)
	
	# Enemy sprite (RIGHT side, facing WEST → toward player)
	enemy_sprite = TextureRect.new()
	enemy_sprite.custom_minimum_size = Vector2(128, 128)
	enemy_sprite.size = Vector2(128, 128)
	enemy_sprite.position = enemy_base_pos
	enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy_sprite.modulate = Color(1, 0.75, 0.75)  # Subtle red tint
	arena_center.add_child(enemy_sprite)
	
	# VS text between fighters
	var vs_label = Label.new()
	vs_label.text = "⚔"
	vs_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vs_label.add_theme_font_size_override("font_size", 28)
	vs_label.add_theme_color_override("font_color", RomanTheme.BLOOD_RED_BRIGHT)
	vs_label.position = Vector2(340, 80)
	vs_label.size = Vector2(80, 40)
	arena_center.add_child(vs_label)
	
	# Info label (combat log)
	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 14)
	info_label.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.set_anchors_preset(Control.PRESET_CENTER)
	info_label.offset_left = -200
	info_label.offset_right = 200
	info_label.offset_top = 100
	info_label.offset_bottom = 130
	info_label.text = ""
	arena_center.add_child(info_label)
	
	# --- Player Panel ---
	var player_panel = _create_styled_fighter_panel("player")
	main_vbox.add_child(player_panel)
	
	# --- Energy ---
	energy_label = Label.new()
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.add_theme_font_size_override("font_size", 18)
	energy_label.add_theme_color_override("font_color", RomanTheme.ARENA_SAND)
	main_vbox.add_child(energy_label)
	
	# --- Card Hand ---
	var hand_scroll = ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = 100
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(hand_scroll)
	
	hand_container = HBoxContainer.new()
	hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_container.add_theme_constant_override("separation", 6)
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_scroll.add_child(hand_container)
	
	# --- Action Buttons ---
	var action_hbox = HBoxContainer.new()
	action_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(action_hbox)
	
	end_turn_button = _create_themed_button("End Turn", RomanTheme.WARM_BRONZE)
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	action_hbox.add_child(end_turn_button)
	
	retreat_button = _create_themed_button("Retreat", RomanTheme.BLOOD_RED)
	retreat_button.pressed.connect(_on_retreat_pressed)
	action_hbox.add_child(retreat_button)
	
	# --- Result overlay (hidden) ---
	result_overlay = ColorRect.new()
	result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.color = RomanTheme.BG_MODAL
	result_overlay.visible = false
	add_child(result_overlay)
	
	var result_center = CenterContainer.new()
	result_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(result_center)
	
	var result_panel = PanelContainer.new()
	result_panel.custom_minimum_size = Vector2(380, 200)
	result_panel.add_theme_stylebox_override("panel", RomanTheme.create_panel_style())
	result_center.add_child(result_panel)
	
	var result_vbox = VBoxContainer.new()
	result_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	result_vbox.add_theme_constant_override("separation", 16)
	result_panel.add_child(result_vbox)
	
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 26)
	result_vbox.add_child(result_label)
	
	return_button = _create_themed_button("Return to Ludus", RomanTheme.VICTORY_GREEN)
	return_button.pressed.connect(_on_return_pressed)
	result_vbox.add_child(return_button)

func _create_styled_fighter_panel(side: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.y = 50
	panel.add_theme_stylebox_override("panel", RomanTheme.create_panel_style(RomanTheme.BG_PANEL))
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)
	
	var name_lbl = Label.new()
	name_lbl.custom_minimum_size.x = 120
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_lbl.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM)
	hbox.add_child(name_lbl)
	
	var stat_vbox = VBoxContainer.new()
	stat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(stat_vbox)
	
	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size.y = 18
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	
	# Style HP bar with Roman blood red fill
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.15, 0.1, 0.08)
	bar_bg.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("background", bar_bg)
	
	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = RomanTheme.BLOOD_RED_BRIGHT if side == "enemy" else RomanTheme.VICTORY_GREEN_BRIGHT
	bar_fill.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("fill", bar_fill)
	stat_vbox.add_child(hp_bar)
	
	var hp_lbl = Label.new()
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 13)
	hp_lbl.add_theme_color_override("font_color", RomanTheme.MARBLE_LIGHT)
	stat_vbox.add_child(hp_lbl)
	
	var block_lbl = Label.new()
	block_lbl.custom_minimum_size.x = 70
	block_lbl.add_theme_font_size_override("font_size", 14)
	block_lbl.add_theme_color_override("font_color", RomanTheme.ARENA_SAND)
	hbox.add_child(block_lbl)
	
	if side == "player":
		player_name_label = name_lbl
		player_hp_bar = hp_bar
		player_hp_label = hp_lbl
		player_block_label = block_lbl
	else:
		enemy_name_label = name_lbl
		enemy_hp_bar = hp_bar
		enemy_hp_label = hp_lbl
		enemy_block_label = block_lbl
	
	return panel

func _create_themed_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(130, 38)
	RomanTheme.style_button(btn, color)
	return btn

# ======================== GLADIATOR PICKER ========================

func _show_gladiator_picker() -> void:
	picker_overlay = ColorRect.new()
	picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	picker_overlay.color = RomanTheme.BG_MODAL
	add_child(picker_overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	picker_overlay.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 380)
	panel.add_theme_stylebox_override("panel", RomanTheme.create_panel_style())
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "⚔ Choose Your Champion ⚔"
	RomanTheme.style_title(title, 22)
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	picker_list = VBoxContainer.new()
	picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_list.add_theme_constant_override("separation", 6)
	scroll.add_child(picker_list)
	
	var available_count = 0
	for i in range(GameManager.roster.size()):
		var g = GameManager.roster[i]
		if g.is_active and g.current_action == "idle":
			available_count += 1
			var row = PanelContainer.new()
			row.add_theme_stylebox_override("panel", RomanTheme.create_row_style())
			
			var hbox = HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 8)
			row.add_child(hbox)
			
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
			info.add_theme_font_size_override("font_size", 13)
			info.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hbox.add_child(info)
			
			var select_btn = _create_themed_button("Fight!", RomanTheme.VICTORY_GREEN)
			select_btn.custom_minimum_size = Vector2(80, 36)
			var idx = i
			select_btn.pressed.connect(func(): _on_gladiator_picked(idx))
			hbox.add_child(select_btn)
			
			picker_list.add_child(row)
	
	if available_count == 0:
		var no_glad = Label.new()
		no_glad.text = "No gladiators available for battle!"
		RomanTheme.style_subtitle(no_glad, 16)
		picker_list.add_child(no_glad)
	
	var retreat_btn = _create_themed_button("Retreat to Ludus", RomanTheme.BLOOD_RED)
	retreat_btn.pressed.connect(func(): SceneRouter.go_to_ludus())
	vbox.add_child(retreat_btn)

func _on_gladiator_picked(index: int) -> void:
	picker_overlay.queue_free()
	_start_combat_with(GameManager.roster[index])

# ======================== COMBAT LOGIC ========================

func _start_combat_with(fighter: Gladiator) -> void:
	# Player sprite: facing EAST (toward enemy)
	var player_tex = _get_player_texture(fighter.type)
	if player_tex:
		player_sprite.texture = player_tex
	player_sprite.modulate = Color.WHITE
	player_sprite.position = player_base_pos
	
	# Generate enemy
	var difficulty = clampi(GameManager.current_day, 1, 30)
	var enemy_types = [
		{"name": "Wild Beast", "hp": 40 + difficulty * 5, "atk": 6 + difficulty, "dodge": 3.0, "type": "Murmillo"},
		{"name": "Rival Gladiator", "hp": 50 + difficulty * 4, "atk": 8 + difficulty, "dodge": 5.0, "type": "Thraex"},
		{"name": "Arena Champion", "hp": 70 + difficulty * 6, "atk": 10 + difficulty * 2, "dodge": 8.0, "type": "Retiarius"},
	]
	
	var enemy_data: Dictionary
	if difficulty < 5:
		enemy_data = enemy_types[0]
	elif difficulty < 15:
		enemy_data = enemy_types[randi() % 2]
	else:
		enemy_data = enemy_types[randi() % enemy_types.size()]
	
	# Enemy sprite: facing WEST (toward player) with red tint
	var enemy_tex = _get_enemy_texture(enemy_data["type"])
	if enemy_tex:
		enemy_sprite.texture = enemy_tex
	enemy_sprite.modulate = Color(1.0, 0.7, 0.7)
	enemy_sprite.position = enemy_base_pos
	
	# Create battle
	battle = BattleManager.new()
	battle.battle_started.connect(_on_battle_started)
	battle.turn_started.connect(_on_turn_started)
	battle.card_played.connect(_on_card_played)
	battle.damage_dealt.connect(_on_damage_dealt)
	battle.battle_ended.connect(_on_battle_ended)
	battle.animation_requested.connect(_on_animation_requested)
	
	battle.start_battle(fighter, enemy_data["name"], enemy_data["hp"], enemy_data["atk"], enemy_data["dodge"], enemy_data["type"])

# ======================== UI UPDATES ========================

func _update_all_ui() -> void:
	if not battle:
		return
	
	player_name_label.text = "⚔ " + battle.player_gladiator.g_name
	player_hp_bar.max_value = battle.get_player_max_hp()
	player_hp_bar.value = battle.get_player_hp()
	player_hp_label.text = "%d / %d" % [battle.get_player_hp(), battle.get_player_max_hp()]
	player_block_label.text = "🛡 %d" % battle.player_block if battle.player_block > 0 else ""
	
	enemy_name_label.text = "💀 " + battle.enemy_name
	enemy_hp_bar.max_value = battle.get_enemy_max_hp()
	enemy_hp_bar.value = battle.get_enemy_hp()
	enemy_hp_label.text = "%d / %d" % [battle.get_enemy_hp(), battle.get_enemy_max_hp()]
	enemy_block_label.text = "🛡 %d" % battle.enemy_block if battle.enemy_block > 0 else ""
	
	energy_label.text = "⚡ Energy: %d / %d" % [battle.energy, battle.max_energy]
	_rebuild_hand()

func _rebuild_hand() -> void:
	for child in hand_container.get_children():
		child.queue_free()
	card_buttons.clear()
	
	for i in range(battle.hand.size()):
		var card = battle.hand[i]
		var btn = _create_card_button(card, i)
		hand_container.add_child(btn)
		card_buttons.append(btn)

func _create_card_button(card: CardModel, index: int) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(105, 90)
	
	var can_play = battle.can_play_card(index)
	var style = StyleBoxFlat.new()
	
	if can_play:
		style.bg_color = Color(0.14, 0.11, 0.08, 0.95)
		style.border_color = RomanTheme.ROMAN_GOLD
	else:
		style.bg_color = Color(0.08, 0.06, 0.05, 0.7)
		style.border_color = Color(0.3, 0.25, 0.15, 0.5)
	
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.border_color = RomanTheme.ROMAN_GOLD_BRIGHT
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var scaled_atk = card.scaled_attack(battle.player_gladiator) if card.attack_power > 0 else 0
	var scaled_blk = card.scaled_block(battle.player_gladiator) if card.health > 0 else 0
	
	var label_text = "%s\nCost: %d" % [card.card_name, card.cost]
	if scaled_atk > 0:
		label_text += "\n⚔ %d" % scaled_atk
	if scaled_blk > 0:
		label_text += "\n🛡 %d" % scaled_blk
	if card.has_tag("energy"):
		label_text += "\n⚡ +1"
	if card.has_tag("debuff"):
		label_text += "\n🕸 Slow"
	
	btn.text = label_text
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM)
	btn.tooltip_text = card.description
	btn.disabled = not can_play
	
	var idx = index
	btn.pressed.connect(func(): _on_card_button_pressed(idx))
	
	return btn

# ======================== ANIMATIONS ========================

func _on_animation_requested(anim_type: String, target: String) -> void:
	var sprite = player_sprite if target == "player" else enemy_sprite
	
	if anim_type == "hit":
		_play_hit_flash(sprite)
	elif anim_type == "dodge":
		_play_dodge_anim(sprite)

func _play_attack_lunge(attacker: TextureRect, target_pos: Vector2) -> void:
	## Attacker lunges toward target, then snaps back
	var original_pos = attacker.position
	var lunge_target = original_pos.lerp(target_pos, 0.4)
	
	var tween = create_tween()
	tween.tween_property(attacker, "position", lunge_target, 0.12).set_ease(Tween.EASE_OUT)
	tween.tween_property(attacker, "position", original_pos, 0.2).set_ease(Tween.EASE_IN)

func _play_hit_flash(sprite: TextureRect) -> void:
	var original_mod = sprite.modulate
	var original_pos = sprite.position
	
	# Red flash
	var flash_tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", Color(2.5, 0.3, 0.2), 0.06)
	flash_tween.tween_property(sprite, "modulate", original_mod, 0.18)
	
	# Violent shake
	var shake_tween = create_tween()
	shake_tween.tween_property(sprite, "position", original_pos + Vector2(10, -3), 0.03)
	shake_tween.tween_property(sprite, "position", original_pos - Vector2(10, -3), 0.03)
	shake_tween.tween_property(sprite, "position", original_pos + Vector2(6, 2), 0.03)
	shake_tween.tween_property(sprite, "position", original_pos - Vector2(4, 0), 0.03)
	shake_tween.tween_property(sprite, "position", original_pos, 0.04)

func _play_dodge_anim(sprite: TextureRect) -> void:
	var original_pos = sprite.position
	var dodge_dir = Vector2(35, -12) if sprite == player_sprite else Vector2(-35, -12)
	
	var tween = create_tween()
	tween.tween_property(sprite, "position", original_pos + dodge_dir, 0.1)
	tween.tween_property(sprite, "position", original_pos, 0.18)
	
	var mod_tween = create_tween()
	mod_tween.tween_property(sprite, "modulate:a", 0.25, 0.08)
	mod_tween.tween_property(sprite, "modulate:a", 1.0, 0.14)

# ======================== SIGNAL HANDLERS ========================

func _on_battle_started() -> void:
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
		# Attack lunge when playing attack card
		if card.attack_power > 0:
			_play_attack_lunge(player_sprite, enemy_base_pos)
	_update_all_ui()

func _on_damage_dealt(target: String, amount: int, blocked: int) -> void:
	if target == "enemy":
		if amount == 0:
			info_label.text = "%s dodged!" % battle.enemy_name
		else:
			info_label.text = "Dealt %d damage to %s!" % [amount, battle.enemy_name]
	elif target == "player":
		# Enemy lunge when attacking player
		_play_attack_lunge(enemy_sprite, player_base_pos)
		if amount == 0:
			info_label.text = "%s dodged the attack!" % battle.player_gladiator.g_name
		elif blocked > 0:
			info_label.text = "%s attacks! %d dmg (%d blocked)" % [battle.enemy_name, amount, blocked]
		else:
			info_label.text = "%s attacks for %d damage!" % [battle.enemy_name, amount]
	_update_all_ui()

func _on_battle_ended(player_won: bool, reward_gold: int) -> void:
	end_turn_button.disabled = true
	
	if player_won:
		result_label.text = "🏆 VICTORIA! 🏆\n+%d Gold" % reward_gold
		result_label.add_theme_color_override("font_color", RomanTheme.ROMAN_GOLD_BRIGHT)
		turn_label.text = "⚔ BATTLE WON ⚔"
	else:
		result_label.text = "💀 DEFEAT 💀\n%s has fallen..." % battle.player_gladiator.g_name
		result_label.add_theme_color_override("font_color", RomanTheme.BLOOD_RED_BRIGHT)
		turn_label.text = "💀 BATTLE LOST 💀"
	
	result_overlay.visible = true
	_update_all_ui()

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
	SceneRouter.go_to_ludus()
