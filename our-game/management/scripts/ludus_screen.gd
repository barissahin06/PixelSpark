extends Control

func _ready() -> void:
	$MarginContainer/VBoxContainer/GladiatorCountLabel.text = "Loaded gladiators: %d" % GameData.gladiators.size()

func _on_to_battle_button_pressed() -> void:
	SceneRouter.go_to_battle()
