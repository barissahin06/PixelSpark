extends Control

## Main Menu — Roman-themed New Game / Load Game

const BG_TEX = preload("res://assets/ui/main_menu/Gemini_Generated_Image_uo220puo220puo22.png")
const SWORDS_TEX = preload("res://assets/ui/main_menu/Gemini_Generated_Image_6nnrog6nnrog6nnr.png")
const DIVIDER_GOLD_TEX = preload("res://assets/ui/main_menu/Gemini_Generated_Image_q9bhzqq9bhzqq9bh.png")
const DIVIDER_FOOTER_TEX = preload("res://assets/ui/main_menu/Gemini_Generated_Image_agju91agju91agju.png")
const BTN_FRAME_TEX = preload("res://assets/ui/main_menu/Gemini_Generated_Image_flgrsnflgrsnflgr.png")
const BTN_GREEN_TEX = preload("res://assets/ui/main_menu/Gemini_Generated_Image_4m9dl14m9dl14m9d.png")
const BTN_GOLD_TEX = preload("res://assets/ui/main_menu/Gemini_Generated_Image_o3gvceo3gvceo3gv.png")
const HOVER_GLOW_TEX = preload("res://assets/ui/main_menu/Gemini_Generated_Image_ft0xo0ft0xo0ft0x.png")

func _ready() -> void:
	custom_minimum_size = Vector2(800, 800)
	size = Vector2(800, 800)
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg = TextureRect.new()
	bg.texture = BG_TEX
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	
	# Title Area
	var title_box = HBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", 20)
	vbox.add_child(title_box)
	
	var title_vbox = VBoxContainer.new()
	title_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_child(title_vbox)
	
	var title = Label.new()
	title.text = "GLADIATOR LUDUS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	title_vbox.add_child(title)
	
	var subtitle = Label.new()
	subtitle.text = "Rise from the sands of the arena"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	title_vbox.add_child(subtitle)
	
	# Spacer
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)
	
	# Buttons
	var btn_vbox = VBoxContainer.new()
	btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_vbox.add_theme_constant_override("separation", 24)
	vbox.add_child(btn_vbox)
	
	var new_game_btn = _create_pixel_button("New Game", BTN_GREEN_TEX)
	new_game_btn.get_node("Button").pressed.connect(_on_new_game)
	btn_vbox.add_child(new_game_btn)
	
	var load_game_btn = _create_pixel_button("Load Game", BTN_GOLD_TEX)
	var load_actual_btn = load_game_btn.get_node("Button")
	load_actual_btn.pressed.connect(_on_load_game)
	if not SaveManager.has_save():
		load_actual_btn.disabled = true
		load_game_btn.get_node("Label").text = "Load Game (No Save)"
		load_game_btn.modulate = Color(0.5, 0.5, 0.5, 0.8)
	btn_vbox.add_child(load_game_btn)
	
	# Spacer
	var spacer2 = Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer2)

func _create_pixel_button(text: String, fill_tex: Texture2D) -> Control:
	var container = MarginContainer.new()
	container.custom_minimum_size = Vector2(300, 80)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var fill = TextureRect.new()
	fill.name = "Fill"
	fill.texture = fill_tex
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.modulate = Color.WHITE
	container.add_child(fill)
	
	var btn = TextureButton.new()
	btn.name = "Button"
	btn.texture_normal = BTN_FRAME_TEX
	btn.ignore_texture_size = true
	btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	container.add_child(btn)
	
	var l_margin = MarginContainer.new()
	l_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	container.add_child(l_margin)
	
	var lbl = Label.new()
	lbl.name = "Label"
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	l_margin.add_child(lbl)
	
	# Hover effect: brighten the fill texture
	btn.mouse_entered.connect(func(): fill.modulate = Color(1.3, 1.3, 1.2))
	btn.mouse_exited.connect(func(): fill.modulate = Color.WHITE)
	
	return container

func _on_new_game() -> void:
	GameManager.reset_run()
	SceneRouter.go_to_ludus()

func _on_load_game() -> void:
	if SaveManager.load_game():
		SceneRouter.go_to_ludus()
	else:
		print("Failed to load game!")
