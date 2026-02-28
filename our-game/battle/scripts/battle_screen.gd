extends Control

## BattleScreen - Visual arena combat with gladiator sprites, pre-battle picker,
## stat-scaled cards, and hit/dodge animations.

var battle: BattleManager = null
var card_buttons: Array[Button] = []

# Character texture map (same as ludus)
var type_textures: Dictionary = {}

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

func _ready() -> void:
	_load_character_textures()
	_build_ui()
	_show_gladiator_picker()

# ======================== TEXTURE LOADING ========================

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

func _get_texture_for_type(type_name: String) -> Texture2D:
	if type_textures.has(type_name):
		return type_textures[type_name]
	var fallback_path = "res://assets/ui/murmillo_base.png"
	if ResourceLoader.exists(fallback_path):
		return load(fallback_path)
	return null

# ======================== UI BUILDING ========================

func _build_ui() -> void:
	# --- Arena Background ---
	arena_bg = ColorRect.new()
	arena_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	arena_bg.color = Color(0.18, 0.14, 0.1, 1.0)  # Sandy dark brown
	add_child(arena_bg)
	
	# Sand gradient overlay
	var sand = ColorRect.new()
	sand.set_anchors_preset(Control.PRESET_FULL_RECT)
	sand.color = Color(0.35, 0.28, 0.18, 0.3)
	arena_bg.add_child(sand)
	
	# Root layout
	var root_margin = MarginContainer.new()
	root_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 16)
	root_margin.add_theme_constant_override("margin_right", 16)
	root_margin.add_theme_constant_override("margin_top", 12)
	root_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(root_margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_theme_constant_override("separation", 4)
	root_margin.add_child(main_vbox)
	
	# --- Title ---
	turn_label = Label.new()
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 20)
	turn_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	turn_label.text = "⚔ ARENA COMBAT ⚔"
	main_vbox.add_child(turn_label)
	
	# --- Enemy Panel ---
	var enemy_panel = _create_styled_fighter_panel("enemy")
	main_vbox.add_child(enemy_panel)
	
	# --- Arena Center (sprites) ---
	var arena_center = Control.new()
	arena_center.custom_minimum_size.y = 260
	arena_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(arena_center)
	
	# Arena decorative line (sand floor)
	var arena_floor = ColorRect.new()
	arena_floor.color = Color(0.45, 0.35, 0.2, 0.4)
	arena_floor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	arena_floor.offset_top = -40
	arena_center.add_child(arena_floor)
	
	# Enemy sprite (top-right area)
	enemy_sprite = TextureRect.new()
	enemy_sprite.custom_minimum_size = Vector2(96, 96)
	enemy_sprite.size = Vector2(96, 96)
	enemy_sprite.position = Vector2(520, 20)
	enemy_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	enemy_sprite.modulate = Color(1, 0.7, 0.7)  # Red tint for enemies
	arena_center.add_child(enemy_sprite)
	
	# Player sprite (bottom-left area)
	player_sprite = TextureRect.new()
	player_sprite.custom_minimum_size = Vector2(96, 96)
	player_sprite.size = Vector2(96, 96)
	player_sprite.position = Vector2(140, 120)
	player_sprite.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	arena_center.add_child(player_sprite)
	
	# Info label (combat log in center)
	info_label = Label.new()
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info_label.add_theme_font_size_override("font_size", 15)
	info_label.add_theme_color_override("font_color", Color(1, 1, 0.8))
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.set_anchors_preset(Control.PRESET_CENTER)
	info_label.offset_left = -150
	info_label.offset_right = 150
	info_label.offset_top = -20
	info_label.offset_bottom = 20
	info_label.text = ""
	arena_center.add_child(info_label)
	
	# --- Player Panel ---
	var player_panel = _create_styled_fighter_panel("player")
	main_vbox.add_child(player_panel)
	
	# --- Energy ---
	energy_label = Label.new()
	energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	energy_label.add_theme_font_size_override("font_size", 18)
	energy_label.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
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
	
	end_turn_button = _create_styled_button("End Turn", Color(0.3, 0.6, 0.9))
	end_turn_button.pressed.connect(_on_end_turn_pressed)
	action_hbox.add_child(end_turn_button)
	
	retreat_button = _create_styled_button("Retreat", Color(0.7, 0.3, 0.3))
	retreat_button.pressed.connect(_on_retreat_pressed)
	action_hbox.add_child(retreat_button)
	
	# --- Result overlay (hidden) ---
	result_overlay = ColorRect.new()
	result_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.color = Color(0, 0, 0, 0.8)
	result_overlay.visible = false
	add_child(result_overlay)
	
	var result_center = CenterContainer.new()
	result_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(result_center)
	
	var result_panel = PanelContainer.new()
	result_panel.custom_minimum_size = Vector2(350, 180)
	var result_style = StyleBoxFlat.new()
	result_style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	result_style.border_color = Color(0.75, 0.6, 0.2, 0.8)
	result_style.set_border_width_all(3)
	result_style.set_corner_radius_all(10)
	result_style.set_content_margin_all(20)
	result_panel.add_theme_stylebox_override("panel", result_style)
	result_center.add_child(result_panel)
	
	var result_vbox = VBoxContainer.new()
	result_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	result_vbox.add_theme_constant_override("separation", 16)
	result_panel.add_child(result_vbox)
	
	result_label = Label.new()
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 26)
	result_vbox.add_child(result_label)
	
	return_button = _create_styled_button("Return to Ludus", Color(0.3, 0.6, 0.3))
	return_button.pressed.connect(_on_return_pressed)
	result_vbox.add_child(return_button)

func _create_styled_fighter_panel(side: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size.y = 50
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.85)
	style.border_color = Color(0.5, 0.4, 0.15, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	panel.add_child(hbox)
	
	var name_lbl = Label.new()
	name_lbl.custom_minimum_size.x = 110
	name_lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(name_lbl)
	
	var stat_vbox = VBoxContainer.new()
	stat_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(stat_vbox)
	
	var hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size.y = 18
	hp_bar.max_value = 100
	hp_bar.value = 100
	hp_bar.show_percentage = false
	stat_vbox.add_child(hp_bar)
	
	var hp_lbl = Label.new()
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 13)
	stat_vbox.add_child(hp_lbl)
	
	var block_lbl = Label.new()
	block_lbl.custom_minimum_size.x = 70
	block_lbl.add_theme_font_size_override("font_size", 14)
	block_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0))
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

func _create_styled_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(130, 38)
	btn.add_theme_font_size_override("font_size", 15)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.bg_color = color.lightened(0.2)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	var pressed_style = style.duplicate()
	pressed_style.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed_style)
	
	return btn

# ======================== GLADIATOR PICKER ========================

func _show_gladiator_picker() -> void:
	picker_overlay = ColorRect.new()
	picker_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	picker_overlay.color = Color(0, 0, 0, 0.85)
	add_child(picker_overlay)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	picker_overlay.add_child(center)
	
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 350)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.border_color = Color(0.75, 0.6, 0.2, 0.8)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "⚔ Choose Your Champion ⚔"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox.add_child(title)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	picker_list = VBoxContainer.new()
	picker_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker_list.add_theme_constant_override("separation", 6)
	scroll.add_child(picker_list)
	
	# Populate with available gladiators
	var available_count = 0
	for i in range(GameManager.roster.size()):
		var g = GameManager.roster[i]
		if g.is_active and g.current_action == "idle":
			available_count += 1
			var row = HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			
			# Character icon
			var icon = TextureRect.new()
			icon.custom_minimum_size = Vector2(48, 48)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var tex = _get_texture_for_type(g.type)
			if tex:
				icon.texture = tex
			row.add_child(icon)
			
			# Info label
			var info = Label.new()
			info.text = "%s [Lv.%d %s]\nHP: %d/%d | ATK: %d | DOD: %.0f%%" % [g.g_name, g.level, g.type, g.current_hp, g.max_hp, g.attack_damage, g.dodge_chance]
			info.add_theme_font_size_override("font_size", 13)
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(info)
			
			# Select button
			var select_btn = _create_styled_button("Fight!", Color(0.2, 0.5, 0.2))
			select_btn.custom_minimum_size = Vector2(80, 36)
			var idx = i
			select_btn.pressed.connect(func(): _on_gladiator_picked(idx))
			row.add_child(select_btn)
			
			picker_list.add_child(row)
	
	if available_count == 0:
		var no_glad = Label.new()
		no_glad.text = "No gladiators available for battle!"
		no_glad.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		no_glad.add_theme_font_size_override("font_size", 16)
		picker_list.add_child(no_glad)
	
	# Retreat button at bottom
	var retreat_btn = _create_styled_button("Retreat to Ludus", Color(0.6, 0.2, 0.2))
	retreat_btn.pressed.connect(func(): SceneRouter.go_to_ludus())
	vbox.add_child(retreat_btn)

func _on_gladiator_picked(index: int) -> void:
	picker_overlay.queue_free()
	_start_combat_with(GameManager.roster[index])

# ======================== COMBAT LOGIC ========================

func _start_combat_with(fighter: Gladiator) -> void:
	# Set player sprite
	var player_tex = _get_texture_for_type(fighter.type)
	if player_tex:
		player_sprite.texture = player_tex
	player_sprite.modulate = Color.WHITE
	
	# Generate enemy based on day difficulty
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
	
	# Set enemy sprite (tinted red)
	var enemy_tex = _get_texture_for_type(enemy_data["type"])
	if enemy_tex:
		enemy_sprite.texture = enemy_tex
	enemy_sprite.modulate = Color(1.0, 0.6, 0.6)  # Red tint
	
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
	
	# Player
	player_name_label.text = "⚔ " + battle.player_gladiator.g_name
	player_hp_bar.max_value = battle.get_player_max_hp()
	player_hp_bar.value = battle.get_player_hp()
	player_hp_label.text = "%d / %d" % [battle.get_player_hp(), battle.get_player_max_hp()]
	if battle.player_block > 0:
		player_block_label.text = "🛡 %d" % battle.player_block
	else:
		player_block_label.text = ""
	
	# Enemy
	enemy_name_label.text = "💀 " + battle.enemy_name
	enemy_hp_bar.max_value = battle.get_enemy_max_hp()
	enemy_hp_bar.value = battle.get_enemy_hp()
	enemy_hp_label.text = "%d / %d" % [battle.get_enemy_hp(), battle.get_enemy_max_hp()]
	if battle.enemy_block > 0:
		enemy_block_label.text = "🛡 %d" % battle.enemy_block
	else:
		enemy_block_label.text = ""
	
	# Energy
	energy_label.text = "⚡ Energy: %d / %d" % [battle.energy, battle.max_energy]
	
	# Hand
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
	
	# Styled card appearance
	var style = StyleBoxFlat.new()
	var can_play = battle.can_play_card(index)
	
	if can_play:
		style.bg_color = Color(0.15, 0.15, 0.2, 0.95)
		style.border_color = Color(0.75, 0.6, 0.2, 0.8)
	else:
		style.bg_color = Color(0.1, 0.1, 0.1, 0.7)
		style.border_color = Color(0.3, 0.3, 0.3, 0.5)
	
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	btn.add_theme_stylebox_override("normal", style)
	
	var hover_style = style.duplicate()
	hover_style.border_color = Color(1, 0.85, 0.3)
	btn.add_theme_stylebox_override("hover", hover_style)
	
	# Card text
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

func _play_hit_flash(sprite: TextureRect) -> void:
	# Flash white then back
	var original_mod = sprite.modulate
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(2, 0.3, 0.3), 0.08)
	tween.tween_property(sprite, "modulate", original_mod, 0.15)
	
	# Shake
	var original_pos = sprite.position
	var shake_tween = create_tween()
	shake_tween.tween_property(sprite, "position", original_pos + Vector2(8, 0), 0.04)
	shake_tween.tween_property(sprite, "position", original_pos - Vector2(8, 0), 0.04)
	shake_tween.tween_property(sprite, "position", original_pos + Vector2(4, 0), 0.04)
	shake_tween.tween_property(sprite, "position", original_pos, 0.04)

func _play_dodge_anim(sprite: TextureRect) -> void:
	# Quick side-step
	var original_pos = sprite.position
	var tween = create_tween()
	tween.tween_property(sprite, "position", original_pos + Vector2(30, -10), 0.1)
	tween.tween_property(sprite, "position", original_pos, 0.15)
	
	# Flash transparent
	var mod_tween = create_tween()
	mod_tween.tween_property(sprite, "modulate:a", 0.3, 0.08)
	mod_tween.tween_property(sprite, "modulate:a", 1.0, 0.12)

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
	_update_all_ui()

func _on_damage_dealt(target: String, amount: int, blocked: int) -> void:
	if target == "enemy":
		if amount == 0:
			info_label.text = "%s dodged!" % battle.enemy_name
		else:
			info_label.text = "Dealt %d damage to %s!" % [amount, battle.enemy_name]
	elif target == "player":
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
		result_label.text = "🏆 VICTORY! 🏆\n+%d Gold" % reward_gold
		result_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		turn_label.text = "⚔ BATTLE WON ⚔"
	else:
		result_label.text = "💀 DEFEAT 💀\n%s has fallen..." % battle.player_gladiator.g_name
		result_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
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
