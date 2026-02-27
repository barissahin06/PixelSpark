extends Node

func _ready() -> void:
	var route := GameData.config.initial_route
	if not SceneRouter.ROUTES.has(route):
		push_warning("Main: Unknown initial route '%s'. Falling back to 'ludus'." % route)
		route = "ludus"

	SceneRouter.go_to(route)
