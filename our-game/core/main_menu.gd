extends Control

## Main Menu — Roman-themed New Game / Load Game

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = RomanTheme.BG_DARK
	add_child(bg)
	
	# Decorative top/bottom sand bars
	var top_bar = ColorRect.new()
	top_bar.color = RomanTheme.WARM_BRONZE.darkened(0.5)
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.custom_minimum_size.y = 6
	top_bar.size.y = 6
	add_child(top_bar)
	
	var bot_bar = ColorRect.new()
	bot_bar.color = RomanTheme.WARM_BRONZE.darkened(0.5)
	bot_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bot_bar.custom_minimum_size.y = 6
	bot_bar.size.y = 6
	add_child(bot_bar)
	
	# Center container
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	
	# Title
	var title = Label.new()
	title.text = "⚔ GLADIATOR LUDUS ⚔"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", RomanTheme.ROMAN_GOLD_BRIGHT)
	vbox.add_child(title)
	
	# Subtitle
	var subtitle = Label.new()
	subtitle.text = "Rise from the sands of the arena"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", RomanTheme.TEXT_DIM)
	vbox.add_child(subtitle)
	
	# Decorative line
	var line = ColorRect.new()
	line.color = RomanTheme.WARM_BRONZE
	line.custom_minimum_size = Vector2(200, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(line)
	
	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 20
	vbox.add_child(spacer)
	
	# New Game button
	var new_game_btn = _create_menu_button("New Game", RomanTheme.VICTORY_GREEN)
	new_game_btn.pressed.connect(_on_new_game)
	vbox.add_child(new_game_btn)
	
	# Load Game button
	var load_game_btn = _create_menu_button("Load Game", RomanTheme.WARM_BRONZE)
	load_game_btn.pressed.connect(_on_load_game)
	if not SaveManager.has_save():
		load_game_btn.disabled = true
		load_game_btn.text = "Load Game (No Save)"
	vbox.add_child(load_game_btn)
	
	# Bottom spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size.y = 30
	vbox.add_child(spacer2)
	
	# Version label
	var version = Label.new()
	version.text = "v0.2.0 — 'Sands of Fortune'"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.add_theme_font_size_override("font_size", 11)
	version.add_theme_color_override("font_color", Color(0.35, 0.3, 0.22))
	vbox.add_child(version)

func _create_menu_button(text: String, color: Color) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 55)
	
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = RomanTheme.ROMAN_GOLD.darkened(0.2)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(10)
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", RomanTheme.MARBLE_CREAM)
	
	var hover = style.duplicate()
	hover.bg_color = color.lightened(0.15)
	hover.border_color = RomanTheme.ROMAN_GOLD_BRIGHT
	btn.add_theme_stylebox_override("hover", hover)
	
	var pressed = style.duplicate()
	pressed.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed)
	
	var disabled_style = style.duplicate()
	disabled_style.bg_color = Color(0.15, 0.12, 0.1, 0.5)
	disabled_style.border_color = Color(0.3, 0.25, 0.15, 0.3)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	
	return btn

func _on_new_game() -> void:
	GameManager.reset_run()
	SceneRouter.go_to_ludus()

func _on_load_game() -> void:
	if SaveManager.load_game():
		SceneRouter.go_to_ludus()
	else:
		print("Failed to load game!")
