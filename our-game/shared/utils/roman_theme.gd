class_name RomanTheme
extends RefCounted

## Consistent Roman-era color palette used across all UI.
## Red = blood, Cream = marble, Green = laurels, Gold = arena sand.

# --- Core Colors ---
const BLOOD_RED := Color(0.54, 0.1, 0.1)
const BLOOD_RED_BRIGHT := Color(0.75, 0.15, 0.12)
const MARBLE_CREAM := Color(0.96, 0.9, 0.8)
const MARBLE_LIGHT := Color(0.92, 0.85, 0.72)
const VICTORY_GREEN := Color(0.18, 0.35, 0.12)
const VICTORY_GREEN_BRIGHT := Color(0.3, 0.55, 0.2)
const ARENA_SAND := Color(0.77, 0.64, 0.35)
const ARENA_SAND_DARK := Color(0.45, 0.35, 0.2)
const ROMAN_GOLD := Color(0.83, 0.63, 0.09)
const ROMAN_GOLD_BRIGHT := Color(1.0, 0.85, 0.3)
const DARK_STONE := Color(0.1, 0.09, 0.08)
const DARK_STONE_MID := Color(0.14, 0.12, 0.1)
const WARM_BRONZE := Color(0.55, 0.41, 0.08)
const TEXT_LIGHT := Color(0.96, 0.9, 0.8)
const TEXT_DIM := Color(0.65, 0.55, 0.4)
const TEXT_GOLD := Color(1.0, 0.85, 0.3)

# --- Background ---
const BG_DARK := Color(0.08, 0.06, 0.04)
const BG_PANEL := Color(0.12, 0.1, 0.08, 0.95)
const BG_MODAL := Color(0.0, 0.0, 0.0, 0.85)

# --- UI Helpers ---

static func create_panel_style(bg_override: Color = BG_PANEL) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_override
	style.border_color = WARM_BRONZE
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(12)
	return style

static func create_card_panel_style(bg_override: Color = BG_PANEL) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_override
	style.border_color = ROMAN_GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(6)
	return style

static func create_row_style(highlight: bool = false) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	if highlight:
		style.bg_color = Color(0.18, 0.14, 0.08, 0.9)
		style.border_color = ROMAN_GOLD.darkened(0.3)
	else:
		style.bg_color = Color(0.14, 0.11, 0.08, 0.9)
		style.border_color = WARM_BRONZE.darkened(0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(8)
	return style

static func style_button(btn: Button, color: Color) -> void:
	btn.add_theme_font_size_override("font_size", 15)
	
	var normal = StyleBoxFlat.new()
	normal.bg_color = color
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)
	
	var hover = normal.duplicate()
	hover.bg_color = color.lightened(0.15)
	hover.border_color = ROMAN_GOLD
	hover.set_border_width_all(1)
	btn.add_theme_stylebox_override("hover", hover)
	
	var pressed = normal.duplicate()
	pressed.bg_color = color.darkened(0.2)
	btn.add_theme_stylebox_override("pressed", pressed)

static func style_title(label: Label, size: int = 24) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_GOLD)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

static func style_subtitle(label: Label, size: int = 14) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", TEXT_DIM)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

static func create_roman_button(text: String, icon_path: String = "", min_size: Vector2 = Vector2(160, 50)) -> Button:
	## Creates a Roman-themed button with stone background, gold border, and optional icon.
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = min_size
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", MARBLE_CREAM)
	
	if icon_path != "" and ResourceLoader.exists(icon_path):
		btn.icon = load(icon_path)
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.expand_icon = true
	
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0.14, 0.11, 0.08, 0.92)
	normal.border_color = WARM_BRONZE
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(6)
	normal.set_content_margin_all(8)
	btn.add_theme_stylebox_override("normal", normal)
	
	var hover = normal.duplicate()
	hover.bg_color = Color(0.18, 0.14, 0.1, 0.95)
	hover.border_color = ROMAN_GOLD_BRIGHT
	hover.set_border_width_all(3)
	btn.add_theme_stylebox_override("hover", hover)
	
	var pressed = normal.duplicate()
	pressed.bg_color = Color(0.08, 0.06, 0.04, 0.95)
	pressed.border_color = ROMAN_GOLD
	btn.add_theme_stylebox_override("pressed", pressed)
	
	var disabled_style = normal.duplicate()
	disabled_style.bg_color = Color(0.1, 0.08, 0.06, 0.5)
	disabled_style.border_color = Color(0.25, 0.2, 0.12, 0.4)
	btn.add_theme_stylebox_override("disabled", disabled_style)
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.35, 0.25))
	
	return btn
