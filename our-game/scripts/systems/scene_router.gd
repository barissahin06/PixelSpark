extends Node

const ROUTES := {
	"ludus": "res://scenes/ui/screens/LudusScreen.tscn",
	"battle": "res://scenes/ui/screens/BattleScreen.tscn"
}

var current_route: String = ""

func go_to(route: String) -> void:
	var scene_path := str(ROUTES.get(route, ""))
	if scene_path.is_empty():
		push_error("SceneRouter: Unknown route '%s'." % route)
		return

	get_tree().call_deferred("change_scene_to_file", scene_path)

	current_route = route

func go_to_ludus() -> void:
	go_to("ludus")

func go_to_battle() -> void:
	go_to("battle")
