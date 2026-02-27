extends Control

func _ready() -> void:
	$MarginContainer/VBoxContainer/CardCountLabel.text = "Loaded cards: %d" % GameData.cards.size()

func _on_to_ludus_button_pressed() -> void:
	SceneRouter.go_to_ludus()
